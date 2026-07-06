module RailsOnboarding
  class Configuration
    # Integration & compatibility options (Devise, Turbo, API mode,
    # background jobs, mailer).
    module Integrations
      attr_accessor :devise_integration_enabled,
                    :redirect_unconfirmed_to_onboarding,
                    :turbo_streams_enabled,
                    :turbo_morphing_enabled,
                    :api_mode_enabled,
                    :api_authentication_method,
                    :background_jobs_enabled,
                    :background_jobs_queue,
                    :mailer_from

      private

      def initialize_integrations
        @devise_integration_enabled = true
        @redirect_unconfirmed_to_onboarding = false
        @turbo_streams_enabled = true
        @turbo_morphing_enabled = false
        @api_mode_enabled = false
        @api_authentication_method = :token
        @background_jobs_enabled = false
        @background_jobs_queue = :default
        @mailer_from = "noreply@example.com"
      end
    end
  end
end
