# frozen_string_literal: true

module RailsOnboarding
  # Integration module for seamless Devise compatibility
  # Automatically detects Devise and provides integration helpers
  module DeviseIntegration
    extend ActiveSupport::Concern

    included do
      # Detect if Devise is available
      if defined?(Devise)
        # Hook into Devise's after_sign_in callback
        after_action :redirect_to_onboarding_if_needed, only: [:create], if: -> { devise_controller? }
      end
    end

    module ClassMethods
      # Check if Devise is present in the application
      def devise_available?
        defined?(Devise)
      end

      # Configure Devise integration
      def configure_devise_integration(options = {})
        @devise_integration_options = {
          redirect_after_sign_in: true,
          redirect_after_sign_up: true,
          skip_for_admin: options.fetch(:skip_for_admin, true),
          admin_check: options.fetch(:admin_check, ->(user) { user.respond_to?(:admin?) && user.admin? })
        }.merge(options)
      end

      def devise_integration_options
        @devise_integration_options || {}
      end
    end

    # Instance methods for Devise integration
    def redirect_to_onboarding_if_needed
      return unless self.class.devise_available?
      return unless current_user
      return if devise_integration_skip_onboarding?

      if current_user.should_see_onboarding?
        store_location_for(current_user, rails_onboarding.onboarding_path) if defined?(store_location_for)
        redirect_to rails_onboarding.onboarding_path and return
      end
    end

    private

    def devise_integration_skip_onboarding?
      options = self.class.devise_integration_options

      # Skip for admins if configured
      if options[:skip_for_admin] && options[:admin_check]
        return true if options[:admin_check].call(current_user)
      end

      false
    end

    def devise_controller?
      is_a?(Devise::SessionsController) ||
      is_a?(Devise::RegistrationsController) ||
      is_a?(Devise::PasswordsController)
    rescue NameError
      false
    end
  end

  # Helper module to extend Devise controllers
  module DeviseControllerExtension
    extend ActiveSupport::Concern

    included do
      # Override Devise's after_sign_in_path_for to redirect to onboarding
      def after_sign_in_path_for(resource)
        if resource.respond_to?(:should_see_onboarding?) && resource.should_see_onboarding?
          rails_onboarding.onboarding_path
        else
          stored_location_for(resource) || super
        end
      end

      # Override Devise's after_sign_up_path_for to redirect to onboarding
      def after_sign_up_path_for(resource)
        if resource.respond_to?(:should_see_onboarding?) && resource.should_see_onboarding?
          rails_onboarding.onboarding_path
        else
          stored_location_for(resource) || super
        end
      end

      # Override after_inactive_sign_up_path_for (for unconfirmed users)
      def after_inactive_sign_up_path_for(resource)
        if RailsOnboarding.configuration.redirect_unconfirmed_to_onboarding
          # Store that they should see onboarding after confirmation
          session[:pending_onboarding] = true
          super
        else
          super
        end
      end
    end
  end

  # Railtie to auto-integrate with Devise when available
  class DeviseRailtie < Rails::Railtie
    initializer "rails_onboarding.devise_integration", after: :load_config_initializers do
      ActiveSupport.on_load(:action_controller) do
        if defined?(Devise)
          # Auto-include DeviseControllerExtension in Devise controllers
          Devise::SessionsController.include(RailsOnboarding::DeviseControllerExtension) rescue nil
          Devise::RegistrationsController.include(RailsOnboarding::DeviseControllerExtension) rescue nil

          Rails.logger.info "RailsOnboarding: Devise integration enabled"
        end
      end
    end
  end
end
