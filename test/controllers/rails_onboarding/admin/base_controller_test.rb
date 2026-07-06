# frozen_string_literal: true

require 'test_helper'

module RailsOnboarding
  module Admin
    class BaseControllerTest < ActionDispatch::IntegrationTest
      include Engine.routes.url_helpers

      test "surfaces a friendly error instead of crashing when the host app hasn't configured admin auth" do
        # authenticate_admin! raises NotImplementedError when neither
        # authenticate_rails_onboarding_admin! nor current_user is defined -
        # simulate that by removing current_user from the host app's
        # ApplicationController for the duration of this request.
        ::ApplicationController.class_eval do
          alias_method :__original_current_user, :current_user
          remove_method :current_user
        end

        get admin_dashboard_path

        assert_redirected_to "/"
        assert_match(/authenticate_rails_onboarding_admin!/, flash[:alert])
      ensure
        ::ApplicationController.class_eval do
          define_method(:current_user, instance_method(:__original_current_user))
          remove_method :__original_current_user
        end
      end
    end
  end
end
