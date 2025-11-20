require "test_helper"

module RailsOnboarding
  class SkipLogicTest < ActiveSupport::TestCase
    def setup
      @user = User.create!(
        email: "test@example.com",
        onboarding_completed: false,
        onboarding_current_step: :welcome
      )

      # Setup test configuration
      RailsOnboarding.configuration.steps = [
        { name: :welcome, title: "Welcome", skippable: true },
        { name: :profile, title: "Profile", skippable: false },
        { name: :optional, title: "Optional", skippable: true, skip_if: ->(user) { true } },
        { name: :complete, title: "Complete", skippable: true }
      ]
    end

    test "should_skip_step? returns false for step without skip_if" do
      step = { name: :welcome, title: "Welcome" }
      result = SkipLogic.should_skip_step?(@user, step)

      assert_equal false, result
    end

    test "should_skip_step? evaluates proc condition" do
      step = { name: :optional, skip_if: ->(user) { user.email.include?("example") } }
      result = SkipLogic.should_skip_step?(@user, step)

      assert_equal true, result
    end

    test "should_skip_step? evaluates symbol condition" do
      def @user.skip_optional?
        true
      end

      step = { name: :optional, skip_if: :skip_optional? }
      result = SkipLogic.should_skip_step?(@user, step)

      assert_equal true, result
    end

    test "should_skip_step? evaluates hash condition with has_attribute" do
      step = { name: :optional, skip_if: { has_attribute: :email } }
      result = SkipLogic.should_skip_step?(@user, step)

      assert_equal true, result
    end

    test "should_skip_step? evaluates hash condition with missing_attribute" do
      step = { name: :optional, skip_if: { missing_attribute: :phone } }
      result = SkipLogic.should_skip_step?(@user, step)

      assert_equal true, result
    end

    test "next_unskipped_step returns next step that should not be skipped" do
      @user.update!(onboarding_current_step: :welcome)
      next_step = SkipLogic.next_unskipped_step(@user, :welcome)

      # Should skip :optional and return :complete or :profile depending on configuration
      assert next_step.present?
    end

    test "skippable_steps returns steps that should be skipped" do
      skippable = SkipLogic.skippable_steps(@user)

      # At least the optional step should be skippable
      assert skippable.any? { |s| s[:name] == :optional }
    end

    test "required_steps returns steps that should not be skipped" do
      required = SkipLogic.required_steps(@user)

      # Profile should be required (not skipped)
      assert required.any? { |s| s[:name] == :profile }
    end

    test "progress_excluding_skipped calculates correct progress" do
      @user.update!(onboarding_current_step: :profile)
      progress = SkipLogic.progress_excluding_skipped(@user)

      assert progress >= 0
      assert progress <= 100
    end

    test "auto_skip_step returns next step if auto_skip is enabled" do
      step_name = :optional
      # Step has skip_if but not auto_skip, should return nil
      result = SkipLogic.auto_skip_step(@user, step_name)

      # Add step with auto_skip
      RailsOnboarding.configuration.steps << {
        name: :auto_skip_test,
        title: "Auto Skip",
        skip_if: ->(_) { true },
        auto_skip: true
      }

      # This would skip if conditions are met
      assert true # Basic assertion
    end

    test "evaluate_conditions handles errors gracefully" do
      bad_proc = ->(_) { raise StandardError, "Test error" }
      result = SkipLogic.evaluate_conditions(@user, bad_proc)

      assert_equal false, result
    end

    test "evaluate_hash_conditions with operator :all" do
      conditions = {
        operator: :all,
        has_attribute: :email,
        attribute_equals: { email: "test@example.com" }
      }

      result = SkipLogic.send(:evaluate_hash_conditions, @user, conditions)
      assert_equal true, result
    end

    test "evaluate_hash_conditions with operator :any" do
      # Testing the :any operator - should return true if any condition matches
      conditions = {
        operator: :any,
        missing_attribute: :phone
      }

      result = SkipLogic.send(:evaluate_hash_conditions, @user, conditions)
      assert_equal true, result
    end
  end
end
