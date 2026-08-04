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
      # - onboarding_replay_started_at: datetime
      # - onboarding_replay_steps: text (serialized JSON array)

      # Fix for Rails 8: Use the new serialize syntax
      if columns_hash["feature_tooltips_shown"]&.type == :text
        serialize :feature_tooltips_shown, coder: JSON
      end

      if columns_hash["milestones_achieved"]&.type == :text
        serialize :milestones_achieved, coder: JSON
      end

      if columns_hash["onboarding_replay_steps"]&.type == :text
        serialize :onboarding_replay_steps, coder: JSON
      end

      # Association with analytics events (only if ActiveRecord is available)
      if respond_to?(:has_many)
        has_many :analytics_events,
                 as: :user,
                 class_name: "RailsOnboarding::AnalyticsEvent",
                 dependent: :destroy
      end

      # Validations for JSON field sizes (only if ActiveRecord validations are available)
      if respond_to?(:validate)
        validate :validate_tooltips_size, if: :feature_tooltips_shown_changed?
        validate :validate_milestones_size, if: :milestones_achieved_changed?
      end
    end

    class_methods do
      # Replay mode needs two columns that predate no host app: installs from
      # before it existed simply don't have them. Everything replay-related
      # degrades to the old auto-advance behaviour when they're missing rather
      # than raising on a column that isn't there.
      def onboarding_replay_supported?
        return false unless respond_to?(:column_names)

        column_names.include?("onboarding_replay_started_at") &&
          column_names.include?("onboarding_replay_steps")
      end
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
      return false if onboarding_skipped?

      case RailsOnboarding.configuration.onboarding_required_for
      when :new_users
        # Users imported before the gem was installed can have a NULL
        # created_at. An unknown signup time is not a recent one, so they're
        # treated as existing users rather than crashing on every request.
        created_at.present? && created_at > 1.hour.ago
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

    # Alias for performance testing - returns the same as current_onboarding_step
    alias_method :current_step_info, :current_onboarding_step

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

      next_step = RailsOnboarding.configuration.steps[current_index + 1]

      if next_step
        update!(onboarding_current_step: next_step[:name])
      else
        complete_onboarding!(session_id: session_id)
      end

      # Track step completion and check for milestones only after the step
      # change above has actually persisted - otherwise a failed save would
      # still leave behind an analytics event (and possibly an awarded
      # milestone) for a step completion that never happened.
      AnalyticsEvent.track_step_completed(
        user: self,
        step_name: step_name,
        step_index: current_index,
        time_spent: time_spent,
        session_id: session_id
      )
      check_and_achieve_step_milestones(step_name, session_id: session_id)
    end

    def complete_onboarding!(session_id: nil, completion_time: nil)
      persist_and_track!(
        {
          onboarding_completed: true,
          onboarding_completed_at: Time.current,
          onboarding_current_step: nil
        }.merge(replay_reset_attributes)
      ) do
        AnalyticsEvent.track_onboarding_completed(
          user: self,
          completion_time: completion_time,
          was_skipped: false,
          session_id: session_id
        )
        check_and_achieve_completion_milestones(session_id: session_id)
      end
    end

    def skip_onboarding!(session_id: nil)
      persist_and_track!(
        {
          onboarding_completed: true,
          onboarding_completed_at: Time.current,
          onboarding_skipped: true,
          onboarding_current_step: nil
        }.merge(replay_reset_attributes)
      ) do
        AnalyticsEvent.track_onboarding_completed(
          user: self,
          completion_time: nil,
          was_skipped: true,
          session_id: session_id
        )
      end
    end

    # Clear onboarding state so the user starts over.
    #
    # Milestones are cleared by default. achieve_milestone! is idempotent
    # (it returns false for anything already in milestones_achieved), so
    # leaving them behind means a user sent back through the flow can never
    # re-earn them and finishes with no milestone notice at all. Pass
    # clear_milestones: false to keep them - worth doing where a host app's
    # milestones record real achievements rather than onboarding progress.
    #
    # Any in-flight replay is cancelled: a bare reset drops the user back to
    # the default behaviour, where a step whose :complete_if already passes is
    # advanced past automatically. Use restart_onboarding! to reset *and*
    # replay.
    #
    # @param clear_milestones [Boolean] also wipe milestones, points and
    #   last_milestone_at (default: true)
    # @return [Boolean] true
    def reset_onboarding!(clear_milestones: true)
      attributes = {
        onboarding_completed: false,
        onboarding_completed_at: nil,
        onboarding_skipped: false,
        onboarding_current_step: nil,
        feature_tooltips_shown: {}
      }
      attributes.merge!(milestone_reset_attributes) if clear_milestones
      attributes.merge!(replay_reset_attributes)

      update!(attributes)
    end

    # Feature tooltips
    def show_feature_tooltip?(feature)
      return false unless RailsOnboarding.configuration.enable_tooltips
      return false unless RailsOnboarding.configuration.feature_tooltips[feature.to_s]

      shown_tooltips = (feature_tooltips_shown || {})
      !shown_tooltips[feature.to_s]
    end

    def mark_tooltip_shown!(feature, session_id: nil)
      self.feature_tooltips_shown ||= {}

      # Trim old entries if approaching limit
      if feature_tooltips_shown.size >= MAX_TOOLTIPS_SHOWN
        trim_oldest_tooltips
      end

      self.feature_tooltips_shown[feature.to_s] = Time.current.iso8601

      persist_and_track! do
        AnalyticsEvent.track_tooltip_interaction(
          user: self,
          tooltip_feature: feature,
          action: "shown",
          session_id: session_id
        )
      end
    end

    # Reset all tooltips (mark all as not shown)
    def reset_tooltips!
      self.feature_tooltips_shown = {}
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

      milestones.map { |m| m.is_a?(Hash) ? m["key"] : m.to_s }
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
          m["key"].to_s == milestone_key.to_s
        else
          m.to_s == milestone_key.to_s
        end
      end

      # Return timestamp if available, otherwise return last_milestone_at as fallback
      if milestone.is_a?(Hash) && milestone["achieved_at"]
        Time.parse(milestone["achieved_at"])
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

      self.milestones_achieved ||= []
      # Store as hash with timestamp for new achievements
      self.milestones_achieved << {
        "key" => milestone_key.to_s,
        "achieved_at" => achieved_at.iso8601
      }
      self.milestone_points = (milestone_points || 0) + points_earned
      self.last_milestone_at = achieved_at

      persist_and_track! do
        AnalyticsEvent.track_milestone_achieved(
          user: self,
          milestone_key: milestone_key,
          points_earned: points_earned,
          session_id: session_id
        )
      end

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

      # Set initial step if not already set
      if onboarding_current_step.nil? && RailsOnboarding.configuration.steps.any?
        update!(onboarding_current_step: RailsOnboarding.configuration.steps.first[:name])
      end

      AnalyticsEvent.track_onboarding_started(
        user: self,
        session_id: session_id
      )
    end

    def skip_onboarding_step!(step_name, session_id: nil)
      current_index = RailsOnboarding.configuration.step_index(step_name)
      return unless current_index

      next_step = RailsOnboarding.configuration.steps[current_index + 1]

      if next_step
        update!(onboarding_current_step: next_step[:name])
      else
        complete_onboarding!(session_id: session_id)
      end

      AnalyticsEvent.track_step_skipped(
        user: self,
        step_name: step_name,
        step_index: current_index,
        session_id: session_id
      )
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

      from_step = onboarding_current_step

      persist_and_track!(onboarding_current_step: prev_step[:name]) do
        AnalyticsEvent.track_custom_event(
          user: self,
          event_name: "onboarding_step_back",
          event_data: { from_step: from_step, to_step: prev_step[:name] },
          session_id: session_id
        )
      end
      true
    end

    def go_to_step!(step_name, session_id: nil)
      step = RailsOnboarding.configuration.step_by_name(step_name)
      return false unless step

      from_step = onboarding_current_step

      persist_and_track!(onboarding_current_step: step_name) do
        AnalyticsEvent.track_custom_event(
          user: self,
          event_name: "onboarding_step_jump",
          event_data: { from_step: from_step, to_step: step_name },
          session_id: session_id
        )
      end
      true
    end

    # Reset and immediately re-enter the flow at step one.
    #
    # Unlike a bare reset this turns replay mode on, so a user whose host-app
    # data already satisfies every :complete_if walks the steps again instead
    # of being auto-advanced straight back to "completed" on their next visit
    # to /onboarding. See replaying_onboarding?.
    def restart_onboarding!(session_id: nil, clear_milestones: true)
      previous_step = onboarding_current_step
      was_completed = onboarding_completed

      reset_onboarding!(clear_milestones: clear_milestones)
      start_onboarding_replay!
      start_onboarding!(session_id: session_id)

      AnalyticsEvent.track_custom_event(
        user: self,
        event_name: "onboarding_restarted",
        event_data: { previous_step: previous_step, was_completed: was_completed },
        session_id: session_id
      )
    end

    # Replay mode
    #
    # A reset clears onboarding's own bookkeeping, but it cannot clear the
    # host-app data a step's :complete_if reads. For an established user every
    # predicate is still satisfied, so /onboarding advances through the whole
    # flow in a single redirect and the reset looks like it did nothing.
    #
    # While a replay is active, :complete_if is no longer enough on its own -
    # the user also has to have been shown the step again. That makes a
    # restart walk the real pages a second time without touching the data
    # those predicates read.

    # Is this user currently re-walking the flow?
    #
    # False once they finish, so a completed user is never stuck in replay.
    def replaying_onboarding?
      return false unless self.class.onboarding_replay_supported?
      return false if onboarding_completed?

      onboarding_replay_started_at.present?
    end

    # @return [Boolean] false when the host app hasn't run the replay migration
    def start_onboarding_replay!
      return false unless self.class.onboarding_replay_supported?

      update!(onboarding_replay_started_at: Time.current, onboarding_replay_steps: [])
      true
    end

    def end_onboarding_replay!
      return false unless self.class.onboarding_replay_supported?

      update!(replay_reset_attributes)
      true
    end

    # Has the user been shown this step since the current replay began?
    #
    # True whenever no replay is active, so callers can gate auto-advance on
    # it unconditionally and get the ordinary behaviour outside a replay.
    def onboarding_step_replayed?(step_name)
      return true unless replaying_onboarding?

      (onboarding_replay_steps || []).map(&:to_s).include?(step_name.to_s)
    end

    # Record that the user has now seen this step. No-op outside a replay.
    def mark_onboarding_step_replayed!(step_name)
      return false unless replaying_onboarding?
      return false if onboarding_step_replayed?(step_name)

      self.onboarding_replay_steps = (onboarding_replay_steps || []) + [ step_name.to_s ]
      save!
      true
    end

    # API-friendly aliases and helper methods
    alias_method :complete_step, :complete_onboarding_step!
    alias_method :skip_step, :skip_onboarding_step!
    alias_method :next_step, :next_onboarding_step
    alias_method :previous_step, :previous_onboarding_step
    alias_method :reset_onboarding, :reset_onboarding!
    alias_method :mark_tooltip_shown, :mark_tooltip_shown!

    # Returns the onboarding steps for this user
    #
    # If multi-tenant support is enabled and the user has an organization,
    # returns organization-specific steps. Otherwise returns the default steps.
    #
    # @return [Array<Hash>] Array of step configurations
    def onboarding_steps
      # Check for organization-specific steps via MultiTenant
      if respond_to?(:current_organization_id) && current_organization_id
        MultiTenant.steps_for(current_organization_id)
      elsif respond_to?(:organization_id) && organization_id
        MultiTenant.steps_for(organization_id)
      else
        RailsOnboarding.configuration.steps
      end
    end

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
          position: config[:position] || "top"
        }
      end
    end

    # Check if a specific tooltip has been shown to this user
    #
    # This method directly checks the user's feature_tooltips_shown hash
    # to determine if a tooltip was marked as shown, regardless of whether
    # the tooltip is configured in the application settings.
    #
    # @param tooltip_id [String, Symbol] the tooltip identifier
    # @return [Boolean] true if the tooltip has been shown, false otherwise
    def tooltip_shown?(tooltip_id)
      shown_tooltips = feature_tooltips_shown || {}
      shown_tooltips.key?(tooltip_id.to_s)
    end

    # Dismiss a tooltip (marks as shown and tracks as dismissed)
    def dismiss_tooltip(tooltip_id, session_id: nil)
      # Mark as shown without tracking (to avoid duplicate event)
      self.feature_tooltips_shown ||= {}
      self.feature_tooltips_shown[tooltip_id.to_s] = Time.current.iso8601
      save!

      # Track as dismissed, not shown
      AnalyticsEvent.track_tooltip_interaction(
        user: self,
        tooltip_feature: tooltip_id,
        action: "dismissed",
        session_id: session_id
      )
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

    # Persists +attributes+ (or just re-saves already-assigned attributes if
    # none given), then runs the tracking block only after that succeeds.
    # Analytics tracking (and, transitively, any milestone-achievement it
    # triggers) must never fire for a state change that didn't actually get
    # persisted - update!/save! raise on failure, so if that happens, this
    # method never reaches the block.
    # Milestone columns arrive in a separate migration, so a host app can be
    # running without them. Only reset what actually exists.
    def milestone_reset_attributes
      attributes = {}
      attributes[:milestones_achieved] = [] if onboarding_column?("milestones_achieved")
      attributes[:milestone_points] = 0 if onboarding_column?("milestone_points")
      attributes[:last_milestone_at] = nil if onboarding_column?("last_milestone_at")
      attributes
    end

    def replay_reset_attributes
      return {} unless self.class.onboarding_replay_supported?

      { onboarding_replay_started_at: nil, onboarding_replay_steps: [] }
    end

    def onboarding_column?(name)
      self.class.respond_to?(:column_names) && self.class.column_names.include?(name)
    end

    def persist_and_track!(attributes = nil)
      if attributes
        update!(attributes)
      else
        save!
      end

      yield if block_given?
    end

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
