# frozen_string_literal: true

module RailsOnboarding
  module Admin
    # Base controller for admin interface
    # Provides authentication and authorization for admin actions
    class BaseController < ApplicationController
      before_action :authenticate_admin!
      layout 'rails_onboarding/admin'

      private

      # Override this method in host application to customize admin authentication
      # Example:
      #   def authenticate_admin!
      #     redirect_to root_path unless current_user&.admin?
      #   end
      def authenticate_admin!
        if defined?(authenticate_rails_onboarding_admin!)
          authenticate_rails_onboarding_admin!
        elsif respond_to?(:current_user, true)
          unless current_user&.respond_to?(:admin?) && current_user.admin?
            flash[:alert] = "You must be an administrator to access this page"
            redirect_to main_app.root_path
          end
        else
          raise NotImplementedError,
            "Please define authenticate_rails_onboarding_admin! method in your ApplicationController " \
            "or ensure your User model has an admin? method"
        end
      end

      # Check if current user has admin access
      def admin_user?
        return false unless respond_to?(:current_user, true)
        current_user&.respond_to?(:admin?) && current_user.admin?
      end
      helper_method :admin_user?

      # Rescue from unauthorized access
      rescue_from StandardError do |exception|
        logger.error "Admin error: #{exception.message}"
        logger.error exception.backtrace.join("\n")

        flash[:alert] = "An error occurred: #{exception.message}"
        redirect_to admin_dashboard_path
      end
    end
  end
end
