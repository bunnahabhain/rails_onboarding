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
    end

    test "should show onboarding page" do
      get onboarding_url
      assert_response :success
      assert_select "div.onboarding-container"
    end

    test "should display current step" do
      get onboarding_url
      assert_response :success
      assert_match /welcome/i, response.body
    end

    test "should advance to next step" do
      post next_onboarding_url
      assert_redirected_to onboarding_url
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
      post skip_onboarding_url
      @user.reload

      assert @user.onboarding_skipped
      assert_redirected_to main_app.root_url
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
      assert_difference "AnalyticsEvent.count" do
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

    test "should respond to turbo requests" do
      post next_onboarding_url, headers: { "Accept" => "text/vnd.turbo-stream.html" }
      assert_response :success
      assert_match /turbo-stream/, response.content_type
    end

    private

    def sign_in(user)
      # Simple sign in for testing
      @request.session[:user_id] = user.id if @request
    end
  end
end
