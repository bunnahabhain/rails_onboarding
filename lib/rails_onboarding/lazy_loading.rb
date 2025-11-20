# frozen_string_literal: true

module RailsOnboarding
  # Lazy Loading module for performance optimization
  #
  # This module provides helpers for lazy loading onboarding components
  # to improve initial page load times and reduce unnecessary processing
  module LazyLoading
    extend ActiveSupport::Concern

    included do
      # Class-level configuration for lazy loading
      class_attribute :lazy_load_enabled, default: true
      class_attribute :lazy_load_threshold, default: 1000 # Load data only when user count < threshold
    end

    class_methods do
      # Scope for users who need onboarding (optimized query)
      #
      # @return [ActiveRecord::Relation]
      def needs_onboarding
        where(onboarding_completed: false)
          .where('created_at > ?', 1.hour.ago)
      end

      # Scope for users currently in onboarding
      #
      # @return [ActiveRecord::Relation]
      def in_onboarding
        where(onboarding_completed: false)
          .where.not(onboarding_current_step: nil)
      end

      # Batch load onboarding states for multiple users
      # Reduces N+1 queries when displaying lists
      #
      # @param user_ids [Array<Integer>] User IDs to load
      # @return [Hash] Hash of user_id => onboarding_state
      def batch_load_onboarding_states(user_ids)
        return {} if user_ids.empty?

        where(id: user_ids)
          .pluck(:id, :onboarding_completed, :onboarding_current_step)
          .each_with_object({}) do |(id, completed, step), hash|
            hash[id] = {
              completed: completed,
              current_step: step
            }
          end
      end

      # Count users in each onboarding step (cached for performance)
      #
      # @param ttl [Integer] Cache TTL in seconds
      # @return [Hash] Step name => count
      def onboarding_step_counts(ttl: 300)
        cache_key = 'rails_onboarding:step_counts'
        Rails.cache.fetch(cache_key, expires_in: ttl) do
          in_onboarding
            .group(:onboarding_current_step)
            .count
        end
      end
    end

    # Lazy load current step data only when needed
    #
    # @return [Hash, nil] Step data
    def lazy_current_step
      return @lazy_current_step if defined?(@lazy_current_step)

      @lazy_current_step = if lazy_load_enabled?
        current_onboarding_step
      else
        nil
      end
    end

    # Lazy load next step data only when needed
    #
    # @return [Hash, nil] Next step data
    def lazy_next_step
      return @lazy_next_step if defined?(@lazy_next_step)

      @lazy_next_step = if lazy_load_enabled?
        next_onboarding_step
      else
        nil
      end
    end

    # Lazy load available milestones
    #
    # @return [Array<Hash>] Available milestones
    def lazy_milestones_available
      return @lazy_milestones_available if defined?(@lazy_milestones_available)

      @lazy_milestones_available = if lazy_load_enabled? && RailsOnboarding.configuration.enable_milestones
        milestones_available
      else
        []
      end
    end

    # Lazy load tooltips only when on a page that needs them
    #
    # @param page_context [String] Current page or controller action
    # @return [Hash] Available tooltips for current page
    def lazy_tooltips_for_page(page_context)
      return {} unless lazy_load_enabled?
      return {} unless RailsOnboarding.configuration.enable_tooltips

      cache_key = "rails_onboarding:user:#{id}:tooltips:#{page_context}"
      Rails.cache.fetch(cache_key, expires_in: 600) do
        tooltips = {}
        RailsOnboarding.configuration.feature_tooltips.each do |feature, config|
          # Only include tooltips relevant to current page
          if feature.include?(page_context) && show_feature_tooltip?(feature)
            tooltips[feature] = config
          end
        end
        tooltips
      end
    end

    # Check if lazy loading should be enabled for this user
    #
    # @return [Boolean]
    def lazy_load_enabled?
      self.class.lazy_load_enabled &&
        self.class.unscoped.count < self.class.lazy_load_threshold
    end

    # Preload onboarding data for this user
    # Call this in controller before rendering to avoid N+1
    #
    # @return [Hash] Preloaded data
    def preload_onboarding_data
      {
        needs_onboarding: needs_onboarding?,
        current_step: current_onboarding_step,
        next_step: next_onboarding_step,
        progress: onboarding_progress,
        milestones: RailsOnboarding.configuration.enable_milestones ? achieved_milestones : [],
        milestone_points: RailsOnboarding.configuration.enable_milestones ? total_milestone_points : 0
      }
    end
  end
end
