require "test_helper"

module RailsOnboarding
  class MultiTenantTest < ActiveSupport::TestCase
    setup do
      @user = users(:one)
      @organization = OpenStruct.new(id: 1, name: "Test Org")
    end

    test "can set organization-specific configuration" do
      MultiTenant.configure_for_organization(@organization.id) do |config|
        config.steps = [
          { name: :org_welcome, title: "Welcome to Org" }
        ]
      end

      org_config = MultiTenant.configuration_for(@organization.id)
      assert_equal 1, org_config[:steps].length
      assert_equal :org_welcome, org_config[:steps].first[:name]
    end

    test "falls back to global configuration when no org config exists" do
      org_config = MultiTenant.configuration_for(999)
      global_config = RailsOnboarding.configuration

      # Should use global config
      assert_not_nil org_config
    end

    test "can retrieve organization for user" do
      @user.define_singleton_method(:organization_id) { @organization.id }

      org_id = MultiTenant.organization_for_user(@user)
      assert_equal @organization.id, org_id
    end

    test "inherits settings from global config" do
      RailsOnboarding.configure do |config|
        config.enable_tooltips = true
      end

      MultiTenant.configure_for_organization(@organization.id) do |config|
        config.steps = [{ name: :custom }]
      end

      org_config = MultiTenant.configuration_for(@organization.id)

      # Should have custom steps but inherit enable_tooltips
      assert org_config[:enable_tooltips]
    end

    test "can override global settings per organization" do
      RailsOnboarding.configure do |config|
        config.enable_tooltips = true
      end

      MultiTenant.configure_for_organization(@organization.id) do |config|
        config.enable_tooltips = false
      end

      org_config = MultiTenant.configuration_for(@organization.id)
      assert_not org_config[:enable_tooltips]
    end
  end
end
