# frozen_string_literal: true

module RailsOnboarding
  module Admin
    # Base controller for admin interface
    # Provides authentication and authorization for admin actions
    class BaseController < ApplicationController
      include RailsOnboarding::AdminAuthorization

      before_action :authenticate_admin!
      before_action :verify_admin_authorization!
      layout 'rails_onboarding/admin'

      # rescue_from handlers are checked most-recently-registered-first, so the
      # generic StandardError handler must be registered BEFORE the specific
      # ones or it swallows them all (UnauthorizedError is a StandardError
      # subclass). Keep StandardError first; the concern supplies the handler
      # methods for the two specific cases.
      rescue_from StandardError, with: :handle_admin_error
      rescue_from NotImplementedError, with: :handle_admin_not_implemented
      rescue_from UnauthorizedError, with: :handle_admin_unauthorized

      private

      # Admin-area catch-all: unlike the concern's admin-only handlers, an
      # unexpected error here sends the operator back to the admin dashboard.
      def handle_admin_error(exception)
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
    end
  end
end
