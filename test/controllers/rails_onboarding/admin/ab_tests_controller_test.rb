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

      test "should paginate tests beyond the first page" do
        configure_tests(BaseController::DEFAULT_PER_PAGE + 3)

        get admin_ab_tests_path
        assert_response :success
        assert_select 'nav.series-nav a[aria-current="page"]', text: '1'
        assert_select '.admin-ab-tests-grid > *', BaseController::DEFAULT_PER_PAGE

        get admin_ab_tests_path(page: 2)
        assert_response :success
        assert_select 'nav.series-nav a[aria-current="page"]', text: '2'
        assert_select '.admin-ab-tests-grid > *', 3
        assert_includes response.body, 'test_27'
        assert_not_includes response.body, 'test_00'
      end

      test "stat cards report collection totals, not the current page" do
        configure_tests(BaseController::DEFAULT_PER_PAGE + 3, enabled_every: 2)
        total = BaseController::DEFAULT_PER_PAGE + 3
        enabled = (0...total).count(&:even?)

        get admin_ab_tests_path(page: 2)

        assert_response :success
        # Active / Inactive / Total cards, whole-collection counts on every page.
        assert_select '.admin-stat-value', text: enabled.to_s
        assert_select '.admin-stat-value', text: (total - enabled).to_s
        assert_select '.admin-stat-value', text: total.to_s
      end

      test "a page holding only inactive tests drops the Active heading" do
        # 1 enabled, the rest disabled: page 2 is inactive-only.
        configure_tests(BaseController::DEFAULT_PER_PAGE + 3, enabled_every: nil, first_enabled: true)

        get admin_ab_tests_path(page: 2)

        assert_response :success
        assert_select '.admin-section-title', text: 'Inactive Tests'
        assert_select '.admin-section-title', text: 'Active Tests', count: 0
      end

      test "renders no pagination for a single page of tests" do
        get admin_ab_tests_path
        assert_response :success
        assert_select 'nav.series-nav', count: 0
      end

      private

      def configure_tests(count, enabled_every: nil, first_enabled: false)
        tests = (0...count).each_with_object({}) do |i, hash|
          enabled = if enabled_every
                      (i % enabled_every).zero?
                    else
                      first_enabled && i.zero?
                    end
          hash[:"test_#{format('%02d', i)}"] = {
            variants: %w[a b], weights: [50, 50], enabled: enabled
          }
        end
        RailsOnboarding.configuration.ab_tests = tests
      end
    end
  end
end
