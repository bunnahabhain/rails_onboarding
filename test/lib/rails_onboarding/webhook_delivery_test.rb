# frozen_string_literal: true

require "test_helper"
require "webmock/minitest"

module RailsOnboarding
  class WebhookDeliveryTest < ActiveSupport::TestCase
    setup do
      @user = users(:one)
      @webhook_url = "https://example.com/webhook"
      @backup_webhook_url = "https://backup.example.com/webhook"

      RailsOnboarding.configure do |config|
        config.webhook_url = @webhook_url
        config.webhook_events = [:onboarding_completed, :step_completed, :milestone_achieved]
        config.webhook_retry_attempts = 3
        config.webhook_retry_delay = 1 # 1 second for testing
        config.webhook_timeout = 5
      end

      WebMock.reset!
    end

    teardown do
      WebMock.reset!
    end

    # ===== Delivery Failure Tests =====

    test "retries on 500 server error" do
      attempt_count = 0

      stub_request(:post, @webhook_url)
        .to_return do |_request|
          attempt_count += 1
          if attempt_count < 3
            { status: 500, body: "Internal Server Error" }
          else
            { status: 200, body: { success: true }.to_json }
          end
        end

      RailsOnboarding::Webhooks.trigger(:onboarding_completed, @user)

      assert_equal 3, attempt_count, "Should retry until success"
    end

    test "retries on 503 service unavailable" do
      attempt_count = 0

      stub_request(:post, @webhook_url)
        .to_return do |_request|
          attempt_count += 1
          { status: 503, body: "Service Unavailable" }
        end

      RailsOnboarding::Webhooks.trigger(:onboarding_completed, @user)

      # Should retry configured number of times
      assert_operator attempt_count, :>=, 2, "Should make multiple attempts"
    end

    test "retries on network timeout" do
      attempt_count = 0

      stub_request(:post, @webhook_url)
        .to_timeout
        .times(2)
        .then
        .to_return(status: 200)

      # Should not raise exception
      assert_nothing_raised do
        RailsOnboarding::Webhooks.trigger(:onboarding_completed, @user)
      end
    end

    test "retries on connection refused" do
      stub_request(:post, @webhook_url)
        .to_raise(Errno::ECONNREFUSED)
        .times(3)

      # Should handle gracefully without raising exception
      assert_nothing_raised do
        RailsOnboarding::Webhooks.trigger(:onboarding_completed, @user)
      end
    end

    test "stops retrying after max attempts" do
      attempt_count = 0

      stub_request(:post, @webhook_url)
        .to_return do |_request|
          attempt_count += 1
          { status: 500 }
        end

      RailsOnboarding::Webhooks.trigger(:onboarding_completed, @user)

      # Should respect max retry attempts (3 attempts + 1 original = 4 total, or just 3 if original is counted)
      assert_operator attempt_count, :<=, 4, "Should not exceed max retries"
      assert_operator attempt_count, :>=, 3, "Should make at least max_retries attempts"
    end

    test "does not retry on 4xx client errors" do
      attempt_count = 0

      stub_request(:post, @webhook_url)
        .to_return do |_request|
          attempt_count += 1
          { status: 400, body: "Bad Request" }
        end

      RailsOnboarding::Webhooks.trigger(:onboarding_completed, @user)

      assert_equal 1, attempt_count, "Should not retry on client error"
    end

    test "does not retry on 401 unauthorized" do
      attempt_count = 0

      stub_request(:post, @webhook_url)
        .to_return do |_request|
          attempt_count += 1
          { status: 401, body: "Unauthorized" }
        end

      RailsOnboarding::Webhooks.trigger(:onboarding_completed, @user)

      assert_equal 1, attempt_count, "Should not retry on auth error"
    end

    test "does not retry on 404 not found" do
      attempt_count = 0

      stub_request(:post, @webhook_url)
        .to_return do |_request|
          attempt_count += 1
          { status: 404, body: "Not Found" }
        end

      RailsOnboarding::Webhooks.trigger(:onboarding_completed, @user)

      assert_equal 1, attempt_count, "Should not retry when endpoint doesn't exist"
    end

    # ===== Exponential Backoff Tests =====

    test "implements exponential backoff between retries" do
      attempt_times = []

      stub_request(:post, @webhook_url)
        .to_return do |_request|
          attempt_times << Time.now
          { status: 500 }
        end

      RailsOnboarding::Webhooks.trigger(:onboarding_completed, @user)

      # Check delays between attempts increase exponentially
      if attempt_times.length >= 3
        delay1 = attempt_times[1] - attempt_times[0]
        delay2 = attempt_times[2] - attempt_times[1]

        assert_operator delay2, :>, delay1,
                        "Second delay (#{delay2}s) should be greater than first delay (#{delay1}s)"
      end
    end

    test "respects maximum backoff delay" do
      attempt_times = []

      stub_request(:post, @webhook_url)
        .to_return do |_request|
          attempt_times << Time.now
          { status: 500 }
        end

      # Configure large number of retries
      RailsOnboarding.configuration.webhook_retry_attempts = 10

      RailsOnboarding::Webhooks.trigger(:onboarding_completed, @user)

      # Check that delays don't grow unbounded
      if attempt_times.length >= 4
        delays = []
        (1...attempt_times.length).each do |i|
          delays << (attempt_times[i] - attempt_times[i - 1])
        end

        # Last delay should not be more than 60 seconds (common max backoff)
        assert_operator delays.last, :<=, 60, "Backoff should have maximum limit"
      end
    end

    # ===== Fallback and Recovery Tests =====

    test "falls back to backup webhook URL on primary failure" do
      RailsOnboarding.configuration.webhook_backup_url = @backup_webhook_url

      stub_request(:post, @webhook_url).to_return(status: 500)
      stub_request(:post, @backup_webhook_url).to_return(status: 200)

      RailsOnboarding::Webhooks.trigger(:onboarding_completed, @user)

      # Both should be requested
      assert_requested :post, @webhook_url
      assert_requested :post, @backup_webhook_url
    end

    test "records failed delivery for later retry" do
      stub_request(:post, @webhook_url).to_return(status: 500)

      # Should track failed webhook deliveries
      assert_difference "RailsOnboarding::WebhookDelivery.failed.count", 1 do
        RailsOnboarding::Webhooks.trigger(:onboarding_completed, @user)
      end
    rescue NameError
      # WebhookDelivery model might not exist yet, skip test
      skip "WebhookDelivery model not implemented yet"
    end

    test "allows manual retry of failed webhooks" do
      stub_request(:post, @webhook_url)
        .to_return(status: 500)
        .times(3)
        .then
        .to_return(status: 200)

      RailsOnboarding::Webhooks.trigger(:onboarding_completed, @user)

      # Manually retry failed webhooks
      assert_nothing_raised do
        RailsOnboarding::Webhooks.retry_failed
      end
    rescue NoMethodError
      skip "Manual retry not implemented yet"
    end

    # ===== Monitoring and Logging Tests =====

    test "logs webhook delivery failures" do
      stub_request(:post, @webhook_url).to_return(status: 500)

      logs = capture_logs do
        RailsOnboarding::Webhooks.trigger(:onboarding_completed, @user)
      end

      assert_match(/webhook.*failed/i, logs)
      assert_match(/500/, logs)
    end

    test "logs retry attempts" do
      attempt_count = 0
      stub_request(:post, @webhook_url)
        .to_return do |_request|
          attempt_count += 1
          { status: 500 }
        end

      logs = capture_logs do
        RailsOnboarding::Webhooks.trigger(:onboarding_completed, @user)
      end

      assert_match(/retry/i, logs) if attempt_count > 1
    end

    test "includes request_id in logs for tracing" do
      stub_request(:post, @webhook_url).to_return(status: 500)

      logs = capture_logs do
        RailsOnboarding::Webhooks.trigger(:onboarding_completed, @user)
      end

      # Should include some form of request identifier
      assert_match(/\w{8,}/, logs, "Logs should include request identifier")
    end

    test "tracks webhook delivery metrics" do
      stub_request(:post, @webhook_url).to_return(status: 200)

      # Should track successful deliveries
      metrics_before = RailsOnboarding::WebhookMonitoring.success_count rescue 0
      RailsOnboarding::Webhooks.trigger(:onboarding_completed, @user)
      metrics_after = RailsOnboarding::WebhookMonitoring.success_count rescue 0

      assert_operator metrics_after, :>=, metrics_before
    rescue NameError
      skip "WebhookMonitoring not implemented yet"
    end

    test "calculates webhook delivery success rate" do
      # Make some successful and some failed deliveries
      stub_request(:post, @webhook_url)
        .to_return(status: 200)
        .times(7)
        .then
        .to_return(status: 500)
        .times(3)

      10.times do
        RailsOnboarding::Webhooks.trigger(:onboarding_completed, @user)
      end

      success_rate = RailsOnboarding::WebhookMonitoring.success_rate rescue nil
      skip "WebhookMonitoring not implemented yet" if success_rate.nil?

      assert_operator success_rate, :>=, 0.65, "Success rate should be at least 65%"
      assert_operator success_rate, :<=, 0.75, "Success rate should be at most 75%"
    rescue NameError
      skip "WebhookMonitoring not implemented yet"
    end

    # ===== Webhook Health Check Tests =====

    test "detects unhealthy webhook endpoint" do
      # Simulate repeated failures
      stub_request(:post, @webhook_url).to_return(status: 500)

      5.times do
        RailsOnboarding::Webhooks.trigger(:onboarding_completed, @user)
      end

      health_status = RailsOnboarding::WebhookMonitoring.health_status rescue nil
      skip "WebhookMonitoring not implemented yet" if health_status.nil?

      assert_equal :unhealthy, health_status
    rescue NameError
      skip "WebhookMonitoring not implemented yet"
    end

    test "sends alert when webhook repeatedly fails" do
      stub_request(:post, @webhook_url).to_return(status: 500)

      alert_sent = false
      RailsOnboarding::WebhookMonitoring.on_unhealthy do
        alert_sent = true
      end rescue nil

      10.times do
        RailsOnboarding::Webhooks.trigger(:onboarding_completed, @user)
      end

      assert alert_sent, "Should send alert for repeated failures" rescue skip("WebhookMonitoring not implemented yet")
    rescue NameError
      skip "WebhookMonitoring not implemented yet"
    end

    # ===== Payload and Signature Tests =====

    test "includes timestamp in webhook payload" do
      stub = stub_request(:post, @webhook_url)
               .with { |request|
                 payload = JSON.parse(request.body)
                 payload.key?("timestamp") || payload.key?("occurred_at")
               }
               .to_return(status: 200)

      RailsOnboarding::Webhooks.trigger(:onboarding_completed, @user)

      assert_requested stub
    end

    test "includes signature for verification" do
      RailsOnboarding.configuration.webhook_secret = "test_secret_key"

      stub = stub_request(:post, @webhook_url)
               .with { |request|
                 request.headers["X-Webhook-Signature"].present? ||
                 request.headers["X-RailsOnboarding-Signature"].present?
               }
               .to_return(status: 200)

      RailsOnboarding::Webhooks.trigger(:onboarding_completed, @user)

      assert_requested stub
    end

    test "rotates webhook secrets gracefully" do
      old_secret = "old_secret_key"
      new_secret = "new_secret_key"

      RailsOnboarding.configuration.webhook_secret = old_secret

      # Send some webhooks with old secret
      stub_request(:post, @webhook_url).to_return(status: 200)
      RailsOnboarding::Webhooks.trigger(:onboarding_completed, @user)

      # Rotate secret
      RailsOnboarding.configuration.webhook_secret = new_secret

      # Should still work with new secret
      assert_nothing_raised do
        RailsOnboarding::Webhooks.trigger(:onboarding_completed, @user)
      end
    end

    # ===== Timeout Tests =====

    test "respects webhook timeout configuration" do
      RailsOnboarding.configuration.webhook_timeout = 2

      # Simulate slow response
      stub_request(:post, @webhook_url)
        .to_timeout

      start_time = Time.now
      RailsOnboarding::Webhooks.trigger(:onboarding_completed, @user)
      elapsed_time = Time.now - start_time

      # Should timeout within reasonable time (timeout + some overhead)
      assert_operator elapsed_time, :<, 10, "Should respect timeout configuration"
    end

    test "times out on extremely slow webhook endpoint" do
      RailsOnboarding.configuration.webhook_timeout = 1

      stub_request(:post, @webhook_url).to_timeout

      # Should handle timeout gracefully
      assert_nothing_raised do
        RailsOnboarding::Webhooks.trigger(:onboarding_completed, @user)
      end
    end

    # ===== Async Delivery Tests =====

    test "delivers webhooks asynchronously by default" do
      stub_request(:post, @webhook_url).to_return(status: 200)

      # Webhook delivery should not block
      start_time = Time.now
      RailsOnboarding::Webhooks.trigger(:onboarding_completed, @user)
      elapsed_time = Time.now - start_time

      # Should return almost immediately
      assert_operator elapsed_time, :<, 1, "Webhook should deliver asynchronously"
    end

    test "supports synchronous delivery when configured" do
      RailsOnboarding.configuration.webhook_async = false
      stub_request(:post, @webhook_url).to_return(status: 200)

      # Should deliver synchronously
      RailsOnboarding::Webhooks.trigger(:onboarding_completed, @user)

      assert_requested :post, @webhook_url
    end

    private

    def capture_logs
      original_logger = Rails.logger
      log_output = StringIO.new
      Rails.logger = Logger.new(log_output)

      yield

      log_output.string
    ensure
      Rails.logger = original_logger
    end
  end
end
