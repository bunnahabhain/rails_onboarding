require "test_helper"

module RailsOnboarding
  class RateLimitableTest < ActionDispatch::IntegrationTest
    include Engine.routes.url_helpers

    setup do
      @user = users(:one)
      @user.update(
        onboarding_completed: false,
        onboarding_current_step: "welcome",
        onboarding_skipped: false
      )
      sign_in @user

      @original_rate_limiting_enabled = RailsOnboarding.configuration.rate_limiting_enabled
      @original_rate_limit_per_period = RailsOnboarding.configuration.rate_limit_per_period
      @original_rate_limit_period = RailsOnboarding.configuration.rate_limit_period

      # The test environment's cache_store is :null_store (see
      # test/dummy/config/environments/test.rb), so Rails.cache.write/read
      # are no-ops there by design - swap in a real store so rate limiting
      # (which is entirely cache-backed) can actually be exercised.
      @original_cache = Rails.cache
      Rails.cache = ActiveSupport::Cache::MemoryStore.new
    end

    teardown do
      RailsOnboarding.configuration.rate_limiting_enabled = @original_rate_limiting_enabled
      RailsOnboarding.configuration.rate_limit_per_period = @original_rate_limit_per_period
      RailsOnboarding.configuration.rate_limit_period = @original_rate_limit_period
      Rails.cache = @original_cache
    end

    test "is disabled by default - requests are never limited" do
      assert_not RailsOnboarding.configuration.rate_limiting_enabled

      5.times { get onboarding_url }

      assert_response :success
    end

    test "limits requests once the configured threshold is exceeded" do
      RailsOnboarding.configuration.rate_limiting_enabled = true
      RailsOnboarding.configuration.rate_limit_per_period = 2
      RailsOnboarding.configuration.rate_limit_period = 60

      get onboarding_url
      assert_response :success

      get onboarding_url
      assert_response :success

      get onboarding_url
      assert_redirected_to "/"
      assert_match(/Too many requests\. Please retry after \d+ seconds\./, flash[:alert])
      assert_equal "0", response.headers["X-RateLimit-Remaining"]
      assert response.headers["Retry-After"].present?
    end

    test "tracks limits per user, not globally" do
      RailsOnboarding.configuration.rate_limiting_enabled = true
      RailsOnboarding.configuration.rate_limit_per_period = 1
      RailsOnboarding.configuration.rate_limit_period = 60

      get onboarding_url
      assert_response :success

      get onboarding_url
      assert_redirected_to "/"

      sign_out
      sign_in users(:two)
      get onboarding_url
      assert_response :success
    end

    test "sets rate limit headers on a successful request" do
      RailsOnboarding.configuration.rate_limiting_enabled = true
      RailsOnboarding.configuration.rate_limit_per_period = 5
      RailsOnboarding.configuration.rate_limit_period = 60

      get onboarding_url

      assert_equal "5", response.headers["X-RateLimit-Limit"]
      assert_equal "4", response.headers["X-RateLimit-Remaining"]
    end
  end
end
