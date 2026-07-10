require "test_helper"
require "generators/rails_onboarding/install_generator"

module RailsOnboarding
  class InstallGeneratorTest < Rails::Generators::TestCase
    tests RailsOnboarding::Generators::InstallGenerator
    destination File.expand_path("../../tmp", __dir__)
    setup :prepare_destination

    def setup
      super
      prepare_destination
      create_user_model
    end

    def teardown
      super
      cleanup_destination
    end

    test "migrations get distinct sequential version numbers" do
      run_generator

      files = Dir.glob(File.join(destination_root, "db/migrate/*.rb")).sort
      versions = files.map { |f| File.basename(f).split("_").first }

      assert_equal 3, versions.length
      assert_equal versions.uniq.length, versions.length,
        "duplicate migration timestamps found: #{versions.inspect}"
      assert_equal versions.sort, versions,
        "migration versions should be in ascending order: #{versions.inspect}"
    end

    test "generator runs successfully with valid environment" do
      run_generator

      # Verify migrations were created
      assert_migration "db/migrate/add_onboarding_to_users.rb"
      assert_migration "db/migrate/add_analytics_to_rails_onboarding.rb"
    end

    test "creates onboarding migration with correct content" do
      run_generator

      migration_file = migration_file_name("db/migrate/add_onboarding_to_users.rb")
      assert_file migration_file do |content|
        assert_match(/class AddOnboardingToUsers/, content)
        assert_match(/def up/, content)
        assert_match(/def down/, content)
        assert_match(/add_column :users, :onboarding_completed/, content)
        assert_match(/add_column :users, :onboarding_completed_at/, content)
        assert_match(/add_column :users, :onboarding_current_step/, content)
        assert_match(/add_column :users, :onboarding_skipped/, content)
        assert_match(/add_column :users, :feature_tooltips_shown/, content)
        assert_match(/remove_column :users, :onboarding_completed/, content)
      end
    end

    test "creates analytics migration with correct content" do
      run_generator

      migration_file = migration_file_name("db/migrate/add_analytics_to_rails_onboarding.rb")
      assert_file migration_file do |content|
        assert_match(/class AddAnalyticsToRailsOnboarding/, content)
        assert_match(/def up/, content)
        assert_match(/def down/, content)
        assert_match(/create_table :rails_onboarding_analytics_events/, content)
        assert_match(/drop_table :rails_onboarding_analytics_events/, content)
      end
    end

    test "creates initializer file" do
      run_generator

      assert_file "config/initializers/rails_onboarding.rb" do |content|
        assert_match(/RailsOnboarding\.configure/, content)
        assert_match(/config\.user_class_name/, content)
        assert_match(/config\.steps/, content)
      end
    end

    test "adds route to routes file" do
      run_generator

      # Note: In a real app, this would check routes.rb
      # For now we'll verify the generator attempts to add the route
      assert_file "config/routes.rb" do |content|
        assert_match(/mount RailsOnboarding::Engine/, content)
      end
    end

    test "copies stylesheet file" do
      run_generator

      assert_file "app/assets/stylesheets/rails_onboarding_custom.css"
    end

    test "validates template paths exist" do
      # Temporarily rename a template to test validation
      original_path = File.join(
        RailsOnboarding::Generators::InstallGenerator.source_root,
        "README"
      )
      backup_path = "#{original_path}.backup"

      FileUtils.mv(original_path, backup_path) if File.exist?(original_path)

      begin
        error = assert_raises(RuntimeError) do
          run_generator
        end
        assert_match(/Missing required template files/, error.message)
      ensure
        FileUtils.mv(backup_path, original_path) if File.exist?(backup_path)
      end
    end

    test "validates User model exists" do
      # Remove the user model to test validation
      FileUtils.rm_f(File.join(destination_root, "app/models/user.rb"))

      error = assert_raises(RuntimeError) do
        run_generator
      end

      assert_match(/User model does not exist/, error.message)
    end

    test "migration uses dynamic Rails version" do
      run_generator

      migration_file = migration_file_name("db/migrate/add_onboarding_to_users.rb")
      assert_file migration_file do |content|
        # Should use ERB template, not hardcoded version
        assert_match(/ActiveRecord::Migration\[\d+\.\d+\]/, content)
      end
    end

    test "migration includes down methods for rollback" do
      run_generator

      migration_file = migration_file_name("db/migrate/add_onboarding_to_users.rb")
      assert_file migration_file do |content|
        assert_match(/def down/, content)
        assert_match(/remove_column/, content)
        assert_match(/remove_index/, content)
      end
    end

    test "analytics migration includes down method for rollback" do
      run_generator

      migration_file = migration_file_name("db/migrate/add_analytics_to_rails_onboarding.rb")
      assert_file migration_file do |content|
        assert_match(/def down/, content)
        assert_match(/drop_table :rails_onboarding_analytics_events/, content)
      end
    end

    test "validates Rails environment" do
      # This test verifies the generator checks for Rails
      # In a non-Rails environment, it should raise an error
      # (This is hard to test directly, but we verify the check exists)

      generator = RailsOnboarding::Generators::InstallGenerator.new([], {}, {})
      assert_respond_to generator, :validate_environment, "Generator should have validate_environment method"
    end

    test "migration handles PostgreSQL jsonb correctly" do
      run_generator

      migration_file = migration_file_name("db/migrate/add_onboarding_to_users.rb")
      assert_file migration_file do |content|
        # Check for case statement that handles different adapters
        assert_match(/case adapter_name/, content)
        assert_match(/when "postgresql"/, content)
        assert_match(/:jsonb/, content)
        assert_match(/:json/, content)
      end
    end

    test "migration includes performance indexes" do
      run_generator

      migration_file = migration_file_name("db/migrate/add_onboarding_to_users.rb")
      assert_file migration_file do |content|
        assert_match(/add_index :users, :onboarding_completed/, content)
        assert_match(/add_index :users, :onboarding_current_step/, content)
        assert_match(/add_index :users, \[:onboarding_completed, :created_at\]/, content)
      end
    end

    test "analytics migration includes comprehensive indexes" do
      run_generator

      migration_file = migration_file_name("db/migrate/add_analytics_to_rails_onboarding.rb")
      assert_file migration_file do |content|
        assert_match(/t\.index :event_type/, content)
        assert_match(/t\.index :occurred_at/, content)
        assert_match(/t\.index :session_id/, content)
        assert_match(/t\.index \[:user_type, :user_id, :event_type\]/, content)
      end
    end

    private

    def create_user_model
      # Create a minimal User model for testing
      FileUtils.mkdir_p(File.join(destination_root, "app/models"))
      File.write(
        File.join(destination_root, "app/models/user.rb"),
        "class User < ActiveRecord::Base\nend\n"
      )

      # Create routes.rb file for testing
      FileUtils.mkdir_p(File.join(destination_root, "config"))
      File.write(
        File.join(destination_root, "config/routes.rb"),
        "Rails.application.routes.draw do\nend\n"
      )
    end

    def cleanup_destination
      FileUtils.rm_rf(destination_root)
    end

    def migration_file_name(relative_path)
      # Find the actual migration file (with timestamp)
      migration_dir = File.join(destination_root, File.dirname(relative_path))
      base_name = File.basename(relative_path, ".rb")

      return nil unless Dir.exist?(migration_dir)

      migration_files = Dir.glob(File.join(migration_dir, "*_#{base_name}.rb"))
      migration_files.first
    end

    def assert_migration(relative_path)
      migration_file = migration_file_name(relative_path)
      assert migration_file, "Expected migration #{relative_path} to exist"
      assert File.exist?(migration_file), "Expected migration file to exist at #{migration_file}"
    end
  end
end
