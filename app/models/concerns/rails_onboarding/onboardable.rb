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

    def onboarding_progress
      return 100 if onboarding_completed?
      return 0 unless onboarding_current_step

      current_index = RailsOnboarding.configuration.step_index(onboarding_current_step)
      return 0 if current_index.nil?

      total_steps = RailsOnboarding.configuration.total_steps

      ((current_index + 1).to_f / total_steps * 100).round
    end

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
      (milestones_achieved || []).map(&:to_s)
    end

    def milestone_achieved?(milestone_key)
      achieved_milestones.include?(milestone_key.to_s)
    end

    def achieve_milestone!(milestone_key, session_id: nil)
      return false unless RailsOnboarding.configuration.enable_milestones
      return false if milestone_achieved?(milestone_key)

      milestone_config = RailsOnboarding.configuration.milestone_by_key(milestone_key)
      return false unless milestone_config

      points_earned = milestone_config[:points] || 0

      # Track milestone achievement
      AnalyticsEvent.track_milestone_achieved(
        user: self,
        milestone_key: milestone_key,
        points_earned: points_earned,
        session_id: session_id
      )

      self.milestones_achieved ||= []
      self.milestones_achieved << milestone_key.to_s
      self.milestone_points = (milestone_points || 0) + points_earned
      self.last_milestone_at = Time.current

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
    def trim_oldest_tooltips
      return unless feature_tooltips_shown.is_a?(Hash)
      return if feature_tooltips_shown.size < MAX_TOOLTIPS_SHOWN

      # Sort by timestamp and keep only the most recent entries
      keep_count = (MAX_TOOLTIPS_SHOWN * 0.8).to_i # Keep 80% to avoid frequent trimming
      sorted_tooltips = feature_tooltips_shown.sort_by { |_, timestamp| timestamp }
      self.feature_tooltips_shown = sorted_tooltips.last(keep_count).to_h
    end

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
