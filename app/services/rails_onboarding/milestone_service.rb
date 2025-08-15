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

    private

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
