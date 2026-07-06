require "test_helper"

module RailsOnboarding
  # Simple organization struct for testing
  TestOrganization = Struct.new(:id, :name, keyword_init: true)

  class MultiTenantTest < ActiveSupport::TestCase
    setup do
      @user = users(:one)
      @organization = TestOrganization.new(id: 1, name: "Test Org")
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
      # Capture organization in closure for singleton method
      org = @organization
      @user.define_singleton_method(:organization_id) { org.id }

      org_id = MultiTenant.organization_for_user(@user)
      assert_equal @organization.id, org_id
    end

    test "inherits settings from global config" do
      RailsOnboarding.configure do |config|
        config.enable_tooltips = true
      end

      MultiTenant.configure_for_organization(@organization.id) do |config|
        config.steps = [ { name: :custom } ]
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

    test "with_tenant_configuration applies tenant steps only for the duration of the block" do
      global_steps = RailsOnboarding.configuration.steps

      MultiTenant.configure_for_organization(@organization.id) do |config|
        config.steps = [ { name: :tenant_only_step, title: "Tenant Only" } ]
      end

      steps_inside = nil
      MultiTenant.with_tenant_configuration(@organization.id) do
        steps_inside = RailsOnboarding.configuration.steps
      end

      assert_equal [ :tenant_only_step ], steps_inside.map { |s| s[:name] }
      assert_equal global_steps, RailsOnboarding.configuration.steps
    end

    test "with_tenant_configuration does not mutate the shared configuration object's ivar" do
      global_steps = RailsOnboarding.configuration.steps

      MultiTenant.configure_for_organization(@organization.id) do |config|
        config.steps = [ { name: :tenant_only_step } ]
      end

      MultiTenant.with_tenant_configuration(@organization.id) do
        assert_equal [ :tenant_only_step ], RailsOnboarding.configuration.steps.map { |s| s[:name] }
      end

      # The global config's own instance variable must be untouched - this
      # only holds unconditionally because nothing ever wrote to @steps, as
      # opposed to the old mutate-then-restore implementation which relied on
      # its `ensure` running to put the original value back.
      assert_equal global_steps, RailsOnboarding.configuration.instance_variable_get(:@steps)
    end

    test "with_tenant_configuration correctly overrides an explicit false boolean setting" do
      RailsOnboarding.configure { |config| config.enable_tooltips = true }

      MultiTenant.configure_for_organization(@organization.id) do |config|
        config.enable_tooltips = false
      end

      MultiTenant.with_tenant_configuration(@organization.id) do
        assert_not RailsOnboarding.configuration.enable_tooltips
      end

      assert RailsOnboarding.configuration.enable_tooltips
    end

    test "nested with_tenant_configuration restores the outer tenant's overrides" do
      other_org = TestOrganization.new(id: 2, name: "Other Org")

      MultiTenant.configure_for_organization(@organization.id) do |config|
        config.steps = [ { name: :outer_step } ]
      end

      MultiTenant.configure_for_organization(other_org.id) do |config|
        config.steps = [ { name: :inner_step } ]
      end

      MultiTenant.with_tenant_configuration(@organization.id) do
        assert_equal [ :outer_step ], RailsOnboarding.configuration.steps.map { |s| s[:name] }

        MultiTenant.with_tenant_configuration(other_org.id) do
          assert_equal [ :inner_step ], RailsOnboarding.configuration.steps.map { |s| s[:name] }
        end

        assert_equal [ :outer_step ], RailsOnboarding.configuration.steps.map { |s| s[:name] }
      end

      assert_nil RailsOnboarding::Current.tenant_overrides
    end

    test "with_tenant_configuration isolates concurrent threads from each other" do
      org_a = TestOrganization.new(id: 101, name: "Org A")
      org_b = TestOrganization.new(id: 102, name: "Org B")

      MultiTenant.configure_for_organization(org_a.id) do |config|
        config.steps = [ { name: :org_a_step } ]
      end

      MultiTenant.configure_for_organization(org_b.id) do |config|
        config.steps = [ { name: :org_b_step } ]
      end

      results = {}
      results_mutex = Mutex.new
      start_gate = Queue.new

      thread_a = Thread.new do
        start_gate.pop
        MultiTenant.with_tenant_configuration(org_a.id) do
          sleep 0.05
          steps = RailsOnboarding.configuration.steps.map { |s| s[:name] }
          results_mutex.synchronize { results[:a] = steps }
        end
      end

      thread_b = Thread.new do
        start_gate.pop
        MultiTenant.with_tenant_configuration(org_b.id) do
          sleep 0.05
          steps = RailsOnboarding.configuration.steps.map { |s| s[:name] }
          results_mutex.synchronize { results[:b] = steps }
        end
      end

      2.times { start_gate << true }
      [ thread_a, thread_b ].each(&:join)

      assert_equal [ :org_a_step ], results[:a]
      assert_equal [ :org_b_step ], results[:b]
    end
  end
end
