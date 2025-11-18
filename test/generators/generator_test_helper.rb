require "test_helper"
require "rails/generators/test_case"
require "fileutils"

module GeneratorTestHelper
  def self.included(base)
    base.class_eval do
      setup :prepare_generator_destination
      teardown :cleanup_generator_destination
    end
  end

  def prepare_generator_destination
    FileUtils.mkdir_p(destination_root)
    prepare_rails_structure
  end

  def cleanup_generator_destination
    FileUtils.rm_rf(destination_root)
  end

  def prepare_rails_structure
    # Create basic Rails directory structure
    dirs = %w[
      app/models
      app/controllers
      app/views
      config/initializers
      config/locales
      db/migrate
      app/assets/stylesheets
    ]

    dirs.each do |dir|
      FileUtils.mkdir_p(File.join(destination_root, dir))
    end

    # Create a basic routes file
    routes_path = File.join(destination_root, "config/routes.rb")
    File.write(routes_path, "Rails.application.routes.draw do\nend\n")

    # Create a basic application.rb
    app_path = File.join(destination_root, "config/application.rb")
    File.write(app_path, "module TestApp\n  class Application < Rails::Application\n  end\nend\n")
  end

  def create_user_model
    user_model_path = File.join(destination_root, "app/models/user.rb")
    File.write(user_model_path, <<~RUBY)
      class User < ActiveRecord::Base
      end
    RUBY
  end

  def migration_file_name(relative_path)
    migration_dir = File.join(destination_root, File.dirname(relative_path))
    base_name = File.basename(relative_path, ".rb")

    return nil unless Dir.exist?(migration_dir)

    migration_files = Dir.glob(File.join(migration_dir, "*_#{base_name}.rb"))
    migration_files.first
  end

  def assert_migration(relative_path, message = nil)
    migration_file = migration_file_name(relative_path)
    msg = message || "Expected migration #{relative_path} to exist"
    assert migration_file, msg
    assert File.exist?(migration_file), "Expected migration file to exist at #{migration_file}"
  end

  def refute_migration(relative_path, message = nil)
    migration_file = migration_file_name(relative_path)
    msg = message || "Expected migration #{relative_path} to not exist"
    refute migration_file, msg
  end

  def assert_file_contains(file, *contents)
    assert_file file do |content|
      contents.each do |expected|
        assert_match expected, content, "Expected #{file} to contain #{expected}"
      end
    end
  end
end
