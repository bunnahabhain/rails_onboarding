module RailsOnboarding
  class Configuration
    # Feature tooltip configuration.
    module Tooltips
      def enable_tooltips
        tenant_override(:enable_tooltips, @enable_tooltips)
      end

      attr_writer :enable_tooltips

      def feature_tooltips
        tenant_override(:feature_tooltips, @feature_tooltips)
      end

      attr_writer :feature_tooltips

      private

      def initialize_tooltips
        @enable_tooltips = true

        @feature_tooltips = {
          "getting_started" => {
            text: "Click here to get started!",
            delay: 1000,
            position: "bottom"
          }
        }
      end
    end
  end
end
