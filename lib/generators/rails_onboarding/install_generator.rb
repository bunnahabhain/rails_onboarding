require 'rails/generators/base'
require 'rails/generators/migration'

module RailsOnboarding
  module Generators
    class InstallGenerator < Rails::Generators::Base
      include Rails::Generators::Migration

      source_root File.expand_path('templates', __dir__)

      def self.next_migration_number(path)
        Time.now.utc.strftime("%Y%m%d%H%M%S")
      end

      def copy_migration
        migration_template "add_onboarding_users.rb",
                           "db/migrate/add_onboarding_to_users.rb"
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
    end
  end
end
