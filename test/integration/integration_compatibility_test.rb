# frozen_string_literal: true

require "test_helper"

class IntegrationCompatibilityTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(
      email: "test@example.com",
      onboarding_completed: false,
      onboarding_current_step: "welcome"
    )
  end

  # Devise Integration Tests
  test "devise integration module is available" do
    assert defined?(RailsOnboarding::DeviseIntegration)
  end

  test "devise integration detects devise availability" do
    # Since we may not have Devise in test, we just check the method exists
    assert_respond_to RailsOnboarding::DeviseIntegration, :included
  end

  test "devise controller extension is available" do
    assert defined?(RailsOnboarding::DeviseControllerExtension)
  end

  # Turbo Compatibility Tests
  test "turbo compatibility module is available" do
    assert defined?(RailsOnboarding::TurboCompatibility)
  end

  test "turbo compatibility has frame request detection" do
    controller = MockController.new
    controller.extend(RailsOnboarding::TurboCompatibility)

    assert_respond_to controller, :turbo_frame_request?
    assert_respond_to controller, :turbo_stream_request?
  end

  test "turbo compatibility has stimulus helpers" do
    controller = MockController.new
    controller.extend(RailsOnboarding::TurboCompatibility)

    assert_respond_to controller, :stimulus_controller_data
    assert_respond_to controller, :stimulus_action
  end

  test "stimulus controller data generates correct attributes" do
    controller = MockController.new
    controller.extend(RailsOnboarding::TurboCompatibility)

    data = controller.stimulus_controller_data("onboarding", { step: "welcome" })

    assert_equal "rails-onboarding--onboarding", data[:controller]
    assert data.key?(:'rails-onboarding--onboarding-step-value')
  end

  # API Mode Tests
  test "api mode module is available" do
    assert defined?(RailsOnboarding::ApiMode)
  end

  test "api mode has request detection" do
    controller = MockApiController.new
    assert_respond_to controller, :api_request?
  end

  test "api mode has success response helper" do
    controller = MockApiController.new
    assert_respond_to controller, :render_api_success
  end

  test "api mode has error response helper" do
    controller = MockApiController.new
    assert_respond_to controller, :render_api_error
  end

  test "api controller is available" do
    assert defined?(RailsOnboarding::ApiController)
  end

  # Background Jobs Tests
  test "background jobs module is available" do
    assert defined?(RailsOnboarding::BackgroundJobs)
  end

  test "onboarding mailer job is available" do
    assert defined?(RailsOnboarding::OnboardingMailerJob)
  end

  test "onboarding notification job is available" do
    assert defined?(RailsOnboarding::OnboardingNotificationJob)
  end

  test "onboarding analytics job is available" do
    assert defined?(RailsOnboarding::OnboardingAnalyticsJob)
  end

  test "milestone achievement job is available" do
    assert defined?(RailsOnboarding::MilestoneAchievementJob)
  end

  test "onboarding mailer is available" do
    assert defined?(RailsOnboarding::OnboardingMailer)
  end

  # Configuration Tests
  test "configuration has devise integration options" do
    config = RailsOnboarding.configuration

    assert_respond_to config, :devise_integration_enabled
    assert_respond_to config, :redirect_unconfirmed_to_onboarding
  end

  test "configuration has turbo options" do
    config = RailsOnboarding.configuration

    assert_respond_to config, :turbo_streams_enabled
    assert_respond_to config, :turbo_morphing_enabled
  end

  test "configuration has background job options" do
    config = RailsOnboarding.configuration

    assert_respond_to config, :background_jobs_enabled
    assert_respond_to config, :background_jobs_queue
    assert_respond_to config, :mailer_from
  end

  test "configuration defaults are set correctly" do
    config = RailsOnboarding::Configuration.new

    assert_equal true, config.devise_integration_enabled
    assert_equal false, config.redirect_unconfirmed_to_onboarding
    assert_equal true, config.turbo_streams_enabled
    assert_equal false, config.turbo_morphing_enabled
    assert_equal false, config.background_jobs_enabled
    assert_equal :default, config.background_jobs_queue
    assert_equal "noreply@example.com", config.mailer_from
  end

  # Integration Tests
  test "can configure devise integration" do
    RailsOnboarding.configure do |config|
      config.devise_integration_enabled = true
      config.redirect_unconfirmed_to_onboarding = true
    end

    assert_equal true, RailsOnboarding.configuration.devise_integration_enabled
    assert_equal true, RailsOnboarding.configuration.redirect_unconfirmed_to_onboarding
  end

  test "can configure turbo compatibility" do
    RailsOnboarding.configure do |config|
      config.turbo_streams_enabled = true
      config.turbo_morphing_enabled = true
    end

    assert_equal true, RailsOnboarding.configuration.turbo_streams_enabled
    assert_equal true, RailsOnboarding.configuration.turbo_morphing_enabled
  end

  test "can configure api mode" do
    RailsOnboarding.configure do |config|
      config.api_mode_enabled = true
      config.api_authentication_method = :bearer
    end

    assert_equal true, RailsOnboarding.configuration.api_mode_enabled
    assert_equal :bearer, RailsOnboarding.configuration.api_authentication_method
  end

  test "can configure background jobs" do
    RailsOnboarding.configure do |config|
      config.background_jobs_enabled = true
      config.background_jobs_queue = :onboarding
      config.mailer_from = "support@example.com"
    end

    assert_equal true, RailsOnboarding.configuration.background_jobs_enabled
    assert_equal :onboarding, RailsOnboarding.configuration.background_jobs_queue
    assert_equal "support@example.com", RailsOnboarding.configuration.mailer_from
  end

  private

  # Mock controllers for testing
  class MockController
    attr_accessor :request, :response

    def initialize
      @request = MockRequest.new
      @response = MockResponse.new
    end

    def turbo_stream
      MockTurboStream.new
    end
  end

  class MockApiController
    include RailsOnboarding::ApiMode

    attr_accessor :request, :response, :params

    def initialize
      @request = MockRequest.new
      @response = MockResponse.new
      @params = {}
    end

    def render(options)
      @rendered = options
    end

    def current_user
      nil
    end
  end

  class MockRequest
    attr_accessor :headers, :format, :path

    def initialize
      @headers = {}
      @format = :html
      @path = "/"
    end

    def request_id
      "test-request-id"
    end
  end

  class MockResponse
    attr_accessor :headers, :content_type

    def initialize
      @headers = {}
      @content_type = "text/html"
    end
  end

  class MockTurboStream
    def replace(target, options = {})
      "replace #{target}"
    end

    def update(target, options = {})
      "update #{target}"
    end

    def append(target, options = {})
      "append #{target}"
    end

    def prepend(target, options = {})
      "prepend #{target}"
    end

    def remove(target)
      "remove #{target}"
    end
  end
end
