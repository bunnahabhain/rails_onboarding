require "test_helper"

module RailsOnboarding
  class ConfigurationValidatorTest < ActiveSupport::TestCase
    def setup
      @config = Configuration.new
    end

    # Basic validation tests

    test "valid default configuration passes validation" do
      assert @config.valid?
      assert_empty @config.validation_errors
    end

    test "validates without raising" do
      @config.steps = []
      refute @config.valid?
      assert @config.validation_errors.any?
    end

    # Step validation tests

    test "requires at least one step" do
      @config.steps = []

      error = assert_raises(ConfigurationError) { @config.validate! }
      assert_match /at least one step/i, error.message
    end

    test "validates step is a hash" do
      @config.steps = ["invalid"]

      error = assert_raises(ConfigurationError) { @config.validate! }
      assert_match /must be a hash/i, error.message
    end

    test "validates step has required name field" do
      @config.steps = [{ title: "Test" }]

      error = assert_raises(ConfigurationError) { @config.validate! }
      assert_match /missing required :name field/i, error.message
    end

    test "validates step name format" do
      @config.steps = [{ name: "invalid-name" }]

      error = assert_raises(ConfigurationError) { @config.validate! }
      assert_match /invalid format/i, error.message
    end

    test "accepts path as Symbol, String, or Proc" do
      @config.steps = [
        { name: :one, title: "One", path: :new_profile_path, complete_if: ->(u) { true } },
        { name: :two, title: "Two", path: "new_profile_path", skippable: true },
        { name: :three, title: "Three", path: -> { "/profile/new" }, skippable: true }
      ]

      assert @config.valid?, @config.validation_errors.map(&:message).join(", ")
    end

    test "rejects path of invalid type" do
      @config.steps = [ { name: :one, title: "One", path: 123 } ]

      error = assert_raises(ConfigurationError) { @config.validate! }
      assert_match /invalid :path type/i, error.message
    end

    test "rejects complete_if that is not a Proc" do
      @config.steps = [ { name: :one, title: "One", complete_if: "user.profile.present?" } ]

      error = assert_raises(ConfigurationError) { @config.validate! }
      assert_match /invalid :complete_if type/i, error.message
    end

    test "warns when a path step has no complete_if and is not skippable" do
      @config.steps = [ { name: :stuck, title: "Stuck", path: :new_profile_path } ]

      warnings = capture_logger_warnings { assert @config.valid? }
      assert_match /advance_onboarding!\(:stuck\)/, warnings
    end

    test "does not warn when a path step has complete_if or is skippable" do
      @config.steps = [
        { name: :one, title: "One", path: :new_profile_path, complete_if: ->(u) { true } },
        { name: :two, title: "Two", path: :new_profile_path, skippable: true }
      ]

      warnings = capture_logger_warnings { assert @config.valid? }
      assert_no_match /advance_onboarding!/, warnings
    end

    def capture_logger_warnings
      io = StringIO.new
      original_logger = Rails.logger
      Rails.logger = Logger.new(io)
      yield
      io.string
    ensure
      Rails.logger = original_logger
    end

    test "accepts valid step name formats" do
      @config.steps = [
        { name: :valid_name },
        { name: "another_valid_name" },
        { name: :_starts_with_underscore },
        { name: "name123" }
      ]
      @config.milestones = [] # Clear default milestones that reference step :welcome

      assert @config.valid?
    end

    test "validates step names are unique" do
      @config.steps = [
        { name: :welcome },
        { name: :welcome }
      ]

      error = assert_raises(ConfigurationError) { @config.validate! }
      assert_match /duplicate step name/i, error.message
    end

    test "validates step title is a string if present" do
      @config.steps = [{ name: :test, title: 123 }]

      error = assert_raises(ConfigurationError) { @config.validate! }
      assert_match /invalid :title type/i, error.message
    end

    test "validates step skippable is boolean if present" do
      @config.steps = [{ name: :test, skippable: "yes" }]

      error = assert_raises(ConfigurationError) { @config.validate! }
      assert_match /invalid :skippable type/i, error.message
    end

    # Milestone validation tests

    test "allows empty milestones array" do
      @config.enable_milestones = true
      @config.milestones = []

      assert @config.valid?
    end

    test "validates milestone is a hash" do
      @config.enable_milestones = true
      @config.milestones = ["invalid"]

      error = assert_raises(ConfigurationError) { @config.validate! }
      assert_match /must be a hash/i, error.message
    end

    test "validates milestone has required key field" do
      @config.enable_milestones = true
      @config.milestones = [{ trigger: :onboarding_completed }]

      error = assert_raises(ConfigurationError) { @config.validate! }
      assert_match /missing required :key field/i, error.message
    end

    test "validates milestone has required trigger field" do
      @config.enable_milestones = true
      @config.milestones = [{ key: :test }]

      error = assert_raises(ConfigurationError) { @config.validate! }
      assert_match /missing required :trigger field/i, error.message
    end

    test "validates milestone keys are unique" do
      @config.enable_milestones = true
      @config.milestones = [
        { key: :test, trigger: :custom },
        { key: :test, trigger: :custom }
      ]

      error = assert_raises(ConfigurationError) { @config.validate! }
      assert_match /duplicate milestone key/i, error.message
    end

    test "validates milestone key format" do
      @config.enable_milestones = true
      @config.milestones = [{ key: "invalid-key", trigger: :custom }]

      error = assert_raises(ConfigurationError) { @config.validate! }
      assert_match /invalid format/i, error.message
    end

    test "validates milestone trigger is valid" do
      @config.enable_milestones = true
      @config.milestones = [{ key: :test, trigger: :invalid_trigger }]

      error = assert_raises(ConfigurationError) { @config.validate! }
      assert_match /invalid trigger/i, error.message
    end

    test "accepts all valid milestone triggers" do
      @config.enable_milestones = true
      @config.milestones = [
        { key: :test1, trigger: :onboarding_step_completed },
        { key: :test2, trigger: :onboarding_completed },
        { key: :test3, trigger: :tooltip_shown },
        { key: :test4, trigger: :tooltip_clicked },
        { key: :test5, trigger: :custom }
      ]

      assert @config.valid?
    end

    test "validates milestone points is an integer if present" do
      @config.enable_milestones = true
      @config.milestones = [{ key: :test, trigger: :custom, points: "10" }]

      error = assert_raises(ConfigurationError) { @config.validate! }
      assert_match /invalid :points type/i, error.message
    end

    test "validates milestone points is non-negative" do
      @config.enable_milestones = true
      @config.milestones = [{ key: :test, trigger: :custom, points: -10 }]

      error = assert_raises(ConfigurationError) { @config.validate! }
      assert_match /negative points/i, error.message
    end

    test "validates milestone conditions is a hash if present" do
      @config.enable_milestones = true
      @config.milestones = [{ key: :test, trigger: :custom, conditions: "invalid" }]

      error = assert_raises(ConfigurationError) { @config.validate! }
      assert_match /invalid :conditions type/i, error.message
    end

    test "validates milestone step condition references valid step" do
      @config.enable_milestones = true
      @config.steps = [{ name: :welcome }]
      @config.milestones = [
        { key: :test, trigger: :onboarding_step_completed, conditions: { step: :nonexistent } }
      ]

      error = assert_raises(ConfigurationError) { @config.validate! }
      assert_match /references undefined step/i, error.message
    end

    # Redirect path validation tests

    test "validates redirect_after_completion is a valid type" do
      @config.redirect_after_completion = 123

      error = assert_raises(ConfigurationError) { @config.validate! }
      assert_match /redirect_after_completion.*must be a symbol, string, or proc/i, error.message.downcase
    end

    test "accepts symbol redirect paths ending with _path or _url" do
      @config.redirect_after_completion = :dashboard_path
      @config.redirect_after_skip = :home_url

      assert @config.valid?
    end

    test "warns about symbol redirect paths not ending with _path or _url" do
      @config.redirect_after_completion = :dashboard

      error = assert_raises(ConfigurationError) { @config.validate! }
      assert_match /should end with '_path' or '_url'/i, error.message
    end

    test "validates string redirect paths start with /" do
      @config.redirect_after_completion = "dashboard"

      error = assert_raises(ConfigurationError) { @config.validate! }
      assert_match /should be an absolute path starting with/i, error.message
    end

    test "accepts valid string redirect paths" do
      @config.redirect_after_completion = "/dashboard"
      @config.redirect_after_skip = "/home"

      assert @config.valid?
    end

    test "accepts proc redirect paths" do
      @config.redirect_after_completion = ->(user) { "/users/#{user.id}" }

      assert @config.valid?
    end

    # Type validation tests

    test "validates user_class_name is a string" do
      @config.user_class_name = :User

      error = assert_raises(ConfigurationError) { @config.validate! }
      assert_match /user_class_name must be a string/i, error.message
    end

    test "validates boolean configuration options" do
      @config.enable_tooltips = "true"

      error = assert_raises(ConfigurationError) { @config.validate! }
      assert_match /must be a boolean/i, error.message
    end

    test "validates analytics_data_retention_days is an integer" do
      @config.analytics_data_retention_days = "365"

      error = assert_raises(ConfigurationError) { @config.validate! }
      assert_match /must be an integer/i, error.message
    end

    test "validates analytics_data_retention_days is positive" do
      @config.analytics_data_retention_days = 0

      error = assert_raises(ConfigurationError) { @config.validate! }
      assert_match /must be positive/i, error.message
    end

    test "validates onboarding_required_for is valid option" do
      @config.onboarding_required_for = :invalid

      error = assert_raises(ConfigurationError) { @config.validate! }
      assert_match /onboarding_required_for/i, error.message
    end

    test "accepts valid onboarding_required_for options" do
      @config.onboarding_required_for = :new_users
      assert @config.valid?

      @config.onboarding_required_for = :all_users
      assert @config.valid?

      @config.onboarding_required_for = ->(user) { user.needs_onboarding? }
      assert @config.valid?
    end

    # Feature tooltip validation tests

    test "validates tooltip is a hash" do
      @config.enable_tooltips = true
      @config.feature_tooltips = { test: "invalid" }

      error = assert_raises(ConfigurationError) { @config.validate! }
      assert_match /must be a hash/i, error.message
    end

    test "validates tooltip has text field" do
      @config.enable_tooltips = true
      @config.feature_tooltips = { test: { delay: 1000 } }

      error = assert_raises(ConfigurationError) { @config.validate! }
      assert_match /must have a :text field/i, error.message
    end

    test "validates tooltip delay is an integer if present" do
      @config.enable_tooltips = true
      @config.feature_tooltips = { test: { text: "Test", delay: "1000" } }

      error = assert_raises(ConfigurationError) { @config.validate! }
      assert_match /invalid :delay type/i, error.message
    end

    test "validates tooltip position is valid if present" do
      @config.enable_tooltips = true
      @config.feature_tooltips = { test: { text: "Test", position: "invalid" } }

      error = assert_raises(ConfigurationError) { @config.validate! }
      assert_match /invalid :position/i, error.message
    end

    test "accepts valid tooltip positions" do
      @config.enable_tooltips = true
      @config.feature_tooltips = {
        test1: { text: "Test", position: "top" },
        test2: { text: "Test", position: "bottom" },
        test3: { text: "Test", position: "left" },
        test4: { text: "Test", position: "right" }
      }

      assert @config.valid?
    end

    # A/B testing validation tests

    test "validates ab_test is a hash" do
      @config.enable_ab_testing = true
      @config.ab_tests = { test: "invalid" }

      error = assert_raises(ConfigurationError) { @config.validate! }
      assert_match /must be a hash/i, error.message
    end

    test "validates ab_test has variants array" do
      @config.enable_ab_testing = true
      @config.ab_tests = { test: { name: "Test" } }

      error = assert_raises(ConfigurationError) { @config.validate! }
      assert_match /must have a :variants array/i, error.message
    end

    test "validates ab_test has at least one variant" do
      @config.enable_ab_testing = true
      @config.ab_tests = { test: { variants: [] } }

      error = assert_raises(ConfigurationError) { @config.validate! }
      assert_match /at least one variant/i, error.message
    end

    # Personalization validation tests

    test "validates personalized_flow is an array" do
      @config.personalization_enabled = true
      @config.personalized_flows = { admin: "invalid" }

      error = assert_raises(ConfigurationError) { @config.validate! }
      assert_match /must be an array/i, error.message
    end

    # Progressive features validation tests

    test "validates progressive_feature is a hash" do
      @config.progressive_disclosure_enabled = true
      @config.progressive_features = ["invalid"]

      error = assert_raises(ConfigurationError) { @config.validate! }
      assert_match /must be a hash/i, error.message
    end

    test "validates progressive_feature has key field" do
      @config.progressive_disclosure_enabled = true
      @config.progressive_features = [{ reveal_condition: :time_based }]

      error = assert_raises(ConfigurationError) { @config.validate! }
      assert_match /missing required :key field/i, error.message
    end

    test "validates progressive_feature reveal_condition is valid" do
      @config.progressive_disclosure_enabled = true
      @config.progressive_features = [{ key: :test, reveal_condition: :invalid }]

      error = assert_raises(ConfigurationError) { @config.validate! }
      assert_match /invalid :reveal_condition/i, error.message
    end

    test "validates time_based progressive_feature has delay" do
      @config.progressive_disclosure_enabled = true
      @config.progressive_features = [{ key: :test, reveal_condition: :time_based }]

      error = assert_raises(ConfigurationError) { @config.validate! }
      assert_match /must have :delay/i, error.message
    end

    test "validates step_based progressive_feature references valid step" do
      @config.progressive_disclosure_enabled = true
      @config.steps = [{ name: :welcome }]
      @config.progressive_features = [
        { key: :test, reveal_condition: :step_based, after_step: :nonexistent }
      ]

      error = assert_raises(ConfigurationError) { @config.validate! }
      assert_match /references undefined step/i, error.message
    end

    # Mailer validation tests

    test "validates mailer_from is a string if present" do
      @config.background_jobs_enabled = true
      @config.mailer_from = 123

      error = assert_raises(ConfigurationError) { @config.validate! }
      assert_match /mailer_from must be a string/i, error.message
    end

    test "validates mailer_from is a valid email" do
      @config.background_jobs_enabled = true
      @config.mailer_from = "invalid-email"

      error = assert_raises(ConfigurationError) { @config.validate! }
      assert_match /not a valid email address/i, error.message
    end

    test "accepts valid email addresses" do
      @config.background_jobs_enabled = true
      @config.mailer_from = "noreply@example.com"

      assert @config.valid?
    end

    # Multiple errors test

    test "collects multiple validation errors" do
      @config.steps = []
      @config.user_class_name = nil
      @config.redirect_after_completion = 123

      error = assert_raises(ConfigurationError) { @config.validate! }
      # Should mention multiple errors
      assert_match /\d+ error\(s\)/i, error.message
    end

    # Edge cases

    test "handles nil values appropriately" do
      @config.analytics_data_retention_days = nil

      assert @config.valid?
    end

    test "validates after configuration changes" do
      assert @config.valid?

      @config.steps = []
      refute @config.valid?

      @config.steps = [{ name: :welcome }]
      assert @config.valid?
    end
  end
end
