# Database Performance & Connection Pooling Guide

This guide provides recommendations for optimizing database performance and configuring connection pooling for RailsOnboarding in production environments.

## Table of Contents

- [Connection Pool Configuration](#connection-pool-configuration)
- [Recommended Pool Sizes](#recommended-pool-sizes)
- [Query Optimization](#query-optimization)
- [Monitoring & Metrics](#monitoring--metrics)
- [Troubleshooting](#troubleshooting)

## Connection Pool Configuration

### Basic Configuration

Configure your database connection pool in `config/database.yml`:

```yaml
production:
  adapter: postgresql
  pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>
  timeout: 5000
  # ... other settings
```

### Dynamic Pool Sizing

For applications with variable load, use environment-based configuration:

```yaml
production:
  pool: <%= ENV.fetch("DB_POOL_SIZE") { 10 } %>
  checkout_timeout: <%= ENV.fetch("DB_CHECKOUT_TIMEOUT") { 5 } %>
```

## Recommended Pool Sizes

### Small Applications (< 1,000 users)

**Web Server:**
- **Puma/Unicorn:** 5-10 connections per worker
- **Background Jobs:** 5 connections
- **Total:** ~25-50 connections

```yaml
# config/database.yml
production:
  pool: 10
  timeout: 5000
```

### Medium Applications (1,000 - 10,000 users)

**Web Server:**
- **Puma/Unicorn:** 10-15 connections per worker
- **Background Jobs:** 10-20 connections
- **Total:** ~50-100 connections

```yaml
production:
  pool: 15
  timeout: 5000
  reaping_frequency: 10  # seconds
```

**Background Job Configuration:**

```ruby
# config/initializers/sidekiq.rb
Sidekiq.configure_server do |config|
  config.redis = { size: 15 }

  # Database connection pool should match or exceed concurrency
  config.on(:startup) do
    ActiveRecord::Base.connection_pool.disconnect!
    ActiveRecord::Base.establish_connection(
      ActiveRecord::Base.configurations[Rails.env].merge(pool: 20)
    )
  end
end
```

### Large Applications (10,000 - 100,000 users)

**Web Server:**
- **Puma/Unicorn:** 15-25 connections per worker
- **Background Jobs:** 25-50 connections
- **Total:** ~100-250 connections

```yaml
production:
  pool: 25
  timeout: 5000
  reaping_frequency: 10
  idle_timeout: 300  # Close idle connections after 5 minutes
```

### Enterprise Applications (> 100,000 users)

**Web Server:**
- **Puma/Unicorn:** 25-50 connections per worker
- **Background Jobs:** 50-100 connections
- **Analytics Processing:** 20-50 connections
- **Total:** ~250-500+ connections

```yaml
production:
  pool: 50
  timeout: 5000
  reaping_frequency: 10
  idle_timeout: 300
  statement_limit: 1000  # Close connections after 1000 statements
```

**Consider using PgBouncer for connection pooling at the database level:**

```yaml
# config/database.yml with PgBouncer
production:
  adapter: postgresql
  host: pgbouncer_host
  port: 6432
  pool: 25  # Smaller pool since PgBouncer handles pooling
  timeout: 5000
```

## Query Optimization

### Analytics Queries

RailsOnboarding uses batching to prevent memory issues when processing large datasets:

```ruby
# Automatic batching in analytics queries
RailsOnboarding::Analytics.onboarding_completion_rate(
  date_range: 30.days.ago..Time.current
)
# Processes events in batches of 1,000 (configurable)
```

**Custom Batch Size:**

```ruby
# Modify the batch size for your specific needs
RailsOnboarding::Analytics::DEFAULT_PAGE_SIZE = 500  # Smaller batches
RailsOnboarding::Analytics::MAX_PAGE_SIZE = 5000    # Lower maximum
```

### Indexes

Ensure proper indexes are in place for optimal query performance:

```ruby
# db/migrate/XXXXXX_add_rails_onboarding_indexes.rb
class AddRailsOnboardingIndexes < ActiveRecord::Migration[7.0]
  def change
    # Composite index for analytics queries
    add_index :rails_onboarding_analytics_events,
              [:event_type, :occurred_at],
              name: 'index_analytics_events_on_type_and_time'

    # Index for user lookups
    add_index :rails_onboarding_analytics_events,
              [:user_type, :user_id],
              name: 'index_analytics_events_on_user'

    # Index for session tracking
    add_index :rails_onboarding_analytics_events,
              :session_id,
              where: "session_id IS NOT NULL",
              name: 'index_analytics_events_on_session_id'

    # Partial index for recent events (PostgreSQL)
    add_index :rails_onboarding_analytics_events,
              :occurred_at,
              where: "occurred_at > NOW() - INTERVAL '90 days'",
              name: 'index_analytics_events_on_recent_occurred_at'
  end
end
```

### Eager Loading

Prevent N+1 queries when loading analytics with users:

```ruby
# Automatically eager loads users
events = RailsOnboarding::AnalyticsEvent
  .with_user
  .by_date_range(start_date, end_date)
  .by_event_type('onboarding_completed')
```

### JSON Field Size Limits

RailsOnboarding automatically enforces size limits on JSON fields to prevent memory issues:

```ruby
# Configured limits (adjustable if needed)
RailsOnboarding::Onboardable::MAX_TOOLTIPS_SHOWN = 1000
RailsOnboarding::Onboardable::MAX_MILESTONES_ACHIEVED = 500
RailsOnboarding::Onboardable::MAX_JSON_SIZE_BYTES = 65_535 # ~64KB
```

## Monitoring & Metrics

### Database Connection Monitoring

Monitor your connection pool health:

```ruby
# config/initializers/database_monitoring.rb
ActiveSupport::Notifications.subscribe('checkout.active_record') do |*args|
  event = ActiveSupport::Notifications::Event.new(*args)

  if event.duration > 1000 # ms
    Rails.logger.warn "Slow DB checkout: #{event.duration}ms"
  end
end

# Check pool status
def pool_status
  pool = ActiveRecord::Base.connection_pool
  {
    size: pool.size,
    connections: pool.connections.size,
    active_connections: pool.connections.count(&:in_use?),
    waiting_in_queue: pool.num_waiting_in_queue
  }
end
```

### Key Metrics to Track

1. **Connection Pool Saturation**
   - Active connections / Pool size
   - Alert when > 80%

2. **Query Duration**
   - Analytics queries should complete in < 5 seconds
   - Batch processing should complete in < 30 seconds

3. **Slow Queries**
   - Log queries > 1 second
   - Review and optimize regularly

4. **Memory Usage**
   - Monitor Rails process memory
   - Alert when > 1GB per process

### APM Integration

```ruby
# config/initializers/rails_onboarding.rb
RailsOnboarding.configure do |config|
  # Enable analytics for monitoring
  config.enable_analytics = true

  # Set data retention to manage database size
  config.analytics_data_retention_days = 90
end
```

## Troubleshooting

### Connection Pool Timeout Errors

**Symptom:** `ActiveRecord::ConnectionTimeoutError: could not obtain a database connection within 5.000 seconds`

**Solutions:**

1. **Increase pool size:**
   ```yaml
   production:
     pool: <%= ENV.fetch("DB_POOL_SIZE") { 20 } %>
   ```

2. **Increase timeout:**
   ```yaml
   production:
     timeout: 10000  # 10 seconds
   ```

3. **Enable connection reaping:**
   ```yaml
   production:
     reaping_frequency: 10  # Check for stale connections every 10s
   ```

4. **Check for connection leaks:**
   ```ruby
   # Find long-running connections
   ActiveRecord::Base.connection.execute(
     "SELECT * FROM pg_stat_activity WHERE state = 'active'"
   )
   ```

### Slow Analytics Queries

**Symptom:** Analytics queries taking > 10 seconds

**Solutions:**

1. **Reduce date range:**
   ```ruby
   # Instead of analyzing all time
   Analytics.onboarding_completion_rate(date_range: 30.days.ago..Time.current)
   ```

2. **Archive old data:**
   ```ruby
   # Run regularly via cron job
   rake rails_onboarding:analytics:cleanup[180]  # Keep last 180 days
   ```

3. **Add database indexes:**
   - See [Indexes](#indexes) section above

4. **Use read replicas for analytics:**
   ```ruby
   # config/database.yml
   production:
     primary:
       # ... primary database config
     analytics:
       replica: true
       # ... read replica config

   # Use replica for analytics
   RailsOnboarding::AnalyticsEvent.connected_to(role: :analytics) do
     Analytics.onboarding_completion_rate
   end
   ```

### Memory Issues

**Symptom:** High memory usage or OOM errors

**Solutions:**

1. **Verify batch processing is enabled:**
   - RailsOnboarding uses `find_each` with configurable batch sizes
   - Default: 1,000 records per batch

2. **Reduce batch size for constrained environments:**
   ```ruby
   # In an initializer
   module RailsOnboarding
     class Analytics
       DEFAULT_PAGE_SIZE = 500  # Smaller batches
     end
   end
   ```

3. **Clean up old analytics data:**
   ```bash
   # Keep only last 90 days
   rails rails_onboarding:analytics:cleanup[90]
   ```

4. **Monitor JSON field sizes:**
   - Automatic validation prevents fields from exceeding 64KB
   - Automatic trimming keeps tooltip history under control

### Database Size Growth

**Symptom:** Database growing too large

**Solutions:**

1. **Configure data retention:**
   ```ruby
   RailsOnboarding.configure do |config|
     config.analytics_data_retention_days = 90
   end
   ```

2. **Set up automated cleanup:**
   ```ruby
   # config/schedule.rb (with whenever gem)
   every 1.day, at: '2:00 am' do
     rake 'rails_onboarding:analytics:cleanup'
   end
   ```

3. **Archive to external storage:**
   ```ruby
   # Export before cleanup
   rake rails_onboarding:analytics:export[90,180]  # Export 90-180 day old data
   rake rails_onboarding:analytics:cleanup[90]     # Then cleanup
   ```

## Performance Checklist

- [ ] Database connection pool sized appropriately for load
- [ ] Connection timeout configured (5-10 seconds)
- [ ] Connection reaping enabled for long-running apps
- [ ] All recommended indexes in place
- [ ] Analytics data retention configured
- [ ] Regular cleanup job scheduled
- [ ] Monitoring in place for pool saturation
- [ ] Slow query logging enabled
- [ ] Memory usage monitored
- [ ] Batch processing verified for large datasets

## Additional Resources

- [PostgreSQL Connection Pooling](https://www.postgresql.org/docs/current/runtime-config-connection.html)
- [Rails Database Best Practices](https://guides.rubyonrails.org/configuring.html#configuring-a-database)
- [PgBouncer Documentation](https://www.pgbouncer.org/)
- [Sidekiq Best Practices](https://github.com/mperham/sidekiq/wiki/Best-Practices)

## Support

For performance-related issues specific to RailsOnboarding:
- Check existing [GitHub Issues](https://github.com/yourusername/rails_onboarding/issues)
- Review the [Performance Guide](PERFORMANCE_GUIDE.md)
- Consult the [Analytics Guide](ANALYTICS_GUIDE.md)
