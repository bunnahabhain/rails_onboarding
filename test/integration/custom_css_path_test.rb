require "test_helper"

# custom_css_path names a host stylesheet that the engine layout loads last, so
# a host can retheme the flow without fighting the engine's own CSS for
# specificity. It was configurable but unread for several releases - the
# install generator wrote app/assets/stylesheets/rails_onboarding_custom.css
# and nothing ever linked it - so these tests pin the wiring, not just the
# setting.
class CustomCssPathTest < ActionDispatch::IntegrationTest
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

  test "no host stylesheet is linked when custom_css_path is unset" do
    configure_onboarding

    get "/rails_onboarding"

    assert_response :success
    assert_select "link[href*=?]", "rails_onboarding_custom", count: 0
  end

  test "custom_css_path is linked on onboarding pages" do
    configure_onboarding { |config| config.custom_css_path = "rails_onboarding_custom" }

    get "/rails_onboarding"

    assert_response :success
    assert_select "link[href*=?]", "rails_onboarding_custom", count: 1
  end

  # The whole point of the setting: overrides that land before the engine's own
  # CSS lose to it at equal specificity, which is exactly the trap hosts fell
  # into when they linked the file themselves.
  test "custom_css_path is linked after the engine and host stylesheets" do
    configure_onboarding { |config| config.custom_css_path = "rails_onboarding_custom" }

    get "/rails_onboarding"

    hrefs = css_select("link[rel=stylesheet]").map { |link| link["href"] }
    custom = hrefs.index { |href| href.include?("rails_onboarding_custom") }

    assert custom, "expected the custom stylesheet to be linked"
    assert_equal hrefs.length - 1, custom, "custom stylesheet should be linked last"
  end

  test "custom_css_path must be a String" do
    RailsOnboarding.reset_configuration!
    RailsOnboarding.configuration.custom_css_path = :rails_onboarding_custom

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
