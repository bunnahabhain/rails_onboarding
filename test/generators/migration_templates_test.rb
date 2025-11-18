require "test_helper"
require "generators/rails_onboarding/install_generator"

module RailsOnboarding
  class MigrationTemplatesTest < ActiveSupport::TestCase
    def setup
      @template_dir = File.join(
        File.dirname(__FILE__),
        "../../lib/generators/rails_onboarding/templates"
      )
    end

    test "all migration templates exist" do
      required_migrations = [
        "add_onboarding_users.rb",
        "add_analytics_to_rails_onboarding.rb",
        "add_milestone_tracking_to_users.rb",
        "add_onboarding_indexes.rb",
        "add_robustness_fields_to_users.rb.tt"
      ]

      required_migrations.each do |migration|
        path = File.join(@template_dir, migration)
        assert File.exist?(path), "Migration template #{migration} should exist"
      end
    end

    test "all migration templates use dynamic Rails version" do
      migration_files = Dir.glob(File.join(@template_dir, "*.rb*"))
        .reject { |f| f.end_with?("rails_onboarding.rb") }

      migration_files.each do |file|
        content = File.read(file)
        migration_class_match = content.match(/class \w+ < ActiveRecord::Migration\[(.*?)\]/)

        if migration_class_match
          version_syntax = migration_class_match[1]
          assert_match(
            /<%=.*ActiveRecord::Migration\.current_version.*%>/,
            version_syntax,
            "#{File.basename(file)} should use dynamic Rails version, got: #{version_syntax}"
          )
        end
      end
    end

    test "all migration templates have up and down methods" do
      migration_files = Dir.glob(File.join(@template_dir, "*.rb*"))
        .reject { |f| f.end_with?("rails_onboarding.rb") }

      migration_files.each do |file|
        content = File.read(file)
        basename = File.basename(file)

        assert_match(/def up/, content, "#{basename} should have 'def up' method")
        assert_match(/def down/, content, "#{basename} should have 'def down' method")
        refute_match(/def change/, content, "#{basename} should not use 'def change'")
      end
    end

    test "add_onboarding_users migration has proper rollback" do
      file = File.join(@template_dir, "add_onboarding_users.rb")
      content = File.read(file)

      # Check up method
      assert_match(/add_column :users, :onboarding_completed/, content)
      assert_match(/add_column :users, :feature_tooltips_shown/, content)
      assert_match(/add_index :users, :onboarding_completed/, content)

      # Check down method
      assert_match(/remove_column :users, :onboarding_completed/, content)
      assert_match(/remove_column :users, :feature_tooltips_shown/, content)
      assert_match(/remove_index.*:onboarding_completed/, content)
    end

    test "add_analytics migration has proper rollback" do
      file = File.join(@template_dir, "add_analytics_to_rails_onboarding.rb")
      content = File.read(file)

      # Check up method
      assert_match(/create_table :rails_onboarding_analytics_events/, content)

      # Check down method
      assert_match(/drop_table :rails_onboarding_analytics_events/, content)
      assert_match(/if table_exists\?/, content, "Should check if table exists before dropping")
    end

    test "add_milestone_tracking migration has proper rollback" do
      file = File.join(@template_dir, "add_milestone_tracking_to_users.rb")
      content = File.read(file)

      # Check up method
      assert_match(/add_column :users, :milestones_achieved/, content)
      assert_match(/add_column :users, :milestone_points/, content)
      assert_match(/add_index :users, :milestone_points/, content)

      # Check down method
      assert_match(/remove_column :users, :milestones_achieved/, content)
      assert_match(/remove_index :users, :milestone_points/, content)
    end

    test "add_onboarding_indexes migration has proper rollback" do
      file = File.join(@template_dir, "add_onboarding_indexes.rb")
      content = File.read(file)

      # Check up method adds indexes
      assert_match(/add_index :users, :onboarding_completed/, content)
      assert_match(/add_index :users, :onboarding_current_step/, content)

      # Check down method removes indexes
      assert_match(/remove_index :users, :onboarding_completed/, content)
      assert_match(/remove_index :users, :onboarding_current_step/, content)

      # Check for safety checks
      assert_match(/if index_exists\?/, content, "Should check if index exists")
    end

    test "add_robustness_fields migration has proper rollback" do
      file = File.join(@template_dir, "add_robustness_fields_to_users.rb.tt")
      content = File.read(file)

      # Check up method
      assert_match(/add_column :users, :onboarding_errors/, content)
      assert_match(/add_column :users, :onboarding_failed_actions/, content)
      assert_match(/add_column :users, :onboarding_session_data/, content)

      # Check down method
      assert_match(/remove_column :users, :onboarding_errors/, content)
      assert_match(/remove_column :users, :onboarding_failed_actions/, content)
      assert_match(/remove_column :users, :onboarding_session_data/, content)

      # Check for safety checks
      assert_match(/if column_exists\?/, content, "Should check if column exists")
    end

    test "migrations use safe column operations" do
      migration_files = Dir.glob(File.join(@template_dir, "*users*.rb*"))

      migration_files.each do |file|
        content = File.read(file)
        basename = File.basename(file)

        # Check for existence checks before removal
        if content.include?("remove_column")
          assert_match(
            /if column_exists\?/,
            content,
            "#{basename} should check column existence before removing"
          )
        end

        if content.include?("remove_index") && !content.include?("name:")
          # Only check for simple index removals (not named indexes in this context)
          # Named indexes should also have their checks
        end
      end
    end

    test "analytics migration uses correct table name" do
      file = File.join(@template_dir, "add_analytics_to_rails_onboarding.rb")
      content = File.read(file)

      # Should use namespaced table name
      assert_match(/rails_onboarding_analytics_events/, content)
      refute_match(/analytics_events[^_]/, content, "Should use fully qualified table name")
    end

    test "migrations include proper indexes for performance" do
      onboarding_file = File.join(@template_dir, "add_onboarding_users.rb")
      onboarding_content = File.read(onboarding_file)

      # Check for performance indexes
      assert_match(/add_index :users, :onboarding_completed/, onboarding_content)
      assert_match(/add_index :users, :onboarding_current_step/, onboarding_content)
      assert_match(/add_index :users, \[:onboarding_completed, :created_at\]/, onboarding_content)

      analytics_file = File.join(@template_dir, "add_analytics_to_rails_onboarding.rb")
      analytics_content = File.read(analytics_file)

      # Check for analytics performance indexes
      assert_match(/t\.index :event_type/, analytics_content)
      assert_match(/t\.index :occurred_at/, analytics_content)
      assert_match(/t\.index :session_id/, analytics_content)
    end

    test "onboarding migration handles different database adapters" do
      file = File.join(@template_dir, "add_onboarding_users.rb")
      content = File.read(file)

      # Should handle PostgreSQL jsonb, MySQL json, and SQLite text
      assert_match(/adapter_name = ActiveRecord::Base\.connection\.adapter_name\.downcase/, content)
      assert_match(/case adapter_name/, content)
      assert_match(/when "postgresql", "postgis"/, content)
      assert_match(/when "mysql2", "trilogy", "mysql"/, content)
      assert_match(/:jsonb/, content, "Should use jsonb for PostgreSQL")
      assert_match(/:json[^b]/, content, "Should use json for MySQL")
      assert_match(/:text/, content, "Should fall back to text for other databases")
    end

    test "all migrations follow naming conventions" do
      migration_files = Dir.glob(File.join(@template_dir, "*.rb*"))
        .reject { |f| f.end_with?("rails_onboarding.rb") }

      migration_files.each do |file|
        content = File.read(file)
        basename = File.basename(file, ".*")

        # Extract class name from content
        class_match = content.match(/class (\w+) < ActiveRecord::Migration/)
        next unless class_match

        class_name = class_match[1]

        # Convert basename to expected class name
        expected_class_name = basename.split("_").map(&:capitalize).join

        assert_equal(
          expected_class_name,
          class_name,
          "Class name should match file name convention"
        )
      end
    end

    test "down methods remove items in reverse order of up methods" do
      # This is a guideline check - down methods should generally
      # remove indexes before columns
      migration_files = Dir.glob(File.join(@template_dir, "*users*.rb*"))

      migration_files.each do |file|
        content = File.read(file)
        basename = File.basename(file)

        # Extract down method
        down_match = content.match(/def down\n(.*?)\n  end/m)
        next unless down_match

        down_content = down_match[1]

        # If there are both remove_index and remove_column calls
        if down_content.include?("remove_index") && down_content.include?("remove_column")
          first_remove_index = down_content.index("remove_index")
          first_remove_column = down_content.index("remove_column")

          assert(
            first_remove_index < first_remove_column,
            "#{basename}: Indexes should be removed before columns in down method"
          )
        end
      end
    end
  end
end
