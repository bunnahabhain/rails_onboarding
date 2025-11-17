require "test_helper"

class RobustnessTest < ActionDispatch::IntegrationTest
  def setup
    RailsOnboarding.reset_configuration!
    RailsOnboarding.configure do |config|
      config.steps = [
        { name: :welcome, title: "Welcome", icon: "🎉", skippable: true },
        { name: :profile, title: "Profile", icon: "👤", skippable: false },
        { name: :explore, title: "Explore", icon: "🔍", skippable: true }
      ]
    end

    @user = User.create!(
      email: "test@example.com",
      onboarding_completed: false,
      onboarding_current_step: :profile
    )
  end

  # Error Recovery Tests
  test "error recovery retries failed operations" do
    success = false
    attempt_count = 0

    result = RailsOnboarding::ErrorRecovery.with_recovery(@user, :test_action) do
      attempt_count += 1
      if attempt_count < 2
        raise StandardError, "Temporary failure"
      end
      success = true
      "completed"
    end

    assert_equal true, success
    assert_equal "completed", result
  end

  # Session Management Tests
  test "session persists across requests" do
    session_hash = {}
    session_data = RailsOnboarding::SessionManager.initialize_session(@user, session_hash)

    assert session_data[:session_id].present?

    # Simulate new request with same session
    restored_data = RailsOnboarding::SessionManager.restore_session(@user, session_hash)
    assert_equal session_data[:session_id], restored_data[:session_id]
  end

  test "session stores and retrieves form data" do
    session_hash = {}
    form_data = { name: "John Doe", bio: "Developer" }

    RailsOnboarding::SessionManager.save_step_data(@user, session_hash, :profile, form_data)
    retrieved = RailsOnboarding::SessionManager.get_step_data(@user, session_hash, :profile)

    assert_equal form_data, retrieved
  end

  # Rollback Tests
  test "user can go back to previous step" do
    @user.update!(onboarding_current_step: :profile)

    assert @user.can_go_back?

    result = @user.go_back!
    @user.reload

    assert_equal true, result
    assert_equal :welcome, @user.onboarding_current_step.to_sym
  end

  test "user cannot go back from first step" do
    @user.update!(onboarding_current_step: :welcome)

    assert_equal false, @user.can_go_back?
  end

  test "user can jump to specific step" do
    @user.update!(onboarding_current_step: :welcome)

    result = @user.go_to_step!(:explore)
    @user.reload

    assert_equal true, result
    assert_equal :explore, @user.onboarding_current_step.to_sym
  end

  test "user can restart onboarding" do
    @user.update!(
      onboarding_completed: true,
      onboarding_completed_at: Time.current,
      onboarding_current_step: nil
    )

    @user.restart_onboarding!
    @user.reload

    assert_equal false, @user.onboarding_completed
    assert_equal :welcome, @user.onboarding_current_step.to_sym
  end

  test "previous_onboarding_step returns correct step" do
    @user.update!(onboarding_current_step: :profile)

    prev_step = @user.previous_onboarding_step

    assert_equal :welcome, prev_step[:name]
  end

  # Skip Logic Tests
  test "conditional skip logic evaluates correctly" do
    step_with_skip = {
      name: :optional,
      title: "Optional",
      skip_if: ->(user) { user.email.include?("example") }
    }

    result = RailsOnboarding::SkipLogic.should_skip_step?(@user, step_with_skip)

    assert_equal true, result
  end

  test "skip logic finds next unskipped step" do
    RailsOnboarding.configuration.steps = [
      { name: :welcome, title: "Welcome" },
      { name: :skip1, title: "Skip 1", skip_if: ->(_) { true } },
      { name: :skip2, title: "Skip 2", skip_if: ->(_) { true } },
      { name: :profile, title: "Profile" }
    ]

    next_step = RailsOnboarding::SkipLogic.next_unskipped_step(@user, :welcome)

    assert_equal :profile, next_step[:name]
  end

  # I18n Tests
  test "translations work for different locales" do
    I18n.with_locale(:en) do
      assert_equal "Next", I18n.t("rails_onboarding.navigation.next")
    end

    I18n.with_locale(:es) do
      assert_equal "Siguiente", I18n.t("rails_onboarding.navigation.next")
    end

    I18n.with_locale(:fr) do
      assert_equal "Suivant", I18n.t("rails_onboarding.navigation.next")
    end
  end

  test "i18n helper methods work correctly" do
    # Create a helper instance
    helper = Object.new
    helper.extend(RailsOnboarding::I18nHelper)

    I18n.with_locale(:en) do
      assert_equal "Next", helper.t_nav(:next)
      assert_equal "Complete", helper.t_action(:complete)
      assert_equal "Welcome!", helper.t_message(:welcome)
    end
  end

  # Integration: Complete flow with error recovery
  test "complete onboarding flow with session persistence and rollback" do
    session_hash = {}

    # Initialize session
    RailsOnboarding::SessionManager.initialize_session(@user, session_hash)

    # Start at welcome
    @user.update!(onboarding_current_step: :welcome)

    # Complete welcome step
    @user.complete_onboarding_step!(:welcome)
    @user.reload
    assert_equal :profile, @user.onboarding_current_step.to_sym

    # Update session
    RailsOnboarding::SessionManager.update_step(@user, session_hash, :profile)

    # Save some form data
    profile_data = { name: "Test User" }
    RailsOnboarding::SessionManager.save_step_data(@user, session_hash, :profile, profile_data)

    # Go back to welcome
    @user.go_back!
    @user.reload
    assert_equal :welcome, @user.onboarding_current_step.to_sym

    # Verify form data is still there
    saved_data = RailsOnboarding::SessionManager.get_step_data(@user, session_hash, :profile)
    assert_equal profile_data, saved_data

    # Go forward again
    @user.go_to_step!(:profile)
    @user.reload
    assert_equal :profile, @user.onboarding_current_step.to_sym

    # Complete profile
    @user.complete_onboarding_step!(:profile)
    @user.reload
    assert_equal :explore, @user.onboarding_current_step.to_sym

    # Complete explore
    @user.complete_onboarding_step!(:explore)
    @user.reload
    assert_equal true, @user.onboarding_completed
  end
end
