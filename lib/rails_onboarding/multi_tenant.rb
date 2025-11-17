module RailsOnboarding
  # Multi-Tenant Support
  # Allows different onboarding configurations per organization/tenant
  class MultiTenant
    class << self
      # Get configuration for a specific tenant
      #
      # @param tenant [Object] The tenant object (organization, account, etc.)
      # @return [Hash] Tenant-specific configuration
      def configuration_for(tenant)
        return default_configuration unless tenant

        # Check if tenant has custom configuration
        tenant_config = if tenant.respond_to?(:onboarding_configuration)
                          tenant.onboarding_configuration
                        elsif tenant.respond_to?(:onboarding_config)
                          tenant.onboarding_config
                        end

        return default_configuration unless tenant_config

        # Merge with default configuration
        merge_configurations(default_configuration, parse_config(tenant_config))
      end

      # Get steps for a specific tenant
      #
      # @param tenant [Object] The tenant object
      # @return [Array<Hash>] Array of step configurations
      def steps_for(tenant)
        config = configuration_for(tenant)
        config[:steps] || RailsOnboarding.configuration.steps
      end

      # Get feature tooltips for a specific tenant
      #
      # @param tenant [Object] The tenant object
      # @return [Hash] Feature tooltip configurations
      def tooltips_for(tenant)
        config = configuration_for(tenant)
        config[:feature_tooltips] || RailsOnboarding.configuration.feature_tooltips
      end

      # Get milestones for a specific tenant
      #
      # @param tenant [Object] The tenant object
      # @return [Array<Hash>] Milestone configurations
      def milestones_for(tenant)
        config = configuration_for(tenant)
        config[:milestones] || RailsOnboarding.configuration.milestones
      end

      # Check if a feature is enabled for a tenant
      #
      # @param tenant [Object] The tenant object
      # @param feature [Symbol] The feature to check
      # @return [Boolean] True if feature is enabled
      def feature_enabled?(tenant, feature)
        config = configuration_for(tenant)

        case feature
        when :tooltips
          config[:enable_tooltips] != false
        when :milestones
          config[:enable_milestones] != false
        when :analytics
          config[:enable_analytics] != false
        when :ab_testing
          config[:enable_ab_testing] == true
        when :personalization
          config[:personalization_enabled] == true
        else
          false
        end
      end

      # Apply tenant configuration to current context
      #
      # @param tenant [Object] The tenant object
      # @yield Block to execute with tenant configuration
      def with_tenant_configuration(tenant)
        return yield unless tenant

        original_config = store_original_config
        apply_tenant_config(tenant)

        yield
      ensure
        restore_original_config(original_config) if original_config
      end

      # Get tenant from user
      #
      # @param user [User] The user object
      # @return [Object, nil] The tenant object
      def tenant_from_user(user)
        return nil unless user

        # Try common tenant associations
        if user.respond_to?(:organization)
          user.organization
        elsif user.respond_to?(:account)
          user.account
        elsif user.respond_to?(:tenant)
          user.tenant
        elsif user.respond_to?(:team)
          user.team
        elsif user.respond_to?(:company)
          user.company
        end
      end

      # Set custom configuration for a tenant
      #
      # @param tenant [Object] The tenant object
      # @param config [Hash] Configuration hash
      def set_configuration(tenant, config)
        return unless tenant

        if tenant.respond_to?(:onboarding_configuration=)
          tenant.onboarding_configuration = config.to_json
          tenant.save
        elsif tenant.respond_to?(:update)
          tenant.update(onboarding_configuration: config.to_json) rescue nil
        end
      end

      # Copy configuration from one tenant to another
      #
      # @param source_tenant [Object] Source tenant
      # @param target_tenant [Object] Target tenant
      def copy_configuration(source_tenant, target_tenant)
        config = configuration_for(source_tenant)
        set_configuration(target_tenant, config)
      end

      # Reset tenant configuration to default
      #
      # @param tenant [Object] The tenant object
      def reset_configuration(tenant)
        return unless tenant

        if tenant.respond_to?(:onboarding_configuration=)
          tenant.onboarding_configuration = nil
          tenant.save
        end
      end

      private

      def default_configuration
        {
          steps: RailsOnboarding.configuration.steps,
          feature_tooltips: RailsOnboarding.configuration.feature_tooltips,
          milestones: RailsOnboarding.configuration.milestones,
          enable_tooltips: RailsOnboarding.configuration.enable_tooltips,
          enable_milestones: RailsOnboarding.configuration.enable_milestones,
          enable_analytics: RailsOnboarding.configuration.enable_analytics,
          enable_ab_testing: RailsOnboarding.configuration.enable_ab_testing,
          personalization_enabled: RailsOnboarding.configuration.personalization_enabled,
          redirect_after_completion: RailsOnboarding.configuration.redirect_after_completion,
          redirect_after_skip: RailsOnboarding.configuration.redirect_after_skip
        }
      end

      def parse_config(config_data)
        return {} unless config_data

        parsed = if config_data.is_a?(String)
                   JSON.parse(config_data)
                 else
                   config_data
                 end

        parsed.deep_symbolize_keys
      rescue JSON::ParserError => e
        Rails.logger.error("Failed to parse tenant configuration: #{e.message}")
        {}
      end

      def merge_configurations(base, override)
        base.deep_merge(override) do |key, base_val, override_val|
          # For arrays, use override completely
          if base_val.is_a?(Array) && override_val.is_a?(Array)
            override_val
          else
            override_val.nil? ? base_val : override_val
          end
        end
      end

      def store_original_config
        {
          steps: RailsOnboarding.configuration.steps.dup,
          feature_tooltips: RailsOnboarding.configuration.feature_tooltips.dup,
          milestones: RailsOnboarding.configuration.milestones.dup,
          enable_tooltips: RailsOnboarding.configuration.enable_tooltips,
          enable_milestones: RailsOnboarding.configuration.enable_milestones
        }
      end

      def apply_tenant_config(tenant)
        config = configuration_for(tenant)

        RailsOnboarding.configuration.steps = config[:steps] if config[:steps]
        RailsOnboarding.configuration.feature_tooltips = config[:feature_tooltips] if config[:feature_tooltips]
        RailsOnboarding.configuration.milestones = config[:milestones] if config[:milestones]
        RailsOnboarding.configuration.enable_tooltips = config[:enable_tooltips] unless config[:enable_tooltips].nil?
        RailsOnboarding.configuration.enable_milestones = config[:enable_milestones] unless config[:enable_milestones].nil?
      end

      def restore_original_config(original)
        RailsOnboarding.configuration.steps = original[:steps]
        RailsOnboarding.configuration.feature_tooltips = original[:feature_tooltips]
        RailsOnboarding.configuration.milestones = original[:milestones]
        RailsOnboarding.configuration.enable_tooltips = original[:enable_tooltips]
        RailsOnboarding.configuration.enable_milestones = original[:enable_milestones]
      end
    end
  end
end
