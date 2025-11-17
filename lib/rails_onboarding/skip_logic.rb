module RailsOnboarding
  # Skip Logic Service
  # Allows conditional step skipping based on user data and custom conditions
  class SkipLogic
    class << self
      # Check if a step should be skipped for a user
      #
      # @param user [User] The current user
      # @param step [Hash] The step configuration
      # @return [Boolean] True if step should be skipped
      def should_skip_step?(user, step)
        return false unless step.is_a?(Hash)

        # Check if step has skip conditions
        skip_conditions = step[:skip_if]
        return false unless skip_conditions

        evaluate_conditions(user, skip_conditions)
      end

      # Evaluate skip conditions
      #
      # @param user [User] The user object
      # @param conditions [Hash, Proc, Symbol] The conditions to evaluate
      # @return [Boolean] True if conditions are met
      def evaluate_conditions(user, conditions)
        case conditions
        when Proc
          # Call proc with user
          conditions.call(user)
        when Symbol
          # Call method on user
          user.respond_to?(conditions) && user.send(conditions)
        when Hash
          # Evaluate hash conditions
          evaluate_hash_conditions(user, conditions)
        else
          false
        end
      rescue StandardError => e
        Rails.logger.error("Error evaluating skip conditions: #{e.message}")
        false
      end

      # Get next unskipped step
      #
      # @param user [User] The current user
      # @param current_step_name [Symbol] Current step name
      # @return [Hash, nil] Next unskipped step
      def next_unskipped_step(user, current_step_name)
        current_index = RailsOnboarding.configuration.step_index(current_step_name)
        return nil unless current_index

        steps = RailsOnboarding.configuration.steps
        remaining_steps = steps[(current_index + 1)..-1]

        return nil unless remaining_steps

        remaining_steps.find { |step| !should_skip_step?(user, step) }
      end

      # Get all steps that should be skipped for a user
      #
      # @param user [User] The current user
      # @return [Array<Hash>] Array of steps to skip
      def skippable_steps(user)
        RailsOnboarding.configuration.steps.select do |step|
          should_skip_step?(user, step)
        end
      end

      # Get all steps that are required for a user
      #
      # @param user [User] The current user
      # @return [Array<Hash>] Array of required steps
      def required_steps(user)
        RailsOnboarding.configuration.steps.reject do |step|
          should_skip_step?(user, step)
        end
      end

      # Calculate actual progress excluding skipped steps
      #
      # @param user [User] The current user
      # @return [Integer] Progress percentage
      def progress_excluding_skipped(user)
        required = required_steps(user)
        return 100 if required.empty?

        current_index = required.find_index { |s| s[:name] == user.onboarding_current_step&.to_sym }
        return 0 unless current_index

        ((current_index + 1).to_f / required.size * 100).round
      end

      # Check if user should auto-skip to next step
      #
      # @param user [User] The current user
      # @param step_name [Symbol] The step to check
      # @return [Hash, nil] Next step if should auto-skip, nil otherwise
      def auto_skip_step(user, step_name)
        step = RailsOnboarding.configuration.step_by_name(step_name)
        return nil unless step

        if should_skip_step?(user, step) && step[:auto_skip]
          next_unskipped_step(user, step_name)
        end
      end

      private

      # Evaluate hash-based conditions
      def evaluate_hash_conditions(user, conditions)
        operator = conditions[:operator] || :all

        predicates = conditions.except(:operator).map do |key, value|
          evaluate_predicate(user, key, value)
        end

        case operator
        when :all
          predicates.all?
        when :any
          predicates.any?
        when :none
          predicates.none?
        else
          predicates.all?
        end
      end

      # Evaluate a single predicate
      def evaluate_predicate(user, key, value)
        case key
        when :has_attribute
          user.respond_to?(value) && user.send(value).present?
        when :missing_attribute
          !user.respond_to?(value) || user.send(value).blank?
        when :attribute_equals
          attribute, expected = value.is_a?(Hash) ? value.first : [value, true]
          user.respond_to?(attribute) && user.send(attribute) == expected
        when :attribute_not_equals
          attribute, expected = value.is_a?(Hash) ? value.first : [value, true]
          !user.respond_to?(attribute) || user.send(attribute) != expected
        when :has_role
          user.respond_to?(:has_role?) && user.has_role?(value)
        when :custom
          value.is_a?(Proc) ? value.call(user) : false
        else
          # Try to call as method on user
          user.respond_to?(key) && user.send(key) == value
        end
      rescue StandardError => e
        Rails.logger.error("Error evaluating predicate #{key}: #{e.message}")
        false
      end
    end
  end
end
