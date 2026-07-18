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
      assert_equal "/rails_onboarding/onboarding", path
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

    test "needs_onboarding? returns false when on onboarding page" do
      @controller.request.path = "/rails_onboarding/onboarding"
      assert_not @controller.needs_onboarding?
    end

    test "helper_methods are defined" do
      assert TestController.method_defined?(:needs_onboarding?)
      assert TestController.method_defined?(:onboarding_path)
    end

    # ===== :path-based steps =====

    def with_steps(steps)
      original = RailsOnboarding.configuration
      RailsOnboarding.reset_configuration!
      RailsOnboarding.configure { |config| config.steps = steps }
      yield
    ensure
      RailsOnboarding.instance_variable_set(:@configuration, original)
    end

    test "needs_onboarding? is false on the current step's own page" do
      with_steps([ { name: :welcome, title: "Welcome", path: :new_profile_path } ]) do
        @controller.request.path = "/profile/new"
        assert_not @controller.needs_onboarding?
      end
    end

    test "needs_onboarding? stays true on unrelated pages when the step has a path" do
      with_steps([ { name: :welcome, title: "Welcome", path: :new_profile_path } ]) do
        @controller.request.path = "/somewhere/else"
        assert @controller.needs_onboarding?
      end
    end

    test "step page loop guard ignores query strings from proc paths" do
      steps = [ { name: :welcome, title: "Welcome", path: -> { main_app.new_profile_path(from: "onboarding") } } ]
      with_steps(steps) do
        @controller.request.path = "/profile/new"
        assert_not @controller.needs_onboarding?
      end
    end

    test "step page loop guard tolerates unresolvable paths" do
      with_steps([ { name: :welcome, title: "Welcome", path: :bogus_route_path } ]) do
        @controller.request.path = "/profile/new"
        assert_nothing_raised do
          assert @controller.needs_onboarding?
        end
      end
    end

    # ===== advance_onboarding! =====

    test "advance_onboarding! completes the matching current step" do
      assert @controller.advance_onboarding!(:welcome)
      assert_equal "profile", @user.reload.onboarding_current_step
    end

    test "advance_onboarding! is a no-op for a step that is not current" do
      assert_not @controller.advance_onboarding!(:profile)
      assert_equal "welcome", @user.reload.onboarding_current_step
    end

    test "advance_onboarding! is a no-op when onboarding is completed" do
      @user.update!(onboarding_completed: true)
      assert_not @controller.advance_onboarding!(:welcome)
    end

    test "advance_onboarding! is a no-op when onboarding was skipped" do
      @user.update!(onboarding_skipped: true)
      assert_not @controller.advance_onboarding!(:welcome)
    end

    test "advance_onboarding! is a no-op without a signed-in user" do
      @controller.current_user = nil
      assert_not @controller.advance_onboarding!(:welcome)
    end
  end
end
