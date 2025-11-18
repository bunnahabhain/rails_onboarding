# frozen_string_literal: true

module RailsOnboarding
  module Admin
    # Admin users controller
    # Manage and view user onboarding progress
    class UsersController < BaseController
      def index
        @users = filtered_users.page(params[:page]).per(params[:per_page] || 25)
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

      def bulk_action
        action = params[:bulk_action]
        user_ids = params[:user_ids] || []

        case action
        when 'reset_onboarding'
          bulk_reset_onboarding(user_ids)
        when 'complete_onboarding'
          bulk_complete_onboarding(user_ids)
        else
          flash[:alert] = "Invalid bulk action"
        end

        redirect_to admin_users_path
      end

      private

      def filtered_users
        users = user_class.all

        # Filter by onboarding status
        if params[:status].present?
          users = case params[:status]
          when 'completed'
            users.where(onboarding_completed: true)
          when 'in_progress'
            users.where(onboarding_completed: false).where.not(onboarding_current_step: nil)
          when 'not_started'
            users.where(onboarding_current_step: nil, onboarding_completed: false)
          when 'skipped'
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
        if params[:search].present?
          search_term = "%#{params[:search]}%"
          users = if user_class.column_names.include?('email')
            users.where("email LIKE ? OR id::text LIKE ?", search_term, search_term)
          else
            users.where("id::text LIKE ?", search_term)
          end
        end

        # Sort
        sort_column = params[:sort] || 'created_at'
        sort_direction = params[:direction] || 'desc'

        if user_class.column_names.include?(sort_column)
          users = users.order("#{sort_column} #{sort_direction}")
        else
          users = users.order(created_at: :desc)
        end

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
            type: 'user_created',
            timestamp: @user.created_at,
            description: 'User account created'
          }
        end

        if defined?(RailsOnboarding::AnalyticsEvent)
          @user_events.each do |event|
            timeline << {
              type: event.event_type,
              timestamp: event.created_at,
              description: format_event_description(event),
              metadata: event.metadata
            }
          end
        end

        if @user_milestones.any?
          @user_milestones.each do |achievement|
            timeline << {
              type: 'milestone_achieved',
              timestamp: achievement.achieved_at,
              description: "Achieved milestone: #{achievement.milestone.title}",
              metadata: { points: achievement.milestone.points }
            }
          end
        end

        timeline.sort_by { |item| item[:timestamp] }.reverse
      end

      def format_event_description(event)
        case event.event_type
        when 'onboarding_started'
          'Started onboarding'
        when 'step_started'
          "Started step: #{event.metadata['step']}"
        when 'step_completed'
          "Completed step: #{event.metadata['step']}"
        when 'onboarding_completed'
          'Completed onboarding'
        when 'onboarding_skipped'
          'Skipped onboarding'
        when 'tooltip_shown'
          "Tooltip shown: #{event.metadata['tooltip_id']}"
        when 'tooltip_dismissed'
          "Tooltip dismissed: #{event.metadata['tooltip_id']}"
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
