module RailsOnboarding
  module Onboardable
    extend ActiveSupport::Concern

    # Maximum sizes for JSON fields to prevent memory issues
    MAX_TOOLTIPS_SHOWN = 1000
    MAX_MILESTONES_ACHIEVED = 500
    MAX_JSON_SIZE_BYTES = 65_535 # ~64KB for TEXT columns

    included do
      # Add fields via migration or expect them in the host model
      # The host app should have these columns:
      # - onboarding_completed: boolean
      # - onboarding_completed_at: datetime
      # - onboarding_current_step: string
      # - onboarding_skipped: boolean
      # - feature_tooltips_shown: jsonb/text (serialized)
      # - milestones_achieved: text (serialized JSON array)
      # - milestone_points: integer
      # - last_milestone_at: datetime

      # Fix for Rails 8: Use the new serialize syntax
      if columns_hash["feature_tooltips_shown"]&.type == :text
        serialize :feature_tooltips_shown, coder: JSON
      end

      if columns_hash["milestones_achieved"]&.type == :text
        serialize :milestones_achieved, coder: JSON
      end

      # Validations for JSON field sizes
      validate :validate_tooltips_size, if: :feature_tooltips_shown_changed?
      validate :validate_milestones_size, if: :milestones_achieved_changed?
    end

    # Determines if the user needs to go through onboarding
    #
    # This method checks the configuration setting and user state to determine
    # if onboarding should be shown. It supports different strategies:
    # - :new_users - Only users created within the last hour
    # - :all_users - All users who haven't completed onboarding
    # - Proc - Custom logic defined in configuration
    #
    # @return [Boolean] true if onboarding is needed, false otherwise
    def needs_onboarding?
      return false if onboarding_completed?

      case RailsOnboarding.configuration.onboarding_required_for
      when :new_users
        created_at > 1.hour.ago
      when :all_users
        true
      when Proc
        RailsOnboarding.configuration.onboarding_required_for.call(self)
      else
        true
      end
    end

    # Calculate onboarding progress as a percentage
    #
    # Returns a value between 0 and 100 representing how far the user has
    # progressed through the onboarding flow. Calculation is based on
    # current step position divided by total steps.
    #
    # @return [Integer] progress percentage (0-100)
    # @example
    #   user.onboarding_progress #=> 75
    def onboarding_progress
      return 100 if onboarding_completed?
      return 0 unless onboarding_current_step

      current_index = RailsOnboarding.configuration.step_index(onboarding_current_step)
      return 0 if current_index.nil?

      total_steps = RailsOnboarding.configuration.total_steps

      ((current_index + 1).to_f / total_steps * 100).round
    end

    # Alias for API compatibility
    alias_method :onboarding_progress_percentage, :onboarding_progress

    def current_onboarding_step
      return nil if onboarding_completed?

      step_name = onboarding_current_step || RailsOnboarding.configuration.steps.first[:name]
      step = RailsOnboarding.configuration.step_by_name(step_name)

      step || RailsOnboarding.configuration.steps.first
    end

    def next_onboarding_step
      return nil if onboarding_completed?

      current_index = RailsOnboarding.configuration.step_index(onboarding_current_step)
      return RailsOnboarding.configuration.steps.first unless current_index

      next_step = RailsOnboarding.configuration.steps[current_index + 1]
      next_step
    end

    # Complete the current onboarding step and advance to the next
    #
    # This method handles the core onboarding flow logic:
    # 1. Validates the step exists in the configuration
    # 2. Tracks step completion for analytics
    # 3. Checks and awards any relevant milestones
    # 4. Advances to the next step or completes onboarding if on the last step
    #
    # @param step_name [String, Symbol] the name of the step to complete
    # @param session_id [String] optional session identifier for tracking
    # @param time_spent [Integer] optional time spent on step in seconds
    # @return [void]
    # @raise [ActiveRecord::RecordInvalid] if the update fails
    def complete_onboarding_step!(step_name, session_id: nil, time_spent: nil)
      current_index = RailsOnboarding.configuration.step_index(step_name)

      if current_index.nil?
        # If step not found, complete onboarding
        complete_onboarding!(session_id: session_id)
        return
      end

      # Track step completion
      AnalyticsEvent.track_step_completed(
        user: self,
        step_name: step_name,
        step_index: current_index,
        time_spent: time_spent,
        session_id: session_id
      )

      # Check for milestone achievements
      check_and_achieve_step_milestones(step_name, session_id: session_id)

      next_step = RailsOnboarding.configuration.steps[current_index + 1]

      if next_step
        update!(onboarding_current_step: next_step[:name])
      else
        complete_onboarding!(session_id: session_id)
      end
    end

    def complete_onboarding!(session_id: nil, completion_time: nil)
      was_skipped = false
      
      # Track completion
      AnalyticsEvent.track_onboarding_completed(
        user: self,
        completion_time: completion_time,
        was_skipped: was_skipped,
        session_id: session_id
      )

      # Check for completion milestone
      check_and_achieve_completion_milestones(session_id: session_id)
      
      update!(
        onboarding_completed: true,
        onboarding_completed_at: Time.current,
        onboarding_current_step: nil
      )
    end

    def skip_onboarding!(session_id: nil)
      was_skipped = true
      
      # Track skipping
      AnalyticsEvent.track_onboarding_completed(
        user: self,
        completion_time: nil,
        was_skipped: was_skipped,
        session_id: session_id
      )
      
      update!(
        onboarding_completed: true,
        onboarding_completed_at: Time.current,
        onboarding_skipped: true,
        onboarding_current_step: nil
      )
    end

    def reset_onboarding!
      update!(
        onboarding_completed: false,
        onboarding_completed_at: nil,
        onboarding_skipped: false,
        onboarding_current_step: nil,
        feature_tooltips_shown: {}
      )
    end

    # Feature tooltips
    def show_feature_tooltip?(feature)
      return false unless RailsOnboarding.configuration.enable_tooltips
      return false unless RailsOnboarding.configuration.feature_tooltips[feature.to_s]

      shown_tooltips = (feature_tooltips_shown || {})
      !shown_tooltips[feature.to_s]
    end

    def mark_tooltip_shown!(feature, session_id: nil)
      # Track tooltip shown
      AnalyticsEvent.track_tooltip_interaction(
        user: self,
        tooltip_feature: feature,
        action: 'shown',
        session_id: session_id
      )

      self.feature_tooltips_shown ||= {}

      # Trim old entries if approaching limit
      if feature_tooltips_shown.size >= MAX_TOOLTIPS_SHOWN
        trim_oldest_tooltips
      end

      self.feature_tooltips_shown[feature.to_s] = Time.current.iso8601
      save!
    end

    def track_tooltip_interaction!(feature, action, session_id: nil)
      AnalyticsEvent.track_tooltip_interaction(
        user: self,
        tooltip_feature: feature,
        action: action,
        session_id: session_id
      )
    end

    # Milestones
    def achieved_milestones
      milestones = milestones_achieved || []

      # Warn about old format if any string entries are found
      if milestones.any? { |m| m.is_a?(String) }
        RailsOnboarding::Deprecation.deprecate_format(
          "Storing milestones as array of strings",
          new_format: "array of hashes with 'key' and 'achieved_at' fields",
          version: "2.0.0"
        )
      end

      milestones.map { |m| m.is_a?(Hash) ? m['key'] : m.to_s }
    end

    def milestone_achieved?(milestone_key)
      achieved_milestones.include?(milestone_key.to_s)
    end

    # Get the timestamp when a specific milestone was achieved
    #
    # This method supports both old (string array) and new (hash array) formats
    # for backwards compatibility. For old format data, it returns last_milestone_at
    # as a fallback since per-milestone timestamps weren't stored.
    #
    # @param milestone_key [String, Symbol] the milestone key to lookup
    # @return [Time, nil] the achievement timestamp, or nil if not achieved
    # @example
    #   user.milestone_achieved_at(:first_login) #=> 2025-01-15 10:30:00 UTC
    def milestone_achieved_at(milestone_key)
      return nil unless milestone_achieved?(milestone_key)

      # Support both old array format and new hash format
      milestones = milestones_achieved || []
      milestone = milestones.find do |m|
        if m.is_a?(Hash)
          m['key'].to_s == milestone_key.to_s
        else
          m.to_s == milestone_key.to_s
        end
      end

      # Return timestamp if available, otherwise return last_milestone_at as fallback
      if milestone.is_a?(Hash) && milestone['achieved_at']
        Time.parse(milestone['achieved_at'])
      else
        last_milestone_at
      end
    rescue StandardError
      last_milestone_at
    end

    def achieve_milestone!(milestone_key, session_id: nil)
      return false unless RailsOnboarding.configuration.enable_milestones
      return false if milestone_achieved?(milestone_key)

      milestone_config = RailsOnboarding.configuration.milestone_by_key(milestone_key)
      return false unless milestone_config

      points_earned = milestone_config[:points] || 0
      achieved_at = Time.current

      # Track milestone achievement
      AnalyticsEvent.track_milestone_achieved(
        user: self,
        milestone_key: milestone_key,
        points_earned: points_earned,
        session_id: session_id
      )

      self.milestones_achieved ||= []
      # Store as hash with timestamp for new achievements
      self.milestones_achieved << {
        'key' => milestone_key.to_s,
        'achieved_at' => achieved_at.iso8601
      }
      self.milestone_points = (milestone_points || 0) + points_earned
      self.last_milestone_at = achieved_at

      save!
      milestone_config
    end

    def total_milestone_points
      milestone_points || 0
    end

    def milestones_available
      return [] unless RailsOnboarding.configuration.enable_milestones
      RailsOnboarding.configuration.milestones.reject { |m| milestone_achieved?(m[:key]) }
    end

    def recent_milestones(limit: 5)
      return [] unless RailsOnboarding.configuration.enable_milestones

      achieved_milestones.last(limit).map do |key|
        RailsOnboarding.configuration.milestone_by_key(key)
      end.compact
    end

    def start_onboarding!(session_id: nil)
      return if onboarding_completed?

      # Track onboarding start
      AnalyticsEvent.track_onboarding_started(
        user: self,
        session_id: session_id
      )

      # Set initial step if not already set
      if onboarding_current_step.nil? && RailsOnboarding.configuration.steps.any?
        update!(onboarding_current_step: RailsOnboarding.configuration.steps.first[:name])
      end
    end

    def skip_onboarding_step!(step_name, session_id: nil)
      current_index = RailsOnboarding.configuration.step_index(step_name)
      return unless current_index

      # Track step skip
      AnalyticsEvent.track_step_skipped(
        user: self,
        step_name: step_name,
        step_index: current_index,
        session_id: session_id
      )

      next_step = RailsOnboarding.configuration.steps[current_index + 1]

      if next_step
        update!(onboarding_current_step: next_step[:name])
      else
        complete_onboarding!(session_id: session_id)
      end
    end

    # Rollback & Navigation Methods

    def can_go_back?
      return false unless onboarding_current_step
      current_index = RailsOnboarding.configuration.step_index(onboarding_current_step)
      current_index && current_index > 0
    end

    def previous_onboarding_step
      return nil unless can_go_back?
      current_index = RailsOnboarding.configuration.step_index(onboarding_current_step)
      RailsOnboarding.configuration.steps[current_index - 1]
    end

    def go_back!(session_id: nil)
      return false unless can_go_back?

      prev_step = previous_onboarding_step
      return false unless prev_step

      # Track navigation
      if defined?(AnalyticsEvent)
        AnalyticsEvent.track_custom_event(
          user: self,
          event_name: 'onboarding_step_back',
          event_data: {
            from_step: onboarding_current_step,
            to_step: prev_step[:name]
          },
          session_id: session_id
        )
      end

      update!(onboarding_current_step: prev_step[:name])
      true
    end

    def go_to_step!(step_name, session_id: nil)
      step = RailsOnboarding.configuration.step_by_name(step_name)
      return false unless step

      # Track navigation
      if defined?(AnalyticsEvent)
        AnalyticsEvent.track_custom_event(
          user: self,
          event_name: 'onboarding_step_jump',
          event_data: {
            from_step: onboarding_current_step,
            to_step: step_name
          },
          session_id: session_id
        )
      end

      update!(onboarding_current_step: step_name)
      true
    end

    def restart_onboarding!(session_id: nil)
      # Track restart
      if defined?(AnalyticsEvent)
        AnalyticsEvent.track_custom_event(
          user: self,
          event_name: 'onboarding_restarted',
          event_data: {
            previous_step: onboarding_current_step,
            was_completed: onboarding_completed
          },
          session_id: session_id
        )
      end

      reset_onboarding!
      start_onboarding!(session_id: session_id)
    end

    # API-friendly aliases and helper methods
    alias_method :complete_step, :complete_onboarding_step!
    alias_method :skip_step, :skip_onboarding_step!
    alias_method :next_step, :next_onboarding_step
    alias_method :previous_step, :previous_onboarding_step

    # Check if a specific step has been completed
    def step_completed?(step_name)
      return false unless step_name

      step_index = RailsOnboarding.configuration.step_index(step_name)
      return false if step_index.nil?

      # If onboarding is completed, all steps are completed
      return true if onboarding_completed?

      # Check if current step is past the requested step
      current_index = RailsOnboarding.configuration.step_index(onboarding_current_step)
      return false if current_index.nil?

      current_index > step_index
    end

    # Get available tooltips that haven't been shown
    def available_tooltips
      return [] unless RailsOnboarding.configuration.enable_tooltips

      RailsOnboarding.configuration.feature_tooltips.select do |key, _config|
        show_feature_tooltip?(key)
      end.map do |key, config|
        {
          id: key.to_s,
          title: config[:title],
          content: config[:content],
          target: config[:target],
          position: config[:position] || 'top'
        }
      end
    end

    # Check if a specific tooltip has been shown
    def tooltip_shown?(tooltip_id)
      !show_feature_tooltip?(tooltip_id)
    end

    # Dismiss a tooltip (alias for mark_tooltip_shown!)
    def dismiss_tooltip(tooltip_id, session_id: nil)
      mark_tooltip_shown!(tooltip_id, session_id: session_id)
      true
    rescue StandardError => e
      Rails.logger.error("Failed to dismiss tooltip: #{e.message}")
      false
    end

    # Onboarding skipped check
    def onboarding_skipped?
      onboarding_skipped == true
    end

    private

    # Validation methods for JSON field sizes
    def validate_tooltips_size
      return unless feature_tooltips_shown.is_a?(Hash)

      # Check number of entries
      if feature_tooltips_shown.size > MAX_TOOLTIPS_SHOWN
        errors.add(:feature_tooltips_shown, "cannot exceed #{MAX_TOOLTIPS_SHOWN} entries")
      end

      # Check serialized size
      json_size = feature_tooltips_shown.to_json.bytesize
      if json_size > MAX_JSON_SIZE_BYTES
        errors.add(:feature_tooltips_shown, "size (#{json_size} bytes) exceeds maximum #{MAX_JSON_SIZE_BYTES} bytes")
      end
    end

    def validate_milestones_size
      return unless milestones_achieved.is_a?(Array)

      # Check number of entries
      if milestones_achieved.size > MAX_MILESTONES_ACHIEVED
        errors.add(:milestones_achieved, "cannot exceed #{MAX_MILESTONES_ACHIEVED} entries")
      end

      # Check serialized size
      json_size = milestones_achieved.to_json.bytesize
      if json_size > MAX_JSON_SIZE_BYTES
        errors.add(:milestones_achieved, "size (#{json_size} bytes) exceeds maximum #{MAX_JSON_SIZE_BYTES} bytes")
      end
    end

    # Trim oldest tooltip entries to prevent exceeding limits
    #
    # This method is called automatically when approaching the MAX_TOOLTIPS_SHOWN limit
    # to prevent unbounded growth of the JSON field. It keeps the 80% most recent
    # tooltips to avoid frequent trimming operations.
    #
    # @return [void]
    # @private
    def trim_oldest_tooltips
      return unless feature_tooltips_shown.is_a?(Hash)
      return if feature_tooltips_shown.size < MAX_TOOLTIPS_SHOWN

      # Sort by timestamp and keep only the most recent entries
      keep_count = (MAX_TOOLTIPS_SHOWN * 0.8).to_i # Keep 80% to avoid frequent trimming
      sorted_tooltips = feature_tooltips_shown.sort_by { |_, timestamp| timestamp }
      self.feature_tooltips_shown = sorted_tooltips.last(keep_count).to_h
    end

    # Check for and award milestones triggered by completing a specific step
    #
    # This method is called automatically after a step is completed. It looks up
    # all milestones configured with the :onboarding_step_completed trigger and
    # awards them if their conditions match the completed step.
    #
    # @param step_name [String, Symbol] the name of the completed step
    # @param session_id [String] optional session identifier for tracking
    # @return [void]
    # @private
    def check_and_achieve_step_milestones(step_name, session_id: nil)
      return unless RailsOnboarding.configuration.enable_milestones

      matching_milestones = RailsOnboarding.configuration.milestones_for_trigger(
        :onboarding_step_completed,
        { step: step_name }
      )

      matching_milestones.each do |milestone|
        achieve_milestone!(milestone[:key], session_id: session_id)
      end
    end

    def check_and_achieve_completion_milestones(session_id: nil)
      return unless RailsOnboarding.configuration.enable_milestones

      matching_milestones = RailsOnboarding.configuration.milestones_for_trigger(
        :onboarding_completed
      )

      matching_milestones.each do |milestone|
        achieve_milestone!(milestone[:key], session_id: session_id)
      end
    end
  end
end
