# frozen_string_literal: true

module RailsOnboarding
  module Admin
    # Base controller for admin interface
    # Provides authentication and authorization for admin actions
    class BaseController < ApplicationController
      before_action :authenticate_admin!
      before_action :verify_admin_authorization!
      layout 'rails_onboarding/admin'

      # Custom exception for unauthorized access
      class UnauthorizedError < StandardError; end

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
          unless current_user.present?
            flash[:alert] = "You must be logged in to access this page"
            redirect_to main_app.root_path
            return
          end

          unless current_user.respond_to?(:admin?) && current_user.admin?
            raise UnauthorizedError, "Unauthorized access to admin area"
          end
        else
          raise NotImplementedError,
            "Please define authenticate_rails_onboarding_admin! method in your ApplicationController " \
            "or ensure your User model has an admin? method"
        end
      end

      # Verify admin authorization for specific actions
      def verify_admin_authorization!
        return if admin_user?

        logger.warn "Unauthorized admin access attempt by #{current_user&.id || 'anonymous'}"
        raise UnauthorizedError, "You do not have permission to perform this action"
      end

      # Check if current user has admin access
      def admin_user?
        return false unless respond_to?(:current_user, true)
        current_user&.respond_to?(:admin?) && current_user.admin?
      end
      helper_method :admin_user?

      # rescue_from handlers are checked most-specific-last-registered-first, so the
      # generic StandardError handler must come before UnauthorizedError or it will
      # swallow every UnauthorizedError too (it's a StandardError subclass) and the
      # specific handler below becomes dead code.
      rescue_from StandardError do |exception|
        logger.error "Admin error: #{exception.message}"
        logger.error exception.backtrace.join("\n")

        respond_to do |format|
          format.html do
            flash[:alert] = "An error occurred: #{exception.message}"
            redirect_to admin_dashboard_path
          end
          format.json do
            render json: { error: exception.message }, status: :internal_server_error
          end
        end
      end

      # NotImplementedError signals the host app hasn't configured admin
      # authentication yet - it's raised by authenticate_admin! above with a
      # message telling the developer exactly what to define. It's not a
      # StandardError though, so the generic handler above never sees it and
      # it would otherwise crash instead of surfacing that guidance.
      rescue_from NotImplementedError do |exception|
        logger.error "Admin setup error: #{exception.message}"

        respond_to do |format|
          format.html do
            flash[:alert] = exception.message
            redirect_to main_app.root_path
          end
          format.json do
            render json: { error: exception.message }, status: :internal_server_error
          end
        end
      end

      # Rescue from unauthorized access
      rescue_from UnauthorizedError do |exception|
        logger.warn "Unauthorized admin access: #{exception.message}"

        respond_to do |format|
          format.html do
            flash[:alert] = "Access denied: #{exception.message}"
            redirect_to main_app.root_path
          end
          format.json do
            render json: { error: "Unauthorized access" }, status: :forbidden
          end
        end
      end
    end
  end
end
