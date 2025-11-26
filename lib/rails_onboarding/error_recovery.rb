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
end
