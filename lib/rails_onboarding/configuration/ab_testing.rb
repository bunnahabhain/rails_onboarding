module RailsOnboarding
  class Configuration
    # A/B testing configuration.
    module AbTesting
      attr_accessor :enable_ab_testing, :ab_tests

      # Get a specific A/B test configuration
      #
      # @param test_name [Symbol, String] The name of the test
      # @return [Hash, nil] The test configuration or nil
      def ab_test(test_name)
        return nil unless enable_ab_testing
        ab_tests[test_name.to_sym]
      end

      private

      def initialize_ab_testing
        @enable_ab_testing = false
        @ab_tests = {}
      end
    end
  end
end
