# frozen_string_literal: true

require 'test_helper'

module RailsOnboarding
  module Admin
    class UsersControllerTest < ActionDispatch::IntegrationTest
      include Engine.routes.url_helpers

      def setup
        @admin_user = User.create!(email: 'admin@example.com', admin: true)
        @test_user = User.create!(
          email: 'test@example.com',
          onboarding_current_step: 'welcome',
          onboarding_completed: false
        )
      end

      test "should list users" do
        skip "Implement based on your authentication system"
      end

      test "should show user details" do
        skip "Implement based on your authentication system"
      end

      test "should reset user onboarding" do
        skip "Implement based on your authentication system"
      end

      test "should complete user onboarding" do
        skip "Implement based on your authentication system"
      end

      test "should filter users by status" do
        skip "Implement based on your authentication system"
      end

      test "should search users" do
        skip "Implement based on your authentication system"
      end
    end
  end
end
