# lib/rails_onboarding/controller_helpers.rb
module RailsOnboarding
  module ControllerHelpers
    extend ActiveSupport::Concern

    included do
      helper_method :needs_onboarding?, :onboarding_path
    end

    # Configuration at the controller level
    class_methods do
      def skip_onboarding_check(options = {})
        @skip_onboarding_options = options
      end

      def skip_onboarding_for_action?(action)
        return false unless @skip_onboarding_options

        if @skip_onboarding_options[:only]
          Array(@skip_onboarding_options[:only]).include?(action.to_sym)
        elsif @skip_onboarding_options[:except]
          !Array(@skip_onboarding_options[:except]).include?(action.to_sym)
        else
          true
        end
      end
    end

    def needs_onboarding?
      return false unless user_signed_in?
      return false if on_onboarding_page?
      return false if skip_onboarding_request?
      return false if self.class.skip_onboarding_for_action?(action_name)

      current_user.needs_onboarding?
    end

    def on_onboarding_page?
      request.path.start_with?(rails_onboarding.onboarding_path)
    end

    def skip_onboarding_request?
      request.xhr? ||
        request.format.json? ||
        request.path.start_with?("/api")
    end

    def onboarding_path
      rails_onboarding.onboarding_path
    end

    private

    def user_signed_in?
      # Override this or use the host app's method
      defined?(current_user) && current_user.present?
    end
  end
end
