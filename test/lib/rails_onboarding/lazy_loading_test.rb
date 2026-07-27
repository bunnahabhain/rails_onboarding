# frozen_string_literal: true

require "test_helper"

module RailsOnboarding
  class LazyLoadingTest < ActiveSupport::TestCase
    # Note: We explicitly clean up users in setup to avoid fixture pollution
    # since test_helper.rb loads all fixtures automatically

    setup do
      # Clean up any existing users from fixtures or previous tests
      User.delete_all

      @user = User.create!(
        email: "test@example.com",
        onboarding_completed: false,
        onboarding_current_step: "welcome"
      )
    end

    # Class-level scope tests

    test "needs_onboarding scope returns users who need onboarding" do
      # Create user who needs onboarding (created recently)
      recent_user = User.create!(
        email: "recent@example.com",
        onboarding_completed: false,
        created_at: 30.minutes.ago
      )

      # Create user who doesn't need onboarding (old user)
      old_user = User.create!(
        email: "old@example.com",
        onboarding_completed: false,
        created_at: 2.hours.ago
      )

      users = User.needs_onboarding
      assert_includes users, recent_user
      refute_includes users, old_user
    end

    test "in_onboarding scope returns users currently in onboarding" do
      # User in onboarding
      in_onboarding = User.create!(
        email: "in_onboarding@example.com",
        onboarding_completed: false,
        onboarding_current_step: "welcome"
      )

      # User not in onboarding
      not_in_onboarding = User.create!(
        email: "not_in_onboarding@example.com",
        onboarding_completed: false,
        onboarding_current_step: nil
      )

      users = User.in_onboarding
      assert_includes users, in_onboarding
      refute_includes users, not_in_onboarding
    end

    test "batch_load_onboarding_states returns hash of user states" do
      user1 = User.create!(
        email: "user1@example.com",
        onboarding_completed: false,
        onboarding_current_step: "welcome"
      )

      user2 = User.create!(
        email: "user2@example.com",
        onboarding_completed: true
      )

      states = User.batch_load_onboarding_states([ user1.id, user2.id ])

      assert_equal 2, states.size
      assert_equal false, states[user1.id][:completed]
      assert_equal "welcome", states[user1.id][:current_step]
      assert_equal true, states[user2.id][:completed]
      assert_nil states[user2.id][:current_step]
    end

    test "batch_load_onboarding_states returns empty hash for empty array" do
      states = User.batch_load_onboarding_states([])
      assert_empty states
    end

    test "onboarding_step_counts returns counts by step" do
      # Note: setup creates a user with 'welcome' step
      # Create users in different steps
      User.create!(
        email: "user1@example.com",
        onboarding_completed: false,
        onboarding_current_step: "welcome"
      )

      User.create!(
        email: "user2@example.com",
        onboarding_completed: false,
        onboarding_current_step: "profile"
      )

      # Clear cache to ensure fresh counts
      Rails.cache.clear

      counts = User.onboarding_step_counts

      assert_equal 2, counts["welcome"]  # @user from setup + user1
      assert_equal 1, counts["profile"]
    end

    # Instance-level lazy loading tests

    test "lazy_current_step returns current step when enabled" do
      @user.class.lazy_loading_enabled = true

      step = @user.lazy_current_step
      assert_equal @user.current_onboarding_step, step
    end

    test "lazy_current_step returns nil when disabled" do
      @user.class.lazy_loading_enabled = false

      step = @user.lazy_current_step
      assert_nil step

      # Reset
      @user.class.lazy_loading_enabled = true
    end

    test "lazy_next_step returns next step when enabled" do
      @user.class.lazy_loading_enabled = true

      next_step = @user.lazy_next_step
      # User is on 'welcome' (first step), so next step should be 'profile' (second step)
      assert_equal :profile, next_step[:name]
      assert_equal :profile, @user.next_onboarding_step[:name]
    end

    test "lazy_milestones_available returns milestones when enabled" do
      @user.class.lazy_loading_enabled = true

      milestones = @user.lazy_milestones_available
      assert_equal @user.milestones_available, milestones
    end

    test "lazy_milestones_available returns empty array when milestones disabled" do
      RailsOnboarding.configuration.enable_milestones = false

      milestones = @user.lazy_milestones_available
      assert_empty milestones

      # Reset
      RailsOnboarding.configuration.enable_milestones = true
    end

    test "lazy_tooltips_for_page returns relevant tooltips" do
      # Configure tooltips
      RailsOnboarding.configuration.feature_tooltips = {
        "dashboard_getting_started" => { text: "Get started!", position: "bottom" },
        "profile_setup" => { text: "Setup profile", position: "top" }
      }

      tooltips = @user.lazy_tooltips_for_page("dashboard")

      # Should include dashboard tooltip
      assert tooltips.key?("dashboard_getting_started")
      # Should not include profile tooltip
      refute tooltips.key?("profile_setup")
    end

    test "lazy_tooltips_for_page returns empty hash when tooltips disabled" do
      RailsOnboarding.configuration.enable_tooltips = false

      tooltips = @user.lazy_tooltips_for_page("dashboard")
      assert_empty tooltips

      # Reset
      RailsOnboarding.configuration.enable_tooltips = true
    end

    test "lazy_load_enabled? returns true when under threshold" do
      @user.class.lazy_loading_enabled = true
      @user.class.lazy_load_threshold = 1000

      assert @user.lazy_load_enabled?
    end

    test "lazy_load_enabled? returns false when over threshold" do
      # Set threshold and enabled flag before creating users
      User.lazy_loading_enabled = true
      User.lazy_load_threshold = 1

      # Create more users to exceed threshold
      # Note: setup already creates 1 user, so we need to create enough to go over threshold
      2.times do |i|
        User.create!(
          email: "user#{i}@example.com"
        )
      end

      # Clear Rails cache
      Rails.cache.clear

      # Test with a fresh user instance
      test_user = User.first
      refute test_user.lazy_load_enabled?

      # Reset
      User.lazy_load_threshold = 1000
    end

    test "preload_onboarding_data returns hash of user data" do
      data = @user.preload_onboarding_data

      assert_instance_of Hash, data
      assert_includes data.keys, :needs_onboarding
      assert_includes data.keys, :current_step
      assert_includes data.keys, :next_step
      assert_includes data.keys, :progress
      assert_includes data.keys, :milestones
      assert_includes data.keys, :milestone_points
    end

    test "preload_onboarding_data includes correct values" do
      # Use new hash format for milestones to avoid deprecation warning when storing
      # Note: achieved_milestones always returns keys as strings for backward compatibility
      @user.update!(
        milestones_achieved: [ { "key" => "welcome_completed", "achieved_at" => Time.current.iso8601 } ],
        milestone_points: 10
      )

      data = @user.preload_onboarding_data

      assert_equal @user.needs_onboarding?, data[:needs_onboarding]
      assert_equal @user.current_onboarding_step, data[:current_step]
      # User is on 'welcome' (first step), so next step should be 'profile' (second step)
      assert_equal :profile, data[:next_step][:name]
      assert_equal :profile, @user.next_onboarding_step[:name]
      assert_equal @user.onboarding_progress, data[:progress]
      # achieved_milestones returns an array of string keys
      assert_equal [ "welcome_completed" ], data[:milestones]
      assert_equal 10, data[:milestone_points]
    end

    test "preload_onboarding_data excludes milestones when disabled" do
      RailsOnboarding.configuration.enable_milestones = false

      data = @user.preload_onboarding_data

      assert_empty data[:milestones]
      assert_equal 0, data[:milestone_points]

      # Reset
      RailsOnboarding.configuration.enable_milestones = true
    end
  end
end
