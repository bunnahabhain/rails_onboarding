# frozen_string_literal: true

module RailsOnboarding
  module Admin
    # Admin users controller
    # Manage and view user onboarding progress
    class UsersController < BaseController
      MYSQL_ADAPTERS = %w[mysql2 trilogy mysql].freeze

      # The cast target for turning an integer id into something LIKE can match
      # is not portable. MySQL rejects `CAST(x AS TEXT)` outright as a syntax
      # error, and PostgreSQL accepts `CAST(x AS CHAR)` but reads it as
      # character(1), silently truncating the id to its first digit. SQLite
      # takes either. Defined on the class rather than as an instance method so
      # Rails doesn't expose it as a controller action.
      def self.id_cast_type_for(adapter_name)
        MYSQL_ADAPTERS.include?(adapter_name.to_s.downcase) ? "CHAR" : "TEXT"
      end

      def index
        @pagy, @users = paginate(filtered_users)
        @stats = calculate_stats
      end

      def show
        @user = user_class.find(params[:id])
        load_user_analytics
      end

      def reset_onboarding
        @user = user_class.find(params[:id])

        if @user.reset_onboarding!
          flash[:notice] = "Onboarding reset for user #{@user.id}"
          redirect_to admin_user_path(@user)
        else
          flash[:alert] = "Failed to reset onboarding"
          redirect_to admin_user_path(@user)
        end
      rescue StandardError => e
        flash[:alert] = "Error resetting onboarding: #{e.message}"
        redirect_to admin_users_path
      end

      def complete_onboarding
        @user = user_class.find(params[:id])

        if @user.complete_onboarding!
          flash[:notice] = "Onboarding completed for user #{@user.id}"
          redirect_to admin_user_path(@user)
        else
          flash[:alert] = "Failed to complete onboarding"
          redirect_to admin_user_path(@user)
        end
      rescue StandardError => e
        flash[:alert] = "Error completing onboarding: #{e.message}"
        redirect_to admin_users_path
      end

      def restart_onboarding
        @user = user_class.find(params[:id])

        @user.restart_onboarding!
        flash[:notice] = "Onboarding restarted for user #{@user.id}"
        redirect_to admin_user_path(@user)
      rescue StandardError => e
        flash[:alert] = "Error restarting onboarding: #{e.message}"
        redirect_to admin_users_path
      end

      def bulk_action
        action = params[:bulk_action]
        user_ids = params[:user_ids] || []

        case action
        when "reset_onboarding"
          bulk_reset_onboarding(user_ids)
        when "complete_onboarding"
          bulk_complete_onboarding(user_ids)
        else
          flash[:alert] = "Invalid bulk action"
        end

        redirect_to admin_users_path
      end

      # Exports every user matching the current filters, not just the page being
      # viewed - the button sits under the filter form, so "export what I'm
      # looking at" is the expectation. Deliberately unpaginated.
      # CSV is the only representation, so this deliberately doesn't respond_to:
      # a bare /admin/users/export would otherwise raise UnknownFormat, which the
      # admin error handler turns into a dashboard redirect with an alert.
      def export
        send_data generate_users_csv,
          filename: "onboarding_users_#{Date.current}.csv",
          type: "text/csv"
      end

      private

      def generate_users_csv
        require "csv"

        has_email = user_class.column_names.include?("email")

        CSV.generate do |csv|
          csv << csv_headers(has_email)
          # Iterated in the admin's chosen sort order, so no find_each here: it
          # would override the ORDER BY with a primary-key scan and silently
          # discard the sort the export was requested under.
          filtered_users.each { |user| csv << csv_row(user, has_email) }
        end
      end

      def csv_headers(has_email)
        headers = [ "ID" ]
        headers << "Email" if has_email
        headers + [ "Status", "Current Step", "Progress (%)", "Completed At", "Created At", "Last Activity" ]
      end

      def csv_row(user, has_email)
        row = [ user.id ]
        row << user.email if has_email
        row + [
          onboarding_status_label(user),
          user.onboarding_current_step,
          user.respond_to?(:onboarding_progress_percentage) ? user.onboarding_progress_percentage : nil,
          user.onboarding_completed_at&.iso8601,
          user.created_at&.iso8601,
          user.updated_at&.iso8601
        ]
      end

      # Mirrors the badge shown in the index table, including its precedence:
      # completed wins over skipped, which wins over in-progress.
      def onboarding_status_label(user)
        if user.onboarding_completed
          "Completed"
        elsif user.onboarding_skipped
          "Skipped"
        elsif user.onboarding_current_step
          "In Progress"
        else
          "Not Started"
        end
      end

      # The search box covers both email and ID. Each half contributes a scope
      # only when it could actually match; if neither can, the result is none
      # rather than an empty WHERE that would return every user.
      #
      # A host app can replace the whole thing via
      # `config.admin_user_search` - the built-in search is SQL, so it can't
      # see through an encrypted email column, and only the host app knows
      # what it's willing to trade to search one.
      def apply_search(users, term)
        custom = RailsOnboarding.configuration.admin_user_search
        return custom.call(users, term) if custom.respond_to?(:call)

        scopes = [ email_search_scope(users, term), id_search_scope(users, term) ].compact
        return users.none if scopes.empty?

        scopes.reduce { |combined, scope| combined.or(scope) }
      end

      # Rails' `encrypts` stores ciphertext in the column, so a LIKE against a
      # substring of the plaintext can't match - and worse, it happily matches
      # ciphertext that happens to contain the term, so an app with an
      # encrypted email column sees confident nonsense rather than nothing.
      # Deterministic encryption still supports exact equality (same plaintext
      # always encrypts to the same ciphertext), so fall back to that. With
      # non-deterministic encryption there is nothing to search on at all.
      def email_search_scope(users, term)
        return nil unless user_class.column_names.include?("email")

        case email_encryption
        when :none
          users.where("#{user_class.table_name}.email LIKE ?", "%#{term}%")
        when :deterministic
          users.where(email: term)
        end
      end

      def email_encryption
        return :none unless user_class.respond_to?(:encrypted_attributes)
        return :none unless user_class.encrypted_attributes&.include?(:email)

        type = user_class.type_for_attribute("email")
        type.respond_to?(:deterministic?) && type.deterministic? ? :deterministic : :non_deterministic
      end

      # An id renders as digits, so a non-numeric term can never be a substring
      # of one. Dropping the clause in that case keeps the common email search
      # off a full-table cast scan rather than merely being tidy.
      def id_search_scope(users, term)
        return nil unless term.match?(/\A\d+\z/)

        cast_type = self.class.id_cast_type_for(user_class.connection.adapter_name)
        users.where("CAST(#{user_class.table_name}.id AS #{cast_type}) LIKE ?", "%#{term}%")
      end

      def filtered_users
        users = user_class.all

        # Filter by onboarding status
        if params[:status].present?
          users = case params[:status]
          when "completed"
            users.where(onboarding_completed: true)
          when "in_progress"
            users.where(onboarding_completed: false).where.not(onboarding_current_step: nil)
          when "not_started"
            users.where(onboarding_current_step: nil, onboarding_completed: false)
          when "skipped"
            users.where(onboarding_skipped: true)
          else
            users
          end
        end

        # Filter by current step
        if params[:step].present?
          users = users.where(onboarding_current_step: params[:step])
        end

        # Search by email or ID
        users = apply_search(users, params[:search]) if params[:search].present?

        # Sort - sanitize column and direction to prevent SQL injection
        allowed_sort_columns = %w[email created_at updated_at onboarding_current_step onboarding_completed_at].freeze
        allowed_directions = %w[asc desc].freeze

        sort_column = params[:sort] || "created_at"
        sort_direction = params[:direction] || "desc"

        # Sanitize inputs
        sort_column = allowed_sort_columns.include?(sort_column) ? sort_column : "created_at"
        sort_direction = allowed_directions.include?(sort_direction.downcase) ? sort_direction.downcase : "desc"

        users = users.order("#{user_class.table_name}.#{sort_column} #{sort_direction}")

        users
      end

      def calculate_stats
        {
          total: user_class.count,
          completed: user_class.where(onboarding_completed: true).count,
          in_progress: user_class.where(onboarding_completed: false).where.not(onboarding_current_step: nil).count,
          not_started: user_class.where(onboarding_current_step: nil, onboarding_completed: false).count,
          skipped: user_class.where(onboarding_skipped: true).count
        }
      end

      def load_user_analytics
        return unless defined?(RailsOnboarding::AnalyticsEvent)

        @user_events = RailsOnboarding::AnalyticsEvent
          .where(user_id: @user.id)
          .order(created_at: :desc)
          .limit(50)

        @user_milestones = if defined?(RailsOnboarding::MilestoneAchievement)
          RailsOnboarding::MilestoneAchievement
            .where(user_id: @user.id)
            .includes(:milestone)
            .order(achieved_at: :desc)
        else
          []
        end

        @user_timeline = build_user_timeline
      end

      def build_user_timeline
        timeline = []

        if @user.created_at
          timeline << {
            type: "user_created",
            timestamp: @user.created_at,
            description: "User account created"
          }
        end

        if defined?(RailsOnboarding::AnalyticsEvent)
          @user_events.each do |event|
            timeline << {
              type: event.event_type,
              timestamp: event.created_at,
              description: format_event_description(event),
              metadata: event.properties.to_h
            }
          end
        end

        if @user_milestones.any?
          @user_milestones.each do |achievement|
            timeline << {
              type: "milestone_achieved",
              timestamp: achievement.achieved_at,
              description: "Achieved milestone: #{achievement.milestone.title}",
              metadata: { points: achievement.milestone.points }
            }
          end
        end

        # A nil timestamp would blow up the sort, and the timeline renders every
        # entry as a date - so drop entries we can't place in time at all.
        timeline.reject { |item| item[:timestamp].nil? }
          .sort_by { |item| item[:timestamp] }
          .reverse
      end

      def format_event_description(event)
        props = event.properties.to_h
        case event.event_type
        when RailsOnboarding::AnalyticsEvent::ONBOARDING_STARTED
          "Started onboarding"
        when RailsOnboarding::AnalyticsEvent::ONBOARDING_STEP_STARTED
          "Started step: #{props['step_name']}"
        when RailsOnboarding::AnalyticsEvent::ONBOARDING_STEP_COMPLETED
          "Completed step: #{props['step_name']}"
        when RailsOnboarding::AnalyticsEvent::ONBOARDING_STEP_SKIPPED
          "Skipped step: #{props['step_name']}"
        when RailsOnboarding::AnalyticsEvent::ONBOARDING_COMPLETED
          "Completed onboarding"
        when RailsOnboarding::AnalyticsEvent::ONBOARDING_SKIPPED
          "Skipped onboarding"
        when RailsOnboarding::AnalyticsEvent::TOOLTIP_SHOWN
          "Tooltip shown: #{props['tooltip_feature']}"
        when RailsOnboarding::AnalyticsEvent::TOOLTIP_DISMISSED
          "Tooltip dismissed: #{props['tooltip_feature']}"
        else
          event.event_type.humanize
        end
      end

      def bulk_reset_onboarding(user_ids)
        count = 0
        user_ids.each do |user_id|
          user = user_class.find_by(id: user_id)
          count += 1 if user&.reset_onboarding!
        end
        flash[:notice] = "Reset onboarding for #{count} user(s)"
      rescue StandardError => e
        flash[:alert] = "Error in bulk reset: #{e.message}"
      end

      def bulk_complete_onboarding(user_ids)
        count = 0
        user_ids.each do |user_id|
          user = user_class.find_by(id: user_id)
          count += 1 if user&.complete_onboarding!
        end
        flash[:notice] = "Completed onboarding for #{count} user(s)"
      rescue StandardError => e
        flash[:alert] = "Error in bulk complete: #{e.message}"
      end

      def user_class
        @user_class ||= RailsOnboarding.configuration.user_class_name.constantize
      end
    end
  end
end
