module RailsOnboarding
  class Configuration
    # Rate limiting configuration (RailsOnboarding::RateLimitable) - opt-in.
    module RateLimiting
      attr_accessor :rate_limiting_enabled, :rate_limit_per_period, :rate_limit_period

      private

      def initialize_rate_limiting
        # Defaulting this on would start enforcing a request limit on every
        # host app that upgrades without them ever having asked for it.
        @rate_limiting_enabled = false
        @rate_limit_per_period = 60  # Number of requests allowed per period
        @rate_limit_period = 60      # Period in seconds (60 seconds = 1 minute)
      end
    end
  end
end
