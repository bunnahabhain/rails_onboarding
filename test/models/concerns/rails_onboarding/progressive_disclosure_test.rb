# frozen_string_literal: true

require "test_helper"

module RailsOnboarding
  # The concern had no behavioural coverage at all, and the dummy User did not
  # include it - which is why a :milestone_based reveal that could never fire
  # went unnoticed. A reveal that does not happen is indistinguishable from one
  # whose condition is not met yet, so nothing surfaced the bug at runtime
  # either.
  class ProgressiveDisclosureTest < ActiveSupport::TestCase
    setup do
      @user = User.create!(email: "disclosure@example.com", revealed_features: [])

      @original_enabled = RailsOnboarding.configuration.progressive_disclosure_enabled
      @original_features = RailsOnboarding.configuration.progressive_features
      RailsOnboarding.configuration.progressive_disclosure_enabled = true
    end

    teardown do
      RailsOnboarding.configuration.progressive_disclosure_enabled = @original_enabled
      RailsOnboarding.configuration.progressive_features = @original_features
    end

    test "a milestone-based feature is revealed once the milestone is held" do
      RailsOnboarding.configuration.progressive_features = [
        { key: :advanced_planning, reveal_condition: :milestone_based,
          required_milestone: :onboarding_completed, title: "Advanced Planning" }
      ]

      assert_not @user.feature_ready?(RailsOnboarding.configuration.progressive_features.first),
        "nothing is held yet, so the feature is not ready"

      @user.update!(milestones_achieved: [ { "key" => "onboarding_completed", "achieved_at" => Time.current.iso8601 } ])

      assert @user.feature_ready?(RailsOnboarding.configuration.progressive_features.first),
        "the milestone is held, so the feature should be ready to reveal"
      assert_equal [ "advanced_planning" ], @user.reveal_ready_features!
      assert @user.feature_revealed?(:advanced_planning)
    end

    test "a milestone-based feature is not revealed for a different milestone" do
      RailsOnboarding.configuration.progressive_features = [
        { key: :advanced_planning, reveal_condition: :milestone_based,
          required_milestone: :onboarding_completed, title: "Advanced Planning" }
      ]
      @user.update!(milestones_achieved: [ { "key" => "welcome_completed", "achieved_at" => Time.current.iso8601 } ])

      assert_empty @user.reveal_ready_features!
      assert_not @user.feature_revealed?(:advanced_planning)
    end

    test "a milestone-based feature with no required_milestone is never ready" do
      feature = { key: :vague, reveal_condition: :milestone_based, title: "Vague" }
      @user.update!(milestones_achieved: [ { "key" => "onboarding_completed", "achieved_at" => Time.current.iso8601 } ])

      assert_not @user.feature_ready?(feature)
    end

    test "a time-based feature is ready only once the delay has elapsed" do
      feature = { key: :later, reveal_condition: :time_based, delay: 7.days, title: "Later" }

      @user.update!(created_at: 1.day.ago)
      assert_not @user.feature_ready?(feature)

      @user.update!(created_at: 8.days.ago)
      assert @user.feature_ready?(feature)
    end

    test "revealing is idempotent and records the key once" do
      RailsOnboarding.configuration.progressive_features = [
        { key: :advanced_planning, reveal_condition: :milestone_based,
          required_milestone: :onboarding_completed, title: "Advanced Planning" }
      ]
      @user.update!(milestones_achieved: [ { "key" => "onboarding_completed", "achieved_at" => Time.current.iso8601 } ])

      assert_equal [ "advanced_planning" ], @user.reveal_ready_features!
      assert_empty @user.reveal_ready_features!, "a second pass has nothing left to reveal"
      assert_equal 1, @user.all_revealed_features.count("advanced_planning")
    end

    test "everything reads as revealed when progressive disclosure is off" do
      RailsOnboarding.configuration.progressive_disclosure_enabled = false

      assert @user.feature_revealed?(:anything_at_all),
        "with the feature off, nothing should be hidden from anyone"
    end
  end
end
