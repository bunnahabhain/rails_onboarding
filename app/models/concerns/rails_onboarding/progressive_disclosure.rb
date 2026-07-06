# frozen_string_literal: true

module RailsOnboarding
  # Concern for progressive disclosure of features
  # Shows features gradually over time based on user behavior and progress
  #
  # @example Include in your User model
  #   class User < ApplicationRecord
  #     include RailsOnboarding::Onboardable
  #     include RailsOnboarding::ProgressiveDisclosure
  #   end
  #
  # @example Configure progressive features
  #   RailsOnboarding.configure do |config|
  #     config.progressive_disclosure_enabled = true
  #     config.progressive_features = [
  #       {
  #         key: :advanced_settings,
  #         reveal_condition: :time_based,
  #         delay: 7.days,
  #         title: "Advanced Settings",
  #         description: "Now that you're familiar with the basics..."
  #       },
  #       {
  #         key: :team_collaboration,
  #         reveal_condition: :action_based,
  #         check_method: :has_created_first_project?,
  #         title: "Team Collaboration",
  #         description: "Ready to invite your team?"
  #       }
  #     ]
  #   end
  module ProgressiveDisclosure
    extend ActiveSupport::Concern

    included do
      # Store revealed features as JSON
      # Expected column: revealed_features (jsonb or text)
      serialize :revealed_features, coder: JSON unless column_names.include?('revealed_features') && columns_hash['revealed_features'].type == :jsonb

      # Callback to check and reveal features
      after_save :check_progressive_features, if: :saved_change_to_onboarding_current_step?
    end

    # Check if a feature has been revealed to the user
    #
    # @param feature_key [String, Symbol] Feature key
    # @return [Boolean] True if feature is revealed
    #
    # @example
    #   user.feature_revealed?(:advanced_settings)
    #   # => false
    def feature_revealed?(feature_key)
      return true unless RailsOnboarding.configuration.progressive_disclosure_enabled

      features = revealed_features || []
      features.include?(feature_key.to_s)
    end

    # Mark a feature as revealed
    #
    # @param feature_key [String, Symbol] Feature key
    # @param metadata [Hash] Additional metadata about the reveal
    # @return [Boolean] True if successfully marked as revealed
    #
    # @example
    #   user.reveal_feature(:advanced_settings, source: :automatic)
    def reveal_feature(feature_key, metadata = {})
      self.revealed_features ||= []
      return false if revealed_features.include?(feature_key.to_s)

      revealed_features << feature_key.to_s

      # Track the reveal event
      if respond_to?(:track_analytics_event)
        track_analytics_event(
          'feature_revealed',
          {
            feature_key: feature_key.to_s,
            reveal_time: Time.current
          }.merge(metadata)
        )
      end

      save if persisted?
    end

    # Hide a previously revealed feature
    #
    # @param feature_key [String, Symbol] Feature key
    # @return [Boolean] True if successfully hidden
    def hide_feature(feature_key)
      return false unless revealed_features

      revealed_features.delete(feature_key.to_s)
      save if persisted?
    end

    # Get all revealed features
    #
    # @return [Array<String>] Array of revealed feature keys
    def all_revealed_features
      revealed_features || []
    end

    # Get features that are ready to be revealed
    #
    # @return [Array<Hash>] Array of feature configurations ready to reveal
    #
    # @example
    #   user.features_ready_to_reveal
    #   # => [{key: :advanced_settings, title: "...", ...}]
    def features_ready_to_reveal
      return [] unless RailsOnboarding.configuration.progressive_disclosure_enabled

      features = RailsOnboarding.configuration.progressive_features || []

      features.select do |feature|
        # Skip if already revealed
        next false if feature_revealed?(feature[:key])

        # Check if feature meets reveal conditions
        feature_ready?(feature)
      end
    end

    # Check if a specific feature is ready to be revealed
    #
    # @param feature [Hash] Feature configuration
    # @return [Boolean] True if feature is ready
    def feature_ready?(feature)
      case feature[:reveal_condition]
      when :time_based
        time_based_ready?(feature)
      when :action_based
        action_based_ready?(feature)
      when :step_based
        step_based_ready?(feature)
      when :milestone_based
        milestone_based_ready?(feature)
      when :engagement_based
        engagement_based_ready?(feature)
      else
        false
      end
    rescue StandardError => e
      Rails.logger.error("Error checking feature readiness: #{e.message}") if defined?(Rails)
      false
    end

    # Reveal all features that are ready
    #
    # @return [Array<String>] Array of newly revealed feature keys
    def reveal_ready_features!
      newly_revealed = []

      features_ready_to_reveal.each do |feature|
        if reveal_feature(feature[:key], source: :automatic, condition: feature[:reveal_condition])
          newly_revealed << feature[:key].to_s
        end
      end

      newly_revealed
    end

    # Get the next feature that will be revealed
    #
    # @return [Hash, nil] Next feature configuration or nil
    def next_feature_to_reveal
      features = RailsOnboarding.configuration.progressive_features || []

      features
        .reject { |f| feature_revealed?(f[:key]) }
        .min_by { |f| estimated_reveal_time(f) }
    end

    # Estimate when a feature will be revealed
    #
    # @param feature [Hash] Feature configuration
    # @return [Time, nil] Estimated reveal time or nil
    def estimated_reveal_time(feature)
      case feature[:reveal_condition]
      when :time_based
        created_at + feature[:delay].seconds
      when :step_based
        nil # Can't estimate step-based reveals
      else
        nil
      end
    end

    # Get a count of how many features have been revealed
    #
    # @return [Integer] Count of revealed features
    def revealed_features_count
      all_revealed_features.size
    end

    # Get a count of features pending reveal
    #
    # @return [Integer] Count of pending features
    def pending_features_count
      return 0 unless RailsOnboarding.configuration.progressive_disclosure_enabled

      total_features = RailsOnboarding.configuration.progressive_features&.size || 0
      total_features - revealed_features_count
    end

    private

    # Check if time-based feature is ready
    def time_based_ready?(feature)
      return false unless created_at

      delay = feature[:delay] || 0
      created_at + delay.seconds <= Time.current
    end

    # Check if action-based feature is ready
    def action_based_ready?(feature)
      method_name = feature[:check_method]
      return false unless method_name
      return false unless respond_to?(method_name)

      send(method_name)
    end

    # Check if step-based feature is ready
    def step_based_ready?(feature)
      return false unless onboarding_current_step

      after_step = feature[:after_step]
      return false unless after_step

      current_index = RailsOnboarding.configuration.step_index(onboarding_current_step)
      required_index = RailsOnboarding.configuration.step_index(after_step)

      return false if current_index.nil? || required_index.nil?

      current_index >= required_index
    end

    # Check if milestone-based feature is ready
    def milestone_based_ready?(feature)
      return false unless respond_to?(:earned_milestones)

      required_milestone = feature[:required_milestone]
      return false unless required_milestone

      earned_milestones.include?(required_milestone.to_s)
    end

    # Check if engagement-based feature is ready
    def engagement_based_ready?(feature)
      return false unless respond_to?(:analytics_events)

      min_events = feature[:min_events] || 0
      event_type = feature[:event_type]

      if event_type
        analytics_events.where(event_type: event_type).count >= min_events
      else
        analytics_events.count >= min_events
      end
    rescue StandardError
      false
    end

    # Callback to check and reveal features after step changes
    def check_progressive_features
      return unless RailsOnboarding.configuration.progressive_disclosure_enabled

      reveal_ready_features!
    end
  end
end
