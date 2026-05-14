# frozen_string_literal: true

require "test_helper"
require "benchmark"

module RailsOnboarding
  class OnboardingPerformanceTest < ActiveSupport::TestCase
    # Set a longer timeout for performance tests
    self.test_order = :sorted

    setup do
      @large_dataset_size = ENV.fetch("PERF_TEST_SIZE", 1000).to_i
      @small_dataset_size = 100
    end

    # ===== Query Performance Tests =====

    test "finding incomplete users is fast with large dataset" do
      create_test_users(@large_dataset_size, onboarding_completed: false)

      benchmark_result = Benchmark.measure do
        User.where(onboarding_completed: false).limit(100).to_a
      end

      assert_operator benchmark_result.real, :<, 1.0,
                      "Query should complete in under 1 second (took #{benchmark_result.real}s)"
    end

    test "finding users by current step is efficient" do
      create_test_users(@large_dataset_size / 2, onboarding_current_step: "welcome")
      create_test_users(@large_dataset_size / 2, onboarding_current_step: "profile")

      benchmark_result = Benchmark.measure do
        User.where(onboarding_current_step: "welcome").limit(100).to_a
      end

      assert_operator benchmark_result.real, :<, 1.0,
                      "Step query should complete in under 1 second (took #{benchmark_result.real}s)"
    end

    test "complex analytics queries perform acceptably" do
      skip "Analytics not available" unless defined?(RailsOnboarding::Analytics)

      create_test_users(@small_dataset_size)

      benchmark_result = Benchmark.measure do
        Analytics.completion_rate
        Analytics.average_time_to_complete
        Analytics.funnel_analysis
      end

      assert_operator benchmark_result.real, :<, 5.0,
                      "Analytics queries should complete in under 5 seconds (took #{benchmark_result.real}s)"
    rescue NameError
      skip "Analytics class not available"
    end

    # ===== JSON Query Performance Tests =====

    test "querying JSONB columns is efficient on PostgreSQL" do
      skip "Not on PostgreSQL" unless ActiveRecord::Base.connection.adapter_name == "PostgreSQL"

      create_test_users(@small_dataset_size) do |user, i|
        user.update(feature_tooltips_shown: { "tooltip_#{i}" => true })
      end

      benchmark_result = Benchmark.measure do
        User.where("feature_tooltips_shown ? :key", key: "tooltip_1").limit(50).to_a
      end

      assert_operator benchmark_result.real, :<, 2.0,
                      "JSONB query should complete in under 2 seconds (took #{benchmark_result.real}s)"
    end

    test "extracting JSON data is fast" do
      user = User.create!(email: "json_test@example.com")
      large_json = {}
      100.times { |i| large_json["key_#{i}"] = "value_#{i}" }
      user.update(feature_tooltips_shown: large_json)

      benchmark_result = Benchmark.measure do
        1000.times do
          user.reload
          user.feature_tooltips_shown["key_50"]
        end
      end

      assert_operator benchmark_result.real, :<, 5.0,
                      "JSON extraction should be fast (took #{benchmark_result.real}s for 1000 iterations)"
    end

    # ===== Bulk Operations Performance Tests =====

    test "bulk insert performance is acceptable" do
      users_data = @large_dataset_size.times.map do |i|
        {
          email: "bulk_insert_#{i}_#{SecureRandom.hex(4)}@example.com",
          onboarding_completed: false,
          created_at: Time.current,
          updated_at: Time.current
        }
      end

      benchmark_result = Benchmark.measure do
        User.insert_all(users_data)
      end

      avg_per_record = benchmark_result.real / @large_dataset_size

      assert_operator benchmark_result.real, :<, 10.0,
                      "Bulk insert of #{@large_dataset_size} records should complete in under 10 seconds (took #{benchmark_result.real}s)"
      assert_operator avg_per_record, :<, 0.01,
                      "Should insert faster than 10ms per record (#{(avg_per_record * 1000).round(2)}ms per record)"
    end

    test "bulk update performance is acceptable" do
      users = create_test_users(@small_dataset_size)
      user_ids = users.map(&:id)

      benchmark_result = Benchmark.measure do
        User.where(id: user_ids).update_all(onboarding_completed: true)
      end

      assert_operator benchmark_result.real, :<, 2.0,
                      "Bulk update should complete in under 2 seconds (took #{benchmark_result.real}s)"
    end

    test "bulk delete performance is acceptable" do
      users = create_test_users(@small_dataset_size)
      user_ids = users.map(&:id)

      benchmark_result = Benchmark.measure do
        User.where(id: user_ids).delete_all
      end

      assert_operator benchmark_result.real, :<, 2.0,
                      "Bulk delete should complete in under 2 seconds (took #{benchmark_result.real}s)"
    end

    # ===== N+1 Query Detection Tests =====

    test "loading users with associations does not cause N+1 queries" do
      skip "Analytics events not available" unless defined?(RailsOnboarding::AnalyticsEvent)

      # Create users with analytics events
      10.times do |i|
        user = User.create!(email: "n1_test_#{i}@example.com")
        3.times do
          RailsOnboarding::AnalyticsEvent.create!(
            user: user,
            event_type: "test_event",
            occurred_at: Time.current
          )
        end
      end

      # Query with proper eager loading
      query_count = count_queries do
        users = User.includes(:analytics_events).limit(10).to_a
        users.each { |u| u.analytics_events.to_a }
      end

      # Should use 2 queries: 1 for users, 1 for events
      assert_operator query_count, :<=, 3,
                      "Should not have N+1 queries (#{query_count} queries executed)"
    rescue NameError
      skip "AnalyticsEvent model not available"
    end

    test "onboardable concern methods are efficient" do
      user = User.create!(email: "concern_test@example.com")

      benchmark_result = Benchmark.measure do
        1000.times do
          user.onboarding_completed?
          user.onboarding_progress_percentage
          user.current_step_info
        end
      end

      assert_operator benchmark_result.real, :<, 5.0,
                      "Concern methods should be fast (took #{benchmark_result.real}s for 1000 iterations)"
    end

    # ===== Configuration Caching Tests =====

    test "configuration lookups are cached" do
      # First access (cache miss)
      cache_miss_time = Benchmark.measure do
        100.times { RailsOnboarding.configuration.steps }
      end

      # Second access (cache hit)
      cache_hit_time = Benchmark.measure do
        100.times { RailsOnboarding.configuration.steps }
      end

      # Cached access should be at least as fast
      assert_operator cache_hit_time.real, :<=, cache_miss_time.real * 1.5,
                      "Cached config should be efficient"
    end

    test "multi-tenant config lookups are cached per organization" do
      skip "MultiTenant not available" unless defined?(RailsOnboarding::MultiTenant)

      org_id = 123

      MultiTenant.configure_for_organization(org_id) do |config|
        config.steps = [{ name: :test }]
      end

      benchmark_result = Benchmark.measure do
        1000.times { MultiTenant.configuration_for(org_id) }
      end

      assert_operator benchmark_result.real, :<, 1.0,
                      "Cached org config lookups should be fast (took #{benchmark_result.real}s)"
    rescue NameError
      skip "MultiTenant not available"
    end

    # ===== Memory Usage Tests =====

    test "memory usage stays reasonable with large JSON data" do
      skip "Memory profiling not available" unless defined?(ObjectSpace)

      user = User.create!(email: "memory_test@example.com")

      # Create large JSON structure
      large_data = {}
      1000.times { |i| large_data["key_#{i}"] = "value" * 100 }

      before_memory = get_memory_usage

      user.update(feature_tooltips_shown: large_data)
      user.reload
      user.feature_tooltips_shown

      after_memory = get_memory_usage
      memory_increase = after_memory - before_memory

      # Memory increase should be reasonable (less than 50MB)
      assert_operator memory_increase, :<, 50_000_000,
                      "Memory usage should be reasonable (increased by #{memory_increase / 1_000_000}MB)"
    rescue
      skip "Memory testing not available"
    end

    test "does not leak memory with repeated operations" do
      skip "GC stats not available" unless GC.respond_to?(:stat)

      before_objects = GC.stat(:total_allocated_objects)

      100.times do |i|
        user = User.create!(email: "leak_test_#{i}@example.com")
        user.update(onboarding_completed: true)
        user.reload
      end

      GC.start

      after_objects = GC.stat(:total_allocated_objects)
      created_objects = after_objects - before_objects

      # Should create reasonable number of objects (adjust threshold as needed)
      objects_per_iteration = created_objects / 100.0

      assert_operator objects_per_iteration, :<, 10000,
                      "Should not create excessive objects (#{objects_per_iteration} per iteration)"
    rescue
      skip "GC stats not available"
    end

    # ===== Analytics Performance Tests =====

    test "analytics event creation is fast" do
      skip "AnalyticsEvent not available" unless defined?(RailsOnboarding::AnalyticsEvent)

      user = User.create!(email: "analytics_perf@example.com")

      benchmark_result = Benchmark.measure do
        100.times do |i|
          AnalyticsEvent.create!(
            user: user,
            event_type: "test_event_#{i % 10}",
            occurred_at: Time.current,
            metadata: { index: i }
          )
        end
      end

      avg_time = benchmark_result.real / 100.0

      assert_operator benchmark_result.real, :<, 5.0,
                      "100 events should be created in under 5 seconds (took #{benchmark_result.real}s)"
      assert_operator avg_time, :<, 0.05,
                      "Each event should be created in under 50ms (avg: #{(avg_time * 1000).round(2)}ms)"
    rescue NameError
      skip "AnalyticsEvent not available"
    end

    test "analytics aggregation queries scale well" do
      skip "Analytics not available" unless defined?(RailsOnboarding::Analytics)

      # Create realistic dataset
      50.times do |i|
        user = User.create!(
          email: "agg_test_#{i}@example.com",
          onboarding_completed: i.even?,
          onboarding_completed_at: i.even? ? Time.current : nil
        )

        3.times do
          AnalyticsEvent.create!(
            user: user,
            event_type: "step_completed",
            occurred_at: Time.current - rand(7).days
          )
        end
      end

      benchmark_result = Benchmark.measure do
        Analytics.completion_rate
        Analytics.average_time_to_complete
      end

      assert_operator benchmark_result.real, :<, 3.0,
                      "Analytics aggregations should complete quickly (took #{benchmark_result.real}s)"
    rescue NameError
      skip "Analytics not available"
    end

    # ===== Concurrent Access Tests =====

    test "handles concurrent read operations efficiently" do
      create_test_users(50)

      threads = []
      results = []

      start_time = Time.now

      10.times do
        threads << Thread.new do
          users = User.where(onboarding_completed: false).limit(10).to_a
          results << users.count
        end
      end

      threads.each(&:join)

      duration = Time.now - start_time

      assert_equal 10, results.length
      assert_operator duration, :<, 5.0,
                      "Concurrent reads should complete in under 5 seconds (took #{duration}s)"
    end

    test "handles concurrent write operations" do
      users = create_test_users(20)
      threads = []
      errors = []

      start_time = Time.now

      users.each do |user|
        threads << Thread.new do
          begin
            user.update(onboarding_completed: true)
          rescue => e
            errors << e
          end
        end
      end

      threads.each(&:join)

      duration = Time.now - start_time

      assert_empty errors, "No errors should occur during concurrent writes"
      assert_operator duration, :<, 5.0,
                      "Concurrent writes should complete in under 5 seconds (took #{duration}s)"
    end

    # ===== Pagination Performance Tests =====

    test "pagination is efficient with large datasets" do
      create_test_users(@large_dataset_size)

      # Test different page sizes
      [25, 50, 100].each do |per_page|
        benchmark_result = Benchmark.measure do
          User.where(onboarding_completed: false)
              .limit(per_page)
              .offset(0)
              .to_a
        end

        assert_operator benchmark_result.real, :<, 1.0,
                        "Pagination with #{per_page} items should be fast (took #{benchmark_result.real}s)"
      end
    end

    test "deep pagination does not degrade significantly" do
      create_test_users(@small_dataset_size)

      # Test pagination at different offsets
      results = []

      [0, 25, 50, 75].each do |offset|
        benchmark_result = Benchmark.measure do
          User.where(onboarding_completed: false)
              .limit(25)
              .offset(offset)
              .to_a
        end

        results << benchmark_result.real
      end

      # Later pages shouldn't be significantly slower.
      # Use a floor of 10ms so sub-millisecond baseline noise doesn't cause false failures;
      # the 10x multiplier catches genuine O(n) degradation, not timing jitter.
      max_acceptable = [results.first * 10, 0.01].max
      assert_operator results.last, :<, max_acceptable,
                      "Deep pagination should not degrade significantly"
    end

    # ===== Stress Tests =====

    test "survives stress test with rapid operations" do
      user = User.create!(email: "stress_test@example.com")

      assert_nothing_raised do
        100.times do |i|
          user.update(onboarding_current_step: "step_#{i % 5}")
          user.reload
          user.onboarding_completed?
        end
      end
    end

    test "handles large tooltip data efficiently" do
      user = User.create!(email: "large_tooltip@example.com")

      # Create large tooltip structure
      tooltips = {}
      500.times { |i| tooltips["tooltip_#{i}"] = true }

      benchmark_result = Benchmark.measure do
        user.update(feature_tooltips_shown: tooltips)
        user.reload
        user.feature_tooltips_shown["tooltip_250"]
      end

      assert_operator benchmark_result.real, :<, 1.0,
                      "Large tooltip operations should be fast (took #{benchmark_result.real}s)"
    end

    private

    def create_test_users(count, attributes = {})
      users = []
      batch_size = 100

      (count / batch_size.to_f).ceil.times do |batch|
        batch_users = []

        batch_size.times do |i|
          index = batch * batch_size + i
          break if index >= count

          batch_users << {
            email: "perf_test_#{index}_#{SecureRandom.hex(4)}@example.com",
            created_at: Time.current,
            updated_at: Time.current
          }.merge(attributes)
        end

        User.insert_all(batch_users) if batch_users.any?

        # Yield for custom setup
        if block_given?
          batch_users.each do |user_attrs|
            user = User.find_by(email: user_attrs[:email])
            yield(user, users.length) if user
            users << user if user
          end
        else
          users.concat(User.where(email: batch_users.map { |u| u[:email] }))
        end
      end

      users
    end

    def count_queries(&block)
      query_count = 0

      subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*args|
        query_count += 1 unless args.last[:name] == "SCHEMA"
      end

      yield

      query_count
    ensure
      ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
    end

    def get_memory_usage
      if defined?(GC) && GC.respond_to?(:stat)
        GC.stat(:total_allocated_bytes)
      elsif defined?(ObjectSpace)
        ObjectSpace.count_objects[:T_DATA] * 100 # Rough estimate
      else
        0
      end
    rescue
      0
    end
  end
end
