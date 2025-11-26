require "test_helper"

module RailsOnboarding
  class ConfigurationTest < ActiveSupport::TestCase
    setup do
      # Save original configuration
      @original_config = RailsOnboarding.configuration.dup

      # Reset to defaults for each test
      RailsOnboarding.reset_configuration!
    end

    teardown do
      # Restore original configuration
      RailsOnboarding.instance_variable_set(:@configuration, @original_config)
    end

    test "configuration has default values" do
      config = RailsOnboarding.configuration

      assert_equal "User", config.user_class_name
      assert_equal :root_path, config.redirect_after_completion
      assert_equal :root_path, config.redirect_after_skip
      assert config.enable_tooltips
      assert_not config.enable_milestones
    end

    test "can configure user_class_name" do
      RailsOnboarding.configure do |config|
        config.user_class_name = "Account"
      end

      assert_equal "Account", RailsOnboarding.configuration.user_class_name
    end

    test "can configure redirect paths" do
      RailsOnboarding.configure do |config|
        config.redirect_after_completion = :dashboard_path
        config.redirect_after_skip = :home_path
      end

      assert_equal :dashboard_path, RailsOnboarding.configuration.redirect_after_completion
      assert_equal :home_path, RailsOnboarding.configuration.redirect_after_skip
    end

    test "can configure feature flags" do
      RailsOnboarding.configure do |config|
        config.enable_tooltips = false
        config.enable_milestones = true
      end

      assert_not RailsOnboarding.configuration.enable_tooltips
      assert RailsOnboarding.configuration.enable_milestones
    end

    test "can configure steps" do
      steps = [
        { name: :custom_welcome, title: "Custom Welcome", icon: "🎉" },
        { name: :custom_profile, title: "Custom Profile", icon: "👤" }
      ]

      RailsOnboarding.configure do |config|
        config.steps = steps
      end

      assert_equal steps, RailsOnboarding.configuration.steps
    end

    test "can configure onboarding requirement" do
      RailsOnboarding.configure do |config|
        config.onboarding_required_for = :all_users
      end

      assert_equal :all_users, RailsOnboarding.configuration.onboarding_required_for
    end

    test "reset_configuration! restores defaults" do
      RailsOnboarding.configure do |config|
        config.user_class_name = "CustomUser"
      end

      RailsOnboarding.reset_configuration!

      assert_equal "User", RailsOnboarding.configuration.user_class_name
    end

    test "steps include default onboarding flow" do
      steps = RailsOnboarding.configuration.steps

      assert steps.any? { |s| s[:name] == :welcome }
      assert steps.any? { |s| s[:name] == :profile }
      assert steps.any? { |s| s[:name] == :first_action }
      assert steps.any? { |s| s[:name] == :explore }
    end

    test "can access milestone configuration" do
      RailsOnboarding.configure do |config|
        config.milestones = [
          {
            id: "test_milestone",
            title: "Test Achievement",
            points: 100
          }
        ]
      end

      milestones = RailsOnboarding.configuration.milestones
      assert_equal 1, milestones.length
      assert_equal "test_milestone", milestones.first[:id]
    end

    test "configuration is a singleton" do
      config1 = RailsOnboarding.configuration
      config2 = RailsOnboarding.configuration

      assert_same config1, config2
    end

    test "can configure analytics settings" do
      RailsOnboarding.configure do |config|
        config.enable_analytics = true
        config.analytics_retention_days = 90
      end

      assert RailsOnboarding.configuration.enable_analytics
      assert_equal 90, RailsOnboarding.configuration.analytics_retention_days
    end
  end
end
