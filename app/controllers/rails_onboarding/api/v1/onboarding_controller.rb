# frozen_string_literal: true

module RailsOnboarding
  module Api
    module V1
      class OnboardingController < ApplicationController
        include RailsOnboarding::ApiMode
        include RailsOnboarding::RateLimitable

        before_action :authenticate_api_request!

        # GET /api/v1/onboarding/status
        def status
          api_onboarding_status
        end

        # POST /api/v1/onboarding/steps/:step_name/complete
        def complete_step
          api_complete_step
        end

        # POST /api/v1/onboarding/steps/:step_name/skip
        def skip_step
          api_skip_step
        end

        # POST /api/v1/onboarding/complete
        def complete
          api_complete_onboarding
        end

        # POST /api/v1/onboarding/restart
        def restart
          api_restart_onboarding
        end
      end
    end
  end
end
