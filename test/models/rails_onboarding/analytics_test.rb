require "test_helper"

module RailsOnboarding
  class AnalyticsTest < ActiveSupport::TestCase
    def setup
      @user1 = User.create!(email: "user1@example.com", created_at: 2.hours.ago)
      @user2 = User.create!(email: "user2@example.com", created_at: 1.hour.ago)
      @user3 = User.create!(email: "user3@example.com", created_at: 30.minutes.ago)
      
      @yesterday = 1.day.ago
      @today = Time.current
      @date_range = @yesterday..@today
      
      # Skip all tests if analytics table doesn't exist
      skip "Analytics table not available" unless RailsOnboarding::AnalyticsEvent.table_exists?
    end

    test "onboarding_completion_rate calculates correctly" do
      # User 1: Started and completed
      AnalyticsEvent.create!(user: @user1, event_type: AnalyticsEvent::ONBOARDING_STARTED, occurred_at: @yesterday)
      AnalyticsEvent.create!(user: @user1, event_type: AnalyticsEvent::ONBOARDING_COMPLETED, occurred_at: @today)
      
      # User 2: Started but not completed
      AnalyticsEvent.create!(user: @user2, event_type: AnalyticsEvent::ONBOARDING_STARTED, occurred_at: @yesterday)
      
      # User 3: Started and skipped
      AnalyticsEvent.create!(user: @user3, event_type: AnalyticsEvent::ONBOARDING_STARTED, occurred_at: @yesterday)
      AnalyticsEvent.create!(user: @user3, event_type: AnalyticsEvent::ONBOARDING_SKIPPED, occurred_at: @today)

      rate = Analytics.onboarding_completion_rate(date_range: @date_range)
      assert_equal 33.33, rate # 1 completed out of 3 started
    end

    test "onboarding_skip_rate calculates correctly" do
      # User 1: Started and completed
      AnalyticsEvent.create!(user: @user1, event_type: AnalyticsEvent::ONBOARDING_STARTED, occurred_at: @yesterday)
      AnalyticsEvent.create!(user: @user1, event_type: AnalyticsEvent::ONBOARDING_COMPLETED, occurred_at: @today)
      
      # User 2: Started and skipped
      AnalyticsEvent.create!(user: @user2, event_type: AnalyticsEvent::ONBOARDING_STARTED, occurred_at: @yesterday)
      AnalyticsEvent.create!(user: @user2, event_type: AnalyticsEvent::ONBOARDING_SKIPPED, occurred_at: @today)

      rate = Analytics.onboarding_skip_rate(date_range: @date_range)
      assert_equal 50.0, rate # 1 skipped out of 2 started
    end

    test "average_completion_time calculates correctly" do
      # User 1: 60 seconds
      AnalyticsEvent.create!(
        user: @user1, 
        event_type: AnalyticsEvent::ONBOARDING_COMPLETED,
        properties: { completion_time_seconds: 60 },
        occurred_at: @today
      )
      
      # User 2: 120 seconds
      AnalyticsEvent.create!(
        user: @user2,
        event_type: AnalyticsEvent::ONBOARDING_COMPLETED,
        properties: { completion_time_seconds: 120 },
        occurred_at: @today
      )

      avg_time = Analytics.average_completion_time(date_range: @date_range)
      assert_equal 90.0, avg_time # (60 + 120) / 2
    end

    test "step_completion_rates calculates correctly" do
      # User 1: Started onboarding
      AnalyticsEvent.create!(user: @user1, event_type: AnalyticsEvent::ONBOARDING_STARTED, occurred_at: @yesterday)
      
      # User 2: Started onboarding
      AnalyticsEvent.create!(user: @user2, event_type: AnalyticsEvent::ONBOARDING_STARTED, occurred_at: @yesterday)
      
      # Both completed welcome step
      AnalyticsEvent.create!(
        user: @user1,
        event_type: AnalyticsEvent::ONBOARDING_STEP_COMPLETED,
        properties: { step_name: "welcome" },
        occurred_at: @today
      )
      AnalyticsEvent.create!(
        user: @user2,
        event_type: AnalyticsEvent::ONBOARDING_STEP_COMPLETED,
        properties: { step_name: "welcome" },
        occurred_at: @today
      )
      
      # Only user 1 completed profile step
      AnalyticsEvent.create!(
        user: @user1,
        event_type: AnalyticsEvent::ONBOARDING_STEP_COMPLETED,
        properties: { step_name: "profile" },
        occurred_at: @today
      )

      rates = Analytics.step_completion_rates(date_range: @date_range)
      assert_equal 100.0, rates["welcome"] # 2 out of 2
      assert_equal 50.0, rates["profile"] # 1 out of 2
    end

    test "tooltip_engagement_rate calculates correctly" do
      # 3 tooltips shown
      3.times do |i|
        AnalyticsEvent.create!(
          user: @user1,
          event_type: AnalyticsEvent::TOOLTIP_SHOWN,
          properties: { tooltip_feature: "feature_#{i}" },
          occurred_at: @today
        )
      end
      
      # 1 tooltip clicked
      AnalyticsEvent.create!(
        user: @user1,
        event_type: AnalyticsEvent::TOOLTIP_CLICKED,
        properties: { tooltip_feature: "feature_0" },
        occurred_at: @today
      )

      rate = Analytics.tooltip_engagement_rate(date_range: @date_range)
      assert_equal 33.33, rate # 1 clicked out of 3 shown
    end

    test "funnel_analysis provides comprehensive funnel data" do
      # User 1: Complete onboarding
      AnalyticsEvent.create!(user: @user1, event_type: AnalyticsEvent::ONBOARDING_STARTED, occurred_at: @yesterday)
      AnalyticsEvent.create!(
        user: @user1,
        event_type: AnalyticsEvent::ONBOARDING_STEP_COMPLETED,
        properties: { step_name: "welcome" },
        occurred_at: @today
      )
      AnalyticsEvent.create!(user: @user1, event_type: AnalyticsEvent::ONBOARDING_COMPLETED, occurred_at: @today)

      # User 2: Partial onboarding
      AnalyticsEvent.create!(user: @user2, event_type: AnalyticsEvent::ONBOARDING_STARTED, occurred_at: @yesterday)
      AnalyticsEvent.create!(
        user: @user2,
        event_type: AnalyticsEvent::ONBOARDING_STEP_COMPLETED,
        properties: { step_name: "welcome" },
        occurred_at: @today
      )

      funnel = Analytics.funnel_analysis(date_range: @date_range)

      assert_equal 2, funnel[:total_started]
      assert_equal 50.0, funnel[:overall_completion_rate] # 1 completed out of 2 started

      welcome_step = funnel[:steps].find { |s| s[:step_name].to_s == "welcome" }
      assert_not_nil welcome_step, "Should find welcome step in funnel results"
      assert_equal 100.0, welcome_step[:retention_rate] # 2 out of 2
    end

    test "daily_summary provides correct counts" do
      date = Date.current
      
      # Create events for today
      AnalyticsEvent.create!(user: @user1, event_type: AnalyticsEvent::ONBOARDING_STARTED, occurred_at: date.beginning_of_day)
      AnalyticsEvent.create!(user: @user1, event_type: AnalyticsEvent::ONBOARDING_COMPLETED, occurred_at: date.end_of_day)
      AnalyticsEvent.create!(user: @user2, event_type: AnalyticsEvent::TOOLTIP_SHOWN, occurred_at: date.noon)
      AnalyticsEvent.create!(user: @user2, event_type: AnalyticsEvent::MILESTONE_ACHIEVED, occurred_at: date.noon)
      
      # Create event for yesterday (should not be included)
      AnalyticsEvent.create!(user: @user3, event_type: AnalyticsEvent::ONBOARDING_STARTED, occurred_at: 1.day.ago)

      summary = Analytics.daily_summary(date: date)
      
      assert_equal date, summary[:date]
      assert_equal 1, summary[:onboarding_started]
      assert_equal 1, summary[:onboarding_completed]
      assert_equal 0, summary[:onboarding_skipped]
      assert_equal 1, summary[:tooltips_shown]
      assert_equal 0, summary[:tooltips_clicked]
      assert_equal 1, summary[:milestones_achieved]
    end

    test "tooltip_metrics_by_feature provides detailed breakdown" do
      # Feature 1: 2 shown, 1 clicked, 0 dismissed
      2.times do
        AnalyticsEvent.create!(
          user: @user1,
          event_type: AnalyticsEvent::TOOLTIP_SHOWN,
          properties: { tooltip_feature: "feature1" },
          occurred_at: @today
        )
      end
      AnalyticsEvent.create!(
        user: @user1,
        event_type: AnalyticsEvent::TOOLTIP_CLICKED,
        properties: { tooltip_feature: "feature1" },
        occurred_at: @today
      )
      
      # Feature 2: 1 shown, 0 clicked, 1 dismissed
      AnalyticsEvent.create!(
        user: @user2,
        event_type: AnalyticsEvent::TOOLTIP_SHOWN,
        properties: { tooltip_feature: "feature2" },
        occurred_at: @today
      )
      AnalyticsEvent.create!(
        user: @user2,
        event_type: AnalyticsEvent::TOOLTIP_DISMISSED,
        properties: { tooltip_feature: "feature2" },
        occurred_at: @today
      )

      metrics = Analytics.tooltip_metrics_by_feature(date_range: @date_range)
      
      feature1_metrics = metrics.find { |m| m[:feature] == "feature1" }
      assert_equal 2, feature1_metrics[:shown]
      assert_equal 1, feature1_metrics[:clicked]
      assert_equal 0, feature1_metrics[:dismissed]
      assert_equal 50.0, feature1_metrics[:engagement_rate]
      
      feature2_metrics = metrics.find { |m| m[:feature] == "feature2" }
      assert_equal 1, feature2_metrics[:shown]
      assert_equal 0, feature2_metrics[:clicked]
      assert_equal 1, feature2_metrics[:dismissed]
      assert_equal 0.0, feature2_metrics[:engagement_rate]
    end

    test "handles empty data gracefully" do
      assert_equal 0.0, Analytics.onboarding_completion_rate
      assert_equal 0.0, Analytics.onboarding_skip_rate
      assert_equal 0.0, Analytics.average_completion_time
      assert_equal({}, Analytics.step_completion_rates)
      assert_equal 0.0, Analytics.tooltip_engagement_rate
      assert_equal({}, Analytics.milestone_achievement_rates)
    end
  end
end