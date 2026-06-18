# frozen_string_literal: true

module RailsOnboarding
  module Admin
    # Admin A/B tests controller
    # View and toggle the A/B tests defined in RailsOnboarding.configuration.ab_tests,
    # and inspect their results. Tests are config-defined (see RailsOnboarding::AbTestable),
    # so there is no create/edit/destroy here - only viewing and enabling/disabling.
    class AbTestsController < BaseController
      before_action :set_ab_test, only: [:show, :start, :stop, :export]

      def index
        @ab_tests = ab_tests_collection
        @active_tests = @ab_tests.select { |t| t[:enabled] }
        @inactive_tests = @ab_tests.reject { |t| t[:enabled] }
      end

      def show
        @results = calculate_results(@test_name, @test_config)
      end

      def start
        set_enabled(true)
        flash[:notice] = "A/B test '#{@test_name}' started"
        redirect_to admin_ab_test_path(@test_name)
      end

      def stop
        set_enabled(false)
        flash[:notice] = "A/B test '#{@test_name}' stopped"
        redirect_to admin_ab_test_path(@test_name)
      end

      def export
        results = calculate_results(@test_name, @test_config)

        respond_to do |format|
          format.csv do
            send_data generate_csv_export(results),
              filename: "ab_test_#{@test_name}_results_#{Date.current}.csv",
              type: 'text/csv'
          end
        end
      end

      private

      def ab_tests_collection
        (RailsOnboarding.configuration.ab_tests || {}).map do |name, config|
          {
            name: name.to_s,
            enabled: !!config[:enabled],
            variants: config[:variants] || [],
            weights: config[:weights]
          }
        end
      end

      def set_ab_test
        @test_name = params[:id]
        @test_config = RailsOnboarding.configuration.ab_tests&.[](@test_name.to_sym)

        unless @test_config
          flash[:alert] = "A/B test not found: #{@test_name}"
          redirect_to admin_ab_tests_path
        end
      end

      def set_enabled(value)
        RailsOnboarding.configuration.ab_tests[@test_name.to_sym][:enabled] = value
      end

      # Computed in Ruby rather than SQL: ab_test_assignments is a serialized
      # JSON column, not always a queryable jsonb type, so this stays portable
      # across the databases the gem supports.
      def calculate_results(test_name, test_config)
        variants = test_config[:variants] || []
        users = user_class.all.select { |u| u.respond_to?(:ab_test_variant) }

        variants.each_with_object({}) do |variant, results|
          in_variant = users.select { |u| u.ab_test_variant(test_name) == variant }
          total = in_variant.size
          completed = in_variant.count(&:onboarding_completed)

          results[variant] = {
            participants: total,
            completions: completed,
            conversion_rate: total.zero? ? 0 : (completed.to_f / total * 100).round(2)
          }
        end
      end

      def generate_csv_export(results)
        require 'csv'

        CSV.generate do |csv|
          csv << ['Variant', 'Participants', 'Completions', 'Conversion Rate (%)']

          results.each do |variant, data|
            csv << [variant, data[:participants], data[:completions], data[:conversion_rate]]
          end
        end
      end

      def user_class
        @user_class ||= RailsOnboarding.configuration.user_class_name.constantize
      end
    end
  end
end
