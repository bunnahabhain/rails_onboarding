require "test_helper"

class AnalyticsIntegrationTest < ActionDispatch::IntegrationTest
  def setup
    @user = User.create!(email: "test@example.com", created_at: 2.hours.ago)
    
    # Skip all tests if analytics table doesn't exist
    skip "Analytics table not available" unless RailsOnboarding::AnalyticsEvent.table_exists?
  end

  test "analytics system works end-to-end" do
    session_id = "test_session_123"
    
    # Start onboarding
    @user.start_onboarding!(session_id: session_id)
    
    assert_equal 1, RailsOnboarding::AnalyticsEvent.count
    event = RailsOnboarding::AnalyticsEvent.last
    assert_equal RailsOnboarding::AnalyticsEvent::ONBOARDING_STARTED, event.event_type
    assert_equal @user, event.user
    assert_equal session_id, event.session_id
    
    # Complete a step
    @user.update!(onboarding_current_step: :welcome)
    @user.complete_onboarding_step!(:welcome, session_id: session_id, time_spent: 30)
    
    # Should have step completion and milestone events
    assert_equal 3, RailsOnboarding::AnalyticsEvent.count # start + step + milestone
    
    step_event = RailsOnboarding::AnalyticsEvent.where(event_type: RailsOnboarding::AnalyticsEvent::ONBOARDING_STEP_COMPLETED).last
    assert_equal "welcome", step_event.properties["step_name"]
    assert_equal 30, step_event.properties["time_spent_seconds"]
    
    # Check milestone achievement
    milestone_event = RailsOnboarding::AnalyticsEvent.where(event_type: RailsOnboarding::AnalyticsEvent::MILESTONE_ACHIEVED).last
    assert_equal "welcome_completed", milestone_event.properties["milestone_key"]
    
    # Track tooltip interaction
    @user.mark_tooltip_shown!("getting_started", session_id: session_id)
    @user.track_tooltip_interaction!("getting_started", "clicked", session_id: session_id)
    
    assert_equal 5, RailsOnboarding::AnalyticsEvent.count
    
    tooltip_events = RailsOnboarding::AnalyticsEvent.where(event_type: [
      RailsOnboarding::AnalyticsEvent::TOOLTIP_SHOWN,
      RailsOnboarding::AnalyticsEvent::TOOLTIP_CLICKED
    ])
    assert_equal 2, tooltip_events.count
    
    # Complete onboarding
    @user.update!(onboarding_current_step: :explore) # Last step
    @user.complete_onboarding_step!(:explore, session_id: session_id, time_spent: 45)
    
    # Should trigger completion
    assert @user.onboarding_completed?
    completion_event = RailsOnboarding::AnalyticsEvent.where(event_type: RailsOnboarding::AnalyticsEvent::ONBOARDING_COMPLETED).last
    assert_not_nil completion_event
    assert_equal false, completion_event.properties["was_skipped"]
  end

  test "analytics reporting methods work" do
    # Create test data
    user1 = User.create!(email: "user1@example.com")
    user2 = User.create!(email: "user2@example.com")
    
    yesterday = 1.day.ago
    today = Time.current
    
    # User 1: Complete onboarding
    RailsOnboarding::AnalyticsEvent.create!(
      user: user1,
      event_type: RailsOnboarding::AnalyticsEvent::ONBOARDING_STARTED,
      occurred_at: yesterday
    )
    RailsOnboarding::AnalyticsEvent.create!(
      user: user1,
      event_type: RailsOnboarding::AnalyticsEvent::ONBOARDING_COMPLETED,
      properties: { completion_time_seconds: 300 },
      occurred_at: today
    )
    
    # User 2: Skip onboarding
    RailsOnboarding::AnalyticsEvent.create!(
      user: user2,
      event_type: RailsOnboarding::AnalyticsEvent::ONBOARDING_STARTED,
      occurred_at: yesterday
    )
    RailsOnboarding::AnalyticsEvent.create!(
      user: user2,
      event_type: RailsOnboarding::AnalyticsEvent::ONBOARDING_SKIPPED,
      occurred_at: today
    )
    
    date_range = yesterday..today
    
    # Test completion rate
    completion_rate = RailsOnboarding::Analytics.onboarding_completion_rate(date_range: date_range)
    assert_equal 50.0, completion_rate # 1 out of 2
    
    # Test skip rate
    skip_rate = RailsOnboarding::Analytics.onboarding_skip_rate(date_range: date_range)
    assert_equal 50.0, skip_rate # 1 out of 2
    
    # Test average completion time
    avg_time = RailsOnboarding::Analytics.average_completion_time(date_range: date_range)
    assert_equal 300.0, avg_time
    
    # Test daily summary
    summary = RailsOnboarding::Analytics.daily_summary(date: Date.current)
    assert_equal 1, summary[:onboarding_completed]
    assert_equal 1, summary[:onboarding_skipped]
  end

  test "analytics can be disabled" do
    RailsOnboarding.configuration.enable_analytics = false
    
    assert_no_difference "RailsOnboarding::AnalyticsEvent.count" do
      @user.start_onboarding!
      @user.complete_onboarding_step!(:welcome)
      @user.mark_tooltip_shown!("test")
      @user.achieve_milestone!(:early_adopter)
    end
  ensure
    RailsOnboarding.configuration.enable_analytics = true
  end
end