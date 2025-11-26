require_relative 'configuration_validator'

module RailsOnboarding
  class Configuration
    attr_accessor :user_class_name,
                  :include_host_styles,
                  :redirect_after_completion,
                  :redirect_after_skip,
                  :steps,
                  :feature_tooltips,
                  :enable_tooltips,
                  :enable_milestones,
                  :milestones,
                  :onboarding_required_for,
                  :custom_css_path,
                  :custom_js_path,
                  :enable_analytics,
                  :analytics_data_retention_days,
                  :analytics_retention_days,
                  :analytics_session_timeout_minutes,
                  :welcome_heading,
                  :welcome_subheading,
                  :welcome_features,
                  :ab_tests,
                  :enable_ab_testing,
                  :personalization_enabled,
                  :user_type_method,
                  :personalized_flows,
                  :progressive_disclosure_enabled,
                  :progressive_features,
                  :onboarding_templates,
                  :devise_integration_enabled,
                  :redirect_unconfirmed_to_onboarding,
                  :turbo_streams_enabled,
                  :turbo_morphing_enabled,
                  :api_mode_enabled,
                  :api_authentication_method,
                  :background_jobs_enabled,
                  :background_jobs_queue,
                  :mailer_from,
                  :rate_limiting_enabled,
                  :rate_limit_per_period,
                  :rate_limit_period

    def initialize
      @user_class_name = "User"
      @include_host_styles = true  # Default to including host app css
      @redirect_after_completion = :root_path
      @redirect_after_skip = :root_path
      @enable_tooltips = true
      @enable_milestones = false
      @enable_analytics = true
      @analytics_data_retention_days = 365 # Keep analytics data for 1 year
      @analytics_retention_days = 365 # Alias for analytics_data_retention_days
      @analytics_session_timeout_minutes = 30 # Consider session ended after 30 minutes of inactivity
      @onboarding_required_for = :new_users # :new_users, :all_users, or a Proc
      @welcome_heading = "We're excited to have you here!"
      @welcome_subheading = "Now, let's take a few moments to get you set up and familiar with a few things you need to know to get started."
      @welcome_features = [
        { icon: "👤", text: "Set up your profile" },
        { icon: "📝", text: "Create your first item" },
        { icon: "🔍", text: "Explore key features" }
      ]

      # Default steps - can be customized
      @steps = [
        {
          name: :welcome,
          title: "Welcome",
          icon: "🎉",
          skippable: true
        },
        {
          name: :profile,
          title: "Setup Profile",
          icon: "👤",
          skippable: false
        },
        {
          name: :first_action,
          title: "First Action",
          icon: "🚀",
          skippable: false
        },
        {
          name: :explore,
          title: "Explore Features",
          icon: "🔍",
          skippable: true
        }
      ]

      @feature_tooltips = {
        "getting_started" => {
          text: "Click here to get started!",
          delay: 1000,
          position: "bottom"
        }
      }

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

      # A/B Testing configuration
      @enable_ab_testing = false
      @ab_tests = {}

      # Personalization configuration
      @personalization_enabled = false
      @user_type_method = :user_type # Method to call on user to determine their type
      @personalized_flows = {}

      # Progressive disclosure configuration
      @progressive_disclosure_enabled = false
      @progressive_features = []

      # Integration & Compatibility options
      @devise_integration_enabled = true
      @redirect_unconfirmed_to_onboarding = false
      @turbo_streams_enabled = true
      @turbo_morphing_enabled = false
      @api_mode_enabled = false
      @api_authentication_method = :token
      @background_jobs_enabled = false
      @background_jobs_queue = :default
      @mailer_from = 'noreply@example.com'

      # Rate limiting
      @rate_limiting_enabled = true
      @rate_limit_per_period = 60  # Number of requests allowed per period
      @rate_limit_period = 60      # Period in seconds (60 seconds = 1 minute)

      # Onboarding templates
      @onboarding_templates = {
        saas: {
          name: "SaaS Application",
          steps: [
            { name: :welcome, title: "Welcome", icon: "🎉", skippable: true },
            { name: :account_setup, title: "Account Setup", icon: "👤", skippable: false },
            { name: :team_invite, title: "Invite Team", icon: "👥", skippable: true },
            { name: :first_project, title: "Create Project", icon: "📁", skippable: false },
            { name: :integration, title: "Connect Tools", icon: "🔌", skippable: true }
          ]
        },
        ecommerce: {
          name: "E-commerce Platform",
          steps: [
            { name: :welcome, title: "Welcome", icon: "🎉", skippable: true },
            { name: :store_setup, title: "Setup Store", icon: "🏪", skippable: false },
            { name: :first_product, title: "Add Product", icon: "📦", skippable: false },
            { name: :payment_setup, title: "Payment Setup", icon: "💳", skippable: false },
            { name: :launch, title: "Launch Store", icon: "🚀", skippable: false }
          ]
        },
        marketplace: {
          name: "Marketplace",
          steps: [
            { name: :welcome, title: "Welcome", icon: "🎉", skippable: true },
            { name: :profile_setup, title: "Create Profile", icon: "👤", skippable: false },
            { name: :verification, title: "Verify Account", icon: "✅", skippable: false },
            { name: :first_listing, title: "Create Listing", icon: "📝", skippable: false },
            { name: :explore, title: "Explore", icon: "🔍", skippable: true }
          ]
        },
        community: {
          name: "Community Platform",
          steps: [
            { name: :welcome, title: "Welcome", icon: "🎉", skippable: true },
            { name: :profile, title: "Setup Profile", icon: "👤", skippable: false },
            { name: :interests, title: "Choose Interests", icon: "❤️", skippable: true },
            { name: :first_post, title: "Create Post", icon: "✍️", skippable: false },
            { name: :connect, title: "Connect", icon: "🤝", skippable: true }
          ]
        },
        education: {
          name: "Educational Platform",
          steps: [
            { name: :welcome, title: "Welcome", icon: "🎉", skippable: true },
            { name: :student_setup, title: "Student Info", icon: "🎓", skippable: false },
            { name: :course_selection, title: "Choose Courses", icon: "📚", skippable: false },
            { name: :first_lesson, title: "First Lesson", icon: "📖", skippable: false },
            { name: :study_plan, title: "Study Plan", icon: "📅", skippable: true }
          ]
        }
      }
    end

    # Validate the current configuration
    # @raise [ConfigurationError] if any validation fails
    def validate!
      validator.validate!
    end

    # Check if the configuration is valid without raising
    # @return [Boolean] true if valid, false otherwise
    def valid?
      validator.valid?
    end

    # Get the validator instance for this configuration
    # @return [ConfigurationValidator]
    def validator
      @validator ||= ConfigurationValidator.new(self)
    end

    # Get validation errors without raising
    # @return [Array<StandardError>] array of validation errors
    def validation_errors
      validator.errors
    end

    def user_class
      @user_class ||= @user_class_name.constantize
    end

    def total_steps
      @total_steps ||= steps.size
    end

    def step_by_name(name)
      return nil if name.nil?

      @step_by_name_cache ||= {}
      @step_by_name_cache[name.to_sym] ||= steps.find do |s|
        next false unless s.is_a?(Hash) && s[:name]
        s[:name].to_sym == name.to_sym
      end
    end

    def step_index(name)
      return nil if name.nil?

      @step_index_cache ||= {}
      @step_index_cache[name.to_sym] ||= steps.find_index do |s|
        next false unless s.is_a?(Hash) && s[:name]
        s[:name].to_sym == name.to_sym
      end
    end

    def milestone_by_key(key)
      return nil if key.nil?

      @milestone_by_key_cache ||= {}
      @milestone_by_key_cache[key.to_sym] ||= milestones.find { |m| m[:key].to_sym == key.to_sym }
    end

    def milestones_for_trigger(trigger, conditions = {})
      cache_key = [trigger, conditions].hash
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

    # Override setters to clear cache when configuration changes
    def steps=(value)
      clear_cache!
      @steps = value
    end

    def milestones=(value)
      clear_cache!
      @milestones = value
    end

    # Keep analytics_retention_days in sync with analytics_data_retention_days
    def analytics_retention_days=(value)
      @analytics_retention_days = value
      @analytics_data_retention_days = value
    end

    def analytics_data_retention_days=(value)
      @analytics_data_retention_days = value
      @analytics_retention_days = value
    end

    # Clear all cached lookups - call this when configuration changes
    def clear_cache!
      @user_class = nil
      @total_steps = nil
      @step_by_name_cache = nil
      @step_index_cache = nil
      @milestone_by_key_cache = nil
      @milestones_for_trigger_cache = nil
      @validator = nil
    end

    # Get a specific A/B test configuration
    #
    # @param test_name [Symbol, String] The name of the test
    # @return [Hash, nil] The test configuration or nil
    def ab_test(test_name)
      return nil unless enable_ab_testing
      ab_tests[test_name.to_sym]
    end

    # Get a personalized flow for a user type
    #
    # @param user_type [Symbol, String] The user type
    # @return [Array, nil] The personalized steps or nil
    def personalized_flow(user_type)
      return nil unless personalization_enabled
      personalized_flows[user_type.to_sym]
    end

    # Get an onboarding template by key
    #
    # @param template_key [Symbol, String] The template key
    # @return [Hash, nil] The template configuration or nil
    def template(template_key)
      onboarding_templates[template_key.to_sym]
    end

    # Apply a template to the current configuration
    #
    # @param template_key [Symbol, String] The template key to apply
    # @return [Boolean] True if template was applied successfully
    def apply_template(template_key)
      template = onboarding_templates[template_key.to_sym]
      return false unless template

      @steps = template[:steps]
      true
    end

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

    def conditions_match?(milestone_conditions, trigger_conditions)
      return true if milestone_conditions.nil?

      milestone_conditions.all? do |key, value|
        trigger_conditions[key] == value || trigger_conditions[key.to_s] == value ||
        trigger_conditions[key.to_sym] == value
      end
    end
  end
end
