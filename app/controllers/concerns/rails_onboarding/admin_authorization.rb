# frozen_string_literal: true

module RailsOnboarding
  # Admin gate shared by the Admin dashboard controllers and by the standalone
  # AbTests/Templates controllers, which are admin-only but live outside the
  # Admin namespace. Provides the authentication/authorization before_action
  # targets plus the handler methods used to turn a denial into a friendly
  # redirect or error response.
  #
  # This concern intentionally does NOT declare any `rescue_from` handlers of
  # its own. Handler *methods* live here, but each controller declares its own
  # `rescue_from ..., with:` so the registration order stays under that
  # controller's control - `rescue_from` resolves most-recently-registered
  # first, so a generic StandardError handler must be registered before the
  # specific ones or it swallows them.
  module AdminAuthorization
    extend ActiveSupport::Concern

    # Raised when a logged-in user without admin privileges reaches an
    # admin-only action.
    class UnauthorizedError < StandardError; end

    included do
      helper_method :admin_user?
    end

    private

    # Override in the host application to customize admin authentication, e.g.
    #   def authenticate_rails_onboarding_admin!
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

    def verify_admin_authorization!
      return if admin_user?

      logger.warn "Unauthorized admin access attempt by #{current_user&.id || 'anonymous'}"
      raise UnauthorizedError, "You do not have permission to perform this action"
    end

    def admin_user?
      return false unless respond_to?(:current_user, true)

      current_user&.respond_to?(:admin?) && current_user.admin?
    end

    # A logged-in non-admin reached an admin-only action.
    def handle_admin_unauthorized(exception)
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

    # The host app hasn't wired up admin authentication yet - surface the
    # guidance from authenticate_admin! instead of crashing. NotImplementedError
    # is a ScriptError, not a StandardError, so it needs its own handler.
    def handle_admin_not_implemented(exception)
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
  end
end
