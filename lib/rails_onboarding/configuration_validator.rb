require_relative 'configuration_errors'

module RailsOnboarding
  # Validates RailsOnboarding configuration to ensure all settings are valid
  class ConfigurationValidator
    VALID_TRIGGERS = [:onboarding_step_completed, :onboarding_completed, :tooltip_shown,
                      :tooltip_clicked, :custom].freeze
    VALID_REDIRECT_TYPES = [Symbol, String, Proc].freeze
    VALID_ONBOARDING_REQUIREMENTS = [:new_users, :all_users, Proc].freeze
    VALID_API_AUTH_METHODS = [:token, :session, :custom].freeze

    attr_reader :config, :errors

    def initialize(config)
      @config = config
      @errors = []
    end

    # Validate all configuration options
    # @raise [ConfigurationError] if any validation fails
    def validate!
      validate_required_options
      validate_types
      validate_steps
      validate_milestones
      validate_redirect_paths
      validate_feature_tooltips
      validate_ab_tests
      validate_personalized_flows
      validate_progressive_features
      validate_webhook_config
      validate_mailer_config

      raise ConfigurationError, error_message unless errors.empty?
    end

    # Validate without raising exceptions
    # @return [Boolean] true if valid, false otherwise
    def valid?
      validate!
      true
    rescue ConfigurationError
      false
    end

    private

    def validate_required_options
      validate_present(:user_class_name, "User class name is required")
      validate_present(:steps, "At least one step must be defined")
    end

    def validate_types
      validate_type(:user_class_name, [String], "user_class_name must be a String")
      validate_type(:include_host_styles, [TrueClass, FalseClass], "include_host_styles must be a Boolean")
      validate_type(:enable_tooltips, [TrueClass, FalseClass], "enable_tooltips must be a Boolean")
      validate_type(:enable_milestones, [TrueClass, FalseClass], "enable_milestones must be a Boolean")
      validate_type(:enable_analytics, [TrueClass, FalseClass], "enable_analytics must be a Boolean")
      validate_type(:steps, [Array], "steps must be an Array")
      validate_type(:milestones, [Array], "milestones must be an Array")
      validate_type(:feature_tooltips, [Hash], "feature_tooltips must be a Hash")

      # Numeric validations
      if config.analytics_data_retention_days
        validate_type(:analytics_data_retention_days, [Integer], "analytics_data_retention_days must be an Integer")
        validate_positive(:analytics_data_retention_days, "analytics_data_retention_days must be positive")
      end

      if config.analytics_session_timeout_minutes
        validate_type(:analytics_session_timeout_minutes, [Integer], "analytics_session_timeout_minutes must be an Integer")
        validate_positive(:analytics_session_timeout_minutes, "analytics_session_timeout_minutes must be positive")
      end

      # Validate onboarding_required_for
      unless VALID_ONBOARDING_REQUIREMENTS.include?(config.onboarding_required_for) ||
             config.onboarding_required_for.is_a?(Proc)
        errors << InvalidTypeError.new(
          "onboarding_required_for must be :new_users, :all_users, or a Proc"
        )
      end

      # API mode validations
      if config.api_mode_enabled
        validate_type(:api_mode_enabled, [TrueClass, FalseClass], "api_mode_enabled must be a Boolean")
        unless VALID_API_AUTH_METHODS.include?(config.api_authentication_method)
          errors << InvalidTypeError.new(
            "api_authentication_method must be one of: #{VALID_API_AUTH_METHODS.join(', ')}"
          )
        end
      end
    end

    def validate_steps
      return unless config.steps.is_a?(Array)

      if config.steps.empty?
        errors << InvalidStepError.new("At least one step must be defined")
        return
      end

      step_names = []

      config.steps.each_with_index do |step, index|
        # Validate step is a hash
        unless step.is_a?(Hash)
          errors << InvalidStepError.new("Step at index #{index} must be a Hash")
          next
        end

        # Validate required fields
        unless step[:name]
          errors << InvalidStepError.new("Step at index #{index} is missing required :name field")
          next
        end

        # Validate name is a symbol or string
        unless step[:name].is_a?(Symbol) || step[:name].is_a?(String)
          errors << InvalidStepError.new(
            "Step at index #{index} has invalid name type. Must be Symbol or String, got #{step[:name].class}"
          )
          next
        end

        # Validate name format (alphanumeric and underscores only)
        step_name = step[:name].to_s
        unless step_name.match?(/\A[a-z_][a-z0-9_]*\z/i)
          errors << InvalidStepError.new(
            "Step '#{step_name}' has invalid format. Use alphanumeric characters and underscores only, starting with a letter or underscore"
          )
        end

        # Check for uniqueness
        if step_names.include?(step[:name].to_sym)
          errors << InvalidStepError.new("Duplicate step name found: '#{step[:name]}'")
        end
        step_names << step[:name].to_sym

        # Validate optional fields
        if step[:title] && !step[:title].is_a?(String)
          errors << InvalidStepError.new("Step '#{step[:name]}' has invalid :title type. Must be a String")
        end

        if step[:icon] && !step[:icon].is_a?(String)
          errors << InvalidStepError.new("Step '#{step[:name]}' has invalid :icon type. Must be a String")
        end

        if step.key?(:skippable) && ![TrueClass, FalseClass].include?(step[:skippable].class)
          errors << InvalidStepError.new("Step '#{step[:name]}' has invalid :skippable type. Must be a Boolean")
        end
      end
    end

    def validate_milestones
      return unless config.enable_milestones
      return unless config.milestones.is_a?(Array)
      return if config.milestones.empty? # Empty milestones array is valid

      milestone_keys = []

      config.milestones.each_with_index do |milestone, index|
        # Validate milestone is a hash
        unless milestone.is_a?(Hash)
          errors << InvalidMilestoneError.new("Milestone at index #{index} must be a Hash")
          next
        end

        # Validate required fields
        unless milestone[:key]
          errors << InvalidMilestoneError.new("Milestone at index #{index} is missing required :key field")
          next
        end

        unless milestone[:trigger]
          errors << InvalidMilestoneError.new("Milestone '#{milestone[:key]}' is missing required :trigger field")
          next
        end

        # Validate key uniqueness
        if milestone_keys.include?(milestone[:key].to_sym)
          errors << InvalidMilestoneError.new("Duplicate milestone key found: '#{milestone[:key]}'")
        end
        milestone_keys << milestone[:key].to_sym

        # Validate key format
        milestone_key = milestone[:key].to_s
        unless milestone_key.match?(/\A[a-z_][a-z0-9_]*\z/i)
          errors << InvalidMilestoneError.new(
            "Milestone key '#{milestone_key}' has invalid format. Use alphanumeric characters and underscores only"
          )
        end

        # Validate trigger
        unless VALID_TRIGGERS.include?(milestone[:trigger].to_sym)
          errors << InvalidMilestoneError.new(
            "Milestone '#{milestone[:key]}' has invalid trigger '#{milestone[:trigger]}'. " \
            "Valid triggers: #{VALID_TRIGGERS.join(', ')}"
          )
        end

        # Validate points
        if milestone[:points]
          unless milestone[:points].is_a?(Integer)
            errors << InvalidMilestoneError.new(
              "Milestone '#{milestone[:key]}' has invalid :points type. Must be an Integer"
            )
          end

          if milestone[:points].is_a?(Integer) && milestone[:points] < 0
            errors << InvalidMilestoneError.new(
              "Milestone '#{milestone[:key]}' has negative points. Points must be non-negative"
            )
          end
        end

        # Validate title and description if present
        if milestone[:title] && !milestone[:title].is_a?(String)
          errors << InvalidMilestoneError.new(
            "Milestone '#{milestone[:key]}' has invalid :title type. Must be a String"
          )
        end

        if milestone[:description] && !milestone[:description].is_a?(String)
          errors << InvalidMilestoneError.new(
            "Milestone '#{milestone[:key]}' has invalid :description type. Must be a String"
          )
        end

        # Validate conditions if present
        if milestone[:conditions] && !milestone[:conditions].is_a?(Hash)
          errors << InvalidMilestoneError.new(
            "Milestone '#{milestone[:key]}' has invalid :conditions type. Must be a Hash"
          )
        end

        # Validate step-based conditions reference valid steps
        if milestone[:conditions].is_a?(Hash) && milestone[:conditions][:step]
          step_name = milestone[:conditions][:step]
          unless config.step_by_name(step_name)
            errors << InvalidMilestoneError.new(
              "Milestone '#{milestone[:key]}' references undefined step '#{step_name}' in conditions"
            )
          end
        end
      end
    end

    def validate_redirect_paths
      validate_redirect_path(:redirect_after_completion, config.redirect_after_completion)
      validate_redirect_path(:redirect_after_skip, config.redirect_after_skip)
    end

    def validate_redirect_path(field_name, value)
      return if value.nil?

      unless VALID_REDIRECT_TYPES.any? { |type| value.is_a?(type) }
        errors << InvalidRedirectPathError.new(
          "#{field_name} must be a Symbol, String, or Proc, got #{value.class}"
        )
        return
      end

      # If it's a symbol, validate it looks like a valid path helper
      if value.is_a?(Symbol) && !value.to_s.end_with?('_path', '_url')
        errors << InvalidRedirectPathError.new(
          "#{field_name} symbol '#{value}' should end with '_path' or '_url' (e.g., :root_path, :dashboard_path)"
        )
      end

      # If it's a string, validate it starts with /
      if value.is_a?(String) && !value.start_with?('/')
        errors << InvalidRedirectPathError.new(
          "#{field_name} string '#{value}' should be an absolute path starting with '/'"
        )
      end
    end

    def validate_feature_tooltips
      return unless config.enable_tooltips
      return unless config.feature_tooltips.is_a?(Hash)

      config.feature_tooltips.each do |key, tooltip|
        unless tooltip.is_a?(Hash)
          errors << InvalidTypeError.new(
            "Tooltip '#{key}' must be a Hash, got #{tooltip.class}"
          )
          next
        end

        # Validate text is present
        unless tooltip[:text].is_a?(String)
          errors << InvalidTypeError.new(
            "Tooltip '#{key}' must have a :text field of type String"
          )
        end

        # Validate delay if present
        if tooltip[:delay] && !tooltip[:delay].is_a?(Integer)
          errors << InvalidTypeError.new(
            "Tooltip '#{key}' has invalid :delay type. Must be an Integer (milliseconds)"
          )
        end

        # Validate position if present
        if tooltip[:position]
          valid_positions = %w[top bottom left right]
          unless valid_positions.include?(tooltip[:position].to_s)
            errors << InvalidTypeError.new(
              "Tooltip '#{key}' has invalid :position '#{tooltip[:position]}'. " \
              "Valid positions: #{valid_positions.join(', ')}"
            )
          end
        end
      end
    end

    def validate_ab_tests
      return unless config.enable_ab_testing
      return unless config.ab_tests.is_a?(Hash)

      config.ab_tests.each do |test_name, test_config|
        unless test_config.is_a?(Hash)
          errors << InvalidTypeError.new(
            "A/B test '#{test_name}' must be a Hash, got #{test_config.class}"
          )
          next
        end

        # Validate variants exist
        unless test_config[:variants].is_a?(Array)
          errors << InvalidTypeError.new(
            "A/B test '#{test_name}' must have a :variants array"
          )
          next
        end

        if test_config[:variants].empty?
          errors << InvalidTypeError.new(
            "A/B test '#{test_name}' must have at least one variant"
          )
        end
      end
    end

    def validate_personalized_flows
      return unless config.personalization_enabled
      return unless config.personalized_flows.is_a?(Hash)

      config.personalized_flows.each do |user_type, steps|
        unless steps.is_a?(Array)
          errors << InvalidTypeError.new(
            "Personalized flow for '#{user_type}' must be an Array, got #{steps.class}"
          )
          next
        end

        # Validate each step follows the same rules as regular steps
        steps.each_with_index do |step, index|
          unless step.is_a?(Hash)
            errors << InvalidStepError.new(
              "Personalized flow '#{user_type}' step at index #{index} must be a Hash"
            )
          end
        end
      end
    end

    def validate_progressive_features
      return unless config.progressive_disclosure_enabled
      return unless config.progressive_features.is_a?(Array)

      valid_reveal_conditions = [:time_based, :action_based, :step_based, :milestone_based, :engagement_based]

      config.progressive_features.each_with_index do |feature, index|
        unless feature.is_a?(Hash)
          errors << InvalidTypeError.new(
            "Progressive feature at index #{index} must be a Hash"
          )
          next
        end

        unless feature[:key]
          errors << InvalidTypeError.new(
            "Progressive feature at index #{index} is missing required :key field"
          )
        end

        if feature[:reveal_condition]
          unless valid_reveal_conditions.include?(feature[:reveal_condition])
            errors << InvalidTypeError.new(
              "Progressive feature '#{feature[:key]}' has invalid :reveal_condition. " \
              "Valid conditions: #{valid_reveal_conditions.join(', ')}"
            )
          end

          # Validate time_based features have delay
          if feature[:reveal_condition] == :time_based && !feature[:delay].is_a?(Integer)
            errors << InvalidTypeError.new(
              "Progressive feature '#{feature[:key]}' with :time_based condition must have :delay (Integer in seconds)"
            )
          end

          # Validate step_based features reference valid steps
          if feature[:reveal_condition] == :step_based && feature[:after_step]
            unless config.step_by_name(feature[:after_step])
              errors << InvalidTypeError.new(
                "Progressive feature '#{feature[:key]}' references undefined step '#{feature[:after_step]}'"
              )
            end
          end
        end
      end
    end

    def validate_webhook_config
      return unless config.webhooks_enabled

      unless config.webhook_endpoints.is_a?(Array)
        errors << InvalidTypeError.new(
          "webhook_endpoints must be an Array, got #{config.webhook_endpoints.class}"
        )
      end

      if config.webhook_secret_key && !config.webhook_secret_key.is_a?(String)
        errors << InvalidTypeError.new(
          "webhook_secret_key must be a String, got #{config.webhook_secret_key.class}"
        )
      end

      if config.webhook_async && ![TrueClass, FalseClass].include?(config.webhook_async.class)
        errors << InvalidTypeError.new(
          "webhook_async must be a Boolean, got #{config.webhook_async.class}"
        )
      end
    end

    def validate_mailer_config
      return unless config.background_jobs_enabled

      if config.mailer_from && !config.mailer_from.is_a?(String)
        errors << InvalidTypeError.new(
          "mailer_from must be a String, got #{config.mailer_from.class}"
        )
      end

      # Validate email format
      if config.mailer_from.is_a?(String) && !valid_email_format?(config.mailer_from)
        errors << InvalidTypeError.new(
          "mailer_from '#{config.mailer_from}' is not a valid email address"
        )
      end
    end

    # Helper methods

    def validate_present(field, message)
      value = config.send(field)
      if value.nil? || (value.respond_to?(:empty?) && value.empty?)
        errors << MissingRequiredOptionError.new(message)
      end
    end

    def validate_type(field, valid_types, message)
      value = config.send(field)
      return if value.nil? # nil is valid unless validate_present says otherwise

      unless valid_types.any? { |type| value.is_a?(type) }
        errors << InvalidTypeError.new(message)
      end
    end

    def validate_positive(field, message)
      value = config.send(field)
      if value && value.is_a?(Integer) && value <= 0
        errors << InvalidTypeError.new(message)
      end
    end

    def valid_email_format?(email)
      email.match?(/\A[^@\s]+@[^@\s]+\.[^@\s]+\z/)
    end

    def error_message
      header = "Configuration validation failed with #{errors.size} error(s):"
      error_list = errors.map.with_index { |error, i| "  #{i + 1}. #{error.message}" }.join("\n")
      "#{header}\n#{error_list}"
    end
  end
end
