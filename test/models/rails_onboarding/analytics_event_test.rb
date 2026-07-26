require "test_helper"

module RailsOnboarding
  class AnalyticsEventTest < ActiveSupport::TestCase
    def setup
      @user = User.create!(email: "test@example.com", created_at: 2.hours.ago)
      @session_id = "test_session_123"
      
      # Skip all tests if analytics table doesn't exist
      skip "Analytics table not available" unless RailsOnboarding::AnalyticsEvent.table_exists?
    end

    test "creates analytics event with valid attributes" do
      event = AnalyticsEvent.create!(
        user: @user,
        event_type: AnalyticsEvent::ONBOARDING_STARTED,
        properties: { test: "value" },
        session_id: @session_id,
        occurred_at: Time.current
      )

      assert event.persisted?
      assert_equal @user, event.user
      assert_equal AnalyticsEvent::ONBOARDING_STARTED, event.event_type
      assert_equal({ "test" => "value" }, event.properties)
      assert_equal @session_id, event.session_id
    end

    test "validates required fields" do
      event = AnalyticsEvent.new
      assert_not event.valid?
      assert_includes event.errors.attribute_names, :event_type
      assert_includes event.errors.attribute_names, :occurred_at
    end

    test "allows optional user" do
      event = AnalyticsEvent.create!(
        event_type: AnalyticsEvent::ONBOARDING_STARTED,
        occurred_at: Time.current
      )

      assert event.persisted?
      assert_nil event.user
    end

    test "serializes properties as JSON" do
      properties = { step_name: "welcome", step_index: 0, custom_data: [1, 2, 3] }
      event = AnalyticsEvent.create!(
        user: @user,
        event_type: AnalyticsEvent::ONBOARDING_STEP_COMPLETED,
        properties: properties,
        occurred_at: Time.current
      )

      event.reload
      assert_equal properties.stringify_keys, event.properties
    end

    test "scopes work correctly" do
      # Create test events
      AnalyticsEvent.create!(user: @user, event_type: AnalyticsEvent::ONBOARDING_STARTED, occurred_at: 1.day.ago)
      AnalyticsEvent.create!(user: @user, event_type: AnalyticsEvent::ONBOARDING_COMPLETED, occurred_at: Time.current)
      
      other_user = User.create!(email: "other@example.com")
      AnalyticsEvent.create!(user: other_user, event_type: AnalyticsEvent::ONBOARDING_STARTED, occurred_at: Time.current)

      # Test event type scope
      started_events = AnalyticsEvent.by_event_type(AnalyticsEvent::ONBOARDING_STARTED)
      assert_equal 2, started_events.count

      # Test user scope
      user_events = AnalyticsEvent.by_user(@user)
      assert_equal 2, user_events.count

      # Test date range scope
      today_events = AnalyticsEvent.by_date_range(Date.current.beginning_of_day, Date.current.end_of_day)
      assert_equal 2, today_events.count
    end

    test "track_event creates event when analytics enabled" do
      RailsOnboarding.configuration.enable_analytics = true

      assert_difference "AnalyticsEvent.count", 1 do
        AnalyticsEvent.track_event(
          user: @user,
          event_type: AnalyticsEvent::ONBOARDING_STARTED,
          properties: { test: "value" },
          session_id: @session_id
        )
      end
    end

    test "track_event does not create event when analytics disabled" do
      RailsOnboarding.configuration.enable_analytics = false

      assert_no_difference "AnalyticsEvent.count" do
        AnalyticsEvent.track_event(
          user: @user,
          event_type: AnalyticsEvent::ONBOARDING_STARTED,
          properties: { test: "value" },
          session_id: @session_id
        )
      end
    ensure
      RailsOnboarding.configuration.enable_analytics = true
    end

    test "track_onboarding_started creates correct event" do
      assert_difference "AnalyticsEvent.count", 1 do
        AnalyticsEvent.track_onboarding_started(user: @user, session_id: @session_id)
      end

      event = AnalyticsEvent.last
      assert_equal AnalyticsEvent::ONBOARDING_STARTED, event.event_type
      assert_equal @user, event.user
      assert_equal @session_id, event.session_id
      assert_includes event.properties.keys, "user_created_at"
      assert_includes event.properties.keys, "total_steps"
    end

    test "track_step_started creates correct event" do
      assert_difference "AnalyticsEvent.count", 1 do
        AnalyticsEvent.track_step_started(
          user: @user,
          step_name: :welcome,
          step_index: 0,
          session_id: @session_id
        )
      end

      event = AnalyticsEvent.last
      assert_equal AnalyticsEvent::ONBOARDING_STEP_STARTED, event.event_type
      assert_equal "welcome", event.properties["step_name"]
      assert_equal 0, event.properties["step_index"]
    end

    test "track_step_completed creates correct event" do
      assert_difference "AnalyticsEvent.count", 1 do
        AnalyticsEvent.track_step_completed(
          user: @user,
          step_name: :welcome,
          step_index: 0,
          time_spent: 30,
          session_id: @session_id
        )
      end

      event = AnalyticsEvent.last
      assert_equal AnalyticsEvent::ONBOARDING_STEP_COMPLETED, event.event_type
      assert_equal "welcome", event.properties["step_name"]
      assert_equal 0, event.properties["step_index"]
      assert_equal 30, event.properties["time_spent_seconds"]
    end

    test "track_tooltip_interaction creates correct event" do
      assert_difference "AnalyticsEvent.count", 1 do
        AnalyticsEvent.track_tooltip_interaction(
          user: @user,
          tooltip_feature: "getting_started",
          action: "clicked",
          session_id: @session_id
        )
      end

      event = AnalyticsEvent.last
      assert_equal AnalyticsEvent::TOOLTIP_CLICKED, event.event_type
      assert_equal "getting_started", event.properties["tooltip_feature"]
      assert_equal "clicked", event.properties["action"]
    end

    test "track_milestone_achieved creates correct event" do
      assert_difference "AnalyticsEvent.count", 1 do
        AnalyticsEvent.track_milestone_achieved(
          user: @user,
          milestone_key: :welcome_completed,
          points_earned: 10,
          session_id: @session_id
        )
      end

      event = AnalyticsEvent.last
      assert_equal AnalyticsEvent::MILESTONE_ACHIEVED, event.event_type
      assert_equal "welcome_completed", event.properties["milestone_key"]
      assert_equal 10, event.properties["points_earned"]
    end
  end
end