# frozen_string_literal: true

module RailsOnboarding
  # Controller for managing A/B tests and viewing results
  # Provides endpoints for test management and analytics
  class AbTestsController < ApplicationController
    include RailsOnboarding::AdminAuthorization
    include RailsOnboarding::RateLimitable

    # These actions view A/B test results and flip tests on/off, and
    # assign_variant writes onto arbitrary user records - admin-only, same gate
    # as the Admin dashboard. No StandardError handler here, so the two
    # specific rescues need no ordering guard.
    before_action :authenticate_admin!
    before_action :verify_admin_authorization!

    rescue_from UnauthorizedError, with: :handle_admin_unauthorized
    rescue_from NotImplementedError, with: :handle_admin_not_implemented

    before_action :set_ab_test, only: [ :show, :results, :toggle ]

    # GET /ab_tests
    # List all configured A/B tests
    def index
      @ab_tests = RailsOnboarding.configuration.ab_tests || {}

      respond_to do |format|
        format.html
        format.json { render json: @ab_tests }
      end
    end

    # GET /ab_tests/:test_name
    # Show details for a specific A/B test
    def show
      respond_to do |format|
        format.html
        format.json { render json: test_details }
      end
    end

    # GET /ab_tests/:test_name/results
    # View results and analytics for an A/B test
    def results
      @results = calculate_results
      @funnel = calculate_funnel_by_variant

      respond_to do |format|
        format.html
        format.json { render json: { results: @results, funnel: @funnel } }
      end
    end

    # POST /ab_tests/:test_name/toggle
    # Enable or disable an A/B test
    def toggle
      # Note: This modifies runtime configuration, not persistent storage
      # For production use, configuration should be managed via config files or database
      current_state = @test_config[:enabled]
      @test_config[:enabled] = !current_state

      flash[:notice] = "A/B test #{@test_name} #{@test_config[:enabled] ? 'enabled' : 'disabled'}"

      respond_to do |format|
        format.html { redirect_to ab_tests_path }
        format.json { render json: { enabled: @test_config[:enabled] } }
      end
    end

    # POST /ab_tests/:test_name/assign_variant
    # Manually assign a user to a specific variant
    def assign_variant
      user_id = params[:user_id]
      variant = params[:variant]
      test_name = params[:test_name]

      user = user_class.find_by(id: user_id)

      if user && user.respond_to?(:assign_variant)
        user.assign_variant(test_name, variant)
        render json: { success: true, variant: variant }
      else
        render json: { success: false, error: "User not found or AbTestable not included" }, status: :unprocessable_entity
      end
    end

    private

    def set_ab_test
      # Sanitize test_name to prevent SQL injection
      raw_test_name = params[:test_name] || params[:id]

      # Only allow alphanumeric characters, underscores, and hyphens
      unless raw_test_name =~ /\A[a-zA-Z0-9_-]+\z/
        respond_to do |format|
          format.html { redirect_to ab_tests_path, alert: "Invalid test name format" }
          format.json { render json: { error: "Invalid test name format" }, status: :bad_request }
        end
        return
      end

      @test_name = raw_test_name
      @test_config = RailsOnboarding.configuration.ab_tests[@test_name.to_sym]

      unless @test_config
        respond_to do |format|
          format.html { redirect_to ab_tests_path, alert: "A/B test not found: #{@test_name}" }
          format.json { render json: { error: "Test not found" }, status: :not_found }
        end
      end
    end

    def test_details
      {
        name: @test_name,
        enabled: @test_config[:enabled],
        variants: @test_config[:variants],
        weights: @test_config[:weights],
        participant_count: participant_count,
        variant_distribution: variant_distribution
      }
    end

    # ab_test_assignments is a serialized JSON column that isn't a queryable
    # jsonb type on every database the gem supports, so all variant filtering is
    # done in Ruby to stay portable (mirrors Admin::AbTestsController#calculate_results).
    def all_test_users
      @all_test_users ||= user_class.all.select { |user| user.respond_to?(:ab_test_variant) }
    end

    def users_in_variant(variant)
      all_test_users.select { |user| user.ab_test_variant(@test_name) == variant }
    end

    def participant_count
      all_test_users.count { |user| user.ab_test_variant(@test_name).present? }
    rescue StandardError
      0
    end

    def variant_distribution
      return {} unless user_class.method_defined?(:ab_test_variant)

      @test_config[:variants].each_with_object({}) do |variant, distribution|
        distribution[variant] = users_in_variant(variant).count
      end
    end

    def calculate_results
      variants = @test_config[:variants]
      results = {}

      variants.each do |variant|
        results[variant] = {
          participants: participant_count_for_variant(variant),
          completions: completion_count_for_variant(variant),
          conversion_rate: conversion_rate_for_variant(variant),
          average_time: average_completion_time_for_variant(variant),
          skip_rate: skip_rate_for_variant(variant)
        }
      end

      results
    end

    def participant_count_for_variant(variant)
      users_in_variant(variant).count
    rescue StandardError
      0
    end

    def completion_count_for_variant(variant)
      users_in_variant(variant).count(&:onboarding_completed)
    rescue StandardError
      0
    end

    def conversion_rate_for_variant(variant)
      participants = participant_count_for_variant(variant)
      return 0 if participants.zero?

      completions = completion_count_for_variant(variant)
      (completions.to_f / participants * 100).round(2)
    end

    def average_completion_time_for_variant(variant)
      users = users_in_variant(variant).select do |user|
        user.onboarding_completed && user.onboarding_completed_at
      end

      return 0 if users.empty?

      times = users.map do |user|
        next unless user.created_at && user.onboarding_completed_at

        (user.onboarding_completed_at - user.created_at).to_i
      end.compact

      return 0 if times.empty?

      (times.sum / times.size.to_f).round(2)
    end

    def skip_rate_for_variant(variant)
      participants = participant_count_for_variant(variant)
      return 0 if participants.zero?

      skipped = users_in_variant(variant).count(&:onboarding_skipped)

      (skipped.to_f / participants * 100).round(2)
    end

    def calculate_funnel_by_variant
      variants = @test_config[:variants]
      steps = RailsOnboarding.configuration.steps.map { |s| s[:name].to_s }

      funnel = {}

      variants.each do |variant|
        funnel[variant] = {}

        steps.each_with_index do |step, index|
          if index.zero?
            # First step - all participants start here
            funnel[variant][step] = participant_count_for_variant(variant)
          else
            # Subsequent steps - count users who reached this step
            funnel[variant][step] = users_reached_step_count(variant, step)
          end
        end
      end

      funnel
    end

    def users_reached_step_count(variant, step)
      # This requires analytics events to track step progression
      # For now, return a simplified version
      step_index = RailsOnboarding.configuration.steps.index { |s| s[:name].to_s == step }
      return 0 unless step_index

      # Users who completed onboarding definitely reached all steps
      completed = completion_count_for_variant(variant)

      # Users currently on this step or beyond
      current_on_step = users_in_variant(variant).count do |user|
        user.onboarding_current_step == step
      end

      completed + current_on_step
    end

    def user_class
      @user_class ||= RailsOnboarding.configuration.user_class_name.constantize
    end
  end
end
