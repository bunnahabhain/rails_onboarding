# frozen_string_literal: true

module RailsOnboarding
  # Concern for A/B testing capabilities on User models
  # Provides methods to assign users to test variants and track their performance
  #
  # @example Include in your User model
  #   class User < ApplicationRecord
  #     include RailsOnboarding::Onboardable
  #     include RailsOnboarding::AbTestable
  #   end
  #
  # @example Configure A/B tests
  #   RailsOnboarding.configure do |config|
  #     config.ab_tests = {
  #       onboarding_flow: {
  #         variants: ['original', 'simplified', 'gamified'],
  #         weights: [50, 25, 25], # Percentage distribution
  #         enabled: true
  #       }
  #     }
  #   end
  module AbTestable
    extend ActiveSupport::Concern

    included do
      # Store A/B test assignments as JSON
      # Expected column: ab_test_assignments (jsonb or text)
      serialize :ab_test_assignments, coder: JSON unless column_names.include?("ab_test_assignments") && columns_hash["ab_test_assignments"].type == :jsonb

      # Callbacks
      after_initialize :assign_ab_test_variants, if: :new_record?
    end

    # Get the variant for a specific A/B test
    #
    # @param test_name [String, Symbol] Name of the A/B test
    # @return [String, nil] The assigned variant name or nil if not assigned
    #
    # @example
    #   user.ab_test_variant(:onboarding_flow)
    #   # => "simplified"
    def ab_test_variant(test_name)
      return nil unless ab_test_assignments.is_a?(Hash)

      ab_test_assignments[test_name.to_s]
    end

    # Check if user is in a specific variant
    #
    # @param test_name [String, Symbol] Name of the A/B test
    # @param variant_name [String, Symbol] Name of the variant to check
    # @return [Boolean] True if user is in the specified variant
    #
    # @example
    #   user.in_variant?(:onboarding_flow, :simplified)
    #   # => true
    def in_variant?(test_name, variant_name)
      ab_test_variant(test_name) == variant_name.to_s
    end

    # Assign a specific variant to the user (useful for manual assignment)
    #
    # @param test_name [String, Symbol] Name of the A/B test
    # @param variant_name [String, Symbol] Name of the variant to assign
    # @return [Boolean] True if assignment was successful
    #
    # @example
    #   user.assign_variant(:onboarding_flow, :gamified)
    def assign_variant(test_name, variant_name)
      self.ab_test_assignments ||= {}
      self.ab_test_assignments[test_name.to_s] = variant_name.to_s
      save if persisted?
    end

    # Get all A/B test assignments for this user
    #
    # @return [Hash] Hash of test_name => variant_name
    def all_ab_test_assignments
      ab_test_assignments || {}
    end

    # Track a conversion for an A/B test
    #
    # @param test_name [String, Symbol] Name of the A/B test
    # @param event_name [String, Symbol] Name of the conversion event
    # @param metadata [Hash] Additional metadata to track
    #
    # @example
    #   user.track_ab_conversion(:onboarding_flow, :completed, { time_spent: 300 })
    def track_ab_conversion(test_name, event_name, metadata = {})
      variant = ab_test_variant(test_name)
      return unless variant

      # Track using analytics system if available
      if respond_to?(:track_analytics_event)
        track_analytics_event(
          "ab_test_conversion",
          {
            test_name: test_name.to_s,
            variant: variant,
            event_name: event_name.to_s
          }.merge(metadata)
        )
      end
    end

    private

    # Automatically assign variants for all enabled A/B tests on user creation
    def assign_ab_test_variants
      self.ab_test_assignments ||= {}

      ab_tests = RailsOnboarding.configuration.ab_tests || {}

      ab_tests.each do |test_name, config|
        next unless config[:enabled]
        next if ab_test_assignments[test_name.to_s].present?

        variant = select_variant(config[:variants], config[:weights])
        ab_test_assignments[test_name.to_s] = variant
      end
    end

    # Select a variant based on weights
    #
    # @param variants [Array<String>] Available variants
    # @param weights [Array<Integer>] Percentage weights for each variant
    # @return [String] Selected variant name
    def select_variant(variants, weights = nil)
      return variants.sample if weights.nil? || weights.empty?

      # Normalize weights to ensure they sum to 100
      total_weight = weights.sum.to_f
      normalized_weights = weights.map { |w| (w / total_weight * 100).to_i }

      # Generate random number and select variant
      random = rand(100)
      cumulative = 0

      variants.each_with_index do |variant, index|
        cumulative += normalized_weights[index]
        return variant if random < cumulative
      end

      variants.last # Fallback to last variant
    end
  end
end
