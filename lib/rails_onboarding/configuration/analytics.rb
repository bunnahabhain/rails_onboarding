module RailsOnboarding
  class Configuration
    # Analytics tracking configuration.
    module Analytics
      attr_accessor :enable_analytics, :analytics_session_timeout_minutes
      attr_reader :analytics_data_retention_days, :analytics_retention_days

      # Keep analytics_retention_days in sync with analytics_data_retention_days
      def analytics_retention_days=(value)
        @analytics_retention_days = value
        @analytics_data_retention_days = value
      end

      def analytics_data_retention_days=(value)
        @analytics_data_retention_days = value
        @analytics_retention_days = value
      end

      private

      def initialize_analytics
        @enable_analytics = true
        @analytics_data_retention_days = 365 # Keep analytics data for 1 year
        @analytics_retention_days = 365 # Alias for analytics_data_retention_days
        @analytics_session_timeout_minutes = 30 # Consider session ended after 30 minutes of inactivity
      end
    end
  end
end
