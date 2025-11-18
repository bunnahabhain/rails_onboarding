# frozen_string_literal: true

module RailsOnboarding
  module Admin
    # Admin dashboard controller
    # Provides analytics overview and metrics visualization
    class DashboardController < BaseController
      def index
        @date_range = params[:date_range] || '30'
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
          .where('created_at >= ?', @start_date)
          .order(created_at: :desc)
          .limit(10)

        # Daily completion trend
        @daily_completions = daily_completion_trend
      rescue StandardError => e
        logger.error "Error loading analytics: #{e.message}"
        @analytics_error = e.message
      end

      def load_milestone_data
        return unless defined?(RailsOnboarding::Milestone)

        @total_milestones = RailsOnboarding::Milestone.count
        @milestone_achievements = user_class
          .joins("LEFT JOIN rails_onboarding_milestone_achievements ON rails_onboarding_milestone_achievements.user_id = #{user_class.table_name}.id")
          .group("#{user_class.table_name}.id")
          .count
        @top_milestones = top_achieved_milestones
      rescue StandardError => e
        logger.error "Error loading milestone data: #{e.message}"
        @milestone_error = e.message
      end

      def load_ab_test_data
        return unless defined?(RailsOnboarding::AbTest)

        @active_tests = RailsOnboarding::AbTest.where(status: 'active').count
        @total_tests = RailsOnboarding::AbTest.count
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
          .where('onboarding_completed_at >= ?', @start_date)

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
          .where('onboarding_completed_at >= ?', @start_date)
          .count
      end

      def calculate_step_funnel
        steps = RailsOnboarding.configuration.steps
        funnel = []

        steps.each do |step|
          step_name = step[:name].to_s
          users_reached = if defined?(RailsOnboarding::AnalyticsEvent)
            RailsOnboarding::AnalyticsEvent
              .where(event_type: 'step_started')
              .where("metadata->>'step' = ?", step_name)
              .where('created_at >= ?', @start_date)
              .distinct
              .count(:user_id)
          else
            0
          end

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
            .where('DATE(onboarding_completed_at) = ?', date)
            .count

          trend.unshift({ date: date.strftime('%m/%d'), count: completions })
        end

        trend
      end

      def top_achieved_milestones
        return [] unless defined?(RailsOnboarding::Milestone)

        RailsOnboarding::Milestone
          .joins("LEFT JOIN rails_onboarding_milestone_achievements ON rails_onboarding_milestone_achievements.milestone_id = rails_onboarding_milestones.id")
          .group('rails_onboarding_milestones.id', 'rails_onboarding_milestones.name', 'rails_onboarding_milestones.title')
          .order('COUNT(rails_onboarding_milestone_achievements.id) DESC')
          .limit(5)
          .pluck('rails_onboarding_milestones.name', 'rails_onboarding_milestones.title', 'COUNT(rails_onboarding_milestone_achievements.id)')
          .map { |name, title, count| { name: name, title: title, count: count } }
      end

      def date_range_start(range)
        case range
        when '7'
          7.days.ago
        when '30'
          30.days.ago
        when '90'
          90.days.ago
        when 'all'
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
