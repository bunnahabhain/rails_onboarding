module RailsOnboarding
  module Onboardable
    extend ActiveSupport::Concern

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

    def complete_onboarding_step!(step_name)
      current_index = RailsOnboarding.configuration.step_index(step_name)

      if current_index.nil?
        # If step not found, complete onboarding
        complete_onboarding!
        return
      end

      next_step = RailsOnboarding.configuration.steps[current_index + 1]

      if next_step
        update!(onboarding_current_step: next_step[:name])
      else
        complete_onboarding!
      end
    end

    def complete_onboarding!
      update!(
        onboarding_completed: true,
        onboarding_completed_at: Time.current,
        onboarding_current_step: nil
      )
    end

    def skip_onboarding!
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

    def mark_tooltip_shown!(feature)
      self.feature_tooltips_shown ||= {}
      self.feature_tooltips_shown[feature.to_s] = Time.current.iso8601
      save!
    end

    # Milestones
    def achieved_milestones
      (milestones_achieved || []).map(&:to_s)
    end

    def milestone_achieved?(milestone_key)
      achieved_milestones.include?(milestone_key.to_s)
    end

    def achieve_milestone!(milestone_key)
      return false unless RailsOnboarding.configuration.enable_milestones
      return false if milestone_achieved?(milestone_key)

      milestone_config = RailsOnboarding.configuration.milestone_by_key(milestone_key)
      return false unless milestone_config

      self.milestones_achieved ||= []
      self.milestones_achieved << milestone_key.to_s
      self.milestone_points = (milestone_points || 0) + (milestone_config[:points] || 0)
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
  end
end
