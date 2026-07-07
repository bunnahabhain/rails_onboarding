module RailsOnboarding
  class MilestoneService
    def self.check_and_award_milestones(user, trigger, conditions = {})
      return [] unless RailsOnboarding.configuration.enable_milestones
      return [] unless user

      eligible_milestones = RailsOnboarding.configuration.milestones_for_trigger(trigger, conditions)
      awarded_milestones = []

      eligible_milestones.each do |milestone|
        next if user.milestone_achieved?(milestone[:key])

        if milestone_conditions_met?(user, milestone, conditions)
          achieved_milestone = user.achieve_milestone!(milestone[:key])
          awarded_milestones << achieved_milestone if achieved_milestone
        end
      end

      awarded_milestones
    end

    def self.check_onboarding_step_milestones(user, step_name)
      check_and_award_milestones(user, :onboarding_step_completed, { step: step_name.to_sym })
    end

    def self.check_onboarding_completion_milestones(user)
      check_and_award_milestones(user, :onboarding_completed)
    end

    def self.check_early_adopter_milestone(user)
      return [] unless user.created_at > 1.hour.ago
      check_and_award_milestones(user, :custom, { early_adopter: true })
    end

    # Award a milestone requested by the client (e.g. the milestones API),
    # but only if the user genuinely qualifies for it right now. Milestones are
    # normally granted by the server-side event helpers above; this exists for
    # clients that want to claim one explicitly, and it re-derives eligibility
    # from the user's actual state so a request can't grant an unearned award.
    #
    # @return [Hash, nil] the awarded milestone config, or nil if the user is
    #   not eligible / already has it / milestones are disabled
    def self.claim_if_eligible(user, milestone_key)
      return nil unless RailsOnboarding.configuration.enable_milestones
      return nil unless user
      return nil if user.milestone_achieved?(milestone_key)

      milestone = RailsOnboarding.configuration.milestone_by_key(milestone_key)
      return nil unless milestone
      return nil unless user_eligible_for?(user, milestone)

      user.achieve_milestone!(milestone[:key])
    end

    private

    # Whether +user+ has actually met the trigger a milestone is awarded for,
    # checked against their real record - not against caller-supplied values.
    # Any trigger/condition we can't confirm server-side is denied.
    def self.user_eligible_for?(user, milestone)
      case milestone[:trigger]
      when :onboarding_step_completed
        step = milestone.dig(:conditions, :step)
        step.present? && user.step_completed?(step)
      when :onboarding_completed
        user.onboarding_completed?
      when :custom
        custom_conditions_met?(user, milestone[:conditions])
      else
        false
      end
    end

    # Custom-trigger milestones can carry arbitrary host-defined conditions, so
    # only the ones we know how to verify from the user's record are honored;
    # everything else (including an empty condition set) is treated as unearned.
    def self.custom_conditions_met?(user, conditions)
      return false if conditions.blank?

      conditions.all? do |key, value|
        case key.to_sym
        when :early_adopter
          value == true && user.created_at.present? && user.created_at > 1.hour.ago
        else
          false
        end
      end
    end

    def self.milestone_conditions_met?(user, milestone, trigger_conditions)
      return true unless milestone[:conditions]

      milestone[:conditions].all? do |key, value|
        case key
        when :step
          trigger_conditions[:step] == value.to_sym
        when :early_adopter
          user.created_at > 1.hour.ago
        else
          trigger_conditions[key] == value
        end
      end
    end
  end
end
