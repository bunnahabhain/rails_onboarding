# frozen_string_literal: true

module RailsOnboarding
  module Admin
    # Admin A/B tests controller
    # Manage onboarding A/B tests and analyze results
    class AbTestsController < BaseController
      before_action :set_ab_test, only: [:show, :edit, :update, :destroy, :start, :stop, :declare_winner]

      def index
        @ab_tests = ab_tests_collection
        @active_tests = @ab_tests.select { |t| t.status == 'active' }
        @completed_tests = @ab_tests.select { |t| t.status == 'completed' }
      end

      def show
        @variants = @ab_test.variants
        @results = calculate_test_results(@ab_test)
        @timeline = test_event_timeline(@ab_test)
      end

      def new
        @ab_test = RailsOnboarding::AbTest.new(status: 'draft')
        @ab_test.variants.build(name: 'control', traffic_percentage: 50)
        @ab_test.variants.build(name: 'variant_a', traffic_percentage: 50)
      end

      def create
        @ab_test = RailsOnboarding::AbTest.new(ab_test_params)

        if @ab_test.save
          flash[:notice] = "A/B test '#{@ab_test.name}' created successfully"
          redirect_to admin_ab_test_path(@ab_test)
        else
          flash.now[:alert] = "Failed to create A/B test: #{@ab_test.errors.full_messages.join(', ')}"
          render :new
        end
      rescue StandardError => e
        flash.now[:alert] = "Error creating A/B test: #{e.message}"
        render :new
      end

      def edit
      end

      def update
        if @ab_test.update(ab_test_params)
          flash[:notice] = "A/B test updated successfully"
          redirect_to admin_ab_test_path(@ab_test)
        else
          flash.now[:alert] = "Failed to update A/B test: #{@ab_test.errors.full_messages.join(', ')}"
          render :edit
        end
      rescue StandardError => e
        flash.now[:alert] = "Error updating A/B test: #{e.message}"
        render :edit
      end

      def destroy
        if @ab_test.destroy
          flash[:notice] = "A/B test deleted successfully"
        else
          flash[:alert] = "Failed to delete A/B test"
        end
        redirect_to admin_ab_tests_path
      rescue StandardError => e
        flash[:alert] = "Error deleting A/B test: #{e.message}"
        redirect_to admin_ab_tests_path
      end

      def start
        if @ab_test.start!
          flash[:notice] = "A/B test '#{@ab_test.name}' started"
        else
          flash[:alert] = "Failed to start A/B test: #{@ab_test.errors.full_messages.join(', ')}"
        end
        redirect_to admin_ab_test_path(@ab_test)
      rescue StandardError => e
        flash[:alert] = "Error starting A/B test: #{e.message}"
        redirect_to admin_ab_test_path(@ab_test)
      end

      def stop
        if @ab_test.stop!
          flash[:notice] = "A/B test '#{@ab_test.name}' stopped"
        else
          flash[:alert] = "Failed to stop A/B test"
        end
        redirect_to admin_ab_test_path(@ab_test)
      rescue StandardError => e
        flash[:alert] = "Error stopping A/B test: #{e.message}"
        redirect_to admin_ab_test_path(@ab_test)
      end

      def declare_winner
        variant_id = params[:variant_id]

        if @ab_test.declare_winner!(variant_id)
          flash[:notice] = "Winner declared for A/B test '#{@ab_test.name}'"
        else
          flash[:alert] = "Failed to declare winner"
        end
        redirect_to admin_ab_test_path(@ab_test)
      rescue StandardError => e
        flash[:alert] = "Error declaring winner: #{e.message}"
        redirect_to admin_ab_test_path(@ab_test)
      end

      def export
        @ab_test = set_ab_test
        results = calculate_test_results(@ab_test)

        respond_to do |format|
          format.csv do
            csv_data = generate_csv_export(@ab_test, results)
            send_data csv_data,
              filename: "ab_test_#{@ab_test.id}_results_#{Date.current}.csv",
              type: 'text/csv'
          end
        end
      rescue StandardError => e
        flash[:alert] = "Error exporting data: #{e.message}"
        redirect_to admin_ab_test_path(@ab_test)
      end

      private

      def set_ab_test
        @ab_test = RailsOnboarding::AbTest.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        flash[:alert] = "A/B test not found"
        redirect_to admin_ab_tests_path
      end

      def ab_tests_collection
        if defined?(RailsOnboarding::AbTest)
          RailsOnboarding::AbTest.order(created_at: :desc)
        else
          []
        end
      end

      def ab_test_params
        params.require(:ab_test).permit(
          :name,
          :description,
          :goal_metric,
          :status,
          :start_date,
          :end_date,
          variants_attributes: [:id, :name, :description, :traffic_percentage, :configuration, :_destroy]
        )
      end

      def calculate_test_results(ab_test)
        return {} unless defined?(RailsOnboarding::AnalyticsEvent)

        results = {}

        ab_test.variants.each do |variant|
          # Get users assigned to this variant
          variant_users = user_assignments_for_variant(ab_test, variant)

          # Calculate metrics
          total_users = variant_users.count
          completed_users = completed_users_for_variant(variant_users)
          conversion_rate = total_users.zero? ? 0 : (completed_users.to_f / total_users * 100).round(2)

          # Calculate average time to complete
          avg_completion_time = calculate_avg_time_for_variant(variant_users)

          # Calculate engagement metrics
          engagement = calculate_engagement_for_variant(variant_users)

          results[variant.id] = {
            variant: variant,
            total_users: total_users,
            completed_users: completed_users,
            conversion_rate: conversion_rate,
            avg_completion_time: avg_completion_time,
            engagement: engagement,
            confidence: calculate_statistical_significance(ab_test, variant)
          }
        end

        results
      end

      def user_assignments_for_variant(ab_test, variant)
        return [] unless defined?(RailsOnboarding::AbTestAssignment)

        RailsOnboarding::AbTestAssignment
          .where(ab_test_id: ab_test.id, variant_id: variant.id)
          .pluck(:user_id)
      end

      def completed_users_for_variant(user_ids)
        return 0 if user_ids.empty?

        user_class.where(id: user_ids, onboarding_completed: true).count
      end

      def calculate_avg_time_for_variant(user_ids)
        return 0 if user_ids.empty?

        users = user_class
          .where(id: user_ids, onboarding_completed: true)
          .where.not(onboarding_completed_at: nil)

        return 0 if users.empty?

        total_time = users.sum do |user|
          next 0 unless user.created_at && user.onboarding_completed_at
          (user.onboarding_completed_at - user.created_at).to_i
        end

        (total_time / users.count / 3600.0).round(2) # Convert to hours
      end

      def calculate_engagement_for_variant(user_ids)
        return 0 if user_ids.empty?
        return 0 unless defined?(RailsOnboarding::AnalyticsEvent)

        total_events = RailsOnboarding::AnalyticsEvent
          .where(user_id: user_ids)
          .count

        (total_events.to_f / user_ids.count).round(2)
      end

      def calculate_statistical_significance(ab_test, variant)
        # Simplified statistical significance calculation
        # In production, use proper statistical tests (chi-square, t-test, etc.)
        results = calculate_test_results(ab_test)
        return 0 unless results[variant.id]

        variant_data = results[variant.id]
        control_variant = ab_test.variants.find_by(name: 'control')
        return 0 unless control_variant

        control_data = results[control_variant.id]
        return 0 unless control_data

        # Simple confidence based on sample size and conversion difference
        sample_size_factor = [variant_data[:total_users] / 100.0, 1.0].min
        conversion_difference = (variant_data[:conversion_rate] - control_data[:conversion_rate]).abs

        confidence = (sample_size_factor * conversion_difference).round(2)
        [confidence, 99.9].min # Cap at 99.9%
      end

      def test_event_timeline(ab_test)
        timeline = []

        timeline << {
          type: 'created',
          timestamp: ab_test.created_at,
          description: 'Test created'
        }

        if ab_test.started_at
          timeline << {
            type: 'started',
            timestamp: ab_test.started_at,
            description: 'Test started'
          }
        end

        if ab_test.ended_at
          timeline << {
            type: 'ended',
            timestamp: ab_test.ended_at,
            description: 'Test ended'
          }
        end

        timeline.sort_by { |item| item[:timestamp] }.reverse
      end

      def generate_csv_export(ab_test, results)
        require 'csv'

        CSV.generate do |csv|
          csv << ['Variant', 'Total Users', 'Completed Users', 'Conversion Rate (%)', 'Avg Completion Time (hours)', 'Engagement', 'Confidence (%)']

          results.each do |variant_id, data|
            csv << [
              data[:variant].name,
              data[:total_users],
              data[:completed_users],
              data[:conversion_rate],
              data[:avg_completion_time],
              data[:engagement],
              data[:confidence]
            ]
          end
        end
      end

      def user_class
        @user_class ||= RailsOnboarding.configuration.user_class_name.constantize
      end
    end
  end
end
