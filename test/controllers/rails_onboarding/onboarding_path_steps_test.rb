require "test_helper"

module RailsOnboarding
  # Covers steps that live on real host-app pages instead of gem-rendered
  # templates: the :path redirect in show, :complete_if auto-advancing, and
  # the advance_onboarding! round trip from a host controller.
  class OnboardingPathStepsTest < ActionDispatch::IntegrationTest
    include Engine.routes.url_helpers

    # complete_if predicates in the test config read this, so each test can
    # flip satisfaction per-step without touching user attributes.
    mattr_accessor :satisfied_steps, default: []

    def setup
      @original_configuration = RailsOnboarding.configuration
      RailsOnboarding.reset_configuration!
      RailsOnboarding.configure do |config|
        config.steps = [
          {
            name: :welcome, title: "Welcome", icon: "🎉", skippable: true,
            complete_if: ->(_user) { OnboardingPathStepsTest.satisfied_steps.include?(:welcome) }
          },
          {
            name: :profile, title: "Profile", icon: "👤", skippable: false,
            path: :new_profile_path,
            complete_if: ->(_user) { OnboardingPathStepsTest.satisfied_steps.include?(:profile) }
          },
          {
            name: :explore, title: "Explore", icon: "🔍", skippable: true,
            complete_if: ->(_user) { OnboardingPathStepsTest.satisfied_steps.include?(:explore) }
          }
        ]
      end
      OnboardingPathStepsTest.satisfied_steps = []

      @user = users(:one)
      @user.update!(
        onboarding_completed: false,
        onboarding_current_step: "profile",
        onboarding_skipped: false
      )
      sign_in @user
    end

    def teardown
      RailsOnboarding.instance_variable_set(:@configuration, @original_configuration)
    end

    test "show redirects to the host-app page when the current step has a path" do
      get onboarding_url

      assert_redirected_to "/profile/new"
    end

    test "show resolves a Proc path in the controller context" do
      RailsOnboarding.configuration.steps[1][:path] = -> { main_app.new_profile_path(from: "onboarding") }
      RailsOnboarding.configuration.clear_cache!

      get onboarding_url

      assert_redirected_to "/profile/new?from=onboarding"
    end

    test "show auto-advances past a step whose complete_if is satisfied" do
      OnboardingPathStepsTest.satisfied_steps = [ :profile ]

      get onboarding_url

      assert_response :success
      assert_equal "explore", @user.reload.onboarding_current_step
    end

    test "show auto-advances past multiple consecutive satisfied steps" do
      @user.update!(onboarding_current_step: "welcome")
      OnboardingPathStepsTest.satisfied_steps = [ :welcome, :profile ]

      get onboarding_url

      assert_response :success
      assert_equal "explore", @user.reload.onboarding_current_step
    end

    test "show completes onboarding when the last step's complete_if is satisfied" do
      @user.update!(onboarding_current_step: "explore")
      OnboardingPathStepsTest.satisfied_steps = [ :explore ]

      get onboarding_url

      assert_redirected_to "http://www.example.com/"
      assert @user.reload.onboarding_completed
    end

    test "show completes onboarding when every step is satisfied at once" do
      @user.update!(onboarding_current_step: "welcome")
      OnboardingPathStepsTest.satisfied_steps = [ :welcome, :profile, :explore ]

      get onboarding_url

      assert_redirected_to "http://www.example.com/"
      assert @user.reload.onboarding_completed
    end

    test "an unsatisfied path step redirects to its page on every visit" do
      get onboarding_url
      assert_redirected_to "/profile/new"

      get onboarding_url
      assert_redirected_to "/profile/new"
      assert_equal "profile", @user.reload.onboarding_current_step
    end

    test "a raising complete_if is treated as unsatisfied instead of erroring" do
      @user.update!(onboarding_current_step: "welcome")
      RailsOnboarding.configuration.steps[0][:complete_if] = ->(_user) { raise "broken predicate" }
      RailsOnboarding.configuration.clear_cache!

      get onboarding_url

      assert_response :success
      assert_equal "welcome", @user.reload.onboarding_current_step
    end

    test "an unresolvable path falls back to rendering a gem template" do
      RailsOnboarding.configuration.steps[1][:path] = :nonexistent_route_path
      RailsOnboarding.configuration.clear_cache!

      get onboarding_url

      assert_response :success
      assert_equal "profile", @user.reload.onboarding_current_step
    end

    test "host controller completes a path step via advance_onboarding! round trip" do
      # /onboarding routes to the host page for the current step
      get onboarding_url
      assert_redirected_to "/profile/new"
      follow_redirect!
      assert_response :success

      # The host app's own create action advances onboarding and returns
      # (to the canonical slash-less engine root ControllerHelpers serves)
      post "/profile"
      assert_redirected_to "/rails_onboarding"
      assert_equal "explore", @user.reload.onboarding_current_step
    end

    test "an active DB flow keeps a path step working even though JSON dropped its Proc" do
      skip "Flow table not available" unless RailsOnboarding::Flow.table_exists?

      # Use a Proc path (like the real host-app configs do), so JSON serializing
      # the flow drops it entirely - the exact case that rendered the "not yet
      # configured" fallback instead of redirecting to the host page.
      RailsOnboarding.configuration.steps[1][:path] = -> { main_app.new_profile_path }
      RailsOnboarding.configuration.clear_cache!

      # Persisting the current config as an active flow is exactly what the
      # admin Flow Editor's seed does. JSON serialization can't hold the
      # :path/:complete_if Procs, which used to leave the profile step with no
      # path (rendering the fallback) and no completion criteria - the bug this
      # guards against.
      flow = RailsOnboarding::Flow.seed_default!
      RailsOnboarding.configuration.clear_cache!

      # The persisted step really did lose its Proc on the way to the database.
      persisted_profile = flow.reload.steps.find { |step| step[:name].to_s == "profile" }
      assert_not_instance_of Proc, persisted_profile[:path],
        "precondition: JSON serialization should have dropped the path Proc"

      # ...but the runtime config re-hydrates it from code, so show still
      # redirects to the host-app page instead of rendering the fallback.
      get onboarding_url
      assert_redirected_to "/profile/new"

      # complete_if is re-hydrated too, so a satisfied step still auto-advances.
      OnboardingPathStepsTest.satisfied_steps = [ :profile ]
      get onboarding_url
      assert_response :success
      assert_equal "explore", @user.reload.onboarding_current_step
    ensure
      RailsOnboarding::Flow.delete_all if RailsOnboarding::Flow.table_exists?
    end

    test "advance_onboarding! is a no-op when onboarding is already completed" do
      @user.update!(onboarding_completed: true, onboarding_completed_at: Time.current)

      post "/profile"

      assert_redirected_to "http://www.example.com/"
      assert @user.reload.onboarding_completed
    end

    test "advance_onboarding! is a no-op when the named step is not current" do
      @user.update!(onboarding_current_step: "welcome")

      post "/profile"

      assert_redirected_to "http://www.example.com/"
      assert_equal "welcome", @user.reload.onboarding_current_step
    end
  end
end
