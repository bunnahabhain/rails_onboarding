# Rails Onboarding - Migration Guide

This guide helps you upgrade between versions of the Rails Onboarding gem.

## Table of Contents

- [General Upgrade Process](#general-upgrade-process)
- [Version Migrations](#version-migrations)
  - [Upgrading to 1.0.0](#upgrading-to-100)
  - [Upgrading to 0.9.0](#upgrading-to-090)
  - [Upgrading to 0.5.0](#upgrading-to-050)
- [Database Migrations](#database-migrations)
- [Configuration Changes](#configuration-changes)
- [Breaking Changes](#breaking-changes)
- [Deprecation Warnings](#deprecation-warnings)

---

## General Upgrade Process

Follow these steps when upgrading to any new version:

### 1. Review the Changelog

Always review [CHANGELOG.md](CHANGELOG.md) for the version you're upgrading to.

### 2. Update the Gem

Update your Gemfile:

```ruby
gem "rails_onboarding", "~> 1.0"
```

Then run:

```bash
bundle update rails_onboarding
```

### 3. Run New Migrations

Check for and run any new migrations:

```bash
# Copy new migrations from the gem
rails rails_onboarding:install:migrations

# Review the migrations
ls db/migrate/*rails_onboarding*

# Run migrations
rails db:migrate
```

### 4. Update Configuration

Review your `config/initializers/rails_onboarding.rb` for any new configuration options or deprecated settings.

### 5. Update Custom Code

If you've customized views, controllers, or JavaScript, review the changes in the new version and update your overrides accordingly.

### 6. Test Thoroughly

```bash
# Run your test suite
bundle exec rails test

# Manually test onboarding flow
# - Create new user
# - Go through onboarding
# - Test skip functionality
# - Test tooltips
# - Test milestones (if enabled)
```

### 7. Deploy

Deploy to staging first, test, then deploy to production.

---

## Version Migrations

### Upgrading to 1.0.0

**Release Date:** TBD
**Status:** Future Release

#### Major Changes

- Stable API release
- Performance improvements
- Enhanced analytics

#### Breaking Changes

None. Version 1.0.0 maintains backward compatibility with 0.9.x.

#### New Features

- Improved caching system
- Enhanced webhook delivery
- Better error handling

#### Migration Steps

1. Update gem version:
   ```ruby
   gem "rails_onboarding", "~> 1.0"
   ```

2. Run bundle update:
   ```bash
   bundle update rails_onboarding
   ```

3. No database migrations required

4. Optional: Enable new caching feature:
   ```ruby
   RailsOnboarding.configure do |config|
     config.cache_configuration = true
     config.cache_ttl = 1.hour
   end
   ```

---

### Upgrading to 0.9.0

**Release Date:** TBD

#### Major Changes

- Advanced features complete
- A/B testing support
- Personalization system
- Multi-tenant support

#### Breaking Changes

##### Configuration Structure Changed

**Before (0.8.x):**
```ruby
RailsOnboarding.configure do |config|
  config.steps = [...]
end
```

**After (0.9.x):**
```ruby
RailsOnboarding.configure do |config|
  # Same - no change required
  config.steps = [...]

  # New optional personalization
  config.personalization_strategy = :user_type
  config.flows = {
    developer: { steps: [...] },
    marketer: { steps: [...] }
  }
end
```

No breaking changes - personalization is opt-in.

#### New Database Fields

Run the migration generator:

```bash
rails generate rails_onboarding:install:migrations
rails db:migrate
```

New fields added:
- `users.ab_test_variants` (jsonb) - A/B test assignments
- `users.user_type` (string) - For personalization
- `users.organization_id` (integer) - For multi-tenancy

#### Migration Steps

1. Update gem:
   ```bash
   bundle update rails_onboarding
   ```

2. Run migrations:
   ```bash
   rails rails_onboarding:install:migrations
   rails db:migrate
   ```

3. Optional: Add personalization:
   ```ruby
   # In User model
   include RailsOnboarding::Personalizable

   # In initializer
   config.personalization_strategy = :user_type
   ```

4. Optional: Add A/B testing:
   ```ruby
   # In User model
   include RailsOnboarding::AbTestable

   # In your code
   current_user.assign_ab_variant('flow_test', 'variant_a')
   ```

---

### Upgrading to 0.5.0

**Release Date:** TBD

#### Major Changes

- Analytics system introduced
- Milestone system added
- Webhook support added

#### Breaking Changes

##### Method Signature Changed: `achieve_milestone!`

**Before (0.4.x):**
```ruby
current_user.achieve_milestone!('milestone_id')
```

**After (0.5.x):**
```ruby
current_user.achieve_milestone!('milestone_id', points)
```

**Migration:** Add points parameter to all `achieve_milestone!` calls.

##### Configuration: Milestones Now Required Array

**Before (0.4.x):**
```ruby
config.enable_milestones = true
# Milestones configured elsewhere
```

**After (0.5.x):**
```ruby
config.enable_milestones = true
config.milestones = [
  { id: 'first_login', title: 'Welcome', points: 10 }
]
```

#### New Database Tables

Run migrations:

```bash
rails rails_onboarding:install:migrations
rails db:migrate
```

New tables:
- `rails_onboarding_analytics_events` - Event tracking
- New columns on users table for milestones

#### Migration Steps

1. Update gem:
   ```bash
   bundle update rails_onboarding
   ```

2. Run migrations:
   ```bash
   rails rails_onboarding:install:migrations
   rails db:migrate
   ```

3. Update `achieve_milestone!` calls to include points:
   ```ruby
   # Search your codebase for:
   grep -r "achieve_milestone!" app/

   # Update each call:
   current_user.achieve_milestone!('profile_complete', 100)
   ```

4. Configure milestones in initializer:
   ```ruby
   RailsOnboarding.configure do |config|
     config.enable_milestones = true
     config.milestones = [
       { id: 'profile_complete', title: 'Profile Master', points: 100 }
     ]
   end
   ```

5. Optional: Enable analytics:
   ```ruby
   config.enable_analytics = true
   config.analytics_retention_days = 90
   ```

---

## Database Migrations

### Checking for Pending Migrations

```bash
# Check migration status
rails db:migrate:status | grep rails_onboarding

# Copy pending migrations
rails rails_onboarding:install:migrations

# Run migrations
rails db:migrate
```

### Rolling Back Migrations

To roll back Rails Onboarding migrations:

```bash
# Find the migration version
rails db:migrate:status | grep rails_onboarding

# Rollback specific version
rails db:migrate:down VERSION=20240101120000
```

### Database Schema Changes by Version

#### Version 0.9.0
- Added `ab_test_variants` (jsonb)
- Added `user_type` (string)
- Added `organization_id` (integer)

#### Version 0.5.0
- Added `rails_onboarding_analytics_events` table
- Added `onboarding_milestone_points` (integer)
- Added `onboarding_milestones_achieved` (jsonb)

#### Version 0.1.0 (Initial)
- Added `onboarding_completed` (boolean)
- Added `onboarding_completed_at` (datetime)
- Added `onboarding_current_step` (string)
- Added `onboarding_skipped` (boolean)
- Added `feature_tooltips_shown` (jsonb)

---

## Configuration Changes

### Deprecated Configuration Options

#### Version 0.9.0

None currently deprecated.

#### Version 0.5.0

**Deprecated:** `milestone_config`
**Replacement:** `milestones`

```ruby
# Deprecated
config.milestone_config = {...}

# Use instead
config.milestones = [...]
```

### New Configuration Options by Version

#### Version 0.9.0

```ruby
config.personalization_strategy = :user_type
config.flows = { ... }
config.enable_ab_testing = true
config.multi_tenant_mode = true
```

#### Version 0.5.0

```ruby
config.enable_analytics = true
config.analytics_retention_days = 90
config.webhook_url = ENV['WEBHOOK_URL']
config.webhook_events = [:onboarding_completed]
config.milestones = [...]
```

---

## Breaking Changes

### Version 1.0.0

None planned. Will maintain backward compatibility with 0.9.x.

### Version 0.9.0

**None.** All new features are opt-in.

### Version 0.5.0

**Method Signature:** `achieve_milestone!` now requires `points` parameter.

**Impact:** Medium
**Workaround:** Update all calls to include points.

```ruby
# Before
current_user.achieve_milestone!('test')

# After
current_user.achieve_milestone!('test', 50)
```

### Version 0.1.0

Initial release - no breaking changes.

---

## Deprecation Warnings

The gem follows semantic versioning:
- **Patch versions** (0.5.1 → 0.5.2): Bug fixes, no breaking changes
- **Minor versions** (0.5.0 → 0.6.0): New features, deprecations warned
- **Major versions** (0.9.0 → 1.0.0): Deprecated features removed

### Deprecation Timeline

Features are deprecated for at least one minor version before removal:

1. **Version X.Y.0**: Feature deprecated, warning added
2. **Version X.Y+1.0**: Feature still works, warning continues
3. **Version X+1.0.0**: Feature removed

Example:
- **0.8.0**: `old_method` deprecated, warning added
- **0.9.0**: `old_method` still works with warning
- **1.0.0**: `old_method` removed, use `new_method`

---

## Handling Custom Views

If you've overridden gem views:

### Before Upgrading

```bash
# Find your custom views
ls app/views/rails_onboarding/

# Backup custom views
cp -r app/views/rails_onboarding app/views/rails_onboarding.backup
```

### After Upgrading

1. Check gem's updated views:
   ```bash
   # Find gem path
   bundle show rails_onboarding

   # View default templates
   cd $(bundle show rails_onboarding)
   ls app/views/rails_onboarding/onboarding/
   ```

2. Compare with your custom views:
   ```bash
   diff app/views/rails_onboarding/onboarding/welcome.html.erb \
        $(bundle show rails_onboarding)/app/views/rails_onboarding/onboarding/welcome.html.erb
   ```

3. Merge changes as needed

---

## Handling Custom JavaScript

If you've customized Stimulus controllers:

### Before Upgrading

```bash
# Find custom controllers
ls app/assets/javascripts/rails_onboarding/

# Backup
cp -r app/assets/javascripts/rails_onboarding app/assets/javascripts/rails_onboarding.backup
```

### After Upgrading

1. Check for new controller methods
2. Ensure your custom controllers extend gem's controllers
3. Test all JavaScript interactions

---

## Testing After Upgrade

### Automated Testing

Add to your test suite:

```ruby
# test/integration/rails_onboarding_upgrade_test.rb
require "test_helper"

class RailsOnboardingUpgradeTest < ActionDispatch::IntegrationTest
  test "onboarding flow works after upgrade" do
    user = users(:new_user)
    sign_in user

    get rails_onboarding.onboarding_path
    assert_response :success

    post rails_onboarding.next_step_onboarding_path
    assert_redirected_to rails_onboarding.onboarding_path
  end

  test "milestones work after upgrade" do
    user = users(:one)
    user.achieve_milestone!('test', 100)

    assert user.milestone_achieved?('test')
    assert_equal 100, user.onboarding_milestone_points
  end

  test "tooltips work after upgrade" do
    user = users(:one)
    sign_in user

    post rails_onboarding.dismiss_tooltip_path,
         params: { tooltip_id: 'test' }

    assert_response :success
    assert user.reload.tooltip_shown?('test')
  end
end
```

### Manual Testing Checklist

- [ ] Create new user account
- [ ] Go through complete onboarding flow
- [ ] Test each step navigation (next/previous)
- [ ] Test skip functionality
- [ ] Test onboarding completion
- [ ] Test tooltip display and dismissal
- [ ] Test milestone achievements (if enabled)
- [ ] Test analytics tracking (if enabled)
- [ ] Test responsive design on mobile
- [ ] Test with different user types (if using personalization)
- [ ] Test A/B variants (if using A/B testing)

---

## Rollback Procedure

If you need to rollback to a previous version:

### 1. Revert Gem Version

```ruby
# Gemfile
gem "rails_onboarding", "0.8.0"  # Previous version
```

```bash
bundle update rails_onboarding
```

### 2. Rollback Database

```bash
# Find migration versions to rollback
rails db:migrate:status | grep rails_onboarding

# Rollback to previous version
rails db:migrate:down VERSION=20240515000000
```

### 3. Revert Configuration

Restore previous `config/initializers/rails_onboarding.rb` from version control:

```bash
git checkout HEAD~1 config/initializers/rails_onboarding.rb
```

### 4. Restart Application

```bash
# Development
rails restart

# Production
# Use your deployment process to restart
```

### 5. Verify Rollback

Test that previous version is working correctly.

---

## Getting Help

If you encounter issues during upgrade:

1. **Check the Changelog**: [CHANGELOG.md](CHANGELOG.md)
2. **Review Documentation**: [README.md](README.md)
3. **Search Issues**: [GitHub Issues](https://github.com/bunnahabhain/rails_onboarding/issues)
4. **Ask for Help**: [GitHub Discussions](https://github.com/bunnahabhain/rails_onboarding/discussions)
5. **Email Support**: david@davidsfolly.com

---

## Version Support Policy

- **Current Version**: Full support, active development
- **Previous Minor Version**: Bug fixes and security patches
- **Older Versions**: Security patches only (critical vulnerabilities)

We recommend always upgrading to the latest version for best performance and security.

---

## Future Migrations

This guide will be updated with each new release. Subscribe to releases on GitHub to stay informed:

https://github.com/bunnahabhain/rails_onboarding/releases

---

## Contributing to This Guide

Found an issue or have a suggestion for this migration guide?

1. Open an issue: https://github.com/bunnahabhain/rails_onboarding/issues
2. Submit a PR with improvements
3. Share your upgrade experience in Discussions

---

**Last Updated:** 2024
**Current Gem Version:** 0.1.0
**Next Planned Version:** 0.5.0
