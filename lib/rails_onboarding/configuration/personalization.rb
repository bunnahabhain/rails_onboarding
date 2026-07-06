module RailsOnboarding
  class Configuration
    # Per-user-type personalized onboarding flows.
    module Personalization
      attr_accessor :personalization_enabled, :user_type_method, :personalized_flows

      # Get a personalized flow for a user type
      #
      # @param user_type [Symbol, String] The user type
      # @return [Array, nil] The personalized steps or nil
      def personalized_flow(user_type)
        return nil unless personalization_enabled
        personalized_flows[user_type.to_sym]
      end

      private

      def initialize_personalization
        @personalization_enabled = false
        @user_type_method = :user_type # Method to call on user to determine their type
        @personalized_flows = {}
      end
    end
  end
end
