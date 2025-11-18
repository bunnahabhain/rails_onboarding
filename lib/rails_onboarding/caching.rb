# frozen_string_literal: true

module RailsOnboarding
  # Caching module for improving performance of onboarding operations
  #
  # This module provides caching capabilities for:
  # - Configuration data
  # - User onboarding state
  # - Step information
  # - Milestone data
  #
  # By default, uses Rails.cache with configurable TTL values
  module Caching
    extend ActiveSupport::Concern

    class_methods do
      # Cache configuration for a specific user class
      #
      # @param config_key [String] The configuration key to cache
      # @param ttl [Integer] Time-to-live in seconds (default: 1 hour)
      # @return [Object] The cached configuration value
      def cached_config(config_key, ttl: 3600)
        cache_key = "rails_onboarding:config:#{config_key}"
        Rails.cache.fetch(cache_key, expires_in: ttl) do
          RailsOnboarding.configuration.send(config_key)
        end
      end

      # Clear all configuration caches
      #
      # Call this when configuration changes
      def clear_config_cache
        Rails.cache.delete_matched("rails_onboarding:config:*")
      end

      # Cache steps configuration
      #
      # @param ttl [Integer] Time-to-live in seconds (default: 1 hour)
      # @return [Array<Hash>] The cached steps
      def cached_steps(ttl: 3600)
        cached_config(:steps, ttl: ttl)
      end

      # Cache milestones configuration
      #
      # @param ttl [Integer] Time-to-live in seconds (default: 1 hour)
      # @return [Array<Hash>] The cached milestones
      def cached_milestones(ttl: 3600)
        cached_config(:milestones, ttl: ttl)
      end

      # Cache feature tooltips configuration
      #
      # @param ttl [Integer] Time-to-live in seconds (default: 1 hour)
      # @return [Hash] The cached feature tooltips
      def cached_feature_tooltips(ttl: 3600)
        cached_config(:feature_tooltips, ttl: ttl)
      end
    end

    included do
      # Cache user's onboarding state
      after_save :clear_onboarding_cache, if: :onboarding_attributes_changed?
    end

    # Get cached onboarding progress
    #
    # @param ttl [Integer] Time-to-live in seconds (default: 5 minutes)
    # @return [Integer] The cached progress percentage
    def cached_onboarding_progress(ttl: 300)
      return onboarding_progress if onboarding_attributes_changed?

      cache_key = "rails_onboarding:user:#{id}:progress"
      Rails.cache.fetch(cache_key, expires_in: ttl) do
        onboarding_progress
      end
    end

    # Get cached current onboarding step
    #
    # @param ttl [Integer] Time-to-live in seconds (default: 5 minutes)
    # @return [Hash, nil] The cached current step
    def cached_current_onboarding_step(ttl: 300)
      return current_onboarding_step if onboarding_attributes_changed?

      cache_key = "rails_onboarding:user:#{id}:current_step"
      Rails.cache.fetch(cache_key, expires_in: ttl) do
        current_onboarding_step
      end
    end

    # Get cached milestone achievements
    #
    # @param ttl [Integer] Time-to-live in seconds (default: 10 minutes)
    # @return [Array<String>] The cached achieved milestones
    def cached_achieved_milestones(ttl: 600)
      return achieved_milestones if milestone_attributes_changed?

      cache_key = "rails_onboarding:user:#{id}:milestones"
      Rails.cache.fetch(cache_key, expires_in: ttl) do
        achieved_milestones
      end
    end

    # Get cached available tooltips
    #
    # @param ttl [Integer] Time-to-live in seconds (default: 10 minutes)
    # @return [Hash] Available tooltips for this user
    def cached_available_tooltips(ttl: 600)
      return {} unless RailsOnboarding.configuration.enable_tooltips

      cache_key = "rails_onboarding:user:#{id}:available_tooltips"
      Rails.cache.fetch(cache_key, expires_in: ttl) do
        tooltips = {}
        RailsOnboarding.configuration.feature_tooltips.each do |feature, config|
          tooltips[feature] = config if show_feature_tooltip?(feature)
        end
        tooltips
      end
    end

    # Clear all caches for this user
    def clear_onboarding_cache
      Rails.cache.delete("rails_onboarding:user:#{id}:progress")
      Rails.cache.delete("rails_onboarding:user:#{id}:current_step")
      Rails.cache.delete("rails_onboarding:user:#{id}:milestones")
      Rails.cache.delete("rails_onboarding:user:#{id}:available_tooltips")
      Rails.cache.delete("rails_onboarding:user:#{id}:needs_onboarding")
    end

    # Check if user needs onboarding (cached)
    #
    # @param ttl [Integer] Time-to-live in seconds (default: 1 minute)
    # @return [Boolean] Whether user needs onboarding
    def cached_needs_onboarding?(ttl: 60)
      return needs_onboarding? if onboarding_attributes_changed?

      cache_key = "rails_onboarding:user:#{id}:needs_onboarding"
      Rails.cache.fetch(cache_key, expires_in: ttl) do
        needs_onboarding?
      end
    end

    private

    def onboarding_attributes_changed?
      return false unless persisted?

      previous_changes.keys.any? do |attr|
        attr.start_with?('onboarding_')
      end
    end

    def milestone_attributes_changed?
      return false unless persisted?

      previous_changes.key?('milestones_achieved') ||
        previous_changes.key?('milestone_points') ||
        previous_changes.key?('last_milestone_at')
    end
  end
end
