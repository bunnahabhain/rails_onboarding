module RailsOnboarding
  # Session Manager
  # Handles browser refresh/navigation during onboarding
  # Persists onboarding state to allow seamless resume
  class SessionManager
    SESSION_KEY = 'rails_onboarding_session'
    SESSION_TIMEOUT = 2.hours

    class << self
      # Initialize or restore onboarding session
      #
      # @param user [User] The current user
      # @param session [ActionDispatch::Session] Rails session
      # @return [Hash] Session data
      def initialize_session(user, session)
        session_data = restore_session(user, session)

        # If no existing session or expired, create new one
        if session_data.nil? || session_expired?(session_data)
          session_data = create_session(user)
        end

        # Update last activity
        session_data[:last_activity_at] = Time.current.iso8601
        persist_session(user, session, session_data)

        session_data
      end

      # Create a new onboarding session
      def create_session(user)
        {
          user_id: user.id,
          started_at: Time.current.iso8601,
          last_activity_at: Time.current.iso8601,
          current_step: user.onboarding_current_step,
          step_history: [],
          form_data: {},
          progress: user.onboarding_progress,
          session_id: SecureRandom.uuid
        }
      end

      # Restore session from storage
      def restore_session(user, session)
        # Try session storage first
        session_data = session[SESSION_KEY]
        return parse_session_data(session_data) if session_data

        # Try database storage if available
        if user.respond_to?(:onboarding_session_data)
          parse_session_data(user.onboarding_session_data)
        end
      end

      # Persist session to storage
      def persist_session(user, session, session_data)
        # Store in Rails session
        session[SESSION_KEY] = session_data.to_json

        # Also persist to database if available
        if user.respond_to?(:onboarding_session_data=)
          user.onboarding_session_data = session_data.to_json
          user.save(validate: false) rescue nil
        end
      end

      # Update current step in session
      def update_step(user, session, step_name)
        session_data = initialize_session(user, session)

        # Add previous step to history
        if session_data[:current_step] && session_data[:current_step] != step_name
          session_data[:step_history] ||= []
          session_data[:step_history] << {
            step: session_data[:current_step],
            completed_at: Time.current.iso8601
          }
        end

        session_data[:current_step] = step_name.to_s
        session_data[:progress] = user.onboarding_progress
        session_data[:last_activity_at] = Time.current.iso8601

        persist_session(user, session, session_data)
        session_data
      end

      # Save form data for a step
      def save_step_data(user, session, step_name, data)
        session_data = initialize_session(user, session)
        session_data[:form_data] ||= {}
        session_data[:form_data][step_name.to_s] = {
          data: data,
          saved_at: Time.current.iso8601
        }
        persist_session(user, session, session_data)
      end

      # Get saved form data for a step
      def get_step_data(user, session, step_name)
        session_data = restore_session(user, session)
        return nil unless session_data

        step_data = session_data.dig(:form_data, step_name.to_sym)
        step_data ? step_data[:data] : nil
      end

      # Clear step data
      def clear_step_data(user, session, step_name)
        session_data = initialize_session(user, session)
        session_data[:form_data]&.delete(step_name.to_s)
        persist_session(user, session, session_data)
      end

      # Get step history
      def step_history(user, session)
        session_data = restore_session(user, session)
        return [] unless session_data
        session_data[:step_history] || []
      end

      # Get previous step from history
      def previous_step(user, session)
        history = step_history(user, session)
        return nil if history.empty?
        history.last[:step]
      end

      # Check if session is expired
      def session_expired?(session_data)
        return true unless session_data&.dig(:last_activity_at)

        last_activity = Time.parse(session_data[:last_activity_at])
        Time.current - last_activity > SESSION_TIMEOUT
      rescue StandardError
        true
      end

      # Clear session data
      def clear_session(user, session)
        session.delete(SESSION_KEY)

        if user.respond_to?(:onboarding_session_data=)
          user.onboarding_session_data = nil
          user.save(validate: false) rescue nil
        end
      end

      # Resume from saved session
      def resume_session(user, session)
        session_data = restore_session(user, session)

        return nil if session_data.nil? || session_expired?(session_data)

        # Sync user state with session
        if user.onboarding_current_step != session_data[:current_step]
          user.update(onboarding_current_step: session_data[:current_step]) rescue nil
        end

        session_data
      end

      # Get session ID for analytics tracking
      def session_id(user, session)
        session_data = restore_session(user, session)
        session_data&.dig(:session_id) || SecureRandom.uuid
      end

      private

      def parse_session_data(data)
        return nil unless data

        parsed = if data.is_a?(String)
                   JSON.parse(data)
                 else
                   data
                 end

        parsed.deep_symbolize_keys
      rescue JSON::ParserError
        nil
      end
    end
  end
end
