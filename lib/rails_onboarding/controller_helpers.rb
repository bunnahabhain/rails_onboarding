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
      return true if request.path.start_with?(rails_onboarding.onboarding_path)

      on_current_step_page?
    end

    def skip_onboarding_request?
      request.xhr? ||
        request.format.json? ||
        request.path.start_with?("/api")
    end

    def onboarding_path
      rails_onboarding.onboarding_path
    end

    # Complete the current onboarding step from a host-app controller.
    #
    # Call this from the action that performs the step's real work (e.g.
    # ProfilesController#create after a successful save), then redirect to
    # onboarding_path to advance the user:
    #
    #   if advance_onboarding!(:profile)
    #     redirect_to onboarding_path
    #   else
    #     redirect_to @profile
    #   end
    #
    # Deliberately a no-op unless the named step is the user's *current*
    # step - so when the same action runs outside onboarding (the user edits
    # their profile again next week), the controller behaves normally.
    #
    # @param step_name [Symbol, String] the step this action fulfills
    # @return [Boolean] true if the step was completed and the user advanced
    def advance_onboarding!(step_name)
      return false unless user_signed_in?
      return false unless current_user.respond_to?(:needs_onboarding?)
      return false unless current_user.needs_onboarding?

      step = current_user.current_onboarding_step
      return false unless step && step[:name].to_sym == step_name.to_sym

      current_user.complete_onboarding_step!(step[:name])
      true
    end

    # Resolve a step's :path option against the host application's routes.
    # Symbols/Strings are sent to the main_app route proxy; Procs are
    # instance_exec'd in the controller context, so a zero-arg lambda can use
    # main_app, current_user, params, etc.:
    #
    #   path: :new_profile_path
    #   path: -> { main_app.new_post_path(from: "onboarding") }
    def resolve_onboarding_step_path(path)
      path.is_a?(Proc) ? instance_exec(&path) : main_app.public_send(path)
    end

    private

    # True when the current request is for the page a :path-based step points
    # at. Folded into on_onboarding_page? (and therefore needs_onboarding?) so
    # a host app's `redirect_to onboarding_path if needs_onboarding?` guard
    # doesn't bounce the user off the very page the current step sent them to
    # - without this, /onboarding redirects to the step page and the step
    # page's guard redirects straight back, forever.
    def on_current_step_page?
      return false unless user_signed_in?
      return false unless current_user.respond_to?(:current_onboarding_step)

      step = current_user.current_onboarding_step
      return false unless step.is_a?(Hash) && step[:path]

      resolved = resolve_onboarding_step_path(step[:path])
      # Compare paths only - the resolved route may carry a query string
      # (path: -> { main_app.new_post_path(from: "onboarding") }) or be a
      # full URL, while request.path never includes either.
      request.path == URI.parse(resolved.to_s).path
    rescue StandardError => e
      Rails.logger.warn("RailsOnboarding: could not resolve step path for loop guard: #{e.class} - #{e.message}")
      false
    end

    def user_signed_in?
      # Override this or use the host app's method
      defined?(current_user) && current_user.present?
    end
  end
end
