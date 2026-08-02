# lib/rails_onboarding/controller_helpers.rb
module RailsOnboarding
  module ControllerHelpers
    extend ActiveSupport::Concern

    included do
      helper_method :needs_onboarding?, :onboarding_path, :onboarding_continue_available?
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
      # Deliberately reads the engine proxy, not the onboarding_path method -
      # in engine controllers the engine's own url_helper shadows ours, so
      # relying on method resolution here would be ambiguous. Chomping makes
      # the match segment-aware: the engine root (with or without its
      # trailing slash) and anything under it count, but sibling host paths
      # that merely share the prefix (/onboarding_help when mounted at
      # /onboarding) do not.
      root = rails_onboarding.onboarding_path.chomp("/")
      return true if request.path == root || request.path.start_with?("#{root}/")

      on_current_step_page?
    end

    def skip_onboarding_request?
      request.xhr? ||
        request.format.json? ||
        request.path.start_with?("/api")
    end

    # The onboarding flow lives at the engine's mount root, so the raw engine
    # helper returns it with a trailing slash ("/onboarding/") like any
    # mounted engine root. Serve host apps the canonical slash-less form for
    # links and redirects.
    def onboarding_path
      path = rails_onboarding.onboarding_path.chomp("/")
      path.empty? ? "/" : path
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

    # Has this step's :complete_if been satisfied?
    #
    # A buggy :complete_if must not brick onboarding - if it raises, treat the
    # step as not yet complete instead of letting the engine's shared
    # StandardError handler redirect back to /onboarding (which would re-raise
    # on arrival, redirecting again in an endless browser loop).
    def onboarding_step_criteria_met?(step)
      return false unless step.is_a?(Hash) && step[:complete_if].is_a?(Proc)

      step[:complete_if].call(current_user)
    rescue StandardError => e
      Rails.logger.error("RailsOnboarding: complete_if for step '#{step[:name]}' raised #{e.class} - #{e.message}")
      false
    end

    # Would following the banner's "Continue" link actually move the user?
    #
    # Anywhere else in the app, yes: /onboarding routes them to the current
    # step. Standing on the step's own page it depends - /onboarding re-checks
    # :complete_if and only advances once it passes. Until then it resolves the
    # step's path and redirects straight back to the page the user is already
    # on, so the link renders but the click does nothing visible. The banner
    # asks this before offering it.
    #
    # The comparison is deliberately an exact path match rather than
    # on_current_step_page?, which also treats any other action on the same
    # controller as "on the step page". That breadth is right for the loop
    # guard - it keeps the guard off the PATCH that completes the step - but
    # wrong here: /profiles/123 is a different page from a step pointing at
    # /profiles/123/edit, and Continue really does move the user between them.
    def onboarding_continue_available?
      return false unless user_signed_in?
      return false unless current_user.respond_to?(:current_onboarding_step)

      step = current_user.current_onboarding_step
      # No :path means the step renders a gem template at /onboarding, which is
      # always somewhere other than the host page showing this banner.
      return true unless step.is_a?(Hash) && step[:path]

      # The resolved route may carry a query string or be a full URL;
      # request.path never does.
      resolved_path = URI.parse(resolve_onboarding_step_path(step[:path]).to_s).path
      return true unless request.path == resolved_path

      onboarding_step_criteria_met?(step)
    rescue StandardError => e
      # An unresolvable :path means the engine can't redirect to it either - it
      # falls back to rendering a gem template, so Continue still goes
      # somewhere. Offer it.
      Rails.logger.warn("RailsOnboarding: could not resolve step path for the banner link: #{e.class} - #{e.message}")
      true
    end

    private

    # True when the current request is for the page a :path-based step points
    # at, or for another action on that same controller. Folded into
    # on_onboarding_page? (and therefore needs_onboarding?) so a host app's
    # `redirect_to onboarding_path if needs_onboarding?` guard doesn't bounce
    # the user off the very flow the current step sent them to.
    #
    # Two things need covering, not just one:
    #   - without the exact-path check, /onboarding redirects to the step
    #     page and the step page's own guard redirects straight back, forever.
    #   - without the same-controller check, the action that actually
    #     performs the step's work (e.g. PATCH /profile for a step whose
    #     :path is edit_profile_path) never runs at all: the guard fires as a
    #     before_action on *every* controller action, so it intercepts the
    #     update/create request and redirects to /onboarding before
    #     advance_onboarding! ever gets a chance to complete the step. That
    #     action decides independently whether the step completes, so the
    #     guard only needs to get out of its way.
    def on_current_step_page?
      return false unless user_signed_in?
      return false unless current_user.respond_to?(:current_onboarding_step)

      step = current_user.current_onboarding_step
      return false unless step.is_a?(Hash) && step[:path]

      resolved = resolve_onboarding_step_path(step[:path])
      # Compare paths only - the resolved route may carry a query string
      # (path: -> { main_app.new_post_path(from: "onboarding") }) or be a
      # full URL, while request.path never includes either.
      resolved_path = URI.parse(resolved.to_s).path
      return true if request.path == resolved_path

      recognized = Rails.application.routes.recognize_path(resolved_path, method: "GET")
      recognized[:controller] == params[:controller]
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
