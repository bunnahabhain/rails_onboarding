require "test_helper"
require "generators/rails_onboarding/install_generator"

module RailsOnboarding
  # The other generator tests only assert on the *text* of the generated
  # migrations - they never actually run them against a database. That's how
  # the AddOnboardingIndexes migration shipped with an add_index call that
  # reused an index name already claimed (for a different column set) by the
  # AddAnalyticsToRailsOnboarding migration: every assertion about the file
  # content passed, but `rails db:migrate` on a fresh install raised
  # "index ... already exists". This test runs the real generated migrations
  # against a real database, up and back down, to catch that class of bug.
  class MigrationExecutionTest < Rails::Generators::TestCase
    tests RailsOnboarding::Generators::InstallGenerator
    destination File.expand_path("../../tmp", __dir__)
    setup :prepare_destination

    def setup
      super
      prepare_destination
      FileUtils.mkdir_p(File.join(destination_root, "app/models"))
      File.write(
        File.join(destination_root, "app/models/user.rb"),
        "class User < ActiveRecord::Base\nend\n"
      )
      FileUtils.mkdir_p(File.join(destination_root, "config"))
      File.write(
        File.join(destination_root, "config/routes.rb"),
        "Rails.application.routes.draw do\nend\n"
      )

      @original_connection_config = ActiveRecord::Base.connection_db_config
    end

    def teardown
      ActiveRecord::Base.establish_connection(@original_connection_config)
      FileUtils.rm_rf(destination_root)
      super
    end

    test "generated migrations run cleanly against a fresh database, up and down" do
      run_generator

      ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
      ActiveRecord::Base.connection.create_table :users do |t|
        t.string :email
        t.timestamps
      end

      migrations_path = File.join(destination_root, "db/migrate")
      context = ActiveRecord::MigrationContext.new([ migrations_path ])

      assert_nothing_raised { context.migrate }
      assert_equal [], context.open.pending_migrations, "all generated migrations should have applied"

      assert_nothing_raised { context.migrate(0) }
    end
  end
end
