# frozen_string_literal: true

require 'test_helper'

module RailsOnboarding
  module Admin
    class AbTestsControllerTest < ActionDispatch::IntegrationTest
      include Engine.routes.url_helpers

      def setup
        @admin_user = User.create!(email: 'admin@example.com')
        sign_in @admin_user

        @original_ab_tests = RailsOnboarding.configuration.ab_tests
        RailsOnboarding.configuration.ab_tests = {
          onboarding_flow: { variants: %w[original simplified], weights: [50, 50], enabled: true }
        }
      end

      def teardown
        RailsOnboarding.configuration.ab_tests = @original_ab_tests
      end

      test "should list configured tests" do
        get admin_ab_tests_path
        assert_response :success
        assert_includes response.body, 'onboarding_flow'
      end

      test "should show test results" do
        get admin_ab_test_path('onboarding_flow')

        assert_response :success
        assert_includes response.body, 'simplified'
      end

      test "unknown test redirects with an alert" do
        get admin_ab_test_path('does_not_exist')
        assert_redirected_to admin_ab_tests_path
      end

      test "should stop and start a test" do
        post stop_admin_ab_test_path('onboarding_flow')
        assert_redirected_to admin_ab_test_path('onboarding_flow')
        assert_not RailsOnboarding.configuration.ab_tests[:onboarding_flow][:enabled]

        post start_admin_ab_test_path('onboarding_flow')
        assert_redirected_to admin_ab_test_path('onboarding_flow')
        assert RailsOnboarding.configuration.ab_tests[:onboarding_flow][:enabled]
      end

      test "should export results as csv" do
        get export_admin_ab_test_path('onboarding_flow', format: :csv)
        assert_response :success
        assert_includes response.body, 'Variant,Participants,Completions,Conversion Rate (%)'
      end
    end
  end
end
