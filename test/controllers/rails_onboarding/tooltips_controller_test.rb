require "test_helper"

module RailsOnboarding
  class TooltipsControllerTest < ActionDispatch::IntegrationTest
    include Engine.routes.url_helpers

    setup do
      @user = users(:one)
      @user.update(feature_tooltips_shown: {})
      sign_in_as(@user)
    end

    test "should dismiss tooltip" do
      post dismiss_tooltip_url, params: { tooltip_id: "feature_dashboard" }

      assert_response :success
      @user.reload

      assert @user.feature_tooltips_shown["feature_dashboard"]
    end

    test "should track tooltip dismissal" do
      assert_difference "RailsOnboarding::AnalyticsEvent.count" do
        post dismiss_tooltip_url, params: { tooltip_id: "feature_search" }
      end

      event = RailsOnboarding::AnalyticsEvent.last
      assert_equal "tooltip_dismissed", event.event_type
      assert_equal "feature_search", event.properties["tooltip_feature"]
    end

    test "should return json response" do
      post dismiss_tooltip_url, params: { tooltip_id: "feature_export" }, as: :json

      assert_response :success
      json_response = JSON.parse(response.body)
      assert_equal true, json_response["success"]
    end

    test "should handle missing tooltip_id" do
      post dismiss_tooltip_url, params: {}

      assert_response :bad_request
    end

    test "should mark tooltip as shown" do
      post show_tooltip_url, params: { tooltip_id: "feature_reports" }

      assert_response :success
      @user.reload

      assert @user.feature_tooltips_shown.key?("feature_reports")
    end

    test "should reset all tooltips" do
      @user.update(feature_tooltips_shown: {
        "feature_1" => true,
        "feature_2" => true
      })

      post reset_tooltips_url

      assert_response :success
      @user.reload

      assert_empty @user.feature_tooltips_shown
    end

    test "should get tooltip status" do
      @user.update(feature_tooltips_shown: { "feature_test" => true })

      get tooltip_status_url(tooltip_id: "feature_test"), as: :json

      assert_response :success
      json_response = JSON.parse(response.body)
      assert_equal true, json_response["shown"]
    end

    private

    def sign_in_as(user)
      # For integration tests, post to a URL that sets the session
      # We need to make an actual request to set the session
      post "/rails_onboarding/test_session", params: { user_id: user.id }
    end
  end
end
