require "test_helper"

module RailsOnboarding
  class OnboardableAnalyticsTest < ActiveSupport::TestCase
    def setup
      @user = User.create!(email: "test@example.com")
      @session_id = "test_session_123"
      
      # Skip all tests if analytics table doesn't exist
      skip "Analytics table not available" unless RailsOnboarding::AnalyticsEvent.table_exists?
    end

    test "start_onboarding! tracks analytics event" do
      assert_difference "AnalyticsEvent.count", 1 do
        @user.start_onboarding!(session_id: @session_id)
      end

      event = AnalyticsEvent.last
      assert_equal AnalyticsEvent::ONBOARDING_STARTED, event.event_type
      assert_equal @user, event.user
      assert_equal @session_id, event.session_id
    end

    test "complete_onboarding_step! tracks analytics event" do
      @user.update!(onboarding_current_step: :welcome)

      # Should create step completion event + milestone event
      assert_difference "AnalyticsEvent.count", 2 do
        @user.complete_onboarding_step!(:welcome, session_id: @session_id, time_spent: 30)
      end

      step_event = AnalyticsEvent.where(event_type: AnalyticsEvent::ONBOARDING_STEP_COMPLETED).last
      assert_equal AnalyticsEvent::ONBOARDING_STEP_COMPLETED, step_event.event_type
      assert_equal @user, step_event.user
      assert_equal @session_id, step_event.session_id
      assert_equal "welcome", step_event.properties["step_name"]
      assert_equal 0, step_event.properties["step_index"]
      assert_equal 30, step_event.properties["time_spent_seconds"]
    end

    test "complete_onboarding_step! achieves step milestones" do
      @user.update!(onboarding_current_step: :welcome)

      # Should trigger welcome milestone
      assert_difference "AnalyticsEvent.count", 2 do # step completion + milestone
        @user.complete_onboarding_step!(:welcome, session_id: @session_id)
      end

      # Check milestone achievement
      milestone_event = AnalyticsEvent.where(event_type: AnalyticsEvent::MILESTONE_ACHIEVED).last
      assert_equal "welcome_completed", milestone_event.properties["milestone_key"]
      assert @user.milestone_achieved?(:welcome_completed)
    end

    test "skip_onboarding_step! tracks analytics event" do
      @user.update!(onboarding_current_step: :welcome)

      assert_difference "AnalyticsEvent.count", 1 do
        @user.skip_onboarding_step!(:welcome, session_id: @session_id)
      end

      event = AnalyticsEvent.last
      assert_equal AnalyticsEvent::ONBOARDING_STEP_SKIPPED, event.event_type
      assert_equal @user, event.user
      assert_equal @session_id, event.session_id
      assert_equal "welcome", event.properties["step_name"]
      assert_equal 0, event.properties["step_index"]
    end

    test "complete_onboarding! tracks analytics event" do
      @user.update!(onboarding_current_step: :explore)

      assert_difference "AnalyticsEvent.count", 2 do # completion + milestone
        @user.complete_onboarding!(session_id: @session_id, completion_time: 300)
      end

      completion_event = AnalyticsEvent.where(event_type: AnalyticsEvent::ONBOARDING_COMPLETED).last
      assert_equal @user, completion_event.user
      assert_equal @session_id, completion_event.session_id
      assert_equal 300, completion_event.properties["completion_time_seconds"]
      assert_equal false, completion_event.properties["was_skipped"]

      # Check completion milestone
      milestone_event = AnalyticsEvent.where(event_type: AnalyticsEvent::MILESTONE_ACHIEVED).last
      assert_equal "onboarding_completed", milestone_event.properties["milestone_key"]
    end

    test "skip_onboarding! tracks analytics event as skipped" do
      assert_difference "AnalyticsEvent.count", 1 do
        @user.skip_onboarding!(session_id: @session_id)
      end

      event = AnalyticsEvent.last
      assert_equal AnalyticsEvent::ONBOARDING_SKIPPED, event.event_type
      assert_equal @user, event.user
      assert_equal @session_id, event.session_id
      assert_equal true, event.properties["was_skipped"]
    end

    test "mark_tooltip_shown! tracks analytics event" do
      assert_difference "AnalyticsEvent.count", 1 do
        @user.mark_tooltip_shown!("getting_started", session_id: @session_id)
      end

      event = AnalyticsEvent.last
      assert_equal AnalyticsEvent::TOOLTIP_SHOWN, event.event_type
      assert_equal @user, event.user
      assert_equal @session_id, event.session_id
      assert_equal "getting_started", event.properties["tooltip_feature"]
      assert_equal "shown", event.properties["action"]
    end

    test "track_tooltip_interaction! tracks different actions" do
      %w[shown clicked dismissed].each do |action|
        assert_difference "AnalyticsEvent.count", 1 do
          @user.track_tooltip_interaction!("test_feature", action, session_id: @session_id)
        end

        event = AnalyticsEvent.last
        expected_type = case action
                       when 'shown' then AnalyticsEvent::TOOLTIP_SHOWN
                       when 'clicked' then AnalyticsEvent::TOOLTIP_CLICKED
                       when 'dismissed' then AnalyticsEvent::TOOLTIP_DISMISSED
                       else 'tooltip_interaction'
                       end
        
        assert_equal expected_type, event.event_type
        assert_equal "test_feature", event.properties["tooltip_feature"]
        assert_equal action, event.properties["action"]
      end
    end

    test "achieve_milestone! tracks analytics event" do
      assert_difference "AnalyticsEvent.count", 1 do
        @user.achieve_milestone!(:early_adopter, session_id: @session_id)
      end

      event = AnalyticsEvent.last
      assert_equal AnalyticsEvent::MILESTONE_ACHIEVED, event.event_type
      assert_equal @user, event.user
      assert_equal @session_id, event.session_id
      assert_equal "early_adopter", event.properties["milestone_key"]
      assert_equal 100, event.properties["points_earned"]
    end

    test "analytics events are not created when analytics disabled" do
      RailsOnboarding.configuration.enable_analytics = false

      assert_no_difference "AnalyticsEvent.count" do
        @user.start_onboarding!(session_id: @session_id)
        @user.complete_onboarding_step!(:welcome, session_id: @session_id)
        @user.complete_onboarding!(session_id: @session_id)
        @user.mark_tooltip_shown!("test", session_id: @session_id)
        @user.achieve_milestone!(:early_adopter, session_id: @session_id)
      end
    ensure
      RailsOnboarding.configuration.enable_analytics = true
    end

    test "analytics events work without session_id" do
      assert_difference "AnalyticsEvent.count", 1 do
        @user.start_onboarding!
      end

      event = AnalyticsEvent.last
      assert_nil event.session_id
    end

    test "step milestone checking works correctly" do
      @user.update!(onboarding_current_step: :profile)

      # Should trigger profile milestone when completing profile step
      assert_difference "AnalyticsEvent.count", 2 do # step completion + milestone
        @user.complete_onboarding_step!(:profile, session_id: @session_id)
      end

      assert @user.milestone_achieved?(:profile_completed)
      
      milestone_event = AnalyticsEvent.where(event_type: AnalyticsEvent::MILESTONE_ACHIEVED).last
      assert_equal "profile_completed", milestone_event.properties["milestone_key"]
      assert_equal 25, milestone_event.properties["points_earned"] # From default config
    end

    test "completion milestone checking works correctly" do
      @user.update!(onboarding_current_step: :explore)

      # Complete the last step, which should trigger: step completion + step milestone + completion + completion milestone
      assert_difference "AnalyticsEvent.count", 3 do # step completion + completion + completion milestone
        @user.complete_onboarding_step!(:explore, session_id: @session_id)
      end

      assert @user.onboarding_completed?
      assert @user.milestone_achieved?(:onboarding_completed)
      
      completion_event = AnalyticsEvent.where(event_type: AnalyticsEvent::ONBOARDING_COMPLETED).last
      milestone_events = AnalyticsEvent.where(event_type: AnalyticsEvent::MILESTONE_ACHIEVED).order(:created_at)
      completion_milestone = milestone_events.find { |e| e.properties["milestone_key"] == "onboarding_completed" }
      
      assert_not_nil completion_milestone
      assert_equal "onboarding_completed", completion_milestone.properties["milestone_key"]
      assert_equal 50, completion_milestone.properties["points_earned"] # From default config
    end
  end
end