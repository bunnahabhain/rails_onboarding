# frozen_string_literal: true

require 'test_helper'

module RailsOnboarding
  module Admin
    class FlowsControllerTest < ActionDispatch::IntegrationTest
      include Engine.routes.url_helpers

      def setup
        @admin_user = User.create!(email: 'admin@example.com')
      end

      test "should list flows" do
        skip "Implement based on your authentication system"
      end

      test "should create new flow" do
        skip "Implement based on your authentication system"
      end

      test "should update flow" do
        skip "Implement based on your authentication system"
      end

      test "should delete flow" do
        skip "Implement based on your authentication system"
      end

      test "should activate flow" do
        skip "Implement based on your authentication system"
      end

      test "should duplicate flow" do
        skip "Implement based on your authentication system"
      end
    end
  end
end
