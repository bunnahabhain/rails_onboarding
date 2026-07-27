# Troubleshooting Guide

This guide helps diagnose and resolve common issues with Rails Onboarding.

## Table of Contents

- [Installation Issues](#installation-issues)
- [Configuration Problems](#configuration-problems)
- [Database Errors](#database-errors)
- [Asset Loading Issues](#asset-loading-issues)
- [Onboarding Flow Problems](#onboarding-flow-problems)
- [Tooltip Issues](#tooltip-issues)
- [Milestone Problems](#milestone-problems)
- [Analytics Issues](#analytics-issues)
- [Performance Problems](#performance-problems)
- [Debugging Tools](#debugging-tools)

## Installation Issues

### Problem: Gem won't install

**Error:**
```
Could not find gem 'rails_onboarding' in rubygems repository
```

**Solution:**

Check your Gemfile syntax:
```ruby
# Correct
gem 'rails_onboarding', '~> 0.1.0'

# If installing from git
gem 'rails_onboarding', git: 'https://github.com/bunnahabhain/rails_onboarding'
```

Then run:
```bash
bundle install
```

### Problem: Generator not found

**Error:**
```
Could not find generator 'rails_onboarding:install'
```

**Solution:**

1. Verify gem is installed:
   ```bash
   bundle show rails_onboarding
   ```

2. Restart Rails server:
   ```bash
   spring stop  # If using Spring
   bundle exec rails restart
   ```

3. Re-run generator:
   ```bash
   bundle exec rails generate rails_onboarding:install
   ```

### Problem: Migration fails

**Error:**
```
PG::DuplicateColumn: ERROR: column "onboarding_completed" already exists
```

**Solution:**

Check if migration already ran:
```bash
bundle exec rails db:migrate:status | grep onboarding
```

If yes, skip the migration or rollback and re-run:
```bash
bundle exec rails db:migrate:down VERSION=XXXXXXXXXXXXXX
bundle exec rails db:migrate
```

## Configuration Problems

### Problem: Configuration validation errors

**Error:**
```
RailsOnboarding::ConfigurationError: Step names must be unique
```

**Solution:**

Check your configuration for duplicate step names:
```ruby
# config/initializers/rails_onboarding.rb
RailsOnboarding.configure do |config|
  config.steps = [
    { name: :welcome, title: 'Welcome' },
    { name: :profile, title: 'Profile Setup' }  # Must be unique
  ]
end
```

Validate your configuration:
```bash
bundle exec rails rails_onboarding:validate
```

### Problem: User class not found

**Error:**
```
NameError: uninitialized constant User
```

**Solution:**

Ensure User model exists and is specified correctly:
```ruby
# config/initializers/rails_onboarding.rb
RailsOnboarding.configure do |config|
  config.user_class_name = 'User'  # Must match your model name
end
```

If using a different model name:
```ruby
config.user_class_name = 'Account'  # Or whatever your model is called
```

### Problem: Redirect path not working

**Error:**
```
NoMethodError: undefined method 'dashboard_path'
```

**Solution:**

Use valid route helpers or paths:
```ruby
# config/initializers/rails_onboarding.rb
config.redirect_after_completion = :root_path  # Symbol (recommended)
# or
config.redirect_after_completion = '/dashboard'  # String path
```

Check available routes:
```bash
bundle exec rails routes | grep dashboard
```

## Database Errors

### Problem: Missing columns

**Error:**
```
ActiveRecord::StatementInvalid: PG::UndefinedColumn: column "onboarding_completed" does not exist
```

**Solution:**

Run migrations:
```bash
bundle exec rails rails_onboarding:install:migrations
bundle exec rails db:migrate
```

Verify columns exist:
```bash
rails dbconsole
\d users  # PostgreSQL
# or
DESCRIBE users;  # MySQL
```

### Problem: JSONB not supported

**Error:**
```
ActiveRecord::StatementInvalid: SQLite3::SQLException: no such column type: jsonb
```

**Solution:**

SQLite doesn't support JSONB. The migration should automatically use TEXT:
```ruby
# Check migration
class AddOnboardingToUsers < ActiveRecord::Migration[7.0]
  def change
    if adapter_name == 'PostgreSQL'
      add_column :users, :feature_tooltips_shown, :jsonb, default: {}
    else
      add_column :users, :feature_tooltips_shown, :text
    end
  end
end
```

### Problem: Admin analytics raises "Unknown column 'metadata'"

**Error:**
```
Mysql2::Error: Unknown column 'metadata' in 'where clause'
```
(logged as `Error loading analytics` on the admin dashboard; also surfaces
as `NoMethodError: undefined method 'metadata'` on a user's detail page.)

**Cause:**

Analytics events store their payload in the `properties` column (a
JSON-serialized **text** column, per the `add_analytics_to_rails_onboarding`
migration), keyed by names like `step_name` and `tooltip_feature`. Older
admin reporting code queried a non-existent `metadata` column with a `step`
key, and used the SQL JSON operator `->>`, which only works on a native
`json`/`jsonb` column — not on the serialized text column used on MySQL and
SQLite.

**Solution:**

Upgrade to a release that includes the fix (the admin dashboard, flows, and
user-timeline controllers now read `event.properties` and filter by variant
in Ruby). If you have forked or customized the admin controllers, do not use
`->>` (or the PostgreSQL `?` key-existence operator) against `properties` or
`ab_test_assignments`; load the records and read the deserialized hash in
Ruby instead:

```ruby
# Portable across PostgreSQL, MySQL, and SQLite
events.select { |e| e.properties.to_h["step_name"] == step_name }
```

### Problem: Index creation fails

**Error:**
```
PG::DuplicateObject: ERROR: relation "index_users_on_onboarding_completed" already exists
```

**Solution:**

Check if index exists before creating:
```ruby
# In migration
add_index :users, :onboarding_completed unless index_exists?(:users, :onboarding_completed)
```

Or drop existing index:
```bash
rails dbconsole
DROP INDEX index_users_on_onboarding_completed;
```

### Problem: Pre-existing users show as "Not Started" forever

**Symptom:**

Every user who signed up before you installed the gem is reported as "Not
Started" in the admin, and with `onboarding_required_for = :all_users` they get
pushed into a flow they don't need.

**Solution:**

Backfill them once, after running the install migrations:

```bash
bundle exec rails rails_onboarding:backfill_existing_users DRY_RUN=true  # preview
bundle exec rails rails_onboarding:backfill_existing_users               # apply
```

Pass `BEFORE=2026-07-01` to grandfather in only the pre-install cohort. Users
who are mid-flow are never touched, so the task is safe to re-run. See the
README's "Installing into an app that already has users" section for details.

### Problem: `undefined method 'strftime' for nil` in the admin

**Error:**
```
ActionView::Template::Error (undefined method 'strftime' for nil)
```

**Cause:**

A `users` row with a `NULL` `created_at` or `updated_at`. This is common in
applications where the `users` table predates Rails timestamp columns, or where
data was imported directly. It is not caused by the onboarding columns — those
are all nil-guarded.

**Solution:**

The admin views tolerate `NULL` timestamps and display `N/A` instead — upgrade
to the latest version if you are still seeing this. To fix the underlying data,
backfill
the timestamps in your own app — the gem deliberately won't invent creation
dates for your users:

```ruby
# Example only - pick a defensible value for your data
User.where(created_at: nil).update_all("created_at = COALESCE(updated_at, NOW())")
```

## Asset Loading Issues

### Problem: Stimulus controllers not loading

**Error (Browser Console):**
```
Error: Unable to autoload controller: rails_onboarding--onboarding
```

**Solution:**

**For Importmap:**
```ruby
# config/importmap.rb
pin "application", preload: true
pin "@hotwired/stimulus", to: "stimulus.min.js", preload: true
pin_all_from "rails_onboarding/javascripts", under: "rails_onboarding"
```

**For ESBuild/Webpack:**
```javascript
// app/javascript/application.js
import "rails_onboarding"
```

Rebuild assets:
```bash
bundle exec rails assets:precompile
```

### Problem: Stylesheets not loading

**Error:**
No onboarding styles applied

**Solution:**

Ensure CSS is imported:
```scss
// app/assets/stylesheets/application.css
*= require rails_onboarding/application
```

Or with SCSS:
```scss
// app/assets/stylesheets/application.scss
@import "rails_onboarding/application";
```

Precompile assets:
```bash
RAILS_ENV=production bundle exec rails assets:precompile
```

### Problem: Assets 404 in production

**Error (Browser):**
```
GET /assets/rails_onboarding/application.css 404 Not Found
```

**Solution:**

Check asset compilation:
```bash
RAILS_ENV=production bundle exec rails assets:precompile
ls public/assets/rails_onboarding/
```

Verify asset host configuration:
```ruby
# config/environments/production.rb
config.asset_host = ENV['ASSET_HOST']  # Should be set or nil
```

## Onboarding Flow Problems

### Problem: Onboarding not triggering

**Symptoms:**
Users not redirected to onboarding after signup

**Solution:**

1. Ensure Onboardable concern is included:
   ```ruby
   class User < ApplicationRecord
     include RailsOnboarding::Onboardable
   end
   ```

2. Check controller helpers are loaded:
   ```ruby
   class ApplicationController < ActionController::Base
     include RailsOnboarding::ControllerHelpers
   end
   ```

3. Verify user requires onboarding:
   ```bash
   rails console
   user = User.last
   user.requires_onboarding?  # Should return true for new users
   ```

4. Check configuration:
   ```ruby
   RailsOnboarding.configure do |config|
     config.onboarding_required_for = :new_users  # or :all_users
   end
   ```

### Problem: Stuck on a step

**Symptoms:**
Cannot progress past a specific step

**Solution:**

Check step completion logic:
```bash
rails console
user = User.find(1)
user.onboarding_current_step  # Current step
user.complete_onboarding_step!(:welcome)  # Try completing manually
```

Verify step configuration:
```ruby
# Ensure step name matches
config.steps = [
  { name: :welcome, title: 'Welcome' }  # :welcome must match controller
]
```

Check for validation errors in controller:
```ruby
# app/controllers/rails_onboarding/onboarding_controller.rb
def complete_step
  # Add debugging
  Rails.logger.debug "Completing step: #{params[:step_name]}"
  Rails.logger.debug "Step data: #{params[:step_data]}"
  # ...
end
```

### Problem: A path-based step shows "This step is not yet fully configured"

**Symptoms:**
A step that normally redirects to a page in your app (configured with `path:`)
instead renders the generic fallback template ("This step is not yet fully
configured. Please contact support..."), and/or a step with a `complete_if:`
never auto-advances. Often appears right after you create/activate a flow in
the admin Flow Editor.

**Cause:**
A saved flow is stored as JSON, and JSON cannot serialize a Proc. When a flow
is written to the database, any `path:` or `complete_if:` option that is a Proc
(or the symbol/lambda form of `path:`) is lost. While that flow is *active*, it
overrides your `config.steps`, so the step arrives at runtime with no `:path`
(hence the fallback render) and no `:complete_if` (hence no auto-advance).

**Solution:**

As of the fix in this release, `Configuration#steps` re-hydrates Proc-valued
options from the statically-configured step of the same name, so an active flow
no longer disables path-based steps - just make sure the step's `name` in the
flow still matches the `name` in your `config.steps`. To confirm what the active
flow resolves to:

```ruby
rails console
RailsOnboarding.configuration.steps.map { |s| [s[:name], s[:path], s[:complete_if]] }
# The profile/create-wish style steps should show their Proc/path again.
RailsOnboarding::Flow.active.first  # nil means config.steps is used as-is
```

If you are on an older version and can't upgrade, deactivate the flow
(`RailsOnboarding::Flow.update_all(active: false)`) to fall back to
`config.steps`, which keeps its Procs.

### Problem: Skip button not working

**Symptoms:**
Skip button visible but doesn't work

**Solution:**

1. Verify step is skippable:
   ```ruby
   config.steps = [
     { name: :welcome, title: 'Welcome', skippable: true }  # Must be true
   ]
   ```

2. Check skip configuration:
   ```ruby
   config.allow_skip = true  # Must be enabled
   config.skip_button_text = 'Skip for now'
   ```

3. Test skip functionality:
   ```bash
   rails console
   user = User.find(1)
   user.skip_onboarding!
   user.onboarding_skipped?  # Should return true
   ```

## Tooltip Issues

### Problem: Tooltips not showing

**Symptoms:**
Tooltips configured but not displaying

**Solution:**

1. Verify tooltips are enabled:
   ```ruby
   # config/initializers/rails_onboarding.rb
   config.enable_tooltips = true
   ```

2. Check tooltip configuration:
   ```ruby
   config.tooltips = {
     dashboard_welcome: {
       title: 'Welcome!',
       content: 'This is your dashboard',
       target: '#dashboard',
       position: 'bottom'
     }
   }
   ```

3. Ensure target element exists:
   ```html
   <!-- View must have matching element -->
   <div id="dashboard">...</div>
   ```

4. Check Stimulus controller:
   ```javascript
   // Browser console
   application.getControllerForElementAndIdentifier(
     document.querySelector('[data-controller~="rails-onboarding--tooltip"]'),
     'rails-onboarding--tooltip'
   )
   ```

### Problem: Tooltip positioning wrong

**Symptoms:**
Tooltip appears in wrong location or off-screen

**Solution:**

Adjust positioning:
```ruby
config.tooltips = {
  my_tooltip: {
    position: 'top',  # Try: top, bottom, left, right
    offset: 10,       # Adjust pixel offset
    arrow: true       # Enable pointer arrow
  }
}
```

Enable collision detection:
```javascript
// Automatic repositioning if off-screen
data-rails-onboarding--tooltip-collision-value="true"
```

## Milestone Problems

### Problem: Milestones not triggering

**Symptoms:**
Actions performed but milestones not achieved

**Solution:**

1. Enable milestones:
   ```ruby
   config.enable_milestones = true
   ```

2. Check milestone configuration:
   ```ruby
   config.milestones = {
     first_login: {
       name: 'First Login',
       points: 10,
       trigger: :on_step_complete,
       trigger_value: :welcome
     }
   }
   ```

3. Manually trigger:
   ```bash
   rails console
   user = User.find(1)
   user.achieve_milestone!(:first_login)
   user.milestones_achieved  # Check if recorded
   ```

4. Check trigger conditions:
   ```ruby
   # Debug milestone tracking
   Rails.logger.debug "Milestone check: #{milestone_key}"
   Rails.logger.debug "User points: #{current_user.onboarding_points}"
   ```

### Problem: Milestone points not accumulating

**Symptoms:**
Milestones achieved but points stay at 0

**Solution:**

Verify points are configured:
```ruby
config.milestones = {
  first_login: { points: 10 },  # Must specify points
  profile_completed: { points: 25 }
}
```

Check database:
```bash
rails console
user = User.find(1)
user.onboarding_points  # Should show total points
user.milestones_achieved  # Should show achieved milestones
```

## Analytics Issues

### Problem: Events not being tracked

**Symptoms:**
No analytics data appearing

**Solution:**

1. Enable analytics:
   ```ruby
   config.enable_analytics = true
   ```

2. Verify table exists:
   ```bash
   rails dbconsole
   \dt rails_onboarding_analytics_events;
   ```

3. Manually track event:
   ```bash
   rails console
   RailsOnboarding::Analytics.track_event(
     user: User.first,
     event_type: 'onboarding',
     event_name: 'step_completed',
     properties: { step: 'welcome' }
   )
   ```

4. Check for errors:
   ```bash
   tail -f log/production.log | grep Analytics
   ```

### Problem: Analytics reports empty

**Symptoms:**
No data in analytics reports

**Solution:**

1. Check date range:
   ```bash
   rails console
   RailsOnboarding::Analytics.completion_rate(since: 30.days.ago)
   ```

2. Verify events exist:
   ```bash
   rails console
   RailsOnboarding::AnalyticsEvent.count
   RailsOnboarding::AnalyticsEvent.last
   ```

3. Check retention settings:
   ```ruby
   # Events may have been cleaned up
   config.analytics_retention_days = 90  # Increase retention
   ```

## Performance Problems

### Problem: Slow page loads

**Symptoms:**
Onboarding pages loading slowly

**Solution:**

1. Enable caching:
   ```ruby
   config.cache_configuration = true
   config.cache_ttl = 1.hour
   ```

2. Use fragment caching:
   ```erb
   <% cache(['onboarding', current_user.id, current_user.updated_at]) do %>
     <%= render 'onboarding_step' %>
   <% end %>
   ```

3. Optimize database queries:
   ```bash
   rails console
   # Check for N+1 queries
   User.includes(:onboarding_analytics_events).first.onboarding_progress
   ```

4. Check asset loading:
   ```ruby
   # config/environments/production.rb
   config.assets.compile = false  # Should be false in production
   ```

### Problem: High memory usage

**Symptoms:**
Application consuming excessive memory

**Solution:**

1. Limit analytics query size:
   ```ruby
   # Use pagination
   RailsOnboarding::AnalyticsEvent
     .where(user: current_user)
     .limit(100)
   ```

2. Clean up old data:
   ```bash
   bundle exec rails rails_onboarding:analytics:cleanup
   ```

3. Configure retention:
   ```ruby
   config.analytics_retention_days = 30  # Reduce retention
   ```

## Debugging Tools

### Enable Debug Mode

```ruby
# config/initializers/rails_onboarding.rb
if Rails.env.development?
  RailsOnboarding.logger.level = Logger::DEBUG
end
```

### Validation Command

Check your setup:
```bash
bundle exec rails rails_onboarding:validate
```

Output:
```
✓ User model found
✓ Onboardable concern included
✓ Required columns present
✓ Configuration valid
✓ Routes mounted
✓ Migrations up to date
```

### Configuration Inspector

View current configuration:
```bash
bundle exec rails rails_onboarding:config
```

### Console Debugging

```bash
rails console

# Check user onboarding status
user = User.find(1)
user.requires_onboarding?
user.onboarding_current_step
user.onboarding_progress_percentage

# Test step completion
user.complete_onboarding_step!(:welcome)

# Check milestones
user.milestones_achieved
user.onboarding_points

# View analytics
RailsOnboarding::Analytics.completion_rate
RailsOnboarding::Analytics.funnel_analysis
```

### Log Analysis

```bash
# Watch logs in real-time
tail -f log/development.log | grep -i onboarding

# Search for errors
grep -i error log/production.log | grep -i onboarding

# Check analytics events
grep "Analytics" log/production.log
```

### Database Inspection

```bash
rails dbconsole

# Check user onboarding data
SELECT id, email, onboarding_completed, onboarding_current_step
FROM users
ORDER BY created_at DESC
LIMIT 10;

# Check analytics events
SELECT event_type, event_name, COUNT(*)
FROM rails_onboarding_analytics_events
GROUP BY event_type, event_name;

# Check milestones
SELECT id, email, onboarding_points, milestones_achieved
FROM users
WHERE milestones_achieved IS NOT NULL;
```

### Browser DevTools

**Check Stimulus Controllers:**
```javascript
// In browser console
application.controllers.forEach(controller => {
  console.log(controller.identifier, controller.element)
})
```

**Check Tooltip Elements:**
```javascript
document.querySelectorAll('[data-controller~="rails-onboarding--tooltip"]')
```

**Monitor Network Requests:**
```javascript
// In Network tab, filter by:
// - "onboarding" to see onboarding requests
// - "api" to see API calls
```

## Getting More Help

### Documentation

- [README.md](../README.md) - Main documentation
- [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md) - Production deployment
- [UPGRADE_GUIDE.md](UPGRADE_GUIDE.md) - Version upgrades

### Community Support

- **GitHub Issues:** [Report bugs and request features](https://github.com/bunnahabhain/rails_onboarding/issues)
- **Discussions:** [Ask questions and share ideas](https://github.com/bunnahabhain/rails_onboarding/discussions)

### Reporting Bugs

When opening an issue, include:

1. **Rails Onboarding version:**
   ```bash
   bundle show rails_onboarding | grep Version
   ```

2. **Ruby version:**
   ```bash
   ruby -v
   ```

3. **Rails version:**
   ```bash
   rails -v
   ```

4. **Database:**
   PostgreSQL/MySQL/SQLite and version

5. **Error message:**
   Full stack trace from logs

6. **Steps to reproduce:**
   Minimal code example demonstrating the issue

7. **Configuration:**
   Relevant parts of your `rails_onboarding.rb` initializer

### Debug Checklist

Before asking for help, verify:

- [ ] Gem is properly installed (`bundle show rails_onboarding`)
- [ ] Migrations are up to date (`rails db:migrate:status`)
- [ ] Configuration is valid (`rails rails_onboarding:validate`)
- [ ] User model includes Onboardable concern
- [ ] ApplicationController includes ControllerHelpers
- [ ] Routes are mounted correctly
- [ ] Assets are compiled (production)
- [ ] Environment variables are set
- [ ] Logs checked for errors
- [ ] Database has required columns
- [ ] Similar issues checked on GitHub

## Quick Fixes

### Reset Onboarding for User

```bash
rails console
user = User.find(1)
user.update(
  onboarding_completed: false,
  onboarding_current_step: nil,
  onboarding_completed_at: nil,
  onboarding_skipped: false
)
```

### Clear Analytics Data

```bash
rails console
RailsOnboarding::AnalyticsEvent.delete_all
```

### Regenerate API Tokens

```bash
rails console
User.find_each do |user|
  user.update(api_token: SecureRandom.hex(32))
end
```

### Reset Configuration Cache

```bash
rails console
Rails.cache.delete('rails_onboarding_config')
RailsOnboarding.reset_configuration!
```

### Force Asset Recompilation

```bash
bundle exec rails assets:clobber
bundle exec rails assets:precompile
```

## Common Gotchas

1. **User model not reloaded after migration**
   - Restart Rails console after running migrations

2. **Cached configuration in development**
   - Restart Rails server after changing initializer

3. **Turbo interfering with JavaScript**
   - Ensure Stimulus controllers use proper lifecycle hooks

4. **CSRF token issues with API**
   - API controllers should skip CSRF verification

5. **PostgreSQL vs MySQL differences**
   - JSONB vs TEXT serialization handling

6. **Asset pipeline vs Webpacker/ESBuild**
   - Different import/require syntax needed

7. **Time zone issues in analytics**
   - Always use UTC for consistency

8. **Rate limiting blocking development**
   - Whitelist localhost in Rack::Attack

## Still Having Issues?

If this guide didn't solve your problem:

1. **Search existing issues:** [GitHub Issues](https://github.com/bunnahabhain/rails_onboarding/issues)
2. **Ask in discussions:** [GitHub Discussions](https://github.com/bunnahabhain/rails_onboarding/discussions)
3. **Open a new issue:** Include debug checklist items above

We're here to help! 🚀
