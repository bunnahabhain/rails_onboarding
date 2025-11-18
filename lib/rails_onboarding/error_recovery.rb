module RailsOnboarding
  # Error Recovery Service
  # Handles failed steps gracefully with retry logic and error state management
  class ErrorRecovery
    MAX_RETRIES = 3
    RETRY_DELAY = 2.seconds

    class << self
      # Execute a block with error recovery
      #
      # @param user [User] The user performing the action
      # @param action [Symbol] The action being performed
      # @param max_retries [Integer] Maximum number of retries
      # @yield The block to execute
      # @return [Boolean] True if successful, false otherwise
      def with_recovery(user, action, max_retries: MAX_RETRIES, &block)
        attempt = 0
        last_error = nil

        loop do
          attempt += 1

          begin
            result = block.call
            clear_error_state(user, action)
            return result
          rescue StandardError => e
            last_error = e
            Rails.logger.error("Error in #{action} (attempt #{attempt}/#{max_retries}): #{e.message}")
            Rails.logger.error(e.backtrace.join("\n")) if Rails.env.development?

            record_error(user, action, e, attempt)

            break if attempt >= max_retries

            sleep RETRY_DELAY if defined?(sleep)
          end
        end

        # All retries failed
        mark_as_failed(user, action, last_error)
        false
      end

      # Record an error for analytics and debugging
      def record_error(user, action, error, attempt)
        return unless user && error

        error_data = {
          action: action.to_s,
          error_class: error.class.name,
          error_message: error.message,
          attempt: attempt,
          timestamp: Time.current.iso8601
        }

        # Store in user's error log if available
        if user.respond_to?(:onboarding_errors)
          user.onboarding_errors ||= []
          user.onboarding_errors << error_data
          user.save(validate: false) rescue nil
        end

        # Track in analytics
        if defined?(RailsOnboarding::AnalyticsEvent)
          RailsOnboarding::AnalyticsEvent.track_custom_event(
            user: user,
            event_name: 'onboarding_error',
            event_data: error_data
          )
        end
      end

      # Mark an action as failed after all retries
      def mark_as_failed(user, action, error)
        return unless user

        if user.respond_to?(:onboarding_failed_actions)
          user.onboarding_failed_actions ||= []
          user.onboarding_failed_actions << {
            action: action.to_s,
            error: error&.message,
            failed_at: Time.current.iso8601
          }
          user.save(validate: false) rescue nil
        end

        Rails.logger.error("Action #{action} failed for user #{user.id} after all retries")
      end

      # Clear error state for a successful action
      def clear_error_state(user, action)
        return unless user

        if user.respond_to?(:onboarding_failed_actions)
          user.onboarding_failed_actions ||= []
          user.onboarding_failed_actions.reject! { |a| a[:action] == action.to_s }
          user.save(validate: false) rescue nil
        end
      end

      # Check if user has any failed actions
      def has_errors?(user)
        return false unless user&.respond_to?(:onboarding_failed_actions)
        user.onboarding_failed_actions&.any? || false
      end

      # Get failed actions for a user
      def failed_actions(user)
        return [] unless user&.respond_to?(:onboarding_failed_actions)
        user.onboarding_failed_actions || []
      end

      # Retry a failed action
      def retry_failed_action(user, action, &block)
        clear_error_state(user, action)
        with_recovery(user, action, &block)
      end

      # Reset all errors for a user
      def reset_errors(user)
        return unless user

        if user.respond_to?(:onboarding_errors=)
          user.onboarding_errors = []
        end

        if user.respond_to?(:onboarding_failed_actions=)
          user.onboarding_failed_actions = []
        end

        user.save(validate: false) rescue nil
      end

      # Retry with exponential backoff
      def with_exponential_backoff(max_attempts: 3, base_delay: 1, max_delay: 30, exponential_base: 2)
        attempt = 0
        begin
          attempt += 1
          yield
        rescue StandardError => e
          if attempt < max_attempts
            delay = [base_delay * (exponential_base ** (attempt - 1)), max_delay].min
            Rails.logger.warn "Attempt #{attempt} failed: #{e.message}. Retrying in #{delay}s..."
            sleep delay
            retry
          else
            Rails.logger.error "All #{max_attempts} attempts failed: #{e.message}"
            raise
          end
        end
      end

      # Execute with timeout
      def with_timeout(seconds: 30)
        Timeout.timeout(seconds) do
          yield
        end
      rescue Timeout::Error => e
        Rails.logger.error "Operation timed out after #{seconds} seconds"
        raise
      end

      # Execute with fallback value
      def with_fallback(fallback_value = nil)
        yield
      rescue StandardError => e
        Rails.logger.warn "Operation failed, using fallback: #{e.message}"
        fallback_value
      end
    end
  end

  # Webhook monitoring and alerting
  module WebhookMonitoring
    extend ActiveSupport::Concern

    # Track webhook delivery
    def self.track_delivery(webhook_url:, event_type:, success:, response_code: nil, error_message: nil, duration: nil)
      cache_key = webhook_cache_key(webhook_url, event_type)

      delivery_stats = Rails.cache.read(cache_key) || {
        total_attempts: 0,
        successful_deliveries: 0,
        failed_deliveries: 0,
        last_success_at: nil,
        last_failure_at: nil,
        recent_failures: []
      }

      delivery_stats[:total_attempts] += 1

      if success
        delivery_stats[:successful_deliveries] += 1
        delivery_stats[:last_success_at] = Time.current
        delivery_stats[:recent_failures] = []
      else
        delivery_stats[:failed_deliveries] += 1
        delivery_stats[:last_failure_at] = Time.current
        delivery_stats[:recent_failures] << {
          timestamp: Time.current,
          error: error_message,
          response_code: response_code
        }

        # Keep only last 10 failures
        delivery_stats[:recent_failures] = delivery_stats[:recent_failures].last(10)
      end

      Rails.cache.write(cache_key, delivery_stats, expires_in: 7.days)

      # Check if we should alert
      check_and_alert(webhook_url, event_type, delivery_stats)

      delivery_stats
    end

    # Get webhook health status
    def self.health_status(webhook_url:, event_type:)
      cache_key = webhook_cache_key(webhook_url, event_type)
      delivery_stats = Rails.cache.read(cache_key)

      return :unknown unless delivery_stats

      # Calculate success rate
      total = delivery_stats[:total_attempts]
      return :unknown if total.zero?

      success_rate = (delivery_stats[:successful_deliveries].to_f / total * 100).round(2)
      recent_failures_count = delivery_stats[:recent_failures].size

      # Determine health status
      if recent_failures_count >= 5
        :critical
      elsif recent_failures_count >= 3
        :degraded
      elsif success_rate >= 95
        :healthy
      elsif success_rate >= 80
        :warning
      else
        :unhealthy
      end
    end

    # Get delivery statistics
    def self.statistics(webhook_url:, event_type:)
      cache_key = webhook_cache_key(webhook_url, event_type)
      delivery_stats = Rails.cache.read(cache_key)

      return nil unless delivery_stats

      total = delivery_stats[:total_attempts]
      return delivery_stats if total.zero?

      delivery_stats.merge(
        success_rate: (delivery_stats[:successful_deliveries].to_f / total * 100).round(2),
        failure_rate: (delivery_stats[:failed_deliveries].to_f / total * 100).round(2),
        health_status: health_status(webhook_url: webhook_url, event_type: event_type)
      )
    end

    private

    def self.webhook_cache_key(webhook_url, event_type)
      url_hash = Digest::SHA256.hexdigest(webhook_url)[0..15]
      "rails_onboarding:webhook:#{url_hash}:#{event_type}"
    end

    def self.check_and_alert(webhook_url, event_type, stats)
      recent_failures_count = stats[:recent_failures].size

      # Alert on 5 consecutive failures
      if recent_failures_count >= 5
        send_alert(
          level: :critical,
          webhook_url: webhook_url,
          event_type: event_type,
          message: "Webhook has failed 5 consecutive times",
          stats: stats
        )
      # Warn on 3 consecutive failures
      elsif recent_failures_count >= 3
        send_alert(
          level: :warning,
          webhook_url: webhook_url,
          event_type: event_type,
          message: "Webhook has failed 3 consecutive times",
          stats: stats
        )
      end
    end

    def self.send_alert(level:, webhook_url:, event_type:, message:, stats:)
      alert_data = {
        level: level,
        webhook_url: webhook_url,
        event_type: event_type,
        message: message,
        statistics: stats,
        timestamp: Time.current
      }

      # Log alert
      case level
      when :critical
        Rails.logger.error "WEBHOOK ALERT [CRITICAL]: #{message} - #{webhook_url}"
      when :warning
        Rails.logger.warn "WEBHOOK ALERT [WARNING]: #{message} - #{webhook_url}"
      else
        Rails.logger.info "WEBHOOK ALERT [#{level.to_s.upcase}]: #{message} - #{webhook_url}"
      end

      # Send to configured alert channels
      send_to_alert_channels(alert_data) rescue nil
    end

    def self.send_to_alert_channels(alert_data)
      # Check for configured alert channels
      config = RailsOnboarding.configuration

      # Slack notification
      if config.respond_to?(:webhook_alerts_slack_url) && config.webhook_alerts_slack_url.present?
        send_slack_alert(config.webhook_alerts_slack_url, alert_data) rescue nil
      end

      # Email notification
      if config.respond_to?(:webhook_alerts_email) && config.webhook_alerts_email.present?
        send_email_alert(config.webhook_alerts_email, alert_data) rescue nil
      end
    end

    def self.send_slack_alert(slack_url, alert_data)
      require 'net/http'
      require 'json'

      color = alert_data[:level] == :critical ? 'danger' : 'warning'

      payload = {
        text: "Webhook Alert: #{alert_data[:message]}",
        attachments: [{
          color: color,
          fields: [
            { title: "Webhook URL", value: alert_data[:webhook_url], short: false },
            { title: "Event Type", value: alert_data[:event_type], short: true },
            { title: "Level", value: alert_data[:level].to_s.upcase, short: true },
            { title: "Total Attempts", value: alert_data[:statistics][:total_attempts], short: true },
            { title: "Failed Deliveries", value: alert_data[:statistics][:failed_deliveries], short: true }
          ],
          footer: "RailsOnboarding",
          ts: alert_data[:timestamp].to_i
        }]
      }

      uri = URI(slack_url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.open_timeout = 5
      http.read_timeout = 5
      request = Net::HTTP::Post.new(uri.path, { 'Content-Type' => 'application/json' })
      request.body = payload.to_json
      response = http.request(request)

      if response.code.to_i >= 400
        Rails.logger.warn "Slack alert failed with status #{response.code}"
      end
    rescue StandardError => e
      Rails.logger.error "Failed to send Slack alert: #{e.message}"
    end

    def self.send_email_alert(email, alert_data)
      # Log email alert (mailer templates would need to be created)
      Rails.logger.info "Would send email alert to #{email} about #{alert_data[:message]}"
    rescue StandardError => e
      Rails.logger.error "Failed to send email alert: #{e.message}"
    end
  end
end
