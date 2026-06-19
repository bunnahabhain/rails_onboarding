# frozen_string_literal: true

require 'test_helper'

module RailsOnboarding
  module Admin
    class FlowsControllerTest < ActionDispatch::IntegrationTest
      include Engine.routes.url_helpers

      def setup
        @admin_user = User.create!(email: 'admin@example.com')
        sign_in @admin_user
      end

      test "should list flows" do
        get admin_flows_path
        assert_response :success
      end

      test "should create new flow" do
        assert_difference -> { RailsOnboarding::Flow.count }, 1 do
          post admin_flows_path, params: {
            flow: { name: 'Test Flow', description: 'A test flow',
                     steps: [{ name: 'welcome', title: 'Welcome', icon: '👋', skippable: '1', order: '0' }] }
          }
        end

        assert_redirected_to admin_flows_path
        flow = RailsOnboarding::Flow.find_by(name: 'Test Flow')
        assert_equal [{ 'name' => 'welcome', 'title' => 'Welcome', 'icon' => '👋', 'skippable' => '1', 'order' => '0' }], flow.steps
      end

      test "should update flow" do
        flow = RailsOnboarding::Flow.create!(name: 'Original', steps: [])

        patch admin_flow_path(flow), params: { flow: { name: 'Renamed' } }

        assert_redirected_to admin_flow_path(flow)
        assert_equal 'Renamed', flow.reload.name
      end

      test "should delete flow" do
        flow = RailsOnboarding::Flow.create!(name: 'Disposable', steps: [])

        assert_difference -> { RailsOnboarding::Flow.count }, -1 do
          delete admin_flow_path(flow)
        end
      end

      test "cannot delete the active flow" do
        flow = RailsOnboarding::Flow.create!(name: 'Active Flow', steps: [], active: true)

        assert_no_difference -> { RailsOnboarding::Flow.count } do
          delete admin_flow_path(flow)
        end
      end

      test "should activate flow and update configuration steps" do
        old_active = RailsOnboarding::Flow.create!(name: 'Old', steps: [{ name: 'old_step' }], active: true)
        new_flow = RailsOnboarding::Flow.create!(name: 'New', steps: [{ name: 'new_step' }], active: false)

        post activate_admin_flow_path(new_flow)

        assert_redirected_to admin_flows_path
        assert_not old_active.reload.active?
        assert new_flow.reload.active?
        assert_equal [{ 'name' => 'new_step' }], RailsOnboarding.configuration.steps
      end

      test "activating a flow is visible without re-activating in another process" do
        flow = RailsOnboarding::Flow.create!(name: 'Shared', steps: [{ name: 'shared_step' }], active: false)
        RailsOnboarding::Flow.activate!(flow)

        # Simulate a fresh process: nothing in this Configuration instance's
        # memoized state was touched, only the database changed.
        assert_equal [{ 'name' => 'shared_step' }], RailsOnboarding.configuration.steps
      end

      test "should duplicate flow" do
        flow = RailsOnboarding::Flow.create!(name: 'Source', steps: [{ name: 'a' }])

        assert_difference -> { RailsOnboarding::Flow.count }, 1 do
          post duplicate_admin_flow_path(flow)
        end

        copy = RailsOnboarding::Flow.find_by(name: 'Source (Copy)')
        assert copy.present?
        assert_not copy.active?
      end

      test "should preview flow steps after a database round trip" do
        flow = RailsOnboarding::Flow.create!(
          name: 'Previewable',
          steps: [{ name: 'welcome', title: 'Say Hello', icon: '👋', skippable: true }]
        )
        flow = RailsOnboarding::Flow.find(flow.id) # force a fresh read, not the in-memory object just saved

        get preview_admin_flow_path(flow)

        assert_response :success
        assert_includes response.body, 'Say Hello'
        assert_includes response.body, '👋'
        assert_includes response.body, 'Skippable'
      end

      test "preview of an unknown flow redirects with an alert" do
        get preview_admin_flow_path(id: 'does-not-exist')
        assert_redirected_to admin_flows_path
      end
    end
  end
end
