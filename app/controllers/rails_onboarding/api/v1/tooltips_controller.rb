# frozen_string_literal: true

module RailsOnboarding
  module Api
    module V1
      class TooltipsController < ApplicationController
        include RailsOnboarding::ApiMode
        include RailsOnboarding::RateLimitable

        before_action :authenticate_api_request!

        # GET /api/v1/tooltips
        def index
          api_tooltips_list
        end

        # POST /api/v1/tooltips/:tooltip_id/dismiss
        def dismiss
          api_dismiss_tooltip
        end

        private

        def current_user
          @current_user ||= begin
            token = extract_api_token
            authenticate_with_token(token) if token.present?
          end
        end
      end
    end
  end
end
