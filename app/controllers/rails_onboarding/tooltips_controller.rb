module RailsOnboarding
  class TooltipsController < ApplicationController
    before_action :authenticate_user!

    def mark_shown
      feature = params[:feature]

      if feature.present? && current_user.respond_to?(:mark_tooltip_shown!)
        current_user.mark_tooltip_shown!(feature)
        render json: { status: 'success', feature: feature }
      else
        render json: { status: 'error', message: 'Invalid feature or user' }, status: :unprocessable_entity
      end
    end

    private

    def authenticate_user!
      # This should be overridden by the host app
      # or use the host app's authentication
      unless defined?(current_user) && current_user
        render json: { status: 'error', message: 'Authentication required' }, status: :unauthorized
      end
    end
  end
end
