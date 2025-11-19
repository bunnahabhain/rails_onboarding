# Upgrade Guide

This guide helps you upgrade Rails Onboarding between versions, documenting breaking changes and migration paths.

## Table of Contents

- [General Upgrade Process](#general-upgrade-process)
- [Version-Specific Upgrades](#version-specific-upgrades)
- [Breaking Changes](#breaking-changes)
- [Database Migrations](#database-migrations)
- [Configuration Changes](#configuration-changes)
- [Testing Your Upgrade](#testing-your-upgrade)

## General Upgrade Process

Follow these steps when upgrading Rails Onboarding:

### 1. Review the CHANGELOG

Always read the [CHANGELOG](CHANGELOG.md) before upgrading to understand what has changed.

### 2. Update the Gem Version

Update your Gemfile:

```ruby
# Gemfile
gem 'rails_onboarding', '~> X.X.X'
```

Then run:

```bash
bundle update rails_onboarding
```

### 3. Run New Migrations

Check for new migrations:

```bash
bundle exec rails rails_onboarding:install:migrations
bundle exec rails db:migrate
```

### 4. Update Configuration

Review your configuration file and update with any new options:

```ruby
# config/initializers/rails_onboarding.rb
RailsOnboarding.configure do |config|
  # Review CHANGELOG for new configuration options
end
```

### 5. Update Assets (if using Asset Pipeline)

If you're using Sprockets/Asset Pipeline:

```bash
bundle exec rails assets:precompile
```

### 6. Test Thoroughly

Run your test suite and manually test onboarding flows:

```bash
bundle exec rails test
```

## Version-Specific Upgrades

### Upgrading to 0.1.0 (Initial Release)

Version 0.1.0 is the initial release. If you're upgrading from a development version:

#### Database Changes

Run all migrations:

```bash
bundle exec rails rails_onboarding:install:migrations
bundle exec rails db:migrate
```

Required columns on User model:
- `onboarding_completed` (boolean)
- `onboarding_completed_at` (datetime)
- `onboarding_current_step` (string)
- `onboarding_skipped` (boolean)
- `feature_tooltips_shown` (jsonb/text)
- `milestones_achieved` (jsonb/text)

#### Configuration Changes

Update your initializer with new options:

```ruby
# config/initializers/rails_onboarding.rb
RailsOnboarding.configure do |config|
  # Required
  config.user_class_name = 'User'

  # Steps configuration
  config.steps = [
    { name: :welcome, title: 'Welcome', icon: '🎉', skippable: true },
    { name: :profile, title: 'Setup Profile', icon: '👤', skippable: false }
  ]

  # NEW: Advanced features
  config.enable_milestones = true
  config.enable_analytics = true
  config.enable_tooltips = true

  # NEW: Milestone configuration
  config.milestones = {
    first_login: { points: 10, name: 'First Login' },
    profile_completed: { points: 25, name: 'Profile Complete' }
  }

  # NEW: A/B Testing
  config.enable_ab_testing = false

  # NEW: Multi-tenant support
  config.multi_tenant = false

  # NEW: Webhooks
  config.webhooks = []

  # NEW: API mode
  config.api_mode = false
end
```

#### View Changes

If you've customized views, review these changes:

1. Progress indicator now uses Stimulus controller
2. Tooltips use new positioning system
3. Dark mode support added

To preserve customizations:

```bash
# Copy new views to your app
bundle exec rails generate rails_onboarding:views
```

Then merge your customizations with the new templates.

#### JavaScript Changes

If you've customized JavaScript:

1. Controllers now use Stimulus 3.x syntax
2. New tooltip scheduler controller
3. Tour controller for guided walkthroughs

Review `app/assets/javascripts/rails_onboarding/` for changes.

## Breaking Changes

### Future Versions

Breaking changes will be documented here for each version.

### Version 0.1.0

No breaking changes (initial release).

## Database Migrations

### Migration History

#### Version 0.1.0

**Migration: AddOnboardingToUsers**

Adds core onboarding fields:

```ruby
class AddOnboardingToUsers < ActiveRecord::Migration[7.0]
  def change
    add_column :users, :onboarding_completed, :boolean, default: false
    add_column :users, :onboarding_completed_at, :datetime
    add_column :users, :onboarding_current_step, :string
    add_column :users, :onboarding_skipped, :boolean, default: false

    # Use jsonb for PostgreSQL, text for others
    if adapter_name == 'PostgreSQL'
      add_column :users, :feature_tooltips_shown, :jsonb, default: {}
    else
      add_column :users, :feature_tooltips_shown, :text
    end

    add_index :users, :onboarding_completed
    add_index :users, :onboarding_current_step
  end
end
```

**Migration: AddMilestonesToUsers**

Adds milestone tracking:

```ruby
class AddMilestonesToUsers < ActiveRecord::Migration[7.0]
  def change
    if adapter_name == 'PostgreSQL'
      add_column :users, :milestones_achieved, :jsonb, default: {}
    else
      add_column :users, :milestones_achieved, :text
    end

    add_column :users, :onboarding_points, :integer, default: 0

    add_index :users, :onboarding_points
  end
end
```

**Migration: CreateAnalyticsEvents**

Adds analytics tracking:

```ruby
class CreateRailsOnboardingAnalyticsEvents < ActiveRecord::Migration[7.0]
  def change
    create_table :rails_onboarding_analytics_events do |t|
      t.references :user, null: false, polymorphic: true
      t.string :event_type, null: false
      t.string :event_name, null: false
      t.jsonb :properties, default: {}
      t.string :session_id
      t.timestamps
    end

    add_index :rails_onboarding_analytics_events, :event_type
    add_index :rails_onboarding_analytics_events, :event_name
    add_index :rails_onboarding_analytics_events, :session_id
    add_index :rails_onboarding_analytics_events, :created_at
  end
end
```

### Rolling Back Migrations

To roll back Rails Onboarding migrations:

```bash
# Find migration versions
bundle exec rails db:migrate:status | grep rails_onboarding

# Rollback specific migration
bundle exec rails db:migrate:down VERSION=XXXXXXXXXXXXXX
```

Or manually:

```ruby
# In rails console
ActiveRecord::Migration.drop_table :rails_onboarding_analytics_events

# Remove columns
ActiveRecord::Migration.remove_column :users, :onboarding_completed
ActiveRecord::Migration.remove_column :users, :onboarding_completed_at
# ... etc
```

## Configuration Changes

### Deprecated Options

#### Version 0.1.0

No deprecated options (initial release).

### Future Deprecations

Deprecated options will be documented here with recommended alternatives.

### Configuration Validation

Use the validation rake task to check your configuration:

```bash
bundle exec rails rails_onboarding:validate
```

This will check for:
- Required configuration options
- Valid step names
- Valid milestone configurations
- Valid redirect paths
- Type correctness

## Testing Your Upgrade

### 1. Automated Tests

Run your test suite:

```bash
# Run all tests
bundle exec rails test

# Run only onboarding-related tests
bundle exec rails test test/integration/*onboarding*
```

### 2. Manual Testing Checklist

- [ ] Start fresh onboarding flow
- [ ] Complete all steps
- [ ] Skip onboarding (if enabled)
- [ ] View tooltips
- [ ] Achieve milestones
- [ ] Check analytics tracking
- [ ] Test mobile responsiveness
- [ ] Verify dark mode (if enabled)
- [ ] Test A/B variants (if enabled)

### 3. Database Consistency

Verify database schema:

```bash
bundle exec rails db:schema:dump
```

Check for:
- All required columns exist
- Indexes are in place
- No duplicate migrations

### 4. Configuration Check

Validate your configuration:

```bash
bundle exec rails rails_onboarding:config
```

This displays your current configuration and checks for issues.

### 5. Asset Compilation

Test asset compilation:

```bash
RAILS_ENV=production bundle exec rails assets:precompile
```

Verify:
- No JavaScript errors in browser console
- Stimulus controllers load correctly
- Stylesheets apply properly

## Common Upgrade Issues

### Issue: Missing Migrations

**Symptoms:**
```
ActiveRecord::StatementInvalid: PG::UndefinedColumn: column "onboarding_completed" does not exist
```

**Solution:**
```bash
bundle exec rails rails_onboarding:install:migrations
bundle exec rails db:migrate
```

### Issue: Configuration Errors

**Symptoms:**
```
RailsOnboarding::ConfigurationError: Step names must be unique
```

**Solution:**

Check your configuration for duplicate step names:

```ruby
# BAD
config.steps = [
  { name: :welcome, title: 'Welcome' },
  { name: :welcome, title: 'Welcome Again' } # Duplicate!
]

# GOOD
config.steps = [
  { name: :welcome, title: 'Welcome' },
  { name: :profile, title: 'Profile Setup' }
]
```

### Issue: Asset Loading Problems

**Symptoms:**
- Stimulus controllers not working
- Styles not applying

**Solution:**

For Importmap:
```ruby
# config/importmap.rb
pin_all_from "rails_onboarding/javascripts", under: "rails_onboarding"
```

For ESBuild/Webpack:
```bash
# Rebuild assets
bundle exec rails assets:precompile
```

### Issue: User Model Missing Methods

**Symptoms:**
```
NoMethodError: undefined method `onboarding_progress' for User
```

**Solution:**

Ensure Onboardable concern is included:

```ruby
class User < ApplicationRecord
  include RailsOnboarding::Onboardable

  # Your code...
end
```

### Issue: Webhook Signature Failures After Upgrade

**Symptoms:**
Webhooks failing signature verification after upgrade.

**Solution:**

Check that your secret key hasn't changed:

```ruby
# config/initializers/rails_onboarding.rb
config.webhooks = [
  {
    url: 'https://example.com/webhook',
    secret_key: ENV['WEBHOOK_SECRET_KEY'] # Should be consistent
  }
]
```

Verify your webhook endpoint uses the correct signature algorithm (see [WEBHOOK_SECURITY_GUIDE.md](WEBHOOK_SECURITY_GUIDE.md)).

## Upgrade Support

### Getting Help

If you encounter issues during upgrade:

1. **Check Documentation:**
   - [CHANGELOG.md](CHANGELOG.md)
   - [README.md](README.md)
   - [TROUBLESHOOTING.md](TROUBLESHOOTING.md)

2. **Search Issues:**
   - Check [GitHub Issues](https://github.com/bunnahabhain/rails_onboarding/issues)
   - Search for similar upgrade problems

3. **Validate Setup:**
   ```bash
   bundle exec rails rails_onboarding:validate
   ```

4. **Enable Debug Logging:**
   ```ruby
   # config/initializers/rails_onboarding.rb
   RailsOnboarding.logger.level = Logger::DEBUG
   ```

5. **Report Issues:**
   - Open a new issue with upgrade details
   - Include Rails version, Ruby version, error messages
   - Provide relevant configuration

## Best Practices

### Before Upgrading

1. **Backup Database:**
   ```bash
   bundle exec rails db:dump
   ```

2. **Review Changes:**
   - Read CHANGELOG thoroughly
   - Check for breaking changes
   - Review new features

3. **Test in Staging:**
   - Never upgrade directly in production
   - Test the upgrade in staging environment
   - Run full test suite

### During Upgrade

1. **Follow Steps Sequentially:**
   - Don't skip steps
   - Run migrations before deploying code
   - Update configuration before restarting

2. **Monitor Logs:**
   - Watch application logs during upgrade
   - Check for deprecation warnings
   - Look for errors

### After Upgrading

1. **Verify Functionality:**
   - Test all onboarding flows
   - Check analytics tracking
   - Verify webhooks

2. **Monitor Performance:**
   - Check query performance
   - Monitor memory usage
   - Review error tracking

3. **Update Documentation:**
   - Update internal documentation
   - Train team on new features
   - Document any custom changes

## Version Support Policy

### Active Support

- **Current stable release:** Full support, bug fixes, security patches
- **Previous minor release:** Security patches only
- **Older releases:** No official support

### LTS (Long Term Support)

Currently no LTS releases. Will be announced when established.

### Compatibility Matrix

| Rails Onboarding | Rails     | Ruby    |
|------------------|-----------|---------|
| 0.1.x            | >= 8.0.0  | >= 3.2.5|

## Rollback Strategy

If you need to rollback an upgrade:

### 1. Restore Gem Version

```ruby
# Gemfile
gem 'rails_onboarding', '~> 0.1.0' # Previous version
```

```bash
bundle install
```

### 2. Rollback Migrations

```bash
# Find new migrations
bundle exec rails db:migrate:status

# Rollback each new migration
bundle exec rails db:migrate:down VERSION=XXXXXXXXXXXXXX
```

### 3. Restore Configuration

Revert your initializer to the previous version from version control:

```bash
git checkout HEAD~1 config/initializers/rails_onboarding.rb
```

### 4. Restart Application

```bash
# Development
bundle exec rails restart

# Production (depends on your setup)
# Passenger:
touch tmp/restart.txt
# Or:
sudo systemctl restart your-app
```

### 5. Verify Rollback

- Test onboarding flows
- Check logs for errors
- Verify user data intact

## Additional Resources

- [CHANGELOG.md](CHANGELOG.md) - Detailed version history
- [API_AUTHENTICATION_GUIDE.md](API_AUTHENTICATION_GUIDE.md) - API security
- [WEBHOOK_SECURITY_GUIDE.md](WEBHOOK_SECURITY_GUIDE.md) - Webhook integration
- [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md) - Production deployment
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - Common issues

## Contributing

Found an upgrade issue? Help improve this guide:

1. Fork the repository
2. Add your fix/improvement
3. Submit a pull request

## Questions?

- Open an issue on GitHub
- Check the [Troubleshooting Guide](TROUBLESHOOTING.md)
- Review example applications in `examples/`
