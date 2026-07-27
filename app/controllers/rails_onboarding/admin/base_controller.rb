# frozen_string_literal: true

module RailsOnboarding
  module Admin
    # Base controller for admin interface
    # Provides authentication and authorization for admin actions
    class BaseController < ApplicationController
      include RailsOnboarding::AdminAuthorization
      include Pagy::Method

      DEFAULT_PER_PAGE = 25
      # Upper bound on the client-supplied ?per_page=, so a crafted URL can't ask
      # for a whole table in one query.
      MAX_PER_PAGE = 100

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

      # Shared pagination entry point for the admin index screens.
      #
      # limit_key keeps the ?per_page= parameter these screens have always
      # documented working - pagy's own default is ?limit=. max_limit is doing
      # double duty: it is both what makes pagy honour a client-supplied value at
      # all (without it the parameter is ignored outright) and the cap enforced on
      # that value.
      #
      # Accepts an Array as well as a relation - pagy slices arrays directly - but
      # returns [] rather than nil for a page past the end of an array, which is
      # what pagy's own Array slicing gives you.
      def paginate(collection, limit: DEFAULT_PER_PAGE)
        pagy, records = pagy(collection,
                             limit: limit,
                             limit_key: 'per_page',
                             max_limit: MAX_PER_PAGE)
        [pagy, records || []]
      end

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
