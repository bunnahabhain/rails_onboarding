class AnalyticsEvent < ApplicationRecord
  # Stub model for testing - not actually used in the gem
  # Would be implemented by the host application

  # Stub class methods for analytics tracking
  class << self
    def track_step_completed(**args)
      # Noop for testing
    end

    def track_onboarding_completed(**args)
      # Noop for testing
    end

    def track_onboarding_started(**args)
      # Noop for testing
    end

    def track_step_skipped(**args)
      # Noop for testing
    end

    def track_tooltip_interaction(**args)
      # Noop for testing
    end

    def track_milestone_achieved(**args)
      # Noop for testing
    end

    def track_custom_event(**args)
      # Noop for testing
    end
  end
end
