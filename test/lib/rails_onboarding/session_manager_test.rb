require "test_helper"

module RailsOnboarding
  class SessionManagerTest < ActiveSupport::TestCase
    def setup
      @user = User.create!(
        email: "test@example.com",
        onboarding_completed: false,
        onboarding_current_step: :welcome
      )
      @session = {}
    end

    test "create_session creates new session data" do
      session_data = SessionManager.create_session(@user)

      assert_equal @user.id, session_data[:user_id]
      assert session_data[:session_id].present?
      assert_equal :welcome, session_data[:current_step]
      assert_equal [], session_data[:step_history]
    end

    test "initialize_session creates new session if none exists" do
      session_data = SessionManager.initialize_session(@user, @session)

      assert session_data.present?
      assert_equal @user.id, session_data[:user_id]
    end

    test "update_step updates session and adds to history" do
      SessionManager.initialize_session(@user, @session)
      session_data = SessionManager.update_step(@user, @session, :profile)

      assert_equal "profile", session_data[:current_step]
      assert_equal 1, session_data[:step_history].length
    end

    test "save_step_data persists form data" do
      data = { name: "John", email: "john@example.com" }
      SessionManager.save_step_data(@user, @session, :profile, data)

      retrieved_data = SessionManager.get_step_data(@user, @session, :profile)
      assert_equal data, retrieved_data
    end

    test "get_step_data returns nil for non-existent step" do
      data = SessionManager.get_step_data(@user, @session, :nonexistent)

      assert_nil data
    end

    test "clear_step_data removes data for a step" do
      data = { name: "John" }
      SessionManager.save_step_data(@user, @session, :profile, data)
      SessionManager.clear_step_data(@user, @session, :profile)

      retrieved_data = SessionManager.get_step_data(@user, @session, :profile)
      assert_nil retrieved_data
    end

    test "step_history returns empty array for new session" do
      SessionManager.initialize_session(@user, @session)
      history = SessionManager.step_history(@user, @session)

      assert_equal [], history
    end

    test "previous_step returns nil for first step" do
      SessionManager.initialize_session(@user, @session)
      prev = SessionManager.previous_step(@user, @session)

      assert_nil prev
    end

    test "clear_session removes session data" do
      SessionManager.initialize_session(@user, @session)
      SessionManager.clear_session(@user, @session)

      assert_nil @session[SessionManager::SESSION_KEY]
    end

    test "session_id returns consistent id for session" do
      SessionManager.initialize_session(@user, @session)
      id1 = SessionManager.session_id(@user, @session)
      id2 = SessionManager.session_id(@user, @session)

      assert_equal id1, id2
    end

    test "session_expired? returns false for recent session" do
      session_data = {
        last_activity_at: Time.current.iso8601
      }

      assert_equal false, SessionManager.session_expired?(session_data)
    end

    test "session_expired? returns true for old session" do
      session_data = {
        last_activity_at: (Time.current - 3.hours).iso8601
      }

      assert_equal true, SessionManager.session_expired?(session_data)
    end
  end
end
