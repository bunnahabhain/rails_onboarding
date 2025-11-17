require "test_helper"

module RailsOnboarding
  class MilestonesControllerTest < ActionDispatch::IntegrationTest
    include Engine.routes.url_helpers

    setup do
      @user = users(:one)
      @user.update(onboarding_milestones_achieved: [])
      sign_in @user
    end

    test "should list all milestones" do
      get milestones_url, as: :json

      assert_response :success
      json_response = JSON.parse(response.body)
      assert json_response.is_a?(Array)
    end

    test "should get user progress" do
      @user.update(
        onboarding_milestones_achieved: ["first_login"],
        onboarding_milestone_points: 100
      )

      get progress_milestones_url, as: :json

      assert_response :success
      json_response = JSON.parse(response.body)
      assert_equal 100, json_response["points"]
      assert_includes json_response["achieved"], "first_login"
    end

    test "should check milestone achievement" do
      milestone_id = "profile_completed"
      @user.update(onboarding_milestones_achieved: [milestone_id])

      get check_milestone_url(id: milestone_id), as: :json

      assert_response :success
      json_response = JSON.parse(response.body)
      assert_equal true, json_response["achieved"]
    end

    test "should trigger milestone" do
      assert_difference "@user.reload.onboarding_milestone_points", 50 do
        post trigger_milestone_url, params: {
          milestone_id: "first_action_completed"
        }, as: :json
      end

      assert_response :success
    end

    test "should not trigger same milestone twice" do
      milestone_id = "duplicate_test"

      # First trigger
      post trigger_milestone_url, params: { milestone_id: milestone_id }, as: :json
      first_points = @user.reload.onboarding_milestone_points

      # Second trigger (should not add points again)
      post trigger_milestone_url, params: { milestone_id: milestone_id }, as: :json
      second_points = @user.reload.onboarding_milestone_points

      assert_equal first_points, second_points
    end

    test "should get available milestones" do
      get available_milestones_url, as: :json

      assert_response :success
      json_response = JSON.parse(response.body)
      assert json_response.is_a?(Array)

      # Should only return unachieved milestones
      achieved = @user.onboarding_milestones_achieved
      json_response.each do |milestone|
        assert_not_includes achieved, milestone["id"]
      end
    end

    test "should celebrate milestone achievement" do
      post trigger_milestone_url, params: {
        milestone_id: "celebration_test"
      }, as: :json

      assert_response :success
      json_response = JSON.parse(response.body)
      assert json_response["celebration"]
      assert json_response["points_awarded"]
    end

    private

    def sign_in(user)
      @request.session[:user_id] = user.id if @request
    end
  end
end
