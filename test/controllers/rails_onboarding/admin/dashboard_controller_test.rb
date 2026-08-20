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

      # Milestone panel. This was all gated on a RailsOnboarding::Milestone
      # model that the engine has never defined, so the panel rendered nothing
      # at all while achievements accumulated on the users table. These tests
      # pin it to the real storage.

      test "milestone panel counts achievements held on the user record" do
        with_milestones do
          award(@regular_user, :welcome_completed, 4.days.ago)
          award(@regular_user, :onboarding_completed, 3.days.ago)
          award(other_user("second@example.com"), :welcome_completed, 2.days.ago)

          sign_in @admin_user
          get admin_dashboard_path

          assert_response :success
          top = milestone_rows

          assert_equal 2, top.size, "both awarded milestones should be listed"
          assert_match(/Welcome Aboard!/, top[0][:title])
          assert_match(/2 achieved/, top[0][:count], "welcome was awarded to two users")
          assert_match(/1 achieved/, top[1][:count])
        end
      end

      test "milestone panel totals awards, holders and points" do
        with_milestones do
          # 10 points + 50 points, across two users.
          award(@regular_user, :welcome_completed, 1.day.ago)
          award(other_user("third@example.com"), :onboarding_completed, 1.day.ago)

          sign_in @admin_user
          get admin_dashboard_path

          assert_response :success
          assert_equal "2", milestone_stat("Awarded")
          assert_equal "60", milestone_stat("Points")
          assert_match(/2 users/, milestone_stat_change("Awarded"))
        end
      end

      test "milestone panel honours the selected date range" do
        with_milestones do
          award(@regular_user, :welcome_completed, 60.days.ago)

          sign_in @admin_user

          get admin_dashboard_path, params: { date_range: "7" }
          assert_response :success
          assert_equal "0", milestone_stat("Awarded"), "a 60-day-old award is outside a 7-day window"
          assert_empty milestone_rows

          get admin_dashboard_path, params: { date_range: "90" }
          assert_response :success
          assert_equal "1", milestone_stat("Awarded")
        end
      end

      test "milestone panel counts an award it cannot date" do
        with_milestones do
          # Legacy string format with no last_milestone_at to fall back on.
          @regular_user.update!(milestones_achieved: [ "welcome_completed" ], last_milestone_at: nil)

          sign_in @admin_user
          get admin_dashboard_path, params: { date_range: "7" }

          assert_response :success
          assert_equal "1", milestone_stat("Awarded"),
            "an undatable award is still an award and must not vanish from the panel"
        end
      end

      test "milestone panel surfaces a key the host has since removed" do
        with_milestones do
          award(@regular_user, :welcome_completed, 1.day.ago)
          RailsOnboarding.configuration.milestones = []

          sign_in @admin_user
          get admin_dashboard_path

          assert_response :success
          row = milestone_rows.first
          assert row, "an unconfigured key should still be listed"
          assert_match(/Welcome completed/, row[:title])
          assert_match(/no longer configured/, row[:meta])
        end
      end

      test "milestone panel is absent when milestones are disabled" do
        with_milestones do
          award(@regular_user, :welcome_completed, 1.day.ago)
          RailsOnboarding.configuration.enable_milestones = false

          sign_in @admin_user
          get admin_dashboard_path

          assert_response :success
          assert_empty css_select(".admin-card-title").select { |t| t.text.strip == "Milestones" }
        end
      end

      private

      # achieve_milestone! writes analytics events through a polymorphic
      # association the dummy app can't always satisfy, so award directly and
      # keep these tests about the dashboard's reading of the column.
      def award(user, key, at)
        config = RailsOnboarding.configuration.milestone_by_key(key)
        entries = (user.milestones_achieved || []) + [ { "key" => key.to_s, "achieved_at" => at.iso8601 } ]

        user.update!(
          milestones_achieved: entries,
          milestone_points: (user.milestone_points || 0) + (config[:points] || 0),
          last_milestone_at: at
        )
      end

      def other_user(email)
        User.create!(email: email)
      end

      # Other tests in the suite mutate the global milestone configuration, so
      # pin it rather than assuming the dummy app's defaults survived.
      def with_milestones
        original_milestones = RailsOnboarding.configuration.milestones
        original_enabled = RailsOnboarding.configuration.enable_milestones

        RailsOnboarding.configuration.milestones = [
          { key: :welcome_completed, title: "Welcome Aboard!", icon: "🎉", points: 10,
            trigger: :onboarding_step_completed, conditions: { step: :welcome } },
          { key: :onboarding_completed, title: "Onboarding Champion", icon: "🏆", points: 50,
            trigger: :onboarding_completed }
        ]
        RailsOnboarding.configuration.enable_milestones = true

        yield
      ensure
        RailsOnboarding.configuration.milestones = original_milestones
        RailsOnboarding.configuration.enable_milestones = original_enabled
      end

      def milestone_card
        css_select(".admin-card").find do |card|
          card.css(".admin-card-title").any? { |t| t.text.strip == "Milestones" }
        end
      end

      def milestone_rows
        card = milestone_card
        return [] unless card

        card.css(".admin-list-item").map do |item|
          {
            title: item.css(".admin-list-title").text.strip,
            meta: item.css(".admin-list-meta").text.strip,
            count: item.css(".admin-list-value").text.strip
          }
        end
      end

      def milestone_stat_card(label)
        milestone_card&.css(".admin-stat-card")&.find do |c|
          c.css(".admin-stat-label").text.strip == label
        end
      end

      def milestone_stat(label)
        milestone_stat_card(label)&.css(".admin-stat-value")&.text&.strip
      end

      def milestone_stat_change(label)
        milestone_stat_card(label)&.css(".admin-stat-change")&.text&.strip
      end
    end
  end
end
