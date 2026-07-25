# frozen_string_literal: true

require 'test_helper'

module RailsOnboarding
  module Admin
    class UsersControllerTest < ActionDispatch::IntegrationTest
      include Engine.routes.url_helpers

      def setup
        @admin_user = User.create!(email: 'admin@example.com')
        @test_user = User.create!(
          email: 'test@example.com',
          onboarding_current_step: 'welcome',
          onboarding_completed: false
        )
        sign_in @admin_user
      end

      test "should list users" do
        get admin_users_path
        assert_response :success
      end

      test "non-admin cannot list users" do
        sign_out
        sign_in User.create!(email: 'regular@example.com')

        get admin_users_path
        assert_redirected_to "/"
      end

      test "should show user details" do
        get admin_user_path(@test_user)
        assert_response :success
      end

      test "should reset user onboarding" do
        @test_user.update!(onboarding_completed: true, onboarding_completed_at: Time.current)

        post reset_onboarding_admin_user_path(@test_user)

        assert_redirected_to admin_user_path(@test_user)
        assert_not @test_user.reload.onboarding_completed
      end

      test "should complete user onboarding" do
        post complete_onboarding_admin_user_path(@test_user)

        assert_redirected_to admin_user_path(@test_user)
        assert @test_user.reload.onboarding_completed
      end

      test "should restart user onboarding" do
        @test_user.update!(onboarding_completed: true, onboarding_skipped: true, onboarding_completed_at: Time.current)

        post restart_onboarding_admin_user_path(@test_user)

        assert_redirected_to admin_user_path(@test_user)
        @test_user.reload
        assert_not @test_user.onboarding_completed
        assert_not @test_user.onboarding_skipped
        assert_not_nil @test_user.onboarding_current_step
      end

      test "should filter users by status" do
        completed_user = User.create!(email: 'completed@example.com', onboarding_completed: true)

        get admin_users_path(status: 'completed')

        assert_response :success
        assert_includes response.body, completed_user.email
        assert_not_includes response.body, @test_user.email
      end

      test "should search users" do
        get admin_users_path(search: @test_user.email)

        assert_response :success
        assert_includes response.body, @test_user.email
      end
    end
  end
end
