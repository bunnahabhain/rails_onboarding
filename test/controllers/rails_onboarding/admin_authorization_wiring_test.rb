# frozen_string_literal: true

require "test_helper"

module RailsOnboarding
  # AbTestsController and TemplatesController are admin-only but ship unrouted
  # (a host app has to mount them deliberately). Their dangerous actions -
  # AbTests#assign_variant writes onto arbitrary users, Templates#apply mutates
  # the process-wide onboarding configuration - must never run without the same
  # admin gate the Admin dashboard enforces. There are no engine routes to
  # exercise them through, so guard the wiring at the class level: if the gate
  # is ever dropped, this fails. The gate's behavior itself is covered by the
  # Admin::* controller tests.
  class AdminAuthorizationWiringTest < ActiveSupport::TestCase
    ADMIN_GATED_CONTROLLERS = [
      RailsOnboarding::AbTestsController,
      RailsOnboarding::TemplatesController
    ].freeze

    ADMIN_GATED_CONTROLLERS.each do |controller|
      test "#{controller} enforces the admin gate" do
        assert_includes controller.ancestors, RailsOnboarding::AdminAuthorization,
          "#{controller} must include AdminAuthorization"

        before_filters = controller._process_action_callbacks
          .select { |c| c.kind == :before }
          .map(&:filter)

        assert_includes before_filters, :authenticate_admin!,
          "#{controller} must run authenticate_admin! before every action"
        assert_includes before_filters, :verify_admin_authorization!,
          "#{controller} must run verify_admin_authorization! before every action"
      end
    end
  end
end
