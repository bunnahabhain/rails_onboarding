# frozen_string_literal: true

require "test_helper"

module RailsOnboarding
  module Admin
    class DashboardControllerTest < ActionDispatch::IntegrationTest
      include Engine.routes.url_helpers

      def setup
        # Note: Admin functionality should be provided by the host application's authentication system
        # These tests are skipped until authentication is implemented
        @admin_user = User.create!(email: "admin@example.com")
        @regular_user = User.create!(email: "user@example.com")
      end

      test "should redirect non-admin users" do
        # This test depends on authentication implementation
        skip "Implement based on your authentication system"
      end

      test "should load dashboard for admin" do
        # This test depends on authentication implementation
        skip "Implement based on your authentication system"
      end

      test "step funnel counts distinct users who reached each step" do
        # Pin the steps config: other tests activate flows that mutate the
        # global configuration.steps, so don't assume the default four steps.
        original_steps = RailsOnboarding.configuration.steps
        RailsOnboarding.configuration.steps = [
          { name: :welcome, title: "Welcome", skippable: true },
          { name: :profile, title: "Setup Profile", skippable: false },
          { name: :first_action, title: "First Action", skippable: false },
          { name: :explore, title: "Explore Features", skippable: true }
        ]

        sign_in @admin_user

        # welcome reached by two distinct users, profile by one - a true entry
        # funnel. A refresh (duplicate started event) must not inflate the count.
        other_user = User.create!(email: "reached@example.com")
        [ @regular_user, other_user ].each do |user|
          RailsOnboarding::AnalyticsEvent.track_step_started(user: user, step_name: :welcome, step_index: 0)
        end
        RailsOnboarding::AnalyticsEvent.track_step_started(user: @regular_user, step_name: :welcome, step_index: 0)
        RailsOnboarding::AnalyticsEvent.track_step_started(user: @regular_user, step_name: :profile, step_index: 1)

        # A completion of a later step must NOT count toward its entry funnel.
        RailsOnboarding::AnalyticsEvent.track_step_completed(user: @regular_user, step_name: :explore, step_index: 3, time_spent: 5)

        get admin_dashboard_path

        assert_response :success
        funnel = css_select(".admin-funnel-step .admin-funnel-stats").map(&:text)
        assert_match(/2 users/, funnel[0], "welcome should count 2 distinct users, not 3 events")
        assert_match(/1 users/, funnel[1], "profile should count 1 user")
        assert_match(/0 users/, funnel[3], "explore had only a completion, so 0 entries")
      ensure
        RailsOnboarding.configuration.steps = original_steps
      end

      test "sidebar links Home to the host app's root, not the engine" do
        sign_in @admin_user

        get admin_dashboard_path

        assert_response :success
        home_link = css_select("a.admin-nav-item-home").first
        assert home_link, "admin layout should render a Home nav item"
        assert_equal "Home", home_link.text.strip.sub(/\A🏠\s*/, "")
        # The dummy app's root - "/rails_onboarding/..." would mean the link
        # was built against the engine's routes instead of the host app's.
        assert_equal "/", home_link["href"]
      end

      test "should filter by date range" do
        skip "Implement based on your authentication system"
      end
    end
  end
end
