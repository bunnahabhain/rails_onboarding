# Rails Onboarding

[![Gem Version](https://badge.fury.io/rb/rails_onboarding.svg)](https://badge.fury.io/rb/rails_onboarding)
[![Build Status](https://github.com/bunnahabhain/rails_onboarding/workflows/CI/badge.svg)](https://github.com/bunnahabhain/rails_onboarding/actions)

A flexible, customizable onboarding engine for Rails applications. Create engaging multi-step onboarding flows with progress tracking, tooltips, milestones, analytics, and more.

## Features

- 🎯 **Multi-Step Onboarding Flows** - Guide users through customizable onboarding steps
- 📊 **Progress Tracking** - Visual progress indicators and completion tracking
- 💬 **Smart Tooltips** - Context-aware feature tooltips with progressive disclosure
- 🏆 **Milestone System** - Achievement tracking with points and celebrations
- 📈 **Analytics & Metrics** - Comprehensive tracking of completion rates, drop-off points, and user engagement
- 🎨 **Interactive Tours** - Guided walkthroughs with spotlight effects
- 🧪 **A/B Testing** - Test different onboarding flows and measure effectiveness
- 👥 **Personalization** - Adapt onboarding based on user type or role
- 🌍 **Internationalization** - Built-in support for multiple languages
- 📱 **Mobile Responsive** - Fully responsive design for all devices
- ⚡ **Performance Optimized** - Caching, database optimization, lazy loading, and CDN support
- 🔌 **Easy Integration** - Works seamlessly with Devise, Turbo, and Stimulus
- 🎭 **Multi-Tenant Support** - Different onboarding flows per organization
- 📦 **Pre-built Templates** - 5 ready-to-use onboarding flows for common use cases

## Table of Contents

- [Installation](#installation)
- [Quick Start](#quick-start)
- [Configuration](#configuration)
- [Usage](#usage)
- [Advanced Features](#advanced-features)
- [API Reference](#api-reference)
- [Testing](#testing)
- [Contributing](#contributing)
- [License](#license)

## Installation

Add this line to your application's Gemfile:

```ruby
gem "rails_onboarding"
```

Then execute:

```bash
bundle install
```

Run the installation generator:

```bash
rails generate rails_onboarding:install
```

This will:
- Create an initializer at `config/initializers/rails_onboarding.rb`
- Generate a migration for adding onboarding fields to your User model
- Mount the engine in your routes
- Create sample view templates

Run the migration:

```bash
rails db:migrate
```

## Requirements

This gem requires:
1. **Rails 7.0+** (Rails 8.0+ recommended for Turbo/Stimulus support)
2. **Ruby 3.0+** (Ruby 3.2+ recommended)
3. An `ApplicationController` class
4. A `current_user` method available in your controllers
5. Authentication system (Devise, custom, etc.)

### Version Compatibility Matrix

| Rails Version | Ruby Version | rails_onboarding | Status | Notes |
|--------------|--------------|------------------|--------|-------|
| 8.0.x        | 3.2.5+       | 0.1.0+          | ✅ Fully Supported | Recommended configuration |
| 8.0.x        | 3.1.x        | 0.1.0+          | ✅ Supported | |
| 8.0.x        | 3.0.x        | 0.1.0+          | ⚠️ Compatible | Ruby 3.2+ recommended |
| 7.2.x        | 3.2.5+       | 0.1.0+          | ✅ Supported | |
| 7.2.x        | 3.1.x        | 0.1.0+          | ✅ Supported | |
| 7.2.x        | 3.0.x        | 0.1.0+          | ⚠️ Compatible | Ruby 3.2+ recommended |
| 7.1.x        | 3.2.5+       | 0.1.0+          | ✅ Supported | |
| 7.1.x        | 3.1.x        | 0.1.0+          | ✅ Supported | |
| 7.1.x        | 3.0.x        | 0.1.0+          | ⚠️ Compatible | Ruby 3.2+ recommended |
| 7.0.x        | 3.2.5+       | 0.1.0+          | ✅ Supported | |
| 7.0.x        | 3.1.x        | 0.1.0+          | ✅ Supported | |
| 7.0.x        | 3.0.x        | 0.1.0+          | ⚠️ Compatible | Ruby 3.2+ recommended |
| 6.1.x        | 2.7.x        | -               | ❌ Not Supported | Upgrade to Rails 7.0+ |
| < 6.1        | -            | -               | ❌ Not Supported | Upgrade to Rails 7.0+ |

**Legend:**
- ✅ **Fully Supported**: Active development and testing
- ✅ **Supported**: Compatible and tested
- ⚠️ **Compatible**: Should work but not actively tested
- ❌ **Not Supported**: Will not work or untested

**Feature Compatibility:**

| Feature | Rails 7.0+ | Rails 8.0+ | Notes |
|---------|-----------|-----------|-------|
| Core Onboarding | ✅ | ✅ | All versions |
| Turbo Integration | ✅ | ✅ | Enhanced in Rails 8 |
| Stimulus Controllers | ✅ | ✅ | Enhanced in Rails 8 |
| Importmap | ✅ | ✅ | Native support |
| Asset Pipeline (Sprockets) | ✅ | ✅ | |
| Propshaft | ✅ | ✅ | |
| ESBuild/Webpack | ✅ | ✅ | Via jsbundling-rails |
| PostgreSQL | ✅ | ✅ | Recommended for JSONB |
| MySQL | ✅ | ✅ | JSON field support |
| SQLite | ✅ | ✅ | Development/testing only |

### Dependencies

The gem has both required and optional dependencies:

#### Required Dependencies

These dependencies are automatically installed with the gem:

| Gem | Version | Purpose |
|-----|---------|---------|
| rails | >= 8.0.0 | Core Rails framework |

**Note:** While the gemspec specifies Rails >= 8.0.0, the gem is compatible with Rails 7.0+ as shown in the compatibility matrix above. For Rails 7.x support, you may need to adjust the version constraint in your Gemfile.

#### Optional Dependencies

These enhance functionality but are not required:

| Gem | Version | Purpose | When Needed |
|-----|---------|---------|-------------|
| stimulus-rails | >= 1.0.0 | Interactive JavaScript controllers | For Stimulus-based interactivity (tooltips, tours, navigation) |
| turbo-rails | >= 1.0.0 | Hotwire/Turbo integration | For seamless page transitions and real-time updates |
| importmap-rails | >= 1.0.0 | JavaScript module loading | If using importmaps for asset management |
| jsbundling-rails | >= 1.0.0 | JavaScript bundling | If using ESBuild/Webpack for assets |
| cssbundling-rails | >= 1.0.0 | CSS bundling | If using Tailwind/PostCSS/Sass |
| propshaft | >= 0.6.0 | Asset pipeline | Alternative to Sprockets for Rails 7+ |
| sprockets-rails | >= 3.4.0 | Asset pipeline | Traditional asset pipeline support |
| pg | >= 1.1 | PostgreSQL adapter | For JSONB field support (recommended) |
| mysql2 | >= 0.5 | MySQL adapter | For JSON field support |
| sqlite3 | >= 1.4 | SQLite adapter | Development/testing |
| sidekiq | >= 6.0 | Background jobs | For async email sending |
| resque | >= 2.0 | Background jobs | Alternative job processor |
| delayed_job | >= 4.1 | Background jobs | Alternative job processor |
| redis | >= 4.0 | Caching | For production caching with Redis |

#### Installation Recommendations

**Minimal Installation (Core Features Only):**
```ruby
# Gemfile
gem "rails_onboarding"
```

**Recommended Installation (Full Features):**
```ruby
# Gemfile
gem "rails_onboarding"
gem "stimulus-rails"
gem "turbo-rails"
gem "importmap-rails"  # or jsbundling-rails
```

**Full-Featured Installation (All Advanced Features):**
```ruby
# Gemfile
gem "rails_onboarding"
gem "stimulus-rails"
gem "turbo-rails"
gem "importmap-rails"
gem "sidekiq"  # for background jobs
gem "redis"    # for caching
gem "pg"       # for PostgreSQL/JSONB support
```

#### Feature Requirements

Different features require different optional dependencies:

| Feature | Required Dependencies | Optional Dependencies |
|---------|----------------------|----------------------|
| Core Onboarding | rails | - |
| Interactive Tooltips | rails | stimulus-rails |
| Guided Tours | rails | stimulus-rails |
| Turbo Navigation | rails | turbo-rails, stimulus-rails |
| Background Emails | rails | sidekiq/resque/delayed_job, actionmailer |
| Production Caching | rails | redis, actionpack |
| JSONB Tooltips/Milestones | rails | pg (PostgreSQL) |
| Analytics Tracking | rails | - |
| A/B Testing | rails | - |
| Multi-Tenant | rails | - |

#### Checking for Optional Dependencies

The gem automatically detects available dependencies:

```ruby
# Check if Stimulus is available
RailsOnboarding.stimulus_available?

# Check if Turbo is available
RailsOnboarding.turbo_available?

# Check if background jobs are available
RailsOnboarding.background_jobs_available?

# The gem gracefully degrades if optional dependencies are missing
```

## Quick Start

### 1. Include the Onboardable Concern

Add the concern to your User model:

```ruby
# app/models/user.rb
class User < ApplicationRecord
  include RailsOnboarding::Onboardable

  # Your existing code...
end
```

### 2. Configure Your Onboarding Flow

Edit the generated initializer:

```ruby
# config/initializers/rails_onboarding.rb
RailsOnboarding.configure do |config|
  config.user_class_name = 'User'
  config.redirect_after_completion = :dashboard_path
  config.redirect_after_skip = :root_path

  config.steps = [
    { name: :welcome, title: 'Welcome!', icon: '👋', skippable: true },
    { name: :profile, title: 'Setup Profile', icon: '👤', skippable: false },
    { name: :preferences, title: 'Preferences', icon: '⚙️', skippable: true },
    { name: :explore, title: 'Explore Features', icon: '🔍', skippable: true }
  ]
end
```

### 3. Protect Your Controllers

Add onboarding requirement to controllers:

```ruby
# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  include RailsOnboarding::ControllerHelpers

  before_action :require_onboarding
end
```

Skip onboarding for specific actions:

```ruby
class ProfilesController < ApplicationController
  skip_onboarding_requirement only: [:edit, :update]

  def edit
    # Users can access this during onboarding
  end
end
```

### 4. Customize Step Views

Create custom views for your onboarding steps:

```erb
<!-- app/views/rails_onboarding/onboarding/welcome.html.erb -->
<div class="onboarding-step">
  <h1>Welcome to <%= Rails.application.class.name %>!</h1>
  <p>Let's get you started with a quick tour.</p>

  <%= link_to "Get Started", next_step_onboarding_path,
      method: :post,
      class: "btn btn-primary" %>
</div>
```

## Configuration

### Basic Configuration

```ruby
RailsOnboarding.configure do |config|
  # User model configuration
  config.user_class_name = 'User'

  # Redirect paths
  config.redirect_after_completion = :dashboard_path
  config.redirect_after_skip = :root_path

  # Feature flags
  config.enable_tooltips = true
  config.enable_milestones = true
  config.enable_analytics = true

  # Onboarding requirements
  config.onboarding_required_for = :new_users # or :all_users, :none

  # Define your onboarding steps
  config.steps = [
    { name: :welcome, title: 'Welcome', icon: '🎉', skippable: true },
    { name: :profile, title: 'Complete Profile', icon: '👤', skippable: false },
    { name: :first_action, title: 'Take Action', icon: '🚀', skippable: false },
    { name: :explore, title: 'Explore', icon: '🔍', skippable: true }
  ]
end
```

### Step Configuration Options

Each step supports these options:

```ruby
{
  name: :step_name,           # Required: Unique identifier
  title: 'Step Title',        # Required: Display title
  icon: '🎯',                 # Optional: Emoji or icon class
  skippable: true,            # Optional: Can user skip this step?
  description: 'Details...',  # Optional: Additional context
  estimated_time: '2 min',    # Optional: Time estimate
  required_fields: [:name],   # Optional: Required user fields
  condition: ->(user) { ... } # Optional: Show step conditionally
}
```

### Milestone Configuration

```ruby
RailsOnboarding.configure do |config|
  config.enable_milestones = true

  config.milestones = [
    {
      id: 'profile_complete',
      title: 'Profile Master',
      description: 'Completed your profile',
      points: 100,
      icon: '👤',
      trigger: :profile_completed
    },
    {
      id: 'first_post',
      title: 'Content Creator',
      description: 'Created your first post',
      points: 50,
      icon: '📝',
      trigger: :post_created
    }
  ]
end
```

### Analytics Configuration

```ruby
RailsOnboarding.configure do |config|
  config.enable_analytics = true
  config.analytics_retention_days = 90

  # Track specific events
  config.track_events = [
    :onboarding_started,
    :step_viewed,
    :step_completed,
    :onboarding_completed,
    :onboarding_skipped,
    :tooltip_viewed,
    :tooltip_dismissed
  ]
end
```

## Usage

### Checking Onboarding Status

```ruby
# In your controllers or views
if current_user.needs_onboarding?
  redirect_to rails_onboarding.onboarding_path
end

# Check completion
current_user.onboarding_completed? # => true/false
current_user.onboarding_in_progress? # => true/false

# Get progress
current_user.onboarding_progress # => 75 (percentage)
```

### Managing Onboarding State

```ruby
# Advance to next step
current_user.advance_step!

# Go back to previous step
current_user.go_back!

# Complete onboarding
current_user.complete_onboarding!

# Skip onboarding
current_user.skip_onboarding!

# Restart onboarding
current_user.restart_onboarding!
```

### Working with Tooltips

```ruby
# Check if tooltip has been shown
current_user.tooltip_shown?('feature_dashboard') # => false

# Mark tooltip as shown
current_user.mark_tooltip_shown!('feature_dashboard')

# Reset all tooltips
current_user.reset_tooltips!
```

In your views:

```erb
<%= tooltip_tag('feature_reports',
    'Click here to view your reports',
    placement: 'bottom',
    delay: 1000) %>
```

### Working with Milestones

```ruby
# Check milestone achievement
current_user.milestone_achieved?('profile_complete') # => false

# Trigger milestone
current_user.achieve_milestone!('profile_complete', 100)

# Get user's points
current_user.onboarding_milestone_points # => 150

# List achieved milestones
current_user.onboarding_milestones_achieved # => ['first_login', 'profile_complete']
```

### Analytics and Reporting

```ruby
# Get completion rate
RailsOnboarding::Analytics.completion_rate(30.days.ago..Time.current)
# => 0.75

# Get average completion time
RailsOnboarding::Analytics.average_completion_time
# => 320.5 (seconds)

# Get step funnel
RailsOnboarding::Analytics.step_funnel
# => { welcome: { started: 100, completed: 95 }, profile: { started: 95, completed: 80 }, ... }

# Get drop-off points
RailsOnboarding::Analytics.drop_off_points
# => [{ step: 'profile', drop_off_rate: 0.15 }, ...]
```

Run analytics reports:

```bash
# Daily summary
rails rails_onboarding:analytics:daily_summary

# Weekly summary
rails rails_onboarding:analytics:weekly_summary

# Export data
rails rails_onboarding:analytics:export[30]
```

## Advanced Features

### A/B Testing

Test different onboarding flows:

```ruby
# In your User model
include RailsOnboarding::AbTestable

# Assign variant
current_user.assign_ab_variant('flow_test', 'variant_b')

# Track conversion
current_user.track_ab_conversion('flow_test')

# Get results
RailsOnboarding::AbTest.results('flow_test')
```

### Personalization

Adapt onboarding based on user type:

```ruby
# In your initializer
RailsOnboarding.configure do |config|
  config.personalization_strategy = :user_type

  config.flows = {
    developer: {
      steps: [
        { name: :setup_api, title: 'Setup API Keys' },
        { name: :first_integration, title: 'First Integration' }
      ]
    },
    marketer: {
      steps: [
        { name: :create_campaign, title: 'Create Campaign' },
        { name: :add_tracking, title: 'Add Tracking' }
      ]
    }
  }
end

# Use personalized flow
current_user.update(user_type: 'developer')
current_user.personalized_onboarding_flow # Returns developer flow
```

### Progressive Disclosure

Reveal features over time:

```ruby
# In your controller
class FeaturesController < ApplicationController
  include RailsOnboarding::ProgressiveDisclosure

  def advanced_reports
    feature = ProgressiveFeature.find_by(feature_key: 'advanced_reports')

    if feature_unlocked_for?(current_user, feature)
      # Show feature
    else
      # Show teaser or locked state
    end
  end
end
```

### Multi-Tenant Support

Different onboarding per organization:

```ruby
# Configure per-organization
RailsOnboarding::MultiTenant.configure_for_organization(org.id) do |config|
  config.steps = org.custom_onboarding_steps
  config.enable_tooltips = org.tooltips_enabled?
end

# Use in your app
config = RailsOnboarding::MultiTenant.configuration_for(current_user.organization_id)
```

### Interactive Tours

Create guided tours with spotlight effects:

```erb
<div data-controller="tour"
     data-tour-steps-value='<%= tour_steps.to_json %>'>

  <button data-action="tour#start">Start Tour</button>

  <div data-tour-target="dashboard">Dashboard</div>
  <div data-tour-target="reports">Reports</div>
</div>
```

### Background Jobs

Queue onboarding emails and notifications:

```ruby
# In your config
RailsOnboarding.configure do |config|
  config.background_job_adapter = :sidekiq # or :resque, :delayed_job
end

# Trigger in your code
RailsOnboarding::BackgroundJobs.send_welcome_email(user)
RailsOnboarding::BackgroundJobs.send_milestone_notification(user, milestone)
```

### Skip Logic

Conditionally skip steps based on user data:

```ruby
RailsOnboarding.configure do |config|
  config.skip_logic = {
    profile: ->(user) { user.profile_complete? },
    payment: ->(user) { user.plan == 'free' }
  }
end
```

### Error Recovery

Handle failures gracefully:

```ruby
# Retry failed steps
current_user.retry_step!('profile')

# Track errors
RailsOnboarding::ErrorRecovery.log_error(user, step, error)

# Get error count
current_user.step_error_count('profile')
```

## Pre-built Templates

Use ready-made onboarding flows:

```ruby
# Apply a template
RailsOnboarding::Templates.apply('saas')

# Available templates:
# - 'saas'        - SaaS application onboarding
# - 'ecommerce'   - E-commerce store setup
# - 'marketplace' - Marketplace seller onboarding
# - 'community'   - Community platform onboarding
# - 'education'   - Educational platform onboarding
```

## API Reference

### User Model Methods (Onboardable Concern)

#### Status Methods
- `needs_onboarding?` - Returns true if user needs to complete onboarding
- `onboarding_completed?` - Returns true if onboarding is complete
- `onboarding_in_progress?` - Returns true if onboarding is in progress
- `onboarding_skipped?` - Returns true if user skipped onboarding

#### Navigation Methods
- `current_step_index` - Returns index of current step
- `next_step` - Returns next step name
- `previous_step` - Returns previous step name
- `can_go_back?` - Returns true if can navigate backwards
- `last_step?` - Returns true if on last step

#### Action Methods
- `advance_step!` - Move to next step
- `go_back!` - Move to previous step
- `complete_onboarding!` - Mark onboarding as complete
- `skip_onboarding!` - Skip onboarding
- `restart_onboarding!` - Restart from beginning

#### Progress Methods
- `onboarding_progress` - Returns completion percentage (0-100)

#### Tooltip Methods
- `tooltip_shown?(tooltip_id)` - Check if tooltip was shown
- `mark_tooltip_shown!(tooltip_id)` - Mark tooltip as shown
- `reset_tooltips!` - Reset all tooltips

#### Milestone Methods
- `milestone_achieved?(milestone_id)` - Check achievement status
- `achieve_milestone!(milestone_id, points)` - Record achievement
- `onboarding_milestone_points` - Get total points
- `onboarding_milestones_achieved` - Get list of achievements

### Controller Helpers

- `require_onboarding` - Before action to enforce onboarding
- `skip_onboarding_requirement` - Skip requirement for specific actions
- `user_needs_onboarding?` - Check if current user needs onboarding
- `onboarding_path` - Get path to onboarding flow

### Configuration Class

- `RailsOnboarding.configure { |config| ... }` - Configure the gem
- `RailsOnboarding.configuration` - Access current configuration
- `RailsOnboarding.reset_configuration!` - Reset to defaults

### Analytics Class

- `Analytics.completion_rate(date_range)` - Get completion rate
- `Analytics.average_completion_time` - Get average time
- `Analytics.step_funnel` - Get step-by-step funnel data
- `Analytics.drop_off_points` - Identify where users drop off
- `Analytics.tooltip_engagement` - Get tooltip metrics

## Testing

The gem includes comprehensive test coverage. Run tests with:

```bash
# Run all tests
bundle exec rails test

# Run specific test file
bundle exec rails test test/integration/navigation_test.rb

# Run with coverage
COVERAGE=true bundle exec rails test
```

### Testing in Your Application

Add helpers to your test suite:

```ruby
# test/test_helper.rb
require 'rails_onboarding/test_helpers'

class ActiveSupport::TestCase
  include RailsOnboarding::TestHelpers
end
```

Use in tests:

```ruby
class MyFeatureTest < ActionDispatch::IntegrationTest
  test "requires onboarding" do
    user = create_user_needing_onboarding

    sign_in user
    get dashboard_path

    assert_redirected_to onboarding_path
  end

  test "allows access after onboarding" do
    user = create_user_with_completed_onboarding

    sign_in user
    get dashboard_path

    assert_response :success
  end
end
```

## Internationalization

The gem supports multiple languages:

```yaml
# config/locales/rails_onboarding.en.yml
en:
  rails_onboarding:
    welcome:
      title: "Welcome!"
      description: "Let's get started"
    buttons:
      next: "Next"
      previous: "Back"
      skip: "Skip for now"
      complete: "Finish"
```

Set user locale:

```ruby
# Before onboarding
current_user.update(locale: 'es')
```

## Troubleshooting

### Onboarding not triggering

Ensure you have:
1. Included the concern in your User model
2. Run the migration
3. Added `before_action :require_onboarding` to controllers
4. Configured at least one step

### Assets not loading

For Asset Pipeline:

```ruby
# app/assets/config/manifest.js
//= link rails_onboarding/application.css
//= link rails_onboarding/application.js
```

For Propshaft/Importmap:

```ruby
# config/importmap.rb
pin "rails_onboarding", to: "rails_onboarding/application.js"
```

### Stimulus controllers not working

Ensure Stimulus is installed and configured:

```bash
bin/rails stimulus:manifest:update
```

## Upgrading

See [MIGRATION_GUIDE.md](MIGRATION_GUIDE.md) for version upgrade instructions.

## Performance Considerations

### Caching

Enable caching for better performance:

```ruby
# config/environments/production.rb
config.cache_store = :redis_cache_store

# In your initializer
RailsOnboarding.configure do |config|
  config.cache_configuration = true
  config.cache_ttl = 1.hour
end
```

### Database Indexes

Add indexes for frequently queried fields:

```ruby
add_index :users, :onboarding_completed
add_index :users, :onboarding_current_step
add_index :analytics_events, [:user_id, :event_type]
add_index :analytics_events, :created_at
```

## Security

The gem follows Rails security best practices:
- CSRF protection enabled
- SQL injection prevention
- XSS protection with content sanitization
- Secure session handling

## Browser Support

- Chrome/Edge (last 2 versions)
- Firefox (last 2 versions)
- Safari (last 2 versions)
- Mobile browsers (iOS Safari, Chrome Mobile)

## Contributing

We welcome contributions! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for details.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Write tests for your changes
4. Ensure all tests pass (`bundle exec rails test`)
5. Commit your changes (`git commit -m 'Add amazing feature'`)
6. Push to the branch (`git push origin feature/amazing-feature`)
7. Open a Pull Request

## Documentation

- [Advanced Features Guide](ADVANCED_FEATURES.md)
- [Milestone System Guide](MILESTONES_GUIDE.md)
- [Analytics Guide](ANALYTICS_GUIDE.md)
- [Responsive Design Guide](RESPONSIVE_DESIGN.md)
- [Performance & Scalability Guide](PERFORMANCE_GUIDE.md)
- [API Documentation](API_DOCUMENTATION.md)
- [Migration Guide](MIGRATION_GUIDE.md)

## Credits

Created and maintained by [David Lewis](https://github.com/bunnahabhain).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Support

- 📫 Email: david@davidsfolly.com
- 🐛 Issues: [GitHub Issues](https://github.com/bunnahabhain/rails_onboarding/issues)
- 💬 Discussions: [GitHub Discussions](https://github.com/bunnahabhain/rails_onboarding/discussions)
- 📖 Wiki: [GitHub Wiki](https://github.com/bunnahabhain/rails_onboarding/wiki)

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for a list of changes.
