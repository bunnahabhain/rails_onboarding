require "test_helper"

module RailsOnboarding
  class OnboardableTest < ActiveSupport::TestCase
    setup do
      @user = users(:one)
      @user.update(
        onboarding_completed: false,
        onboarding_current_step: "welcome",
        onboarding_skipped: false,
        feature_tooltips_shown: {}
      )
    end

    test "user includes onboardable concern" do
      assert @user.class.included_modules.include?(RailsOnboarding::Onboardable)
    end

    # Onboarding Status Tests
    test "needs_onboarding? returns true for incomplete onboarding" do
      assert @user.needs_onboarding?
    end

    test "needs_onboarding? returns false when completed" do
      @user.update(onboarding_completed: true)
      assert_not @user.needs_onboarding?
    end

    test "needs_onboarding? returns false when skipped" do
      @user.update(onboarding_skipped: true)
      assert_not @user.needs_onboarding?
    end

    test "onboarding_in_progress? returns true for active onboarding" do
      assert @user.onboarding_in_progress?
    end

    test "onboarding_in_progress? returns false when completed" do
      @user.update(onboarding_completed: true)
      assert_not @user.onboarding_in_progress?
    end

    # Step Navigation Tests
    test "current_step_index returns correct index" do
      @user.update(onboarding_current_step: "profile")
      index = @user.current_step_index

      expected_index = RailsOnboarding.configuration.steps.find_index do |s|
        s[:name].to_s == "profile"
      end

      assert_equal expected_index, index
    end

    test "next_step returns next step name" do
      @user.update(onboarding_current_step: "welcome")
      next_step = @user.next_step

      expected_step = RailsOnboarding.configuration.steps[1][:name]
      assert_equal expected_step, next_step
    end

    test "next_step returns nil on last step" do
      last_step = RailsOnboarding.configuration.steps.last[:name]
      @user.update(onboarding_current_step: last_step.to_s)

      assert_nil @user.next_step
    end

    test "previous_step returns previous step name" do
      @user.update(onboarding_current_step: "profile")
      prev_step = @user.previous_step

      expected_step = RailsOnboarding.configuration.steps[0][:name]
      assert_equal expected_step, prev_step
    end

    test "previous_step returns nil on first step" do
      @user.update(onboarding_current_step: "welcome")
      assert_nil @user.previous_step
    end

    test "can_go_back? returns true when not on first step" do
      @user.update(onboarding_current_step: "profile")
      assert @user.can_go_back?
    end

    test "can_go_back? returns false on first step" do
      @user.update(onboarding_current_step: "welcome")
      assert_not @user.can_go_back?
    end

    test "last_step? returns true on last step" do
      last_step = RailsOnboarding.configuration.steps.last[:name]
      @user.update(onboarding_current_step: last_step.to_s)

      assert @user.last_step?
    end

    test "last_step? returns false on non-last step" do
      @user.update(onboarding_current_step: "welcome")
      assert_not @user.last_step?
    end

    # Step Advancement Tests
    test "advance_step! moves to next step" do
      @user.update(onboarding_current_step: "welcome")
      @user.advance_step!

      expected_step = RailsOnboarding.configuration.steps[1][:name].to_s
      assert_equal expected_step, @user.onboarding_current_step
    end

    test "advance_step! completes onboarding on last step" do
      last_step = RailsOnboarding.configuration.steps.last[:name]
      @user.update(onboarding_current_step: last_step.to_s)
      @user.advance_step!

      assert @user.onboarding_completed
      assert_not_nil @user.onboarding_completed_at
    end

    test "go_back! moves to previous step" do
      @user.update(onboarding_current_step: "profile")
      @user.go_back!

      assert_equal "welcome", @user.onboarding_current_step
    end

    test "go_back! does nothing on first step" do
      @user.update(onboarding_current_step: "welcome")
      @user.go_back!

      assert_equal "welcome", @user.onboarding_current_step
    end

    # Completion Tests
    test "complete_onboarding! marks onboarding as complete" do
      @user.complete_onboarding!

      assert @user.onboarding_completed
      assert_not_nil @user.onboarding_completed_at
    end

    test "skip_onboarding! marks onboarding as skipped" do
      @user.skip_onboarding!

      assert @user.onboarding_skipped
    end

    test "restart_onboarding! resets onboarding state" do
      @user.update(
        onboarding_completed: true,
        onboarding_current_step: "explore"
      )

      @user.restart_onboarding!

      assert_not @user.onboarding_completed
      assert_equal "welcome", @user.onboarding_current_step
    end

    # Progress Tests
    test "onboarding_progress returns correct percentage" do
      # On first step (index 0) out of 4 steps
      @user.update(onboarding_current_step: "welcome")
      progress = @user.onboarding_progress

      expected_progress = (1.0 / RailsOnboarding.configuration.steps.length * 100).round
      assert_equal expected_progress, progress
    end

    test "onboarding_progress returns 100 when completed" do
      @user.update(onboarding_completed: true)

      assert_equal 100, @user.onboarding_progress
    end

    # Tooltip Tests
    test "tooltip_shown? returns false for new tooltip" do
      assert_not @user.tooltip_shown?("feature_new")
    end

    test "tooltip_shown? returns true for shown tooltip" do
      @user.mark_tooltip_shown!("feature_test")

      assert @user.tooltip_shown?("feature_test")
    end

    test "mark_tooltip_shown! records tooltip" do
      @user.mark_tooltip_shown!("feature_dashboard")

      assert @user.feature_tooltips_shown["feature_dashboard"]
    end

    test "reset_tooltips! clears all tooltips" do
      @user.update(feature_tooltips_shown: {
        "feature_1" => true,
        "feature_2" => true
      })

      @user.reset_tooltips!

      assert_empty @user.feature_tooltips_shown
    end

    # Milestone Tests
    test "milestone_achieved? returns false for new milestone" do
      assert_not @user.milestone_achieved?("test_milestone")
    end

    test "milestone_achieved? returns true for achieved milestone" do
      @user.update(onboarding_milestones_achieved: ["completed_milestone"])

      assert @user.milestone_achieved?("completed_milestone")
    end

    test "achieve_milestone! records milestone" do
      @user.achieve_milestone!("new_achievement", 100)

      assert_includes @user.onboarding_milestones_achieved, "new_achievement"
      assert_equal 100, @user.onboarding_milestone_points
    end

    test "achieve_milestone! does not duplicate milestones" do
      @user.achieve_milestone!("duplicate_test", 50)
      @user.achieve_milestone!("duplicate_test", 50)

      count = @user.onboarding_milestones_achieved.count("duplicate_test")
      assert_equal 1, count
      assert_equal 50, @user.onboarding_milestone_points
    end

    # Scopes Tests
    test "needs_onboarding scope returns users needing onboarding" do
      @user.update(onboarding_completed: false, onboarding_skipped: false)
      user_two = users(:two)
      user_two.update(onboarding_completed: true)

      users_needing = User.needs_onboarding

      assert_includes users_needing, @user
      assert_not_includes users_needing, user_two
    end

    test "onboarding_completed scope returns completed users" do
      @user.update(onboarding_completed: true)
      user_two = users(:two)
      user_two.update(onboarding_completed: false)

      completed_users = User.onboarding_completed

      assert_includes completed_users, @user
      assert_not_includes completed_users, user_two
    end

    test "onboarding_in_progress scope returns users in progress" do
      @user.update(onboarding_completed: false, onboarding_skipped: false)
      user_two = users(:two)
      user_two.update(onboarding_completed: true)

      in_progress = User.onboarding_in_progress

      assert_includes in_progress, @user
      assert_not_includes in_progress, user_two
    end
  end
end
