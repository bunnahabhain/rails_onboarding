require "test_helper"

module RailsOnboarding
  class MilestonesControllerTest < ActionDispatch::IntegrationTest
    include Engine.routes.url_helpers

    setup do
      @user = User.create!(
        email: "test@example.com",
        milestones_achieved: [],
        milestone_points: 0
      )
      sign_in @user

      # Enable milestones for these tests
      @original_milestones_setting = RailsOnboarding.configuration.enable_milestones
      RailsOnboarding.configuration.enable_milestones = true

      # Add test milestones. These are awarded on onboarding completion, so a
      # client can only claim them once the user has actually completed it -
      # the tests that expect an award mark the user completed first.
      @original_milestones = RailsOnboarding.configuration.milestones.dup
      RailsOnboarding.configuration.milestones = @original_milestones + [
        { key: :first_action_completed, title: "First Action", points: 50, trigger: :onboarding_completed },
        { key: :duplicate_test, title: "Duplicate Test", points: 25, trigger: :onboarding_completed },
        { key: :celebration_test, title: "Celebration Test", points: 30, trigger: :onboarding_completed },
        { key: :profile_completed, title: "Profile Complete", points: 20, trigger: :onboarding_completed }
      ]
    end

    teardown do
      RailsOnboarding.configuration.enable_milestones = @original_milestones_setting
      RailsOnboarding.configuration.milestones = @original_milestones if @original_milestones
    end

    test "should list all milestones" do
      get milestones_url, as: :json

      assert_response :success
      json_response = JSON.parse(response.body)
      assert json_response.is_a?(Array)
    end

    test "should get user progress" do
      @user.update(
        milestones_achieved: [ { "key" => "first_login", "achieved_at" => Time.current.iso8601 } ],
        milestone_points: 100
      )

      get progress_milestones_url, as: :json

      assert_response :success
      json_response = JSON.parse(response.body)
      assert_equal 100, json_response["points"]
      assert_includes json_response["achieved"], "first_login"
    end

    test "should check milestone achievement" do
      milestone_id = "profile_completed"
      @user.update(milestones_achieved: [ { "key" => milestone_id, "achieved_at" => Time.current.iso8601 } ])

      get check_milestone_url(id: milestone_id), as: :json

      assert_response :success
      json_response = JSON.parse(response.body)
      assert_equal true, json_response["achieved"]
    end

    test "should trigger milestone when the user is eligible" do
      @user.update!(onboarding_completed: true)

      assert_difference "@user.reload.milestone_points", 50 do
        post trigger_milestones_url, params: {
          milestone_id: "first_action_completed"
        }, as: :json
      end

      assert_response :success
    end

    test "should not award a milestone the user has not earned" do
      # The user has NOT completed onboarding, so is not eligible for this
      # milestone. A raw claim must not grant it.
      assert_no_difference "@user.reload.milestone_points" do
        post trigger_milestones_url, params: {
          milestone_id: "first_action_completed"
        }, as: :json
      end

      assert_response :forbidden
      json_response = JSON.parse(response.body)
      assert_equal false, json_response["success"]
      assert_not @user.reload.milestone_achieved?("first_action_completed")
    end

    test "achieve endpoint denies a milestone the user has not earned" do
      assert_no_difference "@user.reload.milestone_points" do
        post achieve_milestones_url, params: {
          milestone_key: "first_action_completed"
        }, as: :json
      end

      assert_response :forbidden
      assert_not @user.reload.milestone_achieved?("first_action_completed")
    end

    test "should not trigger same milestone twice" do
      @user.update!(onboarding_completed: true)
      milestone_id = "duplicate_test"

      # First trigger
      post trigger_milestones_url, params: { milestone_id: milestone_id }, as: :json
      first_points = @user.reload.milestone_points

      # Second trigger (should not add points again)
      post trigger_milestones_url, params: { milestone_id: milestone_id }, as: :json
      second_points = @user.reload.milestone_points

      assert_equal first_points, second_points
    end

    test "should get available milestones" do
      get available_milestones_url, as: :json

      assert_response :success
      json_response = JSON.parse(response.body)
      assert json_response.is_a?(Array)

      # Should only return unachieved milestones
      achieved = @user.milestones_achieved
      json_response.each do |milestone|
        assert_not_includes achieved, milestone["id"]
      end
    end

    test "should celebrate milestone achievement" do
      @user.update!(onboarding_completed: true)

      post trigger_milestones_url, params: {
        milestone_id: "celebration_test"
      }, as: :json

      assert_response :success
      json_response = JSON.parse(response.body)
      assert json_response["celebration"]
      assert json_response["points_awarded"]
    end

    private

    def sign_in(user)
      # For integration tests, we need to post to the test_session endpoint
      post "/rails_onboarding/test_session", params: { user_id: user.id }
    end
  end
end
