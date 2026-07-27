# frozen_string_literal: true

module RailsOnboarding
  # Concern for personalization capabilities on User models
  # Adapts onboarding flows based on user type, role, or other attributes
  #
  # @example Include in your User model
  #   class User < ApplicationRecord
  #     include RailsOnboarding::Onboardable
  #     include RailsOnboarding::Personalizable
  #   end
  #
  # @example Configure personalized flows
  #   RailsOnboarding.configure do |config|
  #     config.personalization_enabled = true
  #     config.user_type_method = :account_type
  #     config.personalized_flows = {
  #       individual: [
  #         { name: :welcome, title: "Welcome", icon: "🎉" },
  #         { name: :profile, title: "Setup Profile", icon: "👤" }
  #       ],
  #       business: [
  #         { name: :welcome, title: "Welcome", icon: "🎉" },
  #         { name: :company, title: "Company Info", icon: "🏢" },
  #         { name: :team, title: "Team Setup", icon: "👥" }
  #       ]
  #     }
  #   end
  module Personalizable
    extend ActiveSupport::Concern

    included do
      # Callback to set personalized steps on onboarding start
      before_save :apply_personalized_flow, if: -> { will_save_change_to_onboarding_current_step? && onboarding_current_step_was.nil? }
    end

    # Get the user's type for personalization
    #
    # @return [Symbol, String] The user type
    #
    # @example
    #   user.personalization_type
    #   # => :business
    def personalization_type
      return nil unless RailsOnboarding.configuration.personalization_enabled

      method_name = RailsOnboarding.configuration.user_type_method
      return nil unless respond_to?(method_name)

      send(method_name)
    end

    # Get the personalized onboarding steps for this user
    #
    # @return [Array<Hash>] Array of step configurations
    #
    # @example
    #   user.personalized_steps
    #   # => [{name: :welcome, title: "Welcome"}, ...]
    def personalized_steps
      return RailsOnboarding.configuration.steps unless RailsOnboarding.configuration.personalization_enabled

      user_type = personalization_type
      return RailsOnboarding.configuration.steps unless user_type

      flow = RailsOnboarding.configuration.personalized_flow(user_type)
      flow || RailsOnboarding.configuration.steps
    end

    # Get the total number of steps in the personalized flow
    #
    # @return [Integer] Number of steps
    def personalized_total_steps
      personalized_steps.size
    end

    # Get a specific step from the personalized flow
    #
    # @param name [String, Symbol] Step name
    # @return [Hash, nil] Step configuration or nil
    def personalized_step_by_name(name)
      return nil if name.nil?
      personalized_steps.find { |s| s[:name].to_s == name.to_s }
    end

    # Get the index of a step in the personalized flow
    #
    # @param name [String, Symbol] Step name
    # @return [Integer, nil] Step index or nil
    def personalized_step_index(name)
      return nil if name.nil?
      personalized_steps.find_index { |s| s[:name].to_s == name.to_s }
    end

    # Get the next step in the personalized flow
    #
    # @return [Hash, nil] Next step configuration or nil
    def personalized_next_step
      return nil if onboarding_current_step.nil?

      current_index = personalized_step_index(onboarding_current_step)
      return nil if current_index.nil?

      next_index = current_index + 1
      return nil if next_index >= personalized_total_steps

      personalized_steps[next_index]
    end

    # Get the previous step in the personalized flow
    #
    # @return [Hash, nil] Previous step configuration or nil
    def personalized_previous_step
      return nil if onboarding_current_step.nil?

      current_index = personalized_step_index(onboarding_current_step)
      return nil if current_index.nil? || current_index.zero?

      personalized_steps[current_index - 1]
    end

    # Check if this is the first step in the personalized flow
    #
    # @return [Boolean]
    def personalized_first_step?
      return false if onboarding_current_step.nil?
      personalized_step_index(onboarding_current_step)&.zero? || false
    end

    # Check if this is the last step in the personalized flow
    #
    # @return [Boolean]
    def personalized_last_step?
      return false if onboarding_current_step.nil?

      current_index = personalized_step_index(onboarding_current_step)
      return false if current_index.nil?

      current_index == personalized_total_steps - 1
    end

    # Get the progress percentage for the personalized flow
    #
    # @return [Integer] Progress as percentage (0-100)
    def personalized_progress_percentage
      return 0 if onboarding_current_step.nil?

      current_index = personalized_step_index(onboarding_current_step)
      return 0 if current_index.nil?

      ((current_index + 1).to_f / personalized_total_steps * 100).round
    end

    # Check if a specific feature should be shown to this user type
    #
    # @param feature_name [String, Symbol] Feature name
    # @return [Boolean] True if feature should be shown
    #
    # @example
    #   user.show_personalized_feature?(:team_invite)
    #   # => true (for business users)
    def show_personalized_feature?(feature_name)
      return true unless RailsOnboarding.configuration.personalization_enabled

      user_type = personalization_type
      return true unless user_type

      # Check if feature is in the personalized steps
      personalized_steps.any? { |step| step[:name].to_s == feature_name.to_s }
    end

    # Get recommended next actions based on user type
    #
    # @return [Array<Hash>] Array of recommended actions
    #
    # @example
    #   user.personalized_recommendations
    #   # => [{title: "Invite Team", description: "...", action: :invite_team}]
    def personalized_recommendations
      return [] unless RailsOnboarding.configuration.personalization_enabled
      return [] unless respond_to?(:personalization_recommendations)

      send(:personalization_recommendations)
    end

    private

    # Apply the personalized flow when onboarding starts
    # This is called automatically before save when onboarding_current_step changes from nil
    def apply_personalized_flow
      return unless RailsOnboarding.configuration.personalization_enabled
      return unless personalization_type

      # Store the personalized flow in a custom attribute if available
      if respond_to?(:personalized_flow_type=)
        self.personalized_flow_type = personalization_type.to_s
      end

      # Track the personalization in analytics if available
      if respond_to?(:track_analytics_event)
        track_analytics_event(
          "personalized_flow_applied",
          {
            user_type: personalization_type.to_s,
            flow_steps: personalized_steps.map { |s| s[:name] }.join(",")
          }
        )
      end
    end
  end
end
