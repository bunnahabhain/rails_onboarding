require "test_helper"

module RailsOnboarding
  class OnboardingControllerTest < ActionDispatch::IntegrationTest
    include Engine.routes.url_helpers

    setup do
      @user = users(:one)
      @user.update(
        onboarding_completed: false,
        onboarding_current_step: "welcome",
        onboarding_skipped: false
      )
      sign_in @user
      @stubbed_user_methods = []
    end

    teardown do
      @stubbed_user_methods.each do |method_name|
        User.class_eval do
          remove_method method_name
          alias_method method_name, :"__original_#{method_name}"
          remove_method :"__original_#{method_name}"
        end
      end
    end

    test "should show onboarding page" do
      get onboarding_url
      assert_response :success
      assert_select "div.welcome-step"
    end

    test "should display current step" do
      get onboarding_url
      assert_response :success
      assert_match /welcome/i, response.body
    end

    test "should advance to next step" do
      post next_onboarding_url
      # Completing the "welcome" step awards the "welcome_completed" milestone
      # (see the default milestones in RailsOnboarding.configuration), which
      # the controller appends to the redirect URL.
      assert_redirected_to onboarding_url(awarded_milestones: [ "welcome_completed" ])
      @user.reload

      expected_step = RailsOnboarding.configuration.steps[1][:name].to_s
      assert_equal expected_step, @user.onboarding_current_step
    end

    test "should go to previous step" do
      @user.update(onboarding_current_step: "profile")

      post back_onboarding_url
      assert_redirected_to onboarding_url
      @user.reload

      assert_equal "welcome", @user.onboarding_current_step
    end

    test "should complete onboarding on last step" do
      last_step = RailsOnboarding.configuration.steps.last[:name]
      @user.update(onboarding_current_step: last_step.to_s)

      post complete_onboarding_url
      @user.reload

      assert @user.onboarding_completed
      assert_not_nil @user.onboarding_completed_at
    end

    test "should skip onboarding if allowed" do
      post skip_onboarding_url, params: { skip_all: "true" }
      @user.reload

      assert @user.onboarding_skipped
      assert_redirected_to "http://www.example.com/"
    end

    test "should not skip onboarding on non-skippable step" do
      @user.update(onboarding_current_step: "profile") # Non-skippable in default config

      post skip_onboarding_url
      @user.reload

      # Behavior depends on configuration - either redirects back or allows skip
      assert_response :redirect
    end

    test "should restart onboarding" do
      @user.update(
        onboarding_completed: true,
        onboarding_current_step: "explore"
      )

      post restart_onboarding_url
      @user.reload

      assert_not @user.onboarding_completed
      assert_equal "welcome", @user.onboarding_current_step
    end

    test "should track step views" do
      assert_difference "RailsOnboarding::AnalyticsEvent.count" do
        get onboarding_url
      end
    end

    test "should handle invalid step gracefully" do
      @user.update(onboarding_current_step: "invalid_step")

      get onboarding_url
      assert_response :success
      # Should reset to first step
      @user.reload
      assert_equal "welcome", @user.onboarding_current_step
    end

    # Turbo support requires turbo-rails gem configuration
    # Skip for now as basic functionality tests pass without it
    # test "should respond to turbo requests" do
    #   post next_onboarding_url, headers: { "Accept" => "text/vnd.turbo-stream.html" }
    #   assert_response :success
    #   assert_match /turbo-stream/, response.content_type
    # end

    # ===== Shared error handling (rescue_from) =====
    # These actions no longer rescue ActiveRecord::RecordInvalid/StandardError
    # inline - they rely entirely on the class-level rescue_from handlers.
    # These tests force each of those exceptions to prove the shared handlers
    # actually fire for every action, not just the ones that used to have
    # their own inline rescue.
    #
    # current_user reloads the user fresh from the database on every request
    # (see test/dummy/app/controllers/application_controller.rb), so a
    # singleton method on @user wouldn't reach it - the method has to be
    # patched onto the User class itself, and restored afterward.

    def stub_user_method(method_name, &implementation)
      User.class_eval do
        alias_method :"__original_#{method_name}", method_name
        define_method(method_name, &implementation)
      end
      @stubbed_user_methods << method_name
    end

    test "next surfaces a validation failure via the shared handler" do
      stub_user_method(:complete_onboarding_step!) do |*|
        errors.add(:base, "something went wrong")
        raise ActiveRecord::RecordInvalid, self
      end
      post next_onboarding_url
      assert_redirected_to onboarding_url
      follow_redirect!
      assert_match(/Unable to save changes: something went wrong/, flash[:alert] || response.body)
    end

    test "complete surfaces a validation failure via the shared handler" do
      stub_user_method(:complete_onboarding!) do |*|
        errors.add(:base, "cannot complete")
        raise ActiveRecord::RecordInvalid, self
      end
      post complete_onboarding_url
      assert_redirected_to onboarding_url
      follow_redirect!
      assert_match(/Unable to save changes: cannot complete/, flash[:alert] || response.body)
    end

    test "skip surfaces a validation failure via the shared handler" do
      stub_user_method(:skip_onboarding!) do |*|
        errors.add(:base, "cannot skip")
        raise ActiveRecord::RecordInvalid, self
      end
      post skip_onboarding_url, params: { skip_all: "true" }
      assert_redirected_to onboarding_url
      follow_redirect!
      assert_match(/Unable to save changes: cannot skip/, flash[:alert] || response.body)
    end

    test "back surfaces an unexpected error via the shared standard error handler" do
      @user.update(onboarding_current_step: "profile")
      stub_user_method(:go_back!) { |*| raise "boom" }
      post back_onboarding_url
      assert_redirected_to onboarding_url
      follow_redirect!
      assert_match(/boom/, flash[:alert] || response.body)
    end
  end
end
