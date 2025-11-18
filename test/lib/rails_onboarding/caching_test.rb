# frozen_string_literal: true

require 'test_helper'

module RailsOnboarding
  class CachingTest < ActiveSupport::TestCase
    setup do
      @user = User.create!(
        email: 'test@example.com',
        password: 'password123',
        onboarding_completed: false,
        onboarding_current_step: 'welcome'
      )
      Rails.cache.clear
    end

    teardown do
      Rails.cache.clear
    end

    # Class-level caching tests

    test 'cached_config returns configuration values' do
      result = User.cached_config(:enable_tooltips)
      assert_equal RailsOnboarding.configuration.enable_tooltips, result
    end

    test 'cached_config uses cache for subsequent calls' do
      # First call - cache miss
      Rails.cache.expects(:fetch).once.returns(true)
      User.cached_config(:enable_tooltips)

      # Subsequent calls should use cache
      # (cannot test this directly without integration, but we verify key exists)
      assert Rails.cache.exist?('rails_onboarding:config:enable_tooltips')
    end

    test 'clear_config_cache removes all config caches' do
      User.cached_config(:enable_tooltips)
      User.cached_config(:steps)

      assert Rails.cache.exist?('rails_onboarding:config:enable_tooltips')

      User.clear_config_cache

      refute Rails.cache.exist?('rails_onboarding:config:enable_tooltips')
    end

    test 'cached_steps returns steps configuration' do
      steps = User.cached_steps
      assert_equal RailsOnboarding.configuration.steps, steps
    end

    test 'cached_milestones returns milestones configuration' do
      milestones = User.cached_milestones
      assert_equal RailsOnboarding.configuration.milestones, milestones
    end

    test 'cached_feature_tooltips returns tooltips configuration' do
      tooltips = User.cached_feature_tooltips
      assert_equal RailsOnboarding.configuration.feature_tooltips, tooltips
    end

    # Instance-level caching tests

    test 'cached_onboarding_progress returns correct progress' do
      progress = @user.cached_onboarding_progress
      assert_equal @user.onboarding_progress, progress
    end

    test 'cached_onboarding_progress uses cache' do
      # First call
      @user.cached_onboarding_progress

      cache_key = "rails_onboarding:user:#{@user.id}:progress"
      assert Rails.cache.exist?(cache_key)
    end

    test 'cached_current_onboarding_step returns current step' do
      step = @user.cached_current_onboarding_step
      assert_equal @user.current_onboarding_step, step
    end

    test 'cached_current_onboarding_step uses cache' do
      @user.cached_current_onboarding_step

      cache_key = "rails_onboarding:user:#{@user.id}:current_step"
      assert Rails.cache.exist?(cache_key)
    end

    test 'cached_achieved_milestones returns milestones array' do
      @user.update!(milestones_achieved: ['welcome_completed'])

      milestones = @user.cached_achieved_milestones
      assert_equal ['welcome_completed'], milestones
    end

    test 'cached_available_tooltips returns tooltips for user' do
      tooltips = @user.cached_available_tooltips
      assert_instance_of Hash, tooltips
    end

    test 'cached_available_tooltips returns empty hash when tooltips disabled' do
      RailsOnboarding.configuration.enable_tooltips = false

      tooltips = @user.cached_available_tooltips
      assert_empty tooltips

      # Reset
      RailsOnboarding.configuration.enable_tooltips = true
    end

    test 'clear_onboarding_cache removes all user caches' do
      # Create caches
      @user.cached_onboarding_progress
      @user.cached_current_onboarding_step
      @user.cached_achieved_milestones

      # Verify they exist
      assert Rails.cache.exist?("rails_onboarding:user:#{@user.id}:progress")
      assert Rails.cache.exist?("rails_onboarding:user:#{@user.id}:current_step")
      assert Rails.cache.exist?("rails_onboarding:user:#{@user.id}:milestones")

      # Clear caches
      @user.clear_onboarding_cache

      # Verify they're gone
      refute Rails.cache.exist?("rails_onboarding:user:#{@user.id}:progress")
      refute Rails.cache.exist?("rails_onboarding:user:#{@user.id}:current_step")
      refute Rails.cache.exist?("rails_onboarding:user:#{@user.id}:milestones")
    end

    test 'cached_needs_onboarding returns correct value' do
      result = @user.cached_needs_onboarding?
      assert_equal @user.needs_onboarding?, result
    end

    test 'cache is cleared after user update' do
      @user.cached_onboarding_progress

      cache_key = "rails_onboarding:user:#{@user.id}:progress"
      assert Rails.cache.exist?(cache_key)

      # Update onboarding attribute
      @user.update!(onboarding_current_step: 'profile')

      # Cache should be cleared
      refute Rails.cache.exist?(cache_key)
    end

    test 'cache is not used when attributes changed' do
      # Create cache
      @user.cached_onboarding_progress

      # Change attribute (don't save yet)
      @user.onboarding_current_step = 'profile'

      # Should recalculate instead of using cache
      progress = @user.cached_onboarding_progress
      assert_equal @user.onboarding_progress, progress
    end
  end
end
