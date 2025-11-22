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

    test "onboarding_skipped? returns true when skipped" do
      @user.update(onboarding_skipped: true)
      assert @user.onboarding_skipped?
    end

    test "onboarding_skipped? returns false when not skipped" do
      @user.update(onboarding_skipped: false)
      assert_not @user.onboarding_skipped?
    end

    # Step Navigation Tests
    test "current_onboarding_step returns current step hash" do
      @user.update(onboarding_current_step: "profile")
      step = @user.current_onboarding_step

      assert step.is_a?(Hash)
      assert_equal :profile, step[:name]
    end

    test "next_step returns next step hash" do
      @user.update(onboarding_current_step: "welcome")
      next_step = @user.next_step

      assert next_step.is_a?(Hash)
      expected_step = RailsOnboarding.configuration.steps[1][:name]
      assert_equal expected_step, next_step[:name]
    end

    test "next_step returns nil on last step" do
      last_step = RailsOnboarding.configuration.steps.last[:name]
      @user.update(onboarding_current_step: last_step.to_s)

      assert_nil @user.next_step
    end

    test "previous_step returns previous step hash" do
      @user.update(onboarding_current_step: "profile")
      prev_step = @user.previous_step

      assert prev_step.is_a?(Hash)
      expected_step = RailsOnboarding.configuration.steps[0][:name]
      assert_equal expected_step, prev_step[:name]
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

    # Step Advancement Tests
    test "complete_onboarding_step! moves to next step" do
      @user.update(onboarding_current_step: "welcome")
      @user.complete_onboarding_step!("welcome")

      expected_step = RailsOnboarding.configuration.steps[1][:name].to_s
      assert_equal expected_step, @user.onboarding_current_step
    end

    test "complete_onboarding_step! completes onboarding on last step" do
      last_step = RailsOnboarding.configuration.steps.last[:name]
      @user.update(onboarding_current_step: last_step.to_s)
      @user.complete_onboarding_step!(last_step)

      assert @user.onboarding_completed
      assert_not_nil @user.onboarding_completed_at
    end

    test "go_back! moves to previous step" do
      @user.update(onboarding_current_step: "profile")
      result = @user.go_back!

      assert result
      assert_equal "welcome", @user.onboarding_current_step
    end

    test "go_back! returns false on first step" do
      @user.update(onboarding_current_step: "welcome")
      result = @user.go_back!

      assert_not result
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
      assert @user.onboarding_completed
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

    test "reset_onboarding! resets onboarding state without starting" do
      @user.update(
        onboarding_completed: true,
        onboarding_current_step: "explore",
        onboarding_skipped: true
      )

      @user.reset_onboarding!

      assert_not @user.onboarding_completed
      assert_not @user.onboarding_skipped
      assert_nil @user.onboarding_current_step
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
    test "show_feature_tooltip? returns true for unseen tooltip" do
      assert @user.show_feature_tooltip?("dashboard_overview")
    end

    test "show_feature_tooltip? returns false for seen tooltip" do
      @user.mark_tooltip_shown!("feature_test")

      assert_not @user.show_feature_tooltip?("feature_test")
    end

    test "tooltip_shown? returns false for unseen tooltip" do
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

    # Milestone Tests
    test "milestone_achieved? returns false for new milestone" do
      assert_not @user.milestone_achieved?("test_milestone")
    end

    test "milestone_achieved? returns true for achieved milestone" do
      @user.update(milestones_achieved: [{ "key" => "completed_milestone", "achieved_at" => Time.current.iso8601 }])

      assert @user.milestone_achieved?("completed_milestone")
    end

    test "achieve_milestone! records milestone" do
      result = @user.achieve_milestone!("first_step")

      assert result
      assert @user.milestone_achieved?("first_step")
      assert @user.milestone_points > 0
    end

    test "achieve_milestone! does not duplicate milestones" do
      @user.achieve_milestone!("first_step")
      initial_points = @user.milestone_points

      result = @user.achieve_milestone!("first_step")

      assert_not result
      assert_equal initial_points, @user.milestone_points
    end

    test "achieved_milestones returns list of achieved milestone keys" do
      @user.achieve_milestone!("first_step")

      assert_includes @user.achieved_milestones, "first_step"
    end

    test "total_milestone_points returns points total" do
      @user.update(milestone_points: 150)

      assert_equal 150, @user.total_milestone_points
    end

    # Step completion check
    test "step_completed? returns true for completed steps" do
      @user.update(onboarding_current_step: "profile")

      assert @user.step_completed?("welcome")
    end

    test "step_completed? returns false for current and future steps" do
      @user.update(onboarding_current_step: "welcome")

      assert_not @user.step_completed?("welcome")
      assert_not @user.step_completed?("profile")
    end

    # Navigation
    test "go_to_step! moves to specified step" do
      @user.update(onboarding_current_step: "welcome")
      result = @user.go_to_step!("profile")

      assert result
      assert_equal "profile", @user.onboarding_current_step
    end

    test "go_to_step! returns false for invalid step" do
      result = @user.go_to_step!("nonexistent_step")

      assert_not result
    end

    # skip_onboarding_step tests
    test "skip_onboarding_step! moves to next step" do
      @user.update(onboarding_current_step: "welcome")
      @user.skip_onboarding_step!("welcome")

      expected_step = RailsOnboarding.configuration.steps[1][:name].to_s
      assert_equal expected_step, @user.onboarding_current_step
    end
  end
end
