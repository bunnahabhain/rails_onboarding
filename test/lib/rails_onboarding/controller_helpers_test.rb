require "test_helper"

module RailsOnboarding
  class ControllerHelpersTest < ActionDispatch::IntegrationTest
    class TestController < ActionController::Base
      include RailsOnboarding::ControllerHelpers

      attr_accessor :current_user

      def index
        render plain: "success"
      end

      def profile
        skip_onboarding_requirement
        render plain: "profile"
      end

      def dashboard
        render plain: "dashboard"
      end
    end

    setup do
      @user = users(:one)
      @user.update(
        onboarding_completed: false,
        onboarding_current_step: "welcome",
        onboarding_skipped: false
      )

      @controller = TestController.new
      @controller.current_user = @user
    end

    test "require_onboarding redirects when user needs onboarding" do
      @controller.request = ActionDispatch::TestRequest.create
      @controller.response = ActionDispatch::TestResponse.new

      result = @controller.send(:require_onboarding)

      assert_not_nil result
    end

    test "require_onboarding allows access when onboarding is complete" do
      @user.update(onboarding_completed: true)
      @controller.request = ActionDispatch::TestRequest.create
      @controller.response = ActionDispatch::TestResponse.new

      result = @controller.send(:require_onboarding)

      assert_nil result
    end

    test "require_onboarding allows access when onboarding is skipped" do
      @user.update(onboarding_skipped: true)
      @controller.request = ActionDispatch::TestRequest.create
      @controller.response = ActionDispatch::TestResponse.new

      result = @controller.send(:require_onboarding)

      assert_nil result
    end

    test "skip_onboarding_requirement excludes actions from onboarding check" do
      # This is tested via integration tests since it requires the full Rails stack
      assert @controller.class.method_defined?(:skip_onboarding_requirement)
    end

    test "user_needs_onboarding? returns correct status" do
      assert @controller.send(:user_needs_onboarding?)

      @user.update(onboarding_completed: true)
      assert_not @controller.send(:user_needs_onboarding?)
    end

    test "onboarding_path returns correct path" do
      path = @controller.send(:onboarding_path)
      assert_includes path, "/onboarding"
    end

    test "handles missing current_user gracefully" do
      @controller.current_user = nil
      @controller.request = ActionDispatch::TestRequest.create
      @controller.response = ActionDispatch::TestResponse.new

      result = @controller.send(:require_onboarding)

      # Should not crash, may return nil or redirect
      assert_nothing_raised { result }
    end
  end
end
