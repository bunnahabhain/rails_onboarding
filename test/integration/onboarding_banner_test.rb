require "test_helper"

# The onboarding banner is the gem-provided chrome a host layout renders on
# its own pages while onboarding is in progress (see
# rails_onboarding/shared/_onboarding_banner). The dummy app renders it from
# app/views/layouts/application.html.erb like a real host would.
class OnboardingBannerTest < ActionDispatch::IntegrationTest
  def setup
    @original_configuration = RailsOnboarding.configuration
    RailsOnboarding.reset_configuration!
    RailsOnboarding.configure do |config|
      config.onboarding_required_for = :all_users
      config.steps = [
        { name: :welcome, title: "Welcome", icon: "🎉", skippable: true },
        { name: :profile, title: "Profile", icon: "👤", skippable: false, path: :new_profile_path },
        { name: :explore, title: "Explore", icon: "🔍", skippable: true }
      ]
    end

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

  test "banner shows on the current step's host page with progress and title" do
    get "/profile/new"

    assert_response :success
    assert_select ".onboarding-banner" do
      assert_select ".onboarding-banner-step", text: /Step 2\s+of 3:\s+👤 Profile/
      assert_select "a.onboarding-banner-continue[href=?]", "/rails_onboarding"
    end
  end

  test "banner does not leak its ERB header comment into the page" do
    # Regression: an ERB comment ends at the first %> sequence, so an
    # embedded example tag once cut the header comment short and rendered
    # its tail ("Self-contained on purpose: ...") as page text.
    get "/profile/new"

    assert_response :success
    assert_no_match(/Self-contained on purpose/, response.body)
    assert_no_match(/Onboarding chrome for host-app pages/, response.body)
  end

  test "banner hides the skip button on non-skippable steps" do
    get "/profile/new"

    assert_select ".onboarding-banner"
    assert_select ".onboarding-banner-skip", count: 0
  end

  test "banner shows the skip button on skippable steps" do
    @user.update!(onboarding_current_step: "explore")

    get "/profile/new"

    assert_select "form[action=?]", "/rails_onboarding/skip" do
      assert_select "button[type=submit]", text: "Skip this step"
    end
  end

  test "banner does not render when onboarding is completed" do
    @user.update!(onboarding_completed: true, onboarding_completed_at: Time.current)

    get "/profile/new"

    assert_response :success
    assert_select ".onboarding-banner", count: 0
  end

  test "banner does not render when onboarding was skipped" do
    @user.update!(onboarding_skipped: true)

    get "/profile/new"

    assert_response :success
    assert_select ".onboarding-banner", count: 0
  end

  test "banner does not render for signed-out visitors" do
    sign_out

    get "/profile/new"

    assert_response :success
    assert_select ".onboarding-banner", count: 0
  end
end
