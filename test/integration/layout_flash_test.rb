require "test_helper"

# The engine layout renders the flash. It did not, so every message on the way to onboarding was
# lost: a host redirecting there with an alert (Gift Posse's "this address has already been
# confirmed by its owner", seen by a member who opened the welcome email's other link while
# mid-onboarding), the engine's own redirect_to onboarding_path, alert:, and the Turbo Stream
# errors, which replace #flash-messages and found nothing to replace.
class LayoutFlashTest < ActionDispatch::IntegrationTest
  def setup
    @original_configuration = RailsOnboarding.configuration
    RailsOnboarding.reset_configuration!
    RailsOnboarding.configure do |config|
      config.onboarding_required_for = :all_users
      config.steps = [ { name: :welcome, title: "Welcome", icon: "🎉", skippable: true } ]
    end

    users(:one).update!(onboarding_completed: false, onboarding_current_step: "welcome",
                        onboarding_skipped: false)
    sign_in users(:one)
  end

  def teardown
    RailsOnboarding.instance_variable_set(:@configuration, @original_configuration)
  end

  test "an alert on the way to onboarding is shown there" do
    get "/test_auth/flash", params: { type: "alert", message: "Already confirmed by its owner." }
    follow_redirect!

    assert_response :success
    assert_select "#flash-messages dialog[open].flash-alert .flash-message", text: "Already confirmed by its owner."
  end

  test "a notice on the way to onboarding is shown there" do
    get "/test_auth/flash", params: { type: "notice", message: "Welcome back." }
    follow_redirect!

    assert_select "#flash-messages dialog[open].flash-notice .flash-message", text: "Welcome back."
  end

  # The Turbo Stream errors replace this element, so it is there even with nothing to say.
  test "the flash container is always present, and empty without a message" do
    get "/rails_onboarding"

    assert_select "#flash-messages"
    assert_select "#flash-messages dialog", count: 0
  end

  # A strict Content Security Policy refuses inline handlers, and says so only in the browser
  # console - the close buttons were onclick= attributes. method="dialog" needs no script.
  test "a message closes without JavaScript" do
    get "/test_auth/flash", params: { type: "alert", message: "Closable." }
    follow_redirect!

    assert_select "#flash-messages form[method=dialog] button.flash-close"
    assert_no_match(/\son[a-z]+=/, css_select("#flash-messages").to_s)
  end
end
