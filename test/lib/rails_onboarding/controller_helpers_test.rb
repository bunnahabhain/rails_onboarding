require "test_helper"

module RailsOnboarding
  class ControllerHelpersTest < ActiveSupport::TestCase
    class TestController < ActionController::Base
      include Rails.application.routes.url_helpers
      include RailsOnboarding::Engine.routes.url_helpers
      include RailsOnboarding::ControllerHelpers

      attr_accessor :current_user, :action_name

      def initialize
        super
        @action_name = "index"
      end

      def request
        @request ||= begin
          req = ActionDispatch::TestRequest.create
          req.host = "test.host"
          req.path = "/test"
          req
        end
      end
    end

    class SkippedController < TestController
      skip_onboarding_check only: [:profile]
    end

    setup do
      @user = User.create!(
        email: "controller_helpers_test_#{SecureRandom.hex(4)}@example.com",
        onboarding_completed: false,
        onboarding_current_step: "welcome",
        onboarding_skipped: false
      )

      @controller = TestController.new
      @controller.current_user = @user
    end

    teardown do
      @user&.destroy
    end

    test "needs_onboarding? returns true when user has not completed onboarding" do
      assert @controller.needs_onboarding?
    end

    test "needs_onboarding? returns false when onboarding is complete" do
      @user.update!(onboarding_completed: true)
      assert_not @controller.needs_onboarding?
    end

    test "needs_onboarding? returns false when onboarding is skipped" do
      @user.update!(onboarding_skipped: true)
      assert_not @controller.needs_onboarding?
    end

    test "needs_onboarding? returns false when current_user is nil" do
      @controller.current_user = nil
      assert_not @controller.needs_onboarding?
    end

    test "skip_onboarding_check excludes specified actions from onboarding check" do
      skipped_controller = SkippedController.new
      skipped_controller.current_user = @user

      # Profile action should be skipped
      skipped_controller.action_name = "profile"
      assert_not skipped_controller.needs_onboarding?

      # Index action should NOT be skipped
      skipped_controller.action_name = "index"
      assert skipped_controller.needs_onboarding?
    end

    test "skip_onboarding_for_action? returns correct value for configured actions" do
      assert SkippedController.skip_onboarding_for_action?(:profile)
      assert_not SkippedController.skip_onboarding_for_action?(:index)
      assert_not TestController.skip_onboarding_for_action?(:profile)
    end

    test "onboarding_path returns correct path" do
      path = @controller.onboarding_path
      assert_equal "/onboarding", path
    end

    test "needs_onboarding? returns false for XHR requests" do
      @controller.request.headers["X-Requested-With"] = "XMLHttpRequest"
      assert_not @controller.needs_onboarding?
    end

    test "needs_onboarding? returns false for JSON requests" do
      @controller.request.headers["Accept"] = "application/json"
      @controller.request.format = :json
      assert_not @controller.needs_onboarding?
    end

    test "needs_onboarding? returns false for API paths" do
      @controller.request.path = "/api/v1/something"
      assert_not @controller.needs_onboarding?
    end

    test "needs_onboarding? returns false when on onboarding page" do
      @controller.request.path = "/onboarding"
      assert_not @controller.needs_onboarding?
    end

    test "helper_methods are defined" do
      assert TestController.method_defined?(:needs_onboarding?)
      assert TestController.method_defined?(:onboarding_path)
    end
  end
end
