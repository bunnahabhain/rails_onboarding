module RailsOnboarding
  module ControllerHelpers
    extend ActiveSupport::Concern

    included do
      helper_method :onboarding_enabled?, :current_user_needs_onboarding?
    end

    protected

    def check_onboarding_redirect
      return unless onboarding_enabled?
      return unless current_user_needs_onboarding?
      return if onboarding_controller?
      return if request.xhr?

      redirect_to rails_onboarding.onboarding_path
    end

    def onboarding_enabled?
      defined?(current_user) && current_user.present?
    end

    def current_user_needs_onboarding?
      current_user.respond_to?(:needs_onboarding?) && current_user.needs_onboarding?
    end

    def onboarding_controller?
      controller_path.start_with?('rails_onboarding/')
    end

    # Optional: Add this to ApplicationController
    def self.included(base)
      base.class_eval do
        # Add after_action callback if needed
        def self.enable_onboarding_check(options = {})
          after_action :check_onboarding_redirect, options
        end
      end
    end
  end
end
