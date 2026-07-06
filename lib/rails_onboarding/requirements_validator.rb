# frozen_string_literal: true

module RailsOnboarding
  # Validates that the host application meets all requirements for RailsOnboarding
  # Usage: RailsOnboarding::RequirementsValidator.validate!
  class RequirementsValidator
    class ValidationError < StandardError; end

    class << self
      # Run all validations and raise if any fail
      def validate!
        results = run_validations

        if results[:errors].any?
          raise ValidationError, format_error_message(results)
        end

        log_results(results)
        true
      end

      # Run all validations and return results without raising
      def check
        run_validations
      end

      private

      def run_validations
        results = {
          errors: [],
          warnings: [],
          info: []
        }

        validate_rails_version(results)
        validate_ruby_version(results)
        validate_user_class(results)
        validate_user_model(results)
        validate_application_controller(results)
        validate_current_user_method(results)
        validate_database_columns(results)
        validate_routes(results)
        validate_optional_dependencies(results)
        validate_configuration(results)

        results
      end

      def validate_rails_version(results)
        required_version = Gem::Version.new('7.0.0')
        current_version = Gem::Version.new(Rails.version)

        if current_version < required_version
          results[:errors] << "Rails version #{required_version} or higher required (current: #{current_version})"
        else
          results[:info] << "Rails version: #{current_version} ✓"
        end
      rescue => e
        results[:errors] << "Could not determine Rails version: #{e.message}"
      end

      def validate_ruby_version(results)
        required_version = Gem::Version.new('3.0.0')
        current_version = Gem::Version.new(RUBY_VERSION)

        if current_version < required_version
          results[:errors] << "Ruby version #{required_version} or higher required (current: #{current_version})"
        else
          results[:info] << "Ruby version: #{current_version} ✓"
        end
      rescue => e
        results[:errors] << "Could not determine Ruby version: #{e.message}"
      end

      def validate_user_class(results)
        begin
          user_class_name = RailsOnboarding.configuration.user_class_name
          user_class = user_class_name.constantize

          results[:info] << "User class '#{user_class_name}' found ✓"

          # Check if Onboardable concern is included
          unless user_class.included_modules.include?(RailsOnboarding::Onboardable)
            results[:errors] << "User class '#{user_class_name}' must include RailsOnboarding::Onboardable concern"
          else
            results[:info] << "Onboardable concern included ✓"
          end
        rescue NameError
          results[:errors] << "User class '#{RailsOnboarding.configuration.user_class_name}' not found"
        rescue => e
          results[:errors] << "Error validating user class: #{e.message}"
        end
      end

      def validate_user_model(results)
        begin
          user_class_name = RailsOnboarding.configuration.user_class_name
          user_class = user_class_name.constantize

          # Check for required behavioral methods (provided by the Onboardable concern).
          # onboarding_completed? and onboarding_current_step are column-backed attribute
          # methods instead - Rails generates those lazily on first instantiation, so
          # instance_methods.include? can't reliably see them here; their underlying
          # columns are already checked in validate_database_columns.
          required_methods = [
            :needs_onboarding?,
            :complete_onboarding!,
            :onboarding_progress_percentage
          ]

          required_methods.each do |method|
            unless user_class.instance_methods.include?(method)
              results[:errors] << "User model missing required method: #{method}"
            end
          end
        rescue NameError
          # Already reported in validate_user_class
        rescue => e
          results[:warnings] << "Could not validate user model methods: #{e.message}"
        end
      end

      def validate_application_controller(results)
        if defined?(ApplicationController)
          results[:info] << "ApplicationController found ✓"

          # Check if ControllerHelpers are included
          if ApplicationController.included_modules.include?(RailsOnboarding::ControllerHelpers)
            results[:info] << "ControllerHelpers included ✓"
          else
            results[:warnings] << "RailsOnboarding::ControllerHelpers not included in ApplicationController (this is automatic in engine mode)"
          end
        else
          results[:warnings] << "ApplicationController not found (unusual but may be intentional)"
        end
      rescue => e
        results[:warnings] << "Error checking ApplicationController: #{e.message}"
      end

      def validate_current_user_method(results)
        if defined?(ApplicationController)
          if ApplicationController.instance_methods.include?(:current_user)
            results[:info] << "current_user method available ✓"
          else
            results[:errors] << "ApplicationController must have a current_user method (typically provided by authentication system)"
          end
        end
      rescue => e
        results[:warnings] << "Could not validate current_user method: #{e.message}"
      end

      def validate_database_columns(results)
        begin
          user_class = RailsOnboarding.configuration.user_class_name.constantize

          return unless user_class.respond_to?(:column_names)

          required_columns = {
            'onboarding_completed' => :boolean,
            'onboarding_current_step' => :string,
            'onboarding_skipped' => :boolean
          }

          optional_columns = {
            'onboarding_completed_at' => :datetime,
            'feature_tooltips_shown' => [:jsonb, :text],
            'milestones_achieved' => [:text, :jsonb],
            'milestone_points' => :integer,
            'last_milestone_at' => :datetime
          }

          # Check required columns
          required_columns.each do |column_name, expected_type|
            if user_class.column_names.include?(column_name)
              actual_type = user_class.columns_hash[column_name]&.type
              if actual_type.to_s != expected_type.to_s
                results[:warnings] << "Column '#{column_name}' has type #{actual_type}, expected #{expected_type}"
              else
                results[:info] << "Required column '#{column_name}' (#{expected_type}) ✓"
              end
            else
              results[:errors] << "Required database column missing: #{column_name} (#{expected_type})"
            end
          end

          # Check optional columns
          optional_columns.each do |column_name, expected_types|
            expected_types = Array(expected_types)
            if user_class.column_names.include?(column_name)
              actual_type = user_class.columns_hash[column_name]&.type
              if expected_types.map(&:to_s).include?(actual_type.to_s)
                results[:info] << "Optional column '#{column_name}' (#{actual_type}) ✓"
              else
                results[:warnings] << "Column '#{column_name}' has type #{actual_type}, expected one of #{expected_types.join(', ')}"
              end
            else
              results[:info] << "Optional column '#{column_name}' not present (some features may be unavailable)"
            end
          end
        rescue NameError
          # Already reported in validate_user_class
        rescue => e
          results[:warnings] << "Could not validate database columns: #{e.message}"
        end
      end

      def validate_routes(results)
        if defined?(Rails.application)
          routes = Rails.application.routes.routes.map(&:name).compact

          if routes.include?('rails_onboarding')
            results[:info] << "Engine mounted in routes ✓"
          else
            results[:errors] << "RailsOnboarding engine not mounted in routes. Add: mount RailsOnboarding::Engine => '/onboarding'"
          end
        end
      rescue => e
        results[:warnings] << "Could not validate routes: #{e.message}"
      end

      def validate_optional_dependencies(results)
        # Check for optional gems
        optional_gems = {
          'ActiveJob' => -> { defined?(::ActiveJob::Base) },
          'ActionMailer' => -> { defined?(::ActionMailer::Base) },
          'Devise' => -> { defined?(Devise) },
          'Turbo' => -> { defined?(Turbo) },
          'Stimulus' => -> { defined?(Stimulus) },
          'Noticed' => -> { defined?(Noticed) },
          'ActiveModel::Serializers' => -> { defined?(ActiveModel::Serializer) }
        }

        optional_gems.each do |gem_name, check|
          if check.call
            results[:info] << "Optional: #{gem_name} available ✓"
          else
            results[:info] << "Optional: #{gem_name} not available (some features may be limited)"
          end
        end
      rescue => e
        results[:warnings] << "Error checking optional dependencies: #{e.message}"
      end

      def validate_configuration(results)
        config = RailsOnboarding.configuration

        # Check critical configuration
        unless config.steps.any?
          results[:errors] << "No onboarding steps configured. Add steps in config/initializers/rails_onboarding.rb"
        else
          results[:info] << "#{config.steps.size} onboarding step(s) configured ✓"
        end

        # Check step names are unique
        step_names = config.steps.map { |s| s[:name] }
        duplicates = step_names.select { |name| step_names.count(name) > 1 }.uniq
        if duplicates.any?
          results[:errors] << "Duplicate step names found: #{duplicates.join(', ')}"
        end

        # Check redirect paths
        if config.redirect_after_completion.nil?
          results[:warnings] << "No redirect_after_completion configured (users will stay on onboarding page)"
        end

        # Validate mailer configuration if emails are enabled
        if RailsOnboarding::BackgroundJobs.background_job_options[:enable_emails] && !RailsOnboarding.action_mailer_configured?
          results[:warnings] << "Emails enabled but ActionMailer not properly configured"
        end
      rescue => e
        results[:warnings] << "Error validating configuration: #{e.message}"
      end

      def format_error_message(results)
        message = "\n" + "=" * 80 + "\n"
        message += "RailsOnboarding Requirements Validation Failed\n"
        message += "=" * 80 + "\n\n"

        if results[:errors].any?
          message += "ERRORS (must be fixed):\n"
          results[:errors].each { |error| message += "  ✗ #{error}\n" }
          message += "\n"
        end

        if results[:warnings].any?
          message += "WARNINGS (should be addressed):\n"
          results[:warnings].each { |warning| message += "  ⚠ #{warning}\n" }
          message += "\n"
        end

        message += "Please fix the errors above before using RailsOnboarding.\n"
        message += "See documentation: https://github.com/bunnahabhain/rails_onboarding\n"
        message += "=" * 80 + "\n"

        message
      end

      def log_results(results)
        return unless defined?(Rails.logger)

        Rails.logger.info "RailsOnboarding requirements validation passed ✓"

        if results[:warnings].any?
          Rails.logger.warn "RailsOnboarding has #{results[:warnings].size} warning(s):"
          results[:warnings].each { |warning| Rails.logger.warn "  ⚠ #{warning}" }
        end

        if results[:info].any? && Rails.env.development?
          results[:info].each { |info| Rails.logger.debug "  #{info}" }
        end
      end
    end
  end
end
