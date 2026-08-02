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
    end
  end

  # Also guards the narrower-than-on_current_step_page? comparison: the dummy
  # app serves both "/" and the step's "/profile/new" from ApplicationController,
  # so a same-controller check would wrongly treat the root page as the step's
  # own and drop the link. Only an exact path match means Continue is a no-op.
  test "banner offers Continue on host pages other than the current step's" do
    get "/"

    assert_response :success
    assert_select "a.onboarding-banner-continue[href=?]", "/rails_onboarding"
  end

  # Regression: the banner linked to /onboarding unconditionally, including on
  # the step's own page. There, /onboarding re-checks :complete_if, finds it
  # unmet, and redirects back to the step's path - the page the user is already
  # on. The link rendered, the click issued GET /onboarding, and nothing moved.
  test "banner omits Continue on the current step's own page while it is incomplete" do
    get "/profile/new"

    assert_response :success
    assert_select ".onboarding-banner"
    assert_select "a.onboarding-banner-continue", count: 0
  end

  test "banner offers Continue on the step's own page once its criteria are met" do
    # With :complete_if satisfied, /onboarding advances rather than bouncing
    # back, so the link leads somewhere and belongs on the page.
    RailsOnboarding.configuration.steps = [
      { name: :welcome, title: "Welcome", icon: "🎉", skippable: true },
      { name: :profile, title: "Profile", icon: "👤", skippable: false,
        path: :new_profile_path, complete_if: ->(_user) { true } },
      { name: :explore, title: "Explore", icon: "🔍", skippable: true }
    ]

    get "/profile/new"

    assert_response :success
    assert_select "a.onboarding-banner-continue[href=?]", "/rails_onboarding"
  end

  test "a raising complete_if does not resurrect the dead Continue link" do
    RailsOnboarding.configuration.steps = [
      { name: :welcome, title: "Welcome", icon: "🎉", skippable: true },
      { name: :profile, title: "Profile", icon: "👤", skippable: false,
        path: :new_profile_path, complete_if: ->(_user) { raise "boom" } },
      { name: :explore, title: "Explore", icon: "🔍", skippable: true }
    ]

    get "/profile/new"

    assert_response :success
    assert_select ".onboarding-banner"
    assert_select "a.onboarding-banner-continue", count: 0
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
