# frozen_string_literal: true

module RailsOnboarding
  # Rate limiting concern for API endpoints and webhooks
  # Prevents abuse by limiting the number of requests per time period
  module RateLimitable
    extend ActiveSupport::Concern

    included do
      before_action :check_rate_limit, if: :rate_limiting_enabled?
    end

    private

    # Check if request exceeds rate limit
    def check_rate_limit
      return unless rate_limiting_enabled?

      identifier = rate_limit_identifier
      key = rate_limit_cache_key(identifier)

      # Get current request count
      count = Rails.cache.read(key) || 0
      limit = rate_limit_per_period

      if count >= limit
        rate_limit_exceeded_response
        return
      end

      # Increment counter
      Rails.cache.write(
        key,
        count + 1,
        expires_in: rate_limit_period,
        unless_exist: false
      )

      # Set rate limit headers
      response.set_header("X-RateLimit-Limit", limit.to_s)
      response.set_header("X-RateLimit-Remaining", (limit - count - 1).to_s)
      response.set_header("X-RateLimit-Reset", rate_limit_reset_time.to_i.to_s)
    end

    # Generate cache key for rate limiting
    def rate_limit_cache_key(identifier)
      period = (Time.current.to_i / rate_limit_period).to_i
      "rails_onboarding:rate_limit:#{identifier}:#{period}"
    end

    # Identifier for rate limiting (IP address or user ID)
    def rate_limit_identifier
      if respond_to?(:current_user, true) && current_user
        "user:#{current_user.id}"
      else
        "ip:#{request.remote_ip}"
      end
    end

    # Rate limit configuration
    def rate_limit_per_period
      RailsOnboarding.configuration.rate_limit_per_period || 60
    end

    def rate_limit_period
      RailsOnboarding.configuration.rate_limit_period || 1.minute
    end

    def rate_limit_reset_time
      period_seconds = rate_limit_period.to_i
      current_period = (Time.current.to_i / period_seconds).to_i
      Time.at((current_period + 1) * period_seconds)
    end

    def rate_limiting_enabled?
      RailsOnboarding.configuration.rate_limiting_enabled != false
    end

    # Response when rate limit is exceeded
    def rate_limit_exceeded_response
      retry_after = (rate_limit_reset_time - Time.current).to_i
      message = "Too many requests. Please retry after #{retry_after} seconds."

      response.set_header("Retry-After", retry_after.to_s)
      response.set_header("X-RateLimit-Limit", rate_limit_per_period.to_s)
      response.set_header("X-RateLimit-Remaining", "0")
      response.set_header("X-RateLimit-Reset", rate_limit_reset_time.to_i.to_s)

      if respond_to?(:render_api_error)
        render_api_error(message, status: :too_many_requests)
        return
      end

      # These controllers are HTML/Turbo-driven, not JSON APIs, so a plain
      # `render json:` here would hand a browser a raw JSON body instead of
      # a page. Respond appropriately to what was actually requested.
      respond_to do |format|
        format.html { redirect_back fallback_location: main_app.root_path, alert: message }
        format.json { render json: { error: "Rate limit exceeded", retry_after: retry_after, message: message }, status: :too_many_requests }
        format.any { head :too_many_requests }
      end
    end
  end
end
