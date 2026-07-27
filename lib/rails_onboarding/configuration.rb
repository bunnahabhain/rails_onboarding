require_relative "configuration_validator"
require_relative "configuration/steps"
require_relative "configuration/milestones"
require_relative "configuration/tooltips"
require_relative "configuration/analytics"
require_relative "configuration/ab_testing"
require_relative "configuration/personalization"
require_relative "configuration/progressive_disclosure"
require_relative "configuration/integrations"
require_relative "configuration/rate_limiting"
require_relative "configuration/templates"

module RailsOnboarding
  # Every reader/writer here is part of this gem's public configuration DSL
  # (host apps set these in a RailsOnboarding.configure block), so none of
  # them can change shape without breaking every existing installation. The
  # ~40 settings are grouped by feature into the modules under
  # configuration/ - each one owns its own defaults and any logic specific
  # to it, so a change to (say) A/B testing only touches
  # configuration/ab_testing.rb instead of this whole file. What's left
  # here is identity/branding settings with no logic of their own, plus the
  # infrastructure the feature modules share (tenant overrides, the derived-
  # lookup cache, and the validator).
  class Configuration
    include Steps
    include Milestones
    include Tooltips
    include Analytics
    include AbTesting
    include Personalization
    include ProgressiveDisclosure
    include Integrations
    include RateLimiting
    include Templates

    attr_accessor :user_class_name,
                  :include_host_styles,
                  :redirect_after_completion,
                  :redirect_after_skip,
                  :custom_css_path,
                  :custom_js_path,
                  :welcome_heading,
                  :welcome_subheading,
                  :welcome_features,
                  :admin_user_search

    def initialize
      @user_class_name = "User"
      @include_host_styles = true  # Default to including host app css
      @redirect_after_completion = :root_path
      @redirect_after_skip = :root_path
      @welcome_heading = "We're excited to have you here!"
      @welcome_subheading = "Now, let's take a few moments to get you set up and familiar with a few things you need to know to get started."
      @welcome_features = [
        { icon: "👤", text: "Set up your profile" },
        { icon: "📝", text: "Create your first item" },
        { icon: "🔍", text: "Explore key features" }
      ]

      # Optional override for the admin User Management search box. The
      # built-in search is plain SQL, which can't see through an encrypted
      # email column - a host app that encrypts email and still wants partial
      # matching has to supply the strategy itself. Receives the already
      # status/step-filtered scope and the raw term, and must return a
      # relation (not an array) so sorting and pagination still apply.
      @admin_user_search = nil

      initialize_steps
      initialize_milestones
      initialize_tooltips
      initialize_analytics
      initialize_ab_testing
      initialize_personalization
      initialize_progressive_disclosure
      initialize_integrations
      initialize_rate_limiting
      initialize_templates
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

    private

    # Reads a per-request tenant override for +key+, set by
    # MultiTenant.with_tenant_configuration via RailsOnboarding::Current.
    # Falls back to +default+ (the process-wide value) when no override is
    # active for +key+, distinguishing an explicit `false` override from "no
    # override at all".
    def tenant_override(key, default)
      overrides = RailsOnboarding::Current.tenant_overrides
      return default unless overrides&.key?(key)

      overrides[key]
    end
  end
end
