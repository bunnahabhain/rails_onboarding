module RailsOnboarding
  class Configuration
    # Milestone configuration, lookups, and trigger matching.
    module Milestones
      def enable_milestones
        tenant_override(:enable_milestones, @enable_milestones)
      end

      attr_writer :enable_milestones

      def milestones
        tenant_override(:milestones, @milestones)
      end

      # Override setter to clear cache when configuration changes
      def milestones=(value)
        clear_cache!
        @milestones = value
      end

      def milestone_by_key(key)
        return nil if key.nil?

        @milestone_by_key_cache ||= {}
        @milestone_by_key_cache[key.to_sym] ||= milestones.find { |m| m[:key].to_sym == key.to_sym }
      end

      def milestones_for_trigger(trigger, conditions = {})
        cache_key = [ trigger, conditions ].hash
        @milestones_for_trigger_cache ||= {}
        @milestones_for_trigger_cache[cache_key] ||= milestones.select do |milestone|
          # Match on trigger
          next false unless milestone[:trigger] == trigger.to_sym

          # If no conditions are provided, match all milestones with this trigger
          next true if conditions.empty?

          # If milestone has no conditions, but we're providing conditions, don't match
          next false if milestone[:conditions].nil?

          # Both have conditions, check if they match
          conditions_match?(milestone[:conditions], conditions)
        end
      end

      private

      def conditions_match?(milestone_conditions, trigger_conditions)
        return true if milestone_conditions.nil?

        milestone_conditions.all? do |key, value|
          trigger_conditions[key] == value || trigger_conditions[key.to_s] == value ||
          trigger_conditions[key.to_sym] == value
        end
      end

      def initialize_milestones
        @enable_milestones = false

        # Default milestones - can be customized
        @milestones = [
          {
            key: :welcome_completed,
            title: "Welcome Aboard!",
            description: "You completed the welcome step",
            icon: "🎉",
            points: 10,
            trigger: :onboarding_step_completed,
            conditions: { step: :welcome }
          },
          {
            key: :onboarding_completed,
            title: "Onboarding Champion",
            description: "You completed the entire onboarding flow",
            icon: "🏆",
            points: 50,
            trigger: :onboarding_completed
          },
          {
            key: :early_adopter,
            title: "Early Adopter",
            description: "You joined within the first hour",
            icon: "⚡",
            points: 100,
            trigger: :custom,
            conditions: { early_adopter: true }
          }
        ]
      end
    end
  end
end
