require "rails/generators/base"
require "rails/generators/migration"

module RailsOnboarding
  module Generators
    class InstallGenerator < Rails::Generators::Base
      include Rails::Generators::Migration

      source_root File.expand_path("templates", __dir__)

      def self.next_migration_number(path)
        @prev_migration_nr = if @prev_migration_nr
          @prev_migration_nr + 1
        else
          Time.now.utc.strftime("%Y%m%d%H%M%S").to_i
        end
        @prev_migration_nr.to_s
      end

      def validate_environment
        # Validate that we're in a Rails app
        unless defined?(Rails)
          raise "This generator must be run within a Rails application"
        end

        # Validate template paths exist
        validate_template_paths!

        # Validate User model exists
        validate_user_model!
      end

      def copy_migration
        migration_template "add_onboarding_to_users.rb",
                           "db/migrate/add_onboarding_to_users.rb"
      end

      def copy_analytics_migration
        migration_template "add_analytics_to_rails_onboarding.rb",
                           "db/migrate/add_analytics_to_rails_onboarding.rb"
      end

      def copy_flows_migration
        migration_template "create_rails_onboarding_flows.rb",
                           "db/migrate/create_rails_onboarding_flows.rb"
      end

      def copy_initializer
        template "rails_onboarding.rb", "config/initializers/rails_onboarding.rb"
      end

      def add_route
        route 'mount RailsOnboarding::Engine => "/onboarding"'
      end

      def copy_stylesheets
        copy_file "onboarding.css",
                  "app/assets/stylesheets/rails_onboarding_custom.css"
      end

      def display_readme
        readme "README" if behavior == :invoke
      end

      private

      def validate_template_paths!
        required_templates = [
          "add_onboarding_to_users.rb",
          "add_analytics_to_rails_onboarding.rb",
          "create_rails_onboarding_flows.rb",
          "rails_onboarding.rb",
          "onboarding.css",
          "README"
        ]

        missing_templates = required_templates.reject do |template|
          File.exist?(File.join(self.class.source_root, template))
        end

        if missing_templates.any?
          raise "Missing required template files: #{missing_templates.join(', ')}"
        end
      end

      def validate_user_model!
        # Use destination_root in test environment, Rails.root otherwise
        root_path = respond_to?(:destination_root) ? destination_root : Rails.root
        user_model_path = File.join(root_path, "app/models/user.rb")

        unless File.exist?(user_model_path)
          say_status :error, "User model not found at app/models/user.rb", :red
          say ""
          say "RailsOnboarding requires a User model to exist.", :yellow
          say "Please create a User model before running this generator:", :yellow
          say ""
          say "  rails generate model User email:string", :green
          say ""
          raise "User model does not exist. Please create it first."
        end

        say_status :check, "User model found", :green
      end
    end
  end
end
