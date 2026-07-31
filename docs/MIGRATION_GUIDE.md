# Rails Onboarding - Migration Guide

This guide helps you upgrade between versions of the Rails Onboarding gem.

## Table of Contents

- [General Upgrade Process](#general-upgrade-process)
- [Version Migrations](#version-migrations)
  - [Upgrading to 0.5.0](#upgrading-to-050)
  - [Upgrading to 0.2.0](#upgrading-to-020)
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
gem "rails_onboarding", "~> 0.6"
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

### Upgrading to 0.5.0

**Released:** 2026-07-29

Completes the CSS isolation work started in 0.4.0. Where 0.4.0 stopped the
gem's styles leaking out into the host application, this release stops the
host's styles reaching in, by namespacing the 55 generic class names the gem's
own elements carried.

#### Breaking Changes (CSS only)

No Ruby API, configuration, or database change. Two things can break:

1. **Renamed class names.** Generic names the gem's markup used - state and
   position words (`active`, `completed`, `current`, `error`, `success`,
   `warning`, `info`, `show`, `hide`, `top`, `bottom`, `left`, `right`), names
   that clash with Bootstrap and Tailwind (`btn`, `btn-primary`,
   `btn-secondary`, `form-group`, `progress-bar`, `progress-fill`), and generic
   component names (`tooltip`, `flash`, `empty-state`, `status-message`,
   `radio-group`, `checkbox-group`, `error-message`, `help-text`) - now carry
   an `onboarding-` prefix.

2. **`.rails-onboarding-tooltip` overrides.** Tooltips had been styled with
   hardcoded inline values and ignored the theme; that is fixed, so overrides
   of that selector need revisiting.

**Migration:** if your application targets any of those names in its own CSS or
JavaScript, or renders gem markup by hand, add the `onboarding-` prefix. Note
that the four `status-message` modifiers became `onboarding-status-success` /
`-error` / `-warning` / `-info`, not `onboarding-success` / `-error`, because
those two already existed as unrelated utility classes.

Names that were already semi-namespaced (`tour-*`, `milestone-*`, `feature-*`,
`step-*`) were left alone.

---

### Upgrading to 0.2.0

**Released:** 2026-07-19

#### Breaking Changes (URLs only)

The onboarding flow is now anchored at the engine's mount point
(`resource :onboarding, path: ""`), so mounting at `/onboarding` yields
`/onboarding` instead of the doubled `/onboarding/onboarding` (and
`/onboarding/next`, `/onboarding/skip`, and so on).

Route helpers (`onboarding_path`, `next_onboarding_path`, ...) are unchanged,
so helper-based code needs no migration - only hardcoded URLs and bookmarks are
affected.

**Migration:** update hardcoded URLs, or keep the previous paths by mounting at
`mount RailsOnboarding::Engine => "/onboarding/onboarding"`.

---

### Other Releases

No other release has required migration work. See
[CHANGELOG.md](CHANGELOG.md) for the full history.

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

### Migrations Installed by the Generator

`rails_onboarding:install` copies six migrations. A fresh install runs all of
them - there is no per-version subset to choose from.

| Migration | Adds |
|---|---|
| `add_onboarding_to_users` | `onboarding_completed` (boolean), `onboarding_completed_at` (datetime), `onboarding_current_step` (string), `onboarding_skipped` (boolean), `feature_tooltips_shown` |
| `add_milestone_tracking_to_users` | `milestones_achieved` (text), `milestone_points` (integer), `last_milestone_at` (datetime) |
| `add_robustness_fields_to_users` | `onboarding_errors`, `onboarding_failed_actions`, `onboarding_session_data` (all text) |
| `add_analytics_to_rails_onboarding` | `rails_onboarding_analytics_events` table |
| `create_rails_onboarding_flows` | `rails_onboarding_flows` table |
| `add_onboarding_indexes` | Indexes on the onboarding columns |

`feature_tooltips_shown` is adapter-aware: `jsonb` on PostgreSQL, `json` on
MySQL and Trilogy, serialized `text` elsewhere. On PostgreSQL the indexes are
built `CONCURRENTLY` so they don't hold a write lock on a large users table.

---

## Configuration Changes

### Deprecated Configuration Options

None. No configuration option has been deprecated or removed.

### Adding New Options

Options are introduced in minor releases and none has been withdrawn, so an
initializer written against an earlier version keeps working - new options
simply fall back to their defaults until you set them.

The current set is documented in the
[main README](../README.md#configuration).

---

## Breaking Changes

Two in the project's history, both narrow in scope:

| Version | Scope | What changed |
|---|---|---|
| 0.5.0 | CSS only | 55 generic class names gained an `onboarding-` prefix |
| 0.2.0 | URLs only | The flow is anchored at the mount point; route helpers unchanged |

No release has changed a Ruby method signature, removed a configuration option,
or required a data migration.

---

## Deprecation Warnings

The gem follows semantic versioning:

- **Patch** (0.6.0 → 0.6.1): bug fixes, no breaking changes
- **Minor** (0.5.0 → 0.6.0): new features; anything being withdrawn is
  deprecated with a warning first
- **Major** (0.x → 1.0.0): deprecated features may be removed

### Deprecation Timeline

Nothing is currently deprecated. When something is, it will warn for at least
one minor release before removal, and the warning will name its replacement.

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

    post rails_onboarding.next_onboarding_path
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
gem "rails_onboarding", "0.5.4"  # Previous version
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
2. **Review Documentation**: [README.md](../README.md)
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

**Last Updated:** 2026-07-31
**Current Gem Version:** 0.6.0
