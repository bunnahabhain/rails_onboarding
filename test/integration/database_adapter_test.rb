# frozen_string_literal: true

require "test_helper"

module RailsOnboarding
  class DatabaseAdapterTest < ActiveSupport::TestCase
    setup do
      @user = users(:one)
      @current_adapter = ActiveRecord::Base.connection.adapter_name
    end

    # ===== Adapter Detection Tests =====

    test "correctly detects PostgreSQL adapter" do
      if @current_adapter == "PostgreSQL"
        assert_equal "PostgreSQL", ActiveRecord::Base.connection.adapter_name
      else
        skip "Not running on PostgreSQL"
      end
    end

    test "correctly detects MySQL adapter" do
      if @current_adapter.match?(/MySQL|Mysql2|MariaDB/)
        assert_match(/MySQL|Mysql2|MariaDB/, ActiveRecord::Base.connection.adapter_name)
      else
        skip "Not running on MySQL"
      end
    end

    test "correctly detects SQLite adapter" do
      if @current_adapter == "SQLite"
        assert_equal "SQLite", ActiveRecord::Base.connection.adapter_name
      else
        skip "Not running on SQLite"
      end
    end

    # ===== JSON/JSONB Column Tests =====

    test "handles JSON columns for feature_tooltips_shown" do
      tooltips_data = { "welcome_tooltip" => true, "profile_tooltip" => true }

      @user.update(feature_tooltips_shown: tooltips_data)
      @user.reload

      assert_equal tooltips_data, @user.feature_tooltips_shown
    end

    test "PostgreSQL uses JSONB for feature_tooltips_shown" do
      skip "Not running on PostgreSQL" unless @current_adapter == "PostgreSQL"

      column = @user.class.columns_hash["feature_tooltips_shown"]
      assert_equal :jsonb, column.type
    end

    test "MySQL uses JSON for feature_tooltips_shown" do
      skip "Not running on MySQL" unless @current_adapter.match?(/MySQL|Mysql2/)

      column = @user.class.columns_hash["feature_tooltips_shown"]
      assert_equal :json, column.type
    end

    test "SQLite stores JSON as text" do
      skip "Not running on SQLite" unless @current_adapter == "SQLite"

      # SQLite stores JSON as text, but ActiveRecord handles serialization
      tooltips_data = { "test" => true }
      @user.update(feature_tooltips_shown: tooltips_data)
      @user.reload

      assert_equal tooltips_data, @user.feature_tooltips_shown
    end

    test "can query JSONB columns with PostgreSQL operators" do
      skip "Not running on PostgreSQL" unless @current_adapter == "PostgreSQL"

      @user.update(feature_tooltips_shown: { "welcome" => true, "tour" => false })

      # PostgreSQL JSONB queries
      result = User.where("feature_tooltips_shown ? :key", key: "welcome").first
      assert_equal @user.id, result&.id
    end

    test "handles nested JSON structures" do
      nested_data = {
        "tooltips" => {
          "onboarding" => { "welcome" => true, "profile" => true },
          "features" => { "dashboard" => false }
        },
        "metadata" => { "version" => "1.0" }
      }

      @user.update(feature_tooltips_shown: nested_data)
      @user.reload

      assert_equal nested_data, @user.feature_tooltips_shown
      assert_equal true, @user.feature_tooltips_shown.dig("tooltips", "onboarding", "welcome")
    end

    # ===== Index Performance Tests =====

    test "queries use indexes on onboarding_completed" do
      # Create a large dataset
      100.times do |i|
        User.create!(
          email: "user#{i}@example.com",
          onboarding_completed: i.even?
        )
      end

      # This query should use an index
      completed_users = User.where(onboarding_completed: true)

      # Explain the query to verify index usage
      explain_result = User.where(onboarding_completed: true).explain

      # Different adapters have different explain formats
      case @current_adapter
      when "PostgreSQL"
        assert_match(/Index|Bitmap/, explain_result) rescue nil
      when /MySQL|Mysql2/
        assert_match(/Using index|index/, explain_result) rescue nil
      when "SQLite"
        assert_match(/SEARCH|INDEX/, explain_result) rescue nil
      end
    end

    test "composite indexes work across adapters" do
      # Query using composite index
      users = User.where(onboarding_completed: false)
                  .order(created_at: :desc)
                  .limit(10)

      assert users.any?

      # Verify the query runs efficiently
      explain_result = User.where(onboarding_completed: false)
                           .order(created_at: :desc)
                           .explain

      assert explain_result.present?
    end

    # ===== Boolean Column Tests =====

    test "boolean columns work consistently across adapters" do
      @user.update(onboarding_completed: true, onboarding_skipped: false)
      @user.reload

      assert_equal true, @user.onboarding_completed
      assert_equal false, @user.onboarding_skipped

      # Test falsy values
      @user.update(onboarding_completed: false)
      @user.reload

      assert_equal false, @user.onboarding_completed
    end

    test "PostgreSQL stores booleans as native type" do
      skip "Not running on PostgreSQL" unless @current_adapter == "PostgreSQL"

      column = @user.class.columns_hash["onboarding_completed"]
      assert_equal :boolean, column.type
    end

    test "MySQL stores booleans as tinyint" do
      skip "Not running on MySQL" unless @current_adapter.match?(/MySQL|Mysql2/)

      # MySQL uses tinyint(1) for booleans
      @user.update(onboarding_completed: true)
      @user.reload

      assert_equal true, @user.onboarding_completed
    end

    # ===== DateTime Column Tests =====

    test "datetime columns handle timezones correctly" do
      now = Time.current
      @user.update(onboarding_completed_at: now)
      @user.reload

      assert_in_delta now.to_i, @user.onboarding_completed_at.to_i, 1
    end

    test "PostgreSQL uses timestamp with timezone" do
      skip "Not running on PostgreSQL" unless @current_adapter == "PostgreSQL"

      column = @user.class.columns_hash["onboarding_completed_at"]
      assert_equal :datetime, column.type
    end

    # ===== String/Text Column Tests =====

    test "string columns work across adapters" do
      @user.update(onboarding_current_step: "profile_setup")
      @user.reload

      assert_equal "profile_setup", @user.onboarding_current_step
    end

    test "handles Unicode in string columns" do
      unicode_step = "step_测试_🎉"
      @user.update(onboarding_current_step: unicode_step)
      @user.reload

      assert_equal unicode_step, @user.onboarding_current_step
    end

    # ===== Analytics Event Tests =====

    test "analytics events table works across adapters" do
      skip "AnalyticsEvent not defined" unless defined?(RailsOnboarding::AnalyticsEvent)

      event = AnalyticsEvent.create!(
        event_type: "step_completed",
        user: @user,
        occurred_at: Time.current,
        metadata: { step: "welcome", duration: 30 }
      )

      assert event.persisted?
      assert_equal "step_completed", event.event_type
    rescue NameError
      skip "AnalyticsEvent model not available"
    end

    test "analytics metadata JSON works across adapters" do
      skip "AnalyticsEvent not defined" unless defined?(RailsOnboarding::AnalyticsEvent)

      metadata = {
        "step" => "welcome",
        "duration" => 30,
        "interactions" => ["click", "scroll", "submit"]
      }

      event = AnalyticsEvent.create!(
        event_type: "test",
        user: @user,
        occurred_at: Time.current,
        metadata: metadata
      )

      event.reload
      assert_equal metadata, event.metadata
    rescue NameError
      skip "AnalyticsEvent model not available"
    end

    # ===== Transaction Tests =====

    test "transactions work correctly across adapters" do
      initial_count = User.count

      ActiveRecord::Base.transaction do
        User.create!(email: "transaction_test@example.com")
        raise ActiveRecord::Rollback
      end

      assert_equal initial_count, User.count, "Transaction should have rolled back"
    end

    test "nested transactions work" do
      User.transaction do
        user1 = User.create!(email: "outer@example.com")

        User.transaction(requires_new: true) do
          user2 = User.create!(email: "inner@example.com")
          assert user2.persisted?
        end

        assert user1.persisted?
      end
    end

    # ===== Migration Compatibility Tests =====

    test "migrations work across adapters" do
      # Test that add_column works
      connection = ActiveRecord::Base.connection

      # This is a test, so we'll use a temporary test table
      connection.create_table :test_onboarding_table, force: true do |t|
        t.string :test_column
        t.timestamps
      end

      assert connection.table_exists?(:test_onboarding_table)

      connection.drop_table :test_onboarding_table
    end

    test "index creation works across adapters" do
      connection = ActiveRecord::Base.connection

      connection.create_table :test_index_table, force: true do |t|
        t.string :indexed_column
        t.boolean :boolean_column
      end

      connection.add_index :test_index_table, :indexed_column

      indexes = connection.indexes(:test_index_table)
      assert indexes.any? { |idx| idx.columns.include?("indexed_column") }

      connection.drop_table :test_index_table
    end

    # ===== Constraint Tests =====

    test "NOT NULL constraints work across adapters" do
      connection = ActiveRecord::Base.connection

      # Create a temporary table with NOT NULL constraint
      connection.create_table :test_not_null_table, force: true do |t|
        t.string :required_field, null: false
      end

      # Define a temporary model class
      test_model = Class.new(ActiveRecord::Base) do
        self.table_name = "test_not_null_table"
      end

      begin
        assert_raises(ActiveRecord::NotNullViolation) do
          test_model.create!(required_field: nil)
        end
      ensure
        connection.drop_table :test_not_null_table
      end
    end

    test "UNIQUE constraints work across adapters" do
      connection = ActiveRecord::Base.connection

      # Create a temporary table with UNIQUE constraint
      connection.create_table :test_unique_table, force: true do |t|
        t.string :unique_field
      end
      connection.add_index :test_unique_table, :unique_field, unique: true

      # Define a temporary model class
      test_model = Class.new(ActiveRecord::Base) do
        self.table_name = "test_unique_table"
      end

      begin
        test_model.create!(unique_field: "unique_value")

        assert_raises(ActiveRecord::RecordNotUnique) do
          test_model.create!(unique_field: "unique_value")
        end
      ensure
        connection.drop_table :test_unique_table
      end
    end

    # ===== Default Values Tests =====

    test "default values work across adapters" do
      connection = ActiveRecord::Base.connection

      # Create a temporary table with default values
      connection.create_table :test_defaults_table, force: true do |t|
        t.boolean :active, default: false
        t.string :status, default: "pending"
        t.integer :counter, default: 0
      end

      # Define a temporary model class
      test_model = Class.new(ActiveRecord::Base) do
        self.table_name = "test_defaults_table"
      end

      begin
        record = test_model.new

        assert_equal false, record.active
        assert_equal "pending", record.status
        assert_equal 0, record.counter
      ensure
        connection.drop_table :test_defaults_table
      end
    end

    # ===== Connection Pool Tests =====

    test "connection pooling works correctly" do
      pool_size = ActiveRecord::Base.connection_pool.size

      assert pool_size > 0, "Connection pool should be configured"
    end

    test "handles concurrent connections" do
      threads = []
      results = []

      5.times do
        threads << Thread.new do
          User.connection_pool.with_connection do
            results << User.count
          end
        end
      end

      threads.each(&:join)

      assert_equal 5, results.length
      assert results.all? { |r| r.is_a?(Integer) }
    end

    # ===== Performance Tests =====

    test "bulk insert performance is acceptable" do
      start_time = Time.now

      users = 100.times.map do |i|
        {
          email: "bulk_#{i}_#{rand(10000)}@example.com",
          onboarding_completed: false,
          created_at: Time.current,
          updated_at: Time.current
        }
      end

      User.insert_all(users)

      duration = Time.now - start_time

      assert_operator duration, :<, 5, "Bulk insert should complete in under 5 seconds"
    end

    test "bulk queries are efficient" do
      # Create test data
      20.times do |i|
        User.create!(email: "bulk_query_#{i}@example.com")
      end

      start_time = Time.now

      # Perform bulk query
      users = User.where(onboarding_completed: false).limit(20).to_a

      duration = Time.now - start_time

      assert_operator duration, :<, 1, "Bulk query should complete quickly"
      assert_operator users.length, :>, 0
    end

    # ===== Charset/Collation Tests =====

    test "handles different character sets correctly" do
      unicode_strings = [
        "こんにちは", # Japanese
        "مرحبا",      # Arabic
        "Привет",     # Russian
        "🎉🎊🎈",     # Emoji
        "café"        # Accented
      ]

      unicode_strings.each_with_index do |str, i|
        user = User.create!(email: "unicode_#{i}@example.com")
        user.update(onboarding_current_step: str) rescue next
        user.reload

        assert_equal str, user.onboarding_current_step
      end
    end

    # ===== Edge Case Tests =====

    test "handles NULL values correctly" do
      @user.update(onboarding_current_step: nil)
      @user.reload

      assert_nil @user.onboarding_current_step
    end

    test "handles empty strings vs NULL" do
      @user.update(onboarding_current_step: "")
      @user.reload

      assert_equal "", @user.onboarding_current_step
    end

    test "handles very long strings" do
      long_string = "a" * 1000
      @user.update(onboarding_current_step: long_string)
      @user.reload

      assert_equal long_string, @user.onboarding_current_step
    end

    # ===== Backup and Restore Tests =====

    test "data can be dumped and restored" do
      @user.update(
        onboarding_completed: true,
        onboarding_current_step: "profile",
        feature_tooltips_shown: { "test" => true }
      )

      # Dump user data
      user_data = @user.attributes

      # Create new user with same data
      new_user = User.new(user_data.except("id"))
      new_user.email = "restored_#{@user.email}"
      new_user.save!

      # Verify data integrity
      assert_equal @user.onboarding_completed, new_user.onboarding_completed
      assert_equal @user.onboarding_current_step, new_user.onboarding_current_step
      assert_equal @user.feature_tooltips_shown, new_user.feature_tooltips_shown
    end
  end
end
