module RailsOnboarding
  class Configuration
    # Progressive feature disclosure configuration.
    module ProgressiveDisclosure
      attr_accessor :progressive_disclosure_enabled, :progressive_features

      # Check if a feature should be shown based on progressive disclosure
      #
      # @param feature_key [Symbol, String] The feature key
      # @param user [Object] The user object
      # @return [Boolean] True if feature should be shown
      def show_progressive_feature?(feature_key, user)
        return true unless progressive_disclosure_enabled

        feature = progressive_features.find { |f| f[:key] == feature_key.to_sym }
        return true unless feature

        # Check if feature meets its reveal conditions
        case feature[:reveal_condition]
        when :time_based
          user.created_at + feature[:delay].seconds <= Time.current
        when :action_based
          user.send(feature[:check_method]) if user.respond_to?(feature[:check_method])
        when :step_based
          step_index(user.onboarding_current_step) >= step_index(feature[:after_step])
        else
          true
        end
      rescue StandardError
        true # Default to showing feature if check fails
      end

      private

      def initialize_progressive_disclosure
        @progressive_disclosure_enabled = false
        @progressive_features = []
      end
    end
  end
end
