require "test_helper"

# custom_js_path names a host script that the engine layout loads after its own.
# Nothing else on the engine's pages loads the host's JavaScript, so a host whose
# pages need Turbo lost it here - and a Hotwire Native app, which requires Turbo on
# every page it shows, refused them with "Turbo is not present". The setting was
# declared from the start and read by nothing, so these tests pin the wiring, not
# just the setting.
class CustomJsPathTest < ActionDispatch::IntegrationTest
  def setup
    @original_configuration = RailsOnboarding.configuration
    RailsOnboarding.reset_configuration!

    @user = users(:one)
    @user.update!(
      onboarding_completed: false,
      onboarding_current_step: "welcome",
      onboarding_skipped: false
    )
    sign_in @user
  end

  def teardown
    RailsOnboarding.instance_variable_set(:@configuration, @original_configuration)
  end

  test "no host script is loaded when custom_js_path is unset" do
    configure_onboarding

    get "/rails_onboarding"

    assert_response :success
    assert_select "script[src*=?]", "host_application", count: 0
  end

  test "custom_js_path is loaded on onboarding pages" do
    configure_onboarding { |config| config.custom_js_path = "host_application" }

    get "/rails_onboarding"

    assert_response :success
    assert_select "script[src*=?][defer]", "host_application", count: 1
  end

  # Both are deferred, so they run in document order: the engine's first, then the
  # host's, which is free to build on whatever the engine left on window.
  test "custom_js_path is loaded after the engine's own script" do
    configure_onboarding { |config| config.custom_js_path = "host_application" }

    get "/rails_onboarding"

    sources = css_select("script[src]").map { |script| script["src"] }
    engine = sources.index { |src| src.include?("rails_onboarding/application") }
    host = sources.index { |src| src.include?("host_application") }

    assert engine, "expected the engine's script to be loaded"
    assert host, "expected the host script to be loaded"
    assert engine < host, "the host script should be loaded after the engine's"
  end

  test "custom_js_path must be a String" do
    RailsOnboarding.reset_configuration!
    RailsOnboarding.configuration.custom_js_path = :application

    refute RailsOnboarding.configuration.valid?
  end

  private

  def configure_onboarding
    RailsOnboarding.configure do |config|
      config.onboarding_required_for = :all_users
      config.steps = [
        { name: :welcome, title: "Welcome", icon: "🎉", skippable: true },
        { name: :explore, title: "Explore", icon: "🔍", skippable: true }
      ]
      yield config if block_given?
    end
  end
end
