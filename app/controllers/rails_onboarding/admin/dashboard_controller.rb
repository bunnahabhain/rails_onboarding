# frozen_string_literal: true

module RailsOnboarding
  module Admin
    # Admin dashboard controller
    # Provides analytics overview and metrics visualization
    class DashboardController < BaseController
      def index
        @date_range = params[:date_range] || "30"
        @start_date = date_range_start(@date_range)
        @end_date = Time.current

        load_analytics_data
        load_milestone_data
        load_ab_test_data
      end

      private

      def load_analytics_data
        return unless defined?(RailsOnboarding::AnalyticsEvent)

        # Overall metrics
        @total_users = user_class.count
        @onboarding_started = user_class.where.not(onboarding_current_step: nil).count
        @onboarding_completed = user_class.where(onboarding_completed: true).count
        @completion_rate = calculate_completion_rate

        # Time-based metrics
        @avg_completion_time = calculate_avg_completion_time
        @recent_completions = recent_completions_count

        # Step funnel
        @step_funnel = calculate_step_funnel

        # Recent events
        @recent_events = RailsOnboarding::AnalyticsEvent
          .where("created_at >= ?", @start_date)
          .order(created_at: :desc)
          .limit(10)

        # Daily completion trend
        @daily_completions = daily_completion_trend
      rescue StandardError => e
        logger.error "Error loading analytics: #{e.message}"
        @analytics_error = e.message
      end

      # Milestones have no table of their own. They are *defined* in the host's
      # initializer (RailsOnboarding.configuration.milestones) and *awarded*
      # onto the user record: `milestones_achieved` holds a serialized array of
      # {"key", "achieved_at"} hashes, with `milestone_points` and
      # `last_milestone_at` beside it.
      #
      # This panel used to query a RailsOnboarding::Milestone model and a
      # rails_onboarding_milestone_achievements join table. Neither has ever
      # existed in the engine, so the `defined?` guard was always false and the
      # whole section returned early - silently, while real achievements piled
      # up on the users table. Guard on the two things actually required
      # instead: milestones being switched on, and a user model that speaks
      # Onboardable.
      def load_milestone_data
        return unless RailsOnboarding.configuration.enable_milestones
        return unless user_class.method_defined?(:achieved_milestone_entries)

        @total_milestones = RailsOnboarding.configuration.milestones.size

        stats = milestone_achievement_stats
        @milestones_awarded = stats[:awarded]
        @milestone_points_awarded = stats[:points]
        @users_with_milestones = stats[:users]
        @top_milestones = stats[:top]
      rescue StandardError => e
        logger.error "Error loading milestone data: #{e.message}"
        @milestone_error = e.message
      end

      def load_ab_test_data
        ab_tests = RailsOnboarding.configuration.ab_tests || {}

        @total_tests = ab_tests.size
        @active_tests = ab_tests.count { |_name, config| config[:enabled] }
      rescue StandardError => e
        logger.error "Error loading A/B test data: #{e.message}"
        @ab_test_error = e.message
      end

      def calculate_completion_rate
        return 0 if @onboarding_started.zero?
        (@onboarding_completed.to_f / @onboarding_started * 100).round(2)
      end

      def calculate_avg_completion_time
        completed_users = user_class
          .where(onboarding_completed: true)
          .where.not(onboarding_completed_at: nil)
          .where("onboarding_completed_at >= ?", @start_date)

        return 0 if completed_users.empty?

        total_time = completed_users.sum do |user|
          next 0 unless user.created_at && user.onboarding_completed_at
          (user.onboarding_completed_at - user.created_at).to_i
        end

        (total_time / completed_users.count / 3600.0).round(2) # Convert to hours
      end

      def recent_completions_count
        user_class
          .where(onboarding_completed: true)
          .where("onboarding_completed_at >= ?", @start_date)
          .count
      end

      def calculate_step_funnel
        steps = RailsOnboarding.configuration.steps
        funnel = []

        # A true entry funnel: count distinct users who *reached* each step
        # (step_started), not just those who completed it. `properties` is a
        # JSON-serialized text column, so filter by step in Ruby rather than
        # with a DB JSON operator (not portable to text/MySQL).
        step_events = if defined?(RailsOnboarding::AnalyticsEvent)
          RailsOnboarding::AnalyticsEvent
            .where(event_type: RailsOnboarding::AnalyticsEvent::ONBOARDING_STEP_STARTED)
            .where("created_at >= ?", @start_date)
            .to_a
        else
          []
        end

        steps.each do |step|
          step_name = step[:name].to_s
          users_reached = step_events
            .select { |e| e.properties.to_h["step_name"].to_s == step_name }
            .map(&:user_id).uniq.count

          funnel << {
            step: step_name,
            title: step[:title],
            users: users_reached,
            percentage: @onboarding_started.zero? ? 0 : (users_reached.to_f / @onboarding_started * 100).round(2)
          }
        end

        funnel
      end

      def daily_completion_trend
        return [] unless defined?(RailsOnboarding::AnalyticsEvent)

        days = 7
        trend = []

        days.times do |i|
          date = i.days.ago.to_date
          completions = user_class
            .where(onboarding_completed: true)
            .where("DATE(onboarding_completed_at) = ?", date)
            .count

          trend.unshift({ date: date.strftime("%m/%d"), count: completions })
        end

        trend
      end

      # Roll every user's achievements up into the numbers the panel shows.
      #
      # `milestones_achieved` is a serialized text column, so this cannot be a
      # GROUP BY - the rows have to be loaded and counted in Ruby. Two things
      # keep that honest: only users who hold at least one achievement are
      # loaded, and only the three columns needed are selected. It is still
      # O(users-with-milestones), which is fine into the tens of thousands and
      # is the price of milestones not having a table. An install that outgrows
      # it should denormalise achievements into their own table rather than
      # paginate this.
      #
      # Achievements are counted within the dashboard's selected date range,
      # like every other time-based figure here. Undated achievements are
      # counted regardless: a legacy string entry on a record with no
      # last_milestone_at is still a real award, and dropping it would repeat
      # in miniature exactly the bug this method replaces.
      def milestone_achievement_stats
        counts = Hash.new(0)
        awarded = 0
        points = 0
        users = 0

        achievement_holders.find_each do |user|
          keys = user.achieved_milestone_entries.filter_map do |key, achieved_at|
            key if achieved_at.nil? || achieved_at >= @start_date
          end
          next if keys.empty?

          users += 1
          awarded += keys.size
          keys.each do |key|
            counts[key] += 1
            points += RailsOnboarding.configuration.milestone_by_key(key)&.dig(:points).to_i
          end
        end

        { awarded: awarded, points: points, users: users, top: top_milestones_from(counts) }
      end

      # Users holding at least one achievement. The empty cases are the column's
      # default (NULL) and a serialized empty array, which is what
      # reset_onboarding! leaves behind.
      #
      # The empty-string checks go through raw SQL on purpose: `milestones_achieved`
      # is a serialized attribute, so `where.not(milestones_achieved: "[]")` would
      # hand "[]" to the JSON coder and compare against the string '"[]"' instead.
      # A bare nil is safe - the serialized type passes it straight through.
      def achievement_holders
        column = "#{user_class.quoted_table_name}.milestones_achieved"

        user_class
          .where.not(milestones_achieved: nil)
          .where("#{column} NOT IN (?, ?)", "", "[]")
          .select(:id, :milestones_achieved, :last_milestone_at)
      end

      # The five most-awarded milestones, resolved against the configuration for
      # their display copy. A key with no matching configuration entry is one the
      # host has since renamed or removed; show it under its raw key rather than
      # dropping it, so the leftover data is visible and can be cleaned up.
      def top_milestones_from(counts)
        counts.sort_by { |key, count| [ -count, key ] }.first(5).map do |key, count|
          milestone = RailsOnboarding.configuration.milestone_by_key(key)

          {
            name: key,
            title: milestone&.dig(:title) || key.to_s.humanize,
            icon: milestone&.dig(:icon),
            configured: !milestone.nil?,
            count: count
          }
        end
      end

      def date_range_start(range)
        case range
        when "7"
          7.days.ago
        when "30"
          30.days.ago
        when "90"
          90.days.ago
        when "all"
          100.years.ago
        else
          30.days.ago
        end
      end

      def user_class
        @user_class ||= RailsOnboarding.configuration.user_class_name.constantize
      end
    end
  end
end
