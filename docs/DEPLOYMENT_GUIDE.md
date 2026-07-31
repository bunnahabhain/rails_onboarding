# Deployment Guide

This guide covers production deployment best practices, configuration, and troubleshooting for Rails Onboarding.

## Table of Contents

- [Pre-Deployment Checklist](#pre-deployment-checklist)
- [Environment Configuration](#environment-configuration)
- [Database Setup](#database-setup)
- [Asset Pipeline](#asset-pipeline)
- [Performance Optimization](#performance-optimization)
- [Security Hardening](#security-hardening)
- [Monitoring & Logging](#monitoring--logging)
- [Platform-Specific Guides](#platform-specific-guides)
- [Troubleshooting](#troubleshooting)

## Pre-Deployment Checklist

Before deploying to production, verify:

### Required Components

- [ ] Rails >= 8.0.0
- [ ] Ruby >= 3.4.9
- [ ] Database with JSON/JSONB support (PostgreSQL recommended)
- [ ] Redis (optional, for caching and background jobs)
- [ ] SSL certificate for HTTPS

### Configuration

- [ ] Environment variables set (see [Environment Configuration](#environment-configuration))
- [ ] Database migrations run
- [ ] Assets precompiled
- [ ] Onboarding steps configured

### Testing

- [ ] All tests passing
- [ ] Manual testing in staging environment
- [ ] Load testing completed
- [ ] Security audit performed

### Documentation

- [ ] Team trained on onboarding features
- [ ] Monitoring alerts configured
- [ ] Rollback plan documented

## Environment Configuration

### Required Environment Variables

```bash
# config/application.yml or .env

# Rails Configuration
SECRET_KEY_BASE=your_secret_key_here
RAILS_ENV=production

# Database
DATABASE_URL=postgresql://user:password@localhost/myapp_production

# Redis (optional, for caching)
REDIS_URL=redis://localhost:6379/0

# Email (for notifications)
SMTP_ADDRESS=smtp.gmail.com
SMTP_PORT=587
SMTP_DOMAIN=yourdomain.com
SMTP_USERNAME=your_email@yourdomain.com
SMTP_PASSWORD=your_email_password

# Background Jobs (optional)
SIDEKIQ_CONCURRENCY=10

# Asset Host (optional, for CDN)
ASSET_HOST=https://cdn.yourdomain.com

# Analytics (optional)
GOOGLE_ANALYTICS_ID=UA-XXXXXXXXX-X
```

### Setting Environment Variables

**Heroku:**
```bash
heroku config:set SECRET_KEY_BASE=your_secret_key
```

**AWS Elastic Beanstalk:**
```bash
eb setenv SECRET_KEY_BASE=your_secret_key
```

**Docker:**
```bash
# docker-compose.yml
environment:
  - SECRET_KEY_BASE=your_secret_key
```

**systemd (Linux):**
```bash
# /etc/systemd/system/your-app.service
Environment="SECRET_KEY_BASE=your_secret_key"
```

### Rails Configuration

```ruby
# config/environments/production.rb
Rails.application.configure do
  # Force all access to the app over SSL
  config.force_ssl = true

  # Asset compilation
  config.assets.compile = false
  config.assets.digest = true

  # Logging
  config.log_level = :info
  config.log_tags = [:request_id]

  # Caching
  config.cache_store = :redis_cache_store, { url: ENV['REDIS_URL'] }
  config.action_controller.perform_caching = true

  # File storage (if using ActiveStorage)
  config.active_storage.service = :amazon

  # Email
  config.action_mailer.delivery_method = :smtp
  config.action_mailer.smtp_settings = {
    address: ENV['SMTP_ADDRESS'],
    port: ENV['SMTP_PORT'],
    domain: ENV['SMTP_DOMAIN'],
    user_name: ENV['SMTP_USERNAME'],
    password: ENV['SMTP_PASSWORD'],
    authentication: 'plain',
    enable_starttls_auto: true
  }
end
```

### Rails Onboarding Configuration

```ruby
# config/initializers/rails_onboarding.rb
RailsOnboarding.configure do |config|
  # Core settings
  config.user_class_name = 'User'

  # Onboarding steps
  config.steps = [
    { name: :welcome, title: 'Welcome', icon: '🎉', skippable: true },
    { name: :profile, title: 'Setup Profile', icon: '👤', skippable: false },
    { name: :first_action, title: 'First Action', icon: '🚀', skippable: false },
    { name: :explore, title: 'Explore Features', icon: '🔍', skippable: true }
  ]

  # Redirects
  config.redirect_after_completion = :dashboard_path
  config.redirect_after_skip = :dashboard_path

  # Features
  config.enable_tooltips = true
  config.enable_milestones = true
  config.enable_analytics = true

  # Caching (production only)
  config.cache_configuration = Rails.env.production?
  config.cache_ttl = 1.hour

  # Background jobs
  config.send_emails_async = true

  # API mode (if needed)
  config.api_mode = ENV['API_MODE'] == 'true'

  # Rate limiting
  config.enable_rate_limiting = true
  config.rate_limit = { limit: 100, period: 1.hour }

  # Analytics retention
  config.analytics_retention_days = 90
end
```

## Database Setup

### PostgreSQL (Recommended)

PostgreSQL provides JSONB support for efficient JSON storage and querying.

**Installation:**
```bash
# Ubuntu/Debian
sudo apt-get install postgresql postgresql-contrib

# macOS
brew install postgresql
```

**Configuration:**
```bash
# Create database
createdb myapp_production

# Run migrations
RAILS_ENV=production bundle exec rails db:migrate
```

**Recommended Settings:**
```sql
-- Increase work_mem for complex queries
ALTER SYSTEM SET work_mem = '256MB';

-- Enable parallel query execution
ALTER SYSTEM SET max_parallel_workers_per_gather = 4;

-- Restart PostgreSQL
sudo systemctl restart postgresql
```

### Database Indexes

Ensure critical indexes are in place:

```ruby
# db/migrate/XXXXXX_add_onboarding_indexes.rb
class AddOnboardingIndexes < ActiveRecord::Migration[7.0]
  def change
    # User indexes
    add_index :users, :onboarding_completed unless index_exists?(:users, :onboarding_completed)
    add_index :users, :onboarding_current_step unless index_exists?(:users, :onboarding_current_step)
    add_index :users, :onboarding_points unless index_exists?(:users, :onboarding_points)

    # Analytics indexes
    add_index :rails_onboarding_analytics_events, :event_type unless index_exists?(:rails_onboarding_analytics_events, :event_type)
    add_index :rails_onboarding_analytics_events, :event_name unless index_exists?(:rails_onboarding_analytics_events, :event_name)
    add_index :rails_onboarding_analytics_events, :created_at unless index_exists?(:rails_onboarding_analytics_events, :created_at)
    add_index :rails_onboarding_analytics_events, :session_id unless index_exists?(:rails_onboarding_analytics_events, :session_id)

    # Composite indexes for common queries
    add_index :rails_onboarding_analytics_events, [:user_id, :event_type] unless index_exists?(:rails_onboarding_analytics_events, [:user_id, :event_type])
    add_index :rails_onboarding_analytics_events, [:event_name, :created_at] unless index_exists?(:rails_onboarding_analytics_events, [:event_name, :created_at])
  end
end
```

### Database Backups

**Automated Backups:**
```bash
# Set up daily backups
# /etc/cron.daily/backup-database
#!/bin/bash
BACKUP_DIR="/var/backups/postgresql"
DATE=$(date +%Y%m%d_%H%M%S)

pg_dump myapp_production | gzip > $BACKUP_DIR/myapp_$DATE.sql.gz

# Keep only last 30 days
find $BACKUP_DIR -name "myapp_*.sql.gz" -mtime +30 -delete
```

**Using pgbackups (Heroku):**
```bash
heroku pg:backups:schedule DATABASE_URL --at '02:00 America/Los_Angeles'
heroku pg:backups:capture
heroku pg:backups:download
```

## Asset Pipeline

### Precompiling Assets

**Before Deployment:**
```bash
RAILS_ENV=production bundle exec rails assets:precompile
```

**Automated Deployment:**
```ruby
# config/deploy.rb (Capistrano)
namespace :deploy do
  task :compile_assets do
    on roles(:app) do
      within release_path do
        execute :bundle, :exec, :rails, 'assets:precompile'
      end
    end
  end
end

after 'deploy:updated', 'deploy:compile_assets'
```

### CDN Configuration

**CloudFront (AWS):**
```ruby
# config/environments/production.rb
config.asset_host = ENV['ASSET_HOST'] # https://d1234567890.cloudfront.net
```

**Cloudflare:**
```ruby
# config/environments/production.rb
config.action_controller.asset_host = Proc.new { |source|
  if source.starts_with?('/assets/')
    "https://cdn.yourdomain.com"
  else
    "https://yourdomain.com"
  end
}
```

### Importmap (Rails 7+)

If using importmap:

```ruby
# config/importmap.rb
pin "application", preload: true
pin "@hotwired/turbo-rails", to: "turbo.min.js", preload: true
pin "@hotwired/stimulus", to: "stimulus.min.js", preload: true
pin_all_from "app/javascript/controllers", under: "controllers"

# Rails Onboarding
pin_all_from "rails_onboarding/javascripts", under: "rails_onboarding"
```

## Performance Optimization

### Caching Strategy

**Fragment Caching:**
```erb
<!-- app/views/rails_onboarding/onboarding/show.html.erb -->
<% cache(['onboarding', current_user, current_user.onboarding_current_step], expires_in: 1.hour) do %>
  <%= render 'progress_indicator' %>
<% end %>
```

**Configuration Caching:**
```ruby
# config/initializers/rails_onboarding.rb
RailsOnboarding.configure do |config|
  config.cache_configuration = true
  config.cache_ttl = 1.hour
end
```

**Query Caching:**
```ruby
# app/models/user.rb
class User < ApplicationRecord
  include RailsOnboarding::Onboardable

  def onboarding_status
    Rails.cache.fetch("user_#{id}_onboarding_status", expires_in: 5.minutes) do
      {
        completed: onboarding_completed?,
        current_step: onboarding_current_step,
        progress: onboarding_progress_percentage
      }
    end
  end
end
```

### Database Connection Pooling

```ruby
# config/database.yml
production:
  <<: *default
  database: myapp_production
  pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>
  timeout: 5000
  # Increase pool size for high traffic
  # pool: 25
```

### Background Jobs

**Sidekiq Configuration:**
```ruby
# config/sidekiq.yml
production:
  :concurrency: 10
  :queues:
    - [critical, 2]
    - [default, 1]
    - [low, 1]
```

### HTTP/2 and Asset Optimization

**Enable HTTP/2 (Nginx):**
```nginx
server {
  listen 443 ssl http2;
  server_name yourdomain.com;

  # SSL configuration
  ssl_certificate /path/to/cert.pem;
  ssl_certificate_key /path/to/key.pem;

  # Gzip compression
  gzip on;
  gzip_types text/css application/javascript application/json;

  # Cache static assets
  location ~* \.(js|css|png|jpg|jpeg|gif|svg|woff|woff2)$ {
    expires 1y;
    add_header Cache-Control "public, immutable";
  }
}
```

## Security Hardening

### SSL/TLS Configuration

**Force SSL:**
```ruby
# config/environments/production.rb
config.force_ssl = true
config.ssl_options = {
  hsts: { expires: 1.year, subdomains: true, preload: true }
}
```

**SSL Certificate:**
```bash
# Let's Encrypt (free)
sudo certbot --nginx -d yourdomain.com
```

### Content Security Policy

```ruby
# config/initializers/content_security_policy.rb
Rails.application.config.content_security_policy do |policy|
  policy.default_src :self
  policy.font_src    :self, :data
  policy.img_src     :self, :data, :https
  policy.object_src  :none
  policy.script_src  :self
  policy.style_src   :self

  # Allow inline scripts for Stimulus
  policy.script_src :self, :unsafe_inline if Rails.env.development?
end
```

### Rate Limiting

```ruby
# Gemfile
gem 'rack-attack'

# config/initializers/rack_attack.rb
class Rack::Attack
  # Throttle onboarding endpoints
  throttle('onboarding/ip', limit: 20, period: 1.minute) do |req|
    req.ip if req.path.start_with?('/onboarding')
  end

  # Throttle API endpoints
  throttle('api/token', limit: 100, period: 1.hour) do |req|
    if req.path.start_with?('/api/')
      req.env['HTTP_AUTHORIZATION']&.split(' ')&.last
    end
  end

end
```

### Secrets Management

**Rails Credentials:**
```bash
# Edit encrypted credentials
EDITOR=vim rails credentials:edit --environment production
```

```yaml
# config/credentials/production.yml.enc
smtp_password: xyz789...
```

```ruby
# Access in code
Rails.application.credentials.smtp_password
```

**Vault (HashiCorp):**
```ruby
# config/initializers/vault.rb
require 'vault'

Vault.configure do |config|
  config.address = ENV['VAULT_ADDR']
  config.token = ENV['VAULT_TOKEN']
end

# Fetch secrets
smtp_password = Vault.logical.read('secret/data/rails_onboarding')
  .data[:data][:smtp_password]
```

## Monitoring & Logging

### Application Performance Monitoring (APM)

**New Relic:**
```ruby
# Gemfile
gem 'newrelic_rpm'

# config/newrelic.yml
production:
  license_key: <%= ENV['NEW_RELIC_LICENSE_KEY'] %>
  app_name: My Rails App
  monitor_mode: true
```

**Datadog:**
```ruby
# Gemfile
gem 'ddtrace'

# config/initializers/datadog.rb
Datadog.configure do |c|
  c.service = 'rails-app'
  c.env = 'production'
  c.version = '0.1.0'
end
```

**Scout APM:**
```ruby
# Gemfile
gem 'scout_apm'

# config/scout_apm.yml
production:
  key: <%= ENV['SCOUT_KEY'] %>
  name: My Rails App
  monitor: true
```

### Error Tracking

**Sentry:**
```ruby
# Gemfile
gem 'sentry-ruby'
gem 'sentry-rails'

# config/initializers/sentry.rb
Sentry.init do |config|
  config.dsn = ENV['SENTRY_DSN']
  config.breadcrumbs_logger = [:active_support_logger, :http_logger]
  config.traces_sample_rate = 0.1
  config.environment = Rails.env
end
```

**Rollbar:**
```ruby
# Gemfile
gem 'rollbar'

# config/initializers/rollbar.rb
Rollbar.configure do |config|
  config.access_token = ENV['ROLLBAR_ACCESS_TOKEN']
  config.environment = Rails.env
end
```

### Logging

**Structured Logging:**
```ruby
# config/initializers/lograge.rb
Rails.application.configure do
  config.lograge.enabled = true
  config.lograge.formatter = Lograge::Formatters::Json.new

  config.lograge.custom_options = lambda do |event|
    {
      user_id: event.payload[:user_id],
      request_id: event.payload[:request_id],
      ip: event.payload[:ip]
    }
  end
end
```

**CloudWatch Logs (AWS):**
```ruby
# Gemfile
gem 'aws-sdk-cloudwatchlogs'

# config/initializers/cloudwatch_logger.rb
require 'aws-sdk-cloudwatchlogs'

if Rails.env.production?
  Rails.logger = ActiveSupport::Logger.new(
    CloudWatchLogger.new(
      ENV['AWS_CLOUDWATCH_LOG_GROUP'],
      ENV['AWS_CLOUDWATCH_LOG_STREAM']
    )
  )
end
```

### Analytics Monitoring

**Track Onboarding Metrics:**
```ruby
# config/initializers/rails_onboarding.rb
RailsOnboarding.configure do |config|
  config.enable_analytics = true
  config.analytics_retention_days = 90
end

# Set up automated reporting
# config/schedule.rb (whenever gem)
every 1.day, at: '9:00 am' do
  rake 'rails_onboarding:analytics:daily_summary'
end
```

**Monitor Key Metrics:**
```ruby
# app/jobs/onboarding_metrics_job.rb
class OnboardingMetricsJob < ApplicationJob
  def perform
    completion_rate = RailsOnboarding::Analytics.completion_rate(since: 1.week.ago)
    average_time = RailsOnboarding::Analytics.average_completion_time

    # Send to monitoring service
    StatsD.gauge('onboarding.completion_rate', completion_rate)
    StatsD.gauge('onboarding.average_time', average_time)

    # Alert if below threshold
    if completion_rate < 0.7
      AdminMailer.low_completion_rate(completion_rate).deliver_now
    end
  end
end
```

## Platform-Specific Guides

### Heroku

**Deployment:**
```bash
# Add Heroku remote
heroku git:remote -a your-app-name

# Set environment variables
heroku config:set RAILS_ENV=production
heroku config:set SECRET_KEY_BASE=$(ruby -rsecurerandom -e 'puts SecureRandom.hex(64)')

# Add PostgreSQL
heroku addons:create heroku-postgresql:standard-0

# Add Redis
heroku addons:create heroku-redis:premium-0

# Deploy
git push heroku main

# Run migrations
heroku run rails db:migrate

# Scale workers (for Sidekiq)
heroku ps:scale worker=1
```

**Procfile:**
```
web: bundle exec puma -C config/puma.rb
worker: bundle exec sidekiq -C config/sidekiq.yml
```

### AWS Elastic Beanstalk

**Configuration:**
```yaml
# .ebextensions/01_packages.config
packages:
  yum:
    postgresql-devel: []
    nodejs: []

# .ebextensions/02_rails.config
commands:
  01_migrate:
    command: "bundle exec rails db:migrate"
    leader_only: true
  02_assets:
    command: "bundle exec rails assets:precompile"
    leader_only: true
```

**Deployment:**
```bash
# Initialize EB
eb init -p ruby-3.2 your-app-name

# Create environment
eb create production

# Deploy
eb deploy

# Set environment variables
eb setenv RAILS_ENV=production SECRET_KEY_BASE=your_secret_key_base
```

### Docker

**Dockerfile:**

```dockerfile
FROM ruby:3.4

RUN apt-get update -qq && apt-get install -y nodejs postgresql-client

WORKDIR /app

COPY ../Gemfile Gemfile.lock ./
RUN bundle install

COPY .. .

# Precompile assets
RUN RAILS_ENV=production bundle exec rails assets:precompile

EXPOSE 3000

CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]
```

**docker-compose.yml:**
```yaml
version: '3.8'

services:
  db:
    image: postgres:15
    environment:
      POSTGRES_PASSWORD: password
    volumes:
      - postgres_data:/var/lib/postgresql/data

  redis:
    image: redis:7

  web:
    build: .
    command: bundle exec puma -C config/puma.rb
    volumes:
      - .:/app
    ports:
      - "3000:3000"
    depends_on:
      - db
      - redis
    environment:
      DATABASE_URL: postgresql://postgres:password@db/myapp_production
      REDIS_URL: redis://redis:6379/0

  worker:
    build: .
    command: bundle exec sidekiq
    depends_on:
      - db
      - redis
    environment:
      DATABASE_URL: postgresql://postgres:password@db/myapp_production
      REDIS_URL: redis://redis:6379/0

volumes:
  postgres_data:
```

### Kubernetes

**Deployment manifest:**
```yaml
# k8s/deployment.yml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: rails-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: rails-app
  template:
    metadata:
      labels:
        app: rails-app
    spec:
      containers:
      - name: web
        image: your-registry/rails-app:latest
        ports:
        - containerPort: 3000
        env:
        - name: RAILS_ENV
          value: "production"
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: rails-secrets
              key: database-url
        - name: REDIS_URL
          valueFrom:
            secretKeyRef:
              name: rails-secrets
              key: redis-url
```

## Troubleshooting

### Assets Not Loading

**Symptoms:**
- Broken styles
- JavaScript not working

**Solutions:**
```bash
# Recompile assets
RAILS_ENV=production bundle exec rails assets:clobber
RAILS_ENV=production bundle exec rails assets:precompile

# Check asset paths
rails c production
>> Rails.application.config.asset_host
>> ActionController::Base.helpers.asset_path('application.css')
```

### Database Connection Issues

**Symptoms:**
- ActiveRecord::ConnectionTimeoutError
- Too many open connections

**Solutions:**
```ruby
# Increase connection pool
# config/database.yml
production:
  pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 25 } %>

# Check active connections
rails c production
>> ActiveRecord::Base.connection_pool.stat
```

### Memory Issues

**Symptoms:**
- Out of memory errors
- Slow response times

**Solutions:**
```ruby
# Add memory limits (Puma)
# config/puma.rb
preload_app!

on_worker_boot do
  ActiveRecord::Base.establish_connection
end

before_fork do
  ActiveRecord::Base.connection_pool.disconnect!
end

# Monitor memory usage
# config/initializers/memory_profiler.rb
if ENV['ENABLE_MEMORY_PROFILER']
  require 'memory_profiler'
end
```

## Additional Resources

- [Performance Guide](PERFORMANCE_GUIDE.md)
- [Troubleshooting Guide](TROUBLESHOOTING.md)

## Support

For deployment issues:
- Review application logs
- Check [Troubleshooting Guide](TROUBLESHOOTING.md)
- Open an issue on GitHub with deployment details
