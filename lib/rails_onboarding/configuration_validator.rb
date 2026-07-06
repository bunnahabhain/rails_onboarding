require_relative "configuration_errors"

module RailsOnboarding
  # Validates RailsOnboarding configuration to ensure all settings are valid
  class ConfigurationValidator
    VALID_TRIGGERS = [ :onboarding_step_completed, :onboarding_completed, :tooltip_shown,
                      :tooltip_clicked, :custom ].freeze
    VALID_REDIRECT_TYPES = [ Symbol, String, Proc ].freeze
    VALID_ONBOARDING_REQUIREMENTS = [ :new_users, :all_users, Proc ].freeze
    VALID_API_AUTH_METHODS = [ :token, :session, :custom ].freeze
    VALID_REVEAL_CONDITIONS = [ :time_based, :action_based, :step_based, :milestone_based, :engagement_based ].freeze
    NAME_FORMAT = /\A[a-z_][a-z0-9_]*\z/i

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
      validate_type(:user_class_name, [ String ], "user_class_name must be a String")
      validate_type(:include_host_styles, [ TrueClass, FalseClass ], "include_host_styles must be a Boolean")
      validate_type(:enable_tooltips, [ TrueClass, FalseClass ], "enable_tooltips must be a Boolean")
      validate_type(:enable_milestones, [ TrueClass, FalseClass ], "enable_milestones must be a Boolean")
      validate_type(:enable_analytics, [ TrueClass, FalseClass ], "enable_analytics must be a Boolean")
      validate_type(:steps, [ Array ], "steps must be an Array")
      validate_type(:milestones, [ Array ], "milestones must be an Array")
      validate_type(:feature_tooltips, [ Hash ], "feature_tooltips must be a Hash")

      # Numeric validations
      if config.analytics_data_retention_days
        validate_type(:analytics_data_retention_days, [ Integer ], "analytics_data_retention_days must be an Integer")
        validate_positive(:analytics_data_retention_days, "analytics_data_retention_days must be positive")
      end

      if config.analytics_session_timeout_minutes
        validate_type(:analytics_session_timeout_minutes, [ Integer ], "analytics_session_timeout_minutes must be an Integer")
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
        validate_type(:api_mode_enabled, [ TrueClass, FalseClass ], "api_mode_enabled must be a Boolean")
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

      validate_named_collection(
        config.steps,
        error_class: InvalidStepError,
        label: "Step",
        identifier_field: :name,
        identifier_type: [ Symbol, String ],
        duplicate_label: "step name",
        format_description: "Use alphanumeric characters and underscores only, starting with a letter or underscore",
        fields: [
          { name: :title, type: String },
          { name: :icon, type: String },
          { name: :skippable, type: [ TrueClass, FalseClass ] }
        ]
      )
    end

    def validate_milestones
      return unless config.enable_milestones
      return unless config.milestones.is_a?(Array)
      return if config.milestones.empty? # Empty milestones array is valid

      validate_named_collection(
        config.milestones,
        error_class: InvalidMilestoneError,
        label: "Milestone",
        identifier_field: :key,
        duplicate_label: "milestone key",
        format_description: "Use alphanumeric characters and underscores only",
        fields: [
          { name: :trigger, required: true },
          { name: :points, type: Integer },
          { name: :title, type: String },
          { name: :description, type: String },
          { name: :conditions, type: Hash }
        ]
      ) do |milestone, key|
        # Cross-field and value-range checks that a generic field schema
        # can't express - kept bespoke per collection.
        if milestone[:trigger] && !VALID_TRIGGERS.include?(milestone[:trigger].to_sym)
          errors << InvalidMilestoneError.new(
            "Milestone '#{key}' has invalid trigger '#{milestone[:trigger]}'. " \
            "Valid triggers: #{VALID_TRIGGERS.join(', ')}"
          )
        end

        if milestone[:points].is_a?(Integer) && milestone[:points].negative?
          errors << InvalidMilestoneError.new(
            "Milestone '#{key}' has negative points. Points must be non-negative"
          )
        end

        if milestone[:conditions].is_a?(Hash) && milestone[:conditions][:step]
          step_name = milestone[:conditions][:step]
          unless config.step_by_name(step_name)
            errors << InvalidMilestoneError.new(
              "Milestone '#{key}' references undefined step '#{step_name}' in conditions"
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
      if value.is_a?(Symbol) && !value.to_s.end_with?("_path", "_url")
        errors << InvalidRedirectPathError.new(
          "#{field_name} symbol '#{value}' should end with '_path' or '_url' (e.g., :root_path, :dashboard_path)"
        )
      end

      # If it's a string, validate it starts with /
      if value.is_a?(String) && !value.start_with?("/")
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

        # :text has a combined required+type message ("must have a :text
        # field of type String"), unlike every other field here, so it's
        # kept as its own check rather than going through validate_item_fields.
        unless tooltip[:text].is_a?(String)
          errors << InvalidTypeError.new(
            "Tooltip '#{key}' must have a :text field of type String"
          )
        end

        validate_item_fields(tooltip, "Tooltip '#{key}'", InvalidTypeError, [
          { name: :delay, type: Integer }
        ])

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

      validate_named_collection(
        config.progressive_features,
        error_class: InvalidTypeError,
        label: "Progressive feature",
        identifier_field: :key
      ) do |feature, key|
        next unless feature[:reveal_condition]

        unless VALID_REVEAL_CONDITIONS.include?(feature[:reveal_condition])
          errors << InvalidTypeError.new(
            "Progressive feature '#{key}' has invalid :reveal_condition. " \
            "Valid conditions: #{VALID_REVEAL_CONDITIONS.join(', ')}"
          )
        end

        # Validate time_based features have delay
        if feature[:reveal_condition] == :time_based && !feature[:delay].is_a?(Integer)
          errors << InvalidTypeError.new(
            "Progressive feature '#{key}' with :time_based condition must have :delay (Integer in seconds)"
          )
        end

        # Validate step_based features reference valid steps
        if feature[:reveal_condition] == :step_based && feature[:after_step]
          unless config.step_by_name(feature[:after_step])
            errors << InvalidTypeError.new(
              "Progressive feature '#{key}' references undefined step '#{feature[:after_step]}'"
            )
          end
        end
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

    # Shared engine behind validate_steps/validate_milestones/
    # validate_progressive_features: they all iterate an Array of Hashes,
    # each identified by one field (:name/:key), and each with its own mix
    # of required/optional fields - only the identifier's uniqueness/format
    # rules and the field list differ, plus whatever bespoke cross-field
    # checks the caller needs (yielded per item).
    #
    # @param items [Array] the configured collection (steps, milestones, ...)
    # @param error_class [Class] error class to raise for problems found
    # @param label [String] human label used in messages, e.g. "Step"
    # @param identifier_field [Symbol] the field that identifies each item
    # @param identifier_type [Array<Class>, nil] allowed types for the
    #   identifier's value, if it should be type-checked
    # @param duplicate_label [String, nil] enables a uniqueness check on the
    #   identifier, e.g. "step name"
    # @param format_description [String, nil] enables a name-format check on
    #   the identifier (alphanumeric/underscore), described in the message
    # @param fields [Array<Hash>] field schema: {name:, type:, required:}
    # @yield [item, identifier] for bespoke, collection-specific checks once
    #   the item has passed the structural checks above
    def validate_named_collection(items, error_class:, label:, identifier_field:, identifier_type: nil,
                                   duplicate_label: nil, format_description: nil, fields: [])
      return unless items.is_a?(Array)

      seen_identifiers = []

      items.each_with_index do |item, index|
        unless item.is_a?(Hash)
          errors << error_class.new("#{label} at index #{index} must be a Hash")
          next
        end

        identifier = item[identifier_field]
        unless identifier
          errors << error_class.new("#{label} at index #{index} is missing required :#{identifier_field} field")
          next
        end

        if identifier_type && !identifier_type.any? { |type| identifier.is_a?(type) }
          errors << error_class.new(
            "#{label} at index #{index} has invalid #{identifier_field} type. " \
            "Must be #{identifier_type.map(&:name).join(' or ')}, got #{identifier.class}"
          )
          next
        end

        item_label = "#{label} '#{identifier}'"

        if duplicate_label
          if seen_identifiers.include?(identifier.to_sym)
            errors << error_class.new("Duplicate #{duplicate_label} found: '#{identifier}'")
          end
          seen_identifiers << identifier.to_sym
        end

        if format_description && !identifier.to_s.match?(NAME_FORMAT)
          errors << error_class.new("#{item_label} has invalid format. #{format_description}")
        end

        validate_item_fields(item, item_label, error_class, fields)

        yield item, identifier if block_given?
      end
    end

    # Checks a schema of {name:, type:, required:} field rules against a
    # single Hash item, reporting a missing-required-field or wrong-type
    # error per field as appropriate.
    def validate_item_fields(item, item_label, error_class, fields)
      fields.each do |field|
        value = item[field[:name]]

        if field[:required] && value.nil?
          errors << error_class.new("#{item_label} is missing required :#{field[:name]} field")
          next
        end

        next if value.nil?

        expected_types = Array(field[:type])
        next if expected_types.empty?

        unless expected_types.any? { |type| value.is_a?(type) }
          errors << error_class.new(
            "#{item_label} has invalid :#{field[:name]} type. " \
            "Expected #{expected_types.map(&:name).join(' or ')}, got #{value.class}"
          )
        end
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
