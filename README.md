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
- [Admin Dashboard](#admin-dashboard)
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

> **Prerequisite:** A `User` model must already exist at `app/models/user.rb`. The generator checks for it and stops with an error if it's missing. Create one first (for example `rails generate model User email:string`) if you don't have it yet.

This will:
- Create an initializer at `config/initializers/rails_onboarding.rb`
- Generate six migrations: onboarding fields on your `User` model, the analytics event tables, the onboarding flows table, milestone tracking fields, performance indexes, and robustness/error-recovery fields
- Mount the engine in your routes at `/onboarding`
- Add a customizable stylesheet at `app/assets/stylesheets/rails_onboarding_custom.css`

Run the migrations:

```bash
bin/rails db:migrate
```

The `User` migration adds `onboarding_completed`, `onboarding_completed_at`, `onboarding_current_step`, `onboarding_skipped`, and `feature_tooltips_shown` (stored as `jsonb` on PostgreSQL, `json` on MySQL/MariaDB, and serialized `text` elsewhere), along with the indexes needed to query onboarding state efficiently. On PostgreSQL these indexes are built concurrently so the migration won't lock a large, live `users` table.

### Installing into an app that already has users

The migration leaves every existing user with empty onboarding columns, so the
admin reports them all as "Not Started" and — depending on your
`onboarding_required_for` setting — they may be pushed into a flow they don't
need. Backfill them once, after migrating:

```bash
# See what would change first
bin/rails rails_onboarding:backfill_existing_users DRY_RUN=true

# Apply it
bin/rails rails_onboarding:backfill_existing_users
```

| Variable | Default | Purpose |
|----------|---------|---------|
| `BEFORE` | none | Only backfill users created before this date, e.g. `BEFORE=2026-07-01`. Use it when the gem has been live for a while and you only want to grandfather in the pre-install cohort. Users with a `NULL` `created_at` are always included. |
| `DRY_RUN` | `false` | Report the count without writing. |
| `BATCH_SIZE` | `1000` | Rows per `UPDATE`. |

Only users who have never engaged with onboarding are touched — not completed,
not skipped, and on no current step — so anyone mid-flow is left alone and the
task is safe to re-run on a live app. `onboarding_completed_at` is taken from
each user's own `created_at` (falling back to now when that is `NULL`), which
keeps your completion-over-time charts from spiking on backfill day. No
analytics events are recorded: these users never actually went through
onboarding, and inventing events would corrupt your funnel metrics.

It's also available from the console, where `pending_scope` lets you inspect
exactly who is about to be affected:

```ruby
RailsOnboarding::Backfill.pending_scope(created_before: "2026-07-01").pluck(:id, :email)
RailsOnboarding::Backfill.mark_existing_users_onboarded(created_before: "2026-07-01")
```

## Requirements

This gem requires:
1. **Rails 8.0+** (enforced by the gemspec)
2. **Ruby 3.4.9+** (enforced by the gemspec)
3. An `ApplicationController` class
4. A `current_user` method available in your controllers
5. Authentication system (Devise, custom, etc.)

### Version Compatibility Matrix

| Rails Version | Ruby Version | rails_onboarding | Status | Notes |
|--------------|--------------|------------------|--------|-------|
| 8.0.x        | 3.4.9+       | 0.1.0+          | ✅ Supported | Minimum required by the gemspec |
| < 8.0        | -            | -               | ❌ Not Supported | Rails 8.0+ required |
| any          | < 3.4.9      | -               | ❌ Not Supported | Ruby 3.4.9+ required |

**Legend:**
- ✅ **Supported**: Meets the gemspec's version constraints
- ❌ **Not Supported**: Will not install (blocked by the gemspec's version constraints)

**Feature/Toolchain Compatibility (Rails 8.0+):**

| Feature | Supported | Notes |
|---------|-----------|-------|
| Core Onboarding | ✅ | |
| Turbo Integration | ✅ | Via turbo-rails |
| Stimulus Controllers | ✅ | Via stimulus-rails |
| Importmap | ✅ | Native support |
| Asset Pipeline (Sprockets) | ✅ | |
| Propshaft | ✅ | |
| ESBuild/Webpack | ✅ | Via jsbundling-rails |
| PostgreSQL | ✅ | Recommended for JSONB |
| MySQL/MariaDB | ✅ | JSON field support |
| SQLite | ✅ | Development/testing only |

### Dependencies

The gem has both required and optional dependencies:

#### Required Dependencies

These dependencies are automatically installed with the gem:

| Gem | Version | Purpose |
|-----|---------|---------|
| rails | >= 8.0.0 | Core Rails framework |
| csv | (latest) | Admin CSV exports (no longer a Ruby default gem as of Ruby 3.4) |

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

`RailsOnboarding::ControllerHelpers` is included into `ActionController::Base`
automatically by the engine, giving every controller a `needs_onboarding?`
predicate (it already accounts for XHR/JSON requests, the onboarding page
itself, and per-action skips - see below). The gem doesn't redirect for you;
wire up a `before_action` in your own `ApplicationController`:

```ruby
# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  before_action :redirect_to_onboarding_if_needed

  private

  def redirect_to_onboarding_if_needed
    redirect_to onboarding_path if needs_onboarding?
  end
end
```

Skip onboarding for specific actions:

```ruby
class ProfilesController < ApplicationController
  skip_onboarding_check only: [:edit, :update] # or except: [...]

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

  <%= link_to "Get Started", next_onboarding_path,
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
  condition: ->(user) { ... },# Optional: Show step conditionally
  path: :new_profile_path,    # Optional: Host-app page that owns this step
                              #   (Symbol/String route helper, or a zero-arg
                              #   Proc evaluated in the controller context)
  complete_if: ->(user) {     # Optional: Predicate checked on each visit to
    user.profile.present?     #   /onboarding - when true, the step is
  }                           #   completed and the user advances
}
```

### Reusing Existing Controllers and Views (`path:` steps)

By default each step is rendered by the gem from
`app/views/rails_onboarding/onboarding/<step_name>.html.erb`. That's right
for pure-content steps (a welcome screen, a feature tour), but wrong for
steps your app already has a page for - duplicating your profile form into
an onboarding template means two copies to keep in sync.

Give those steps a `path:` instead. Visiting `/onboarding` then redirects to
your real page, and your existing controller and view do all the work - the
gem only tracks progress:

```ruby
config.steps = [
  { name: :welcome, title: 'Welcome', skippable: true },     # gem-rendered
  { name: :profile, title: 'Set up your profile', icon: '👤',
    path: :new_profile_path,
    complete_if: ->(user) { user.profile.present? } },
  { name: :first_post, title: 'Create your first post',
    path: -> { main_app.new_post_path(from: 'onboarding') },
    complete_if: ->(user) { user.posts.exists? } }
]
```

A `path:` step is completed in one of two ways:

1. **Declaratively** via `complete_if:` - whenever the user lands back on
   `/onboarding`, every satisfied step is skipped automatically. Your
   controllers never have to know onboarding exists.
2. **Explicitly** via `advance_onboarding!` in the host controller - useful
   when completion isn't derivable from persisted state:

   ```ruby
   class ProfilesController < ApplicationController
     def create
       @profile = current_user.build_profile(profile_params)
       if @profile.save
         return redirect_to onboarding_path if advance_onboarding!(:profile)
         redirect_to @profile
       else
         render :new, status: :unprocessable_entity
       end
     end
   end
   ```

   `advance_onboarding!` is a no-op unless the named step is the user's
   *current* onboarding step, so the same action behaves normally when the
   user edits their profile outside onboarding.

A `path:` step with neither `complete_if:` nor `skippable: true` can only
advance through an explicit `advance_onboarding!` call - the validator logs
a warning for such steps so a missing call doesn't silently trap users.

To keep the guided feel while users are on your own pages, render the
gem's progress banner from your layout. It shows current step, progress,
a "Continue setup" link, and a skip button (on skippable steps), and renders
nothing once onboarding is done, skipped, or not required:

```erb
<body>
  <%= render "rails_onboarding/shared/onboarding_banner" %>
  <%= yield %>
</body>
```

If you guard pages with `redirect_to onboarding_path if needs_onboarding?`,
that guard automatically stays off the current step's own page - the gem
recognizes it and lets the request through, so the redirect loop you'd
expect from `/onboarding` bouncing to the page and back can't happen.

### Milestone Configuration

```ruby
RailsOnboarding.configure do |config|
  config.enable_milestones = true

  config.milestones = [
    {
      key: :profile_complete,
      title: 'Profile Master',
      description: 'Completed your profile',
      points: 100,
      icon: '👤',
      trigger: :profile_completed
    },
    {
      key: :first_post,
      title: 'Content Creator',
      description: 'Created your first post',
      points: 50,
      icon: '📝',
      trigger: :post_created
    }
  ]
end
```

Each milestone is identified by `key:`, not `id:` — `milestone_by_key`,
`milestone_achieved?` and the achievement records all look it up by that
field. A milestone without `key:` fails configuration validation at boot with
`InvalidMilestoneError`, so a typo here surfaces immediately rather than
producing achievements nothing can find. `trigger:` is required as well;
`title`, `description`, `points` and `icon` are what the milestone views
display.

### Analytics Configuration

```ruby
RailsOnboarding.configure do |config|
  config.enable_analytics = true

  # How long to keep analytics rows (days)
  config.analytics_retention_days = 90

  # Inactivity after which a visit counts as a new session
  config.analytics_session_timeout_minutes = 30
end
```

Onboarding events (`onboarding_started`, `step_viewed`, `step_completed`,
`onboarding_completed`, `onboarding_skipped`, tooltip views and dismissals) are
recorded automatically while `enable_analytics` is on; there is no per-event
opt-in list.

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

# Reset onboarding state (clears milestones too; pass clear_milestones: false to keep them)
current_user.reset_onboarding!

# Restart onboarding - resets and walks the user through the steps again, even
# if their data already satisfies every :complete_if
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

There's no `tooltip_tag` helper - render the Stimulus controller directly,
gated by `show_feature_tooltip?`, with the copy in a `content` target (the
controller can't read your Ruby config, so the text has to be in the DOM)
and the dismiss URL pointed at the engine's real route:

```erb
<% if current_user.show_feature_tooltip?("feature_reports") %>
  <div data-controller="tooltip"
       data-tooltip-feature-value="feature_reports"
       data-tooltip-position-value="bottom"
       data-tooltip-delay-value="1000"
       data-tooltip-dismiss-url-value="<%= rails_onboarding.dismiss_tooltip_path(tooltip_id: "feature_reports") %>">
    <button data-tooltip-target="trigger" class="btn">Reports</button>
    <div data-tooltip-target="content" hidden>
      Click here to view your reports
    </div>
  </div>
<% end %>
```

Register `config.feature_tooltips["feature_reports"]` in your initializer
first (see [Configuration](#configuration) below) - `show_feature_tooltip?`
returns false for anything not configured there, even if the DOM above is
present.

### Working with Milestones

```ruby
# Check milestone achievement
current_user.milestone_achieved?(:profile_complete) # => false

# Record an achievement. Points come from the milestone's configuration -
# they are not passed in. Returns false if milestones are disabled, the key
# is unknown, or it was already achieved.
current_user.achieve_milestone!(:profile_complete) # => true

# Get user's points
current_user.total_milestone_points # => 150

# List achieved milestone keys
current_user.achieved_milestones # => ['first_login', 'profile_complete']

# Turn those keys into renderable hashes
current_user.achieved_milestones.filter_map { |key|
  RailsOnboarding.configuration.milestone_by_key(key)
}
```

#### Displaying milestones

The engine ships a milestones dashboard at `rails_onboarding.milestones_path`,
and two partials you render yourself when you want achievements to appear
inside your own pages. Both take a milestone hash in the shape
`config.milestones` uses — `key`, `title`, `description`, `points`, `icon`.

**A badge**, for listing achievements in a profile or sidebar. `achieved:`
decides whether it renders unlocked or with a lock overlay:

```erb
<% RailsOnboarding.configuration.milestones.each do |milestone| %>
  <%= render "rails_onboarding/shared/milestone_badge",
             milestone: milestone,
             achieved: current_user.milestone_achieved?(milestone[:key]) %>
<% end %>
```

**A celebration**, a modal overlay that shows itself as soon as it connects,
fires confetti, and auto-dismisses after eight seconds. Render it only when
you have something to celebrate — it is not self-guarding the way the
onboarding banner is:

```erb
<% if (milestone = current_user.recent_milestones(limit: 1).first) %>
  <%= render "rails_onboarding/shared/milestone_celebration",
             milestone: milestone %>
<% end %>
```

Both partials need `rails_onboarding/milestones.css` loaded, and the
celebration additionally needs its Stimulus controller registered — without
it the overlay stays hidden, since it is rendered with `is-hidden` and the
controller is what reveals it. See the
[Asset Loading Guide](docs/ASSET_LOADING_GUIDE.md) for both.

Useful sources for the milestone hashes:

| Call | Returns |
|---|---|
| `RailsOnboarding.configuration.milestones` | every configured milestone |
| `RailsOnboarding.configuration.milestone_by_key(key)` | one milestone, or `nil` |
| `current_user.milestones_available` | configured milestones not yet achieved |
| `current_user.recent_milestones(limit: 5)` | most recently achieved, newest last |
| `current_user.achieved_milestones` | achieved **keys**, not hashes |
| `current_user.total_milestone_points` | integer |

Note that `achieved_milestones` returns keys rather than hashes; pass each
through `milestone_by_key` to get something the partials can render.

### Flash Messages

The engine reports some conditions — a step that can't be skipped, a "back"
from the first step — by replacing a `flash-messages` element over Turbo.
That element only exists if you render the gem's flash partial, so without it
those messages are silently dropped. Render it once in your layout:

```erb
<body>
  <%= render "rails_onboarding/shared/flash" %>
  <%= yield %>
</body>
```

Rendered with no locals it displays `flash[:notice]` and `flash[:alert]`,
because `notice` and `alert` are the standard Rails view helpers. You can
also pass messages explicitly, which is what the engine's own Turbo responses
do:

```erb
<%= render "rails_onboarding/shared/flash", alert: "This step cannot be skipped." %>
```

| Local | Style | Notes |
|---|---|---|
| `notice:` | success (green, ✓) | falls back to `flash[:notice]` |
| `alert:` | warning (amber, ⚠) | falls back to `flash[:alert]` |
| `error:` | error (red, ✕) | explicit only — there is no `error` view helper |

Each message renders with `role="alert"` and its own dismiss button, which
needs no JavaScript from you. Styling comes from
`rails_onboarding/flash_messages.css`.

Two things worth knowing. The partial's root element carries
`id="flash-messages"`, and that is what the engine's Turbo Stream responses
replace — so keep the id if you copy the partial into your own app, or those
updates will stop landing. And unlike the onboarding banner, this partial is
not self-guarding: rendered with no flash set and no locals it emits an empty
container, which is harmless but not nothing, so place it where an empty
`div` won't disturb your layout.

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
  config.personalization_enabled = true

  # Method called on the user to determine their type (default: :user_type)
  config.user_type_method = :user_type

  # Each flow is a plain array of steps, keyed by user type
  config.personalized_flows = {
    developer: [
      { name: :setup_api, title: 'Setup API Keys' },
      { name: :first_integration, title: 'First Integration' }
    ],
    marketer: [
      { name: :create_campaign, title: 'Create Campaign' },
      { name: :add_tracking, title: 'Add Tracking' }
    ]
  }
end
```

Include `RailsOnboarding::Personalizable` in your User model, and the matching
flow is applied when onboarding starts:

```ruby
current_user.update(user_type: 'developer')
current_user.personalized_steps # => the developer flow
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
  config.background_jobs_enabled = true
  config.background_jobs_queue = :default
end
```

`BackgroundJobs` is a concern. Include it where you want to queue work, and
configure the adapter per class if the ActiveJob default doesn't suit:

```ruby
class OnboardingController < ApplicationController
  include RailsOnboarding::BackgroundJobs

  configure_background_jobs(adapter: :sidekiq, queue: :onboarding)

  def complete
    queue_onboarding_welcome_email(current_user)
    queue_milestone_achievement(current_user, :first_login)
  end
end
```

### Skip Logic

Conditionally skip steps based on user data:

Skip conditions live on the step itself, under `skip_if:`. It accepts a proc, a
predicate method name, or a hash:

```ruby
RailsOnboarding.configure do |config|
  config.steps = [
    { name: :welcome, title: 'Welcome' },
    { name: :profile, title: 'Setup Profile',
      skip_if: ->(user) { user.profile_complete? } },
    { name: :payment, title: 'Add Payment',
      skip_if: :free_plan? },
    { name: :team, title: 'Invite Team',
      skip_if: { account_type: 'individual' } }
  ]
end
```

The hash form matches an attribute by default, and also understands
`has_attribute`, `missing_attribute`, `attribute_equals`,
`attribute_not_equals`, `has_role` and `custom`. Combine several with
`operator: :all` (the default), `:any`, or `:none`:

```ruby
skip_if: {
  operator: :any,
  has_role: :admin,
  missing_attribute: :company_name
}
```

A condition that raises is logged and treated as false, so a broken predicate
never blocks the flow.

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

## Admin Dashboard

The engine ships a full admin dashboard - a stats overview, per-user onboarding management (view progress, reset, complete, or restart onboarding), a flow editor, and A/B test management. It's mounted automatically wherever you mounted the engine, at `/admin` under that path (`/onboarding/admin` if you used the default mount point from the installer).

It ships gated behind an authorization check you need to wire up - by default nothing has admin access.

### 1. Add an `admin?` method to your `User` model

```ruby
class User < ApplicationRecord
  def admin?
    role == "admin" # or however you track it
  end
end
```

With this in place and a `current_user` method available on your `ApplicationController` (e.g. from Devise), the default check - `current_user.present? && current_user.admin?` - is all you need.

### 2. Or override the authentication method for custom logic

If you need something more specific than `current_user.admin?` (a different gate, a different method name for the current user, etc.), define this instead and it takes priority over the default check entirely:

```ruby
class ApplicationController < ActionController::Base
  def authenticate_rails_onboarding_admin!
    redirect_to root_path, alert: "Not authorized" unless current_user&.admin?
  end
end
```

Leaving both `admin?` and `authenticate_rails_onboarding_admin!` undefined isn't a silent hole - visiting the dashboard raises a `NotImplementedError` that redirects with a message telling you to define one of them.

No extra asset tags are required for the dashboard itself: its layout (`app/views/layouts/rails_onboarding/admin.html.erb`) is self-contained with its own `<head>` and stylesheet/JS tags, separate from your app's layout.

### 3. Customizing the user search (encrypted email columns)

The User Management search box matches on email and ID with plain SQL. If your
`User` model encrypts email, that SQL is comparing against ciphertext, so the
admin adapts automatically: deterministic encryption falls back to exact
address matching, and non-deterministic encryption skips email entirely. ID
search always works.

Partial matching over an encrypted column can't be done in SQL at all. Only
your app knows what it's willing to trade for it, so supply the strategy
yourself:

```ruby
# config/initializers/rails_onboarding.rb
config.admin_user_search = lambda do |scope, term|
  needle = term.to_s.downcase
  ids = scope.select(:id, :email).filter_map do |user|
    user.id if user.email.to_s.downcase.include?(needle)
  end
  scope.where(id: ids)
end
```

That example decrypts in Ruby, which leaks nothing and needs no schema change,
but is O(n) per search — fine for hundreds or low thousands of users, not for
a large table. The alternative is a searchable index of your own (a trigram or
prefix blind index), which scales but leaks substantially more about the
addresses than deterministic encryption alone.

The lambda receives the scope already narrowed by the status and step filters,
plus the raw search term, and **must return a relation** — returning an array
silently drops sorting and pagination.

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
- `reset_onboarding!(clear_milestones: true)` - Clear onboarding state
- `restart_onboarding!` - Reset and re-walk the flow (replay mode)
- `replaying_onboarding?` - Is the user re-walking the flow?

#### Progress Methods
- `onboarding_progress` - Returns completion percentage (0-100)

#### Tooltip Methods
- `tooltip_shown?(tooltip_id)` - Check if tooltip was shown
- `mark_tooltip_shown!(tooltip_id)` - Mark tooltip as shown
- `reset_tooltips!` - Reset all tooltips

#### Milestone Methods
- `milestone_achieved?(key)` - Check achievement status
- `achieve_milestone!(key, session_id: nil)` - Record achievement; points are read from the milestone's configuration
- `total_milestone_points` - Get total points
- `achieved_milestones` - Get achieved milestone **keys** (not hashes)
- `milestones_available` - Configured milestones not yet achieved, as hashes
- `recent_milestones(limit: 5)` - Most recently achieved, as hashes, newest last

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
2. Run the migrations
3. Added a `before_action` that redirects when `needs_onboarding?` is true (see [Protect Your Controllers](#3-protect-your-controllers) - the gem doesn't add this callback for you)
4. Configured at least one step

### Assets not loading

The engine's CSS and JS aren't included in your layout automatically.

**On Sprockets**, `rails_onboarding/application.css` bundles all of the
gem's stylesheets itself via internal `require` directives, so one tag is
enough:

```erb
<%= stylesheet_link_tag "rails_onboarding/application" %>
<%= javascript_include_tag "rails_onboarding/application", defer: true %>
```

You can alternatively link them via the manifest:

```js
// app/assets/config/manifest.js
//= link rails_onboarding/application.css
//= link rails_onboarding/application.js
```

**On Propshaft** (Rails 8's default, including with cssbundling-rails),
there's no bundling directive processor - `application.css`'s internal
`require` directives are inert comments, so it only contains its own base
styles/tokens. Link every stylesheet individually or you'll silently be
missing tooltips, tours, milestones, mobile responsiveness, and more:

```erb
<%= stylesheet_link_tag "rails_onboarding/application" %>
<%= stylesheet_link_tag "rails_onboarding/tooltips" %>
<%= stylesheet_link_tag "rails_onboarding/utilities" %>
<%= stylesheet_link_tag "rails_onboarding/accessibility" %>
<%= stylesheet_link_tag "rails_onboarding/milestones" %>
<%= stylesheet_link_tag "rails_onboarding/tour" %>
<%= stylesheet_link_tag "rails_onboarding/flash_messages" %>
<%= stylesheet_link_tag "rails_onboarding/progressive_disclosure" %>
<%= stylesheet_link_tag "rails_onboarding/admin" %>
<%= stylesheet_link_tag "rails_onboarding/mobile" %>
<%= javascript_include_tag "rails_onboarding/application", defer: true %>
```

Keep `application` first (it defines the `--onboarding-*` custom properties
the rest use) and `mobile` last (its media-query overrides need to win
cascade ties). Skip `admin` if you don't use the admin dashboard. This is
unrelated to cssbundling-rails - these tags bypass your JS/CSS build
pipeline and are served by Propshaft directly.

If you're on Importmap, the engine's `config/importmap.rb` pins are drawn
into your app's importmap automatically - you don't need to pin anything
yourself. You do still need to import and register the Stimulus controllers
you use (see [Asset Loading Guide](docs/ASSET_LOADING_GUIDE.md)), since
pinning a module only makes it loadable, not registered with Stimulus.

### Gem styles bleeding into my app's pages

They shouldn't, and as of 0.4.0 they don't. Every rule in
the gem's stylesheets is confined to markup the engine owns, scoped with
`:where(.onboarding-container)` for engine pages or
`:where(.onboarding-banner)` for the banner rendered on your own pages. It
is safe to bundle the gem's CSS globally.

If you are on an older version and see symptoms like every link on your
homepage suddenly underlined, tables and fieldsets restyled, or buttons
forced to a 44px minimum, that's the pre-fix `accessibility.css` — it
carried unscoped `a`, `table`, `fieldset`, `button` and `[role="dialog"]`
selectors, and under Sprockets `*= require rails_onboarding/application`
pulls in every gem stylesheet via `require_tree`. Upgrade, or drop the
`require` from your host `application.css` and link the individual
stylesheets you need.

Two utility classes are namespaced rather than scoped, because they are
meant to be used outside the container: `.onboarding-sr-only` (screen-reader
text) and `.onboarding-skip-link` (a skip link has to be the first focusable
element in the document). If you used the older `.sr-only` / `.skip-link`
names in your own markup, rename them.

The gem does define `--onboarding-*` custom properties on `:root`, which is
intentional — that's the supported way to retheme it from your own
stylesheet:

```css
:root {
  --onboarding-primary: #0f766e;
  --onboarding-primary-hover: #115e59;
}
```

### Do I need to load accessibility.css?

Yes — load it like any other gem stylesheet. It isn't gated on a user
preference and there's no toggle to switch it on for people who need it.
Most of it is unconditional baseline: focus indicators, 44px touch targets,
screen-reader text, disabled-state contrast. Focus rings use `:focus-visible`,
so browsers already paint them only for keyboard and assistive-technology
users, not on mouse clicks. The parts that *are* preference-dependent —
`prefers-contrast: high`, `prefers-reduced-motion: reduce`,
`prefers-color-scheme: dark` — are gated by the browser off the user's OS
setting, with nothing for your app to detect or configure.

### Stimulus controllers not working

Ensure Stimulus is installed and configured:

```bash
bin/rails stimulus:manifest:update
```

## Upgrading

See [MIGRATION_GUIDE.md](docs/MIGRATION_GUIDE.md) for version upgrade instructions.

## Performance Considerations

### Caching

Enable caching for better performance:

Caching is opt-in at the call site rather than through configuration - include
`RailsOnboarding::Caching` and use the cached readers, each taking its own
`ttl:` in seconds:

```ruby
# config/environments/production.rb
config.cache_store = :redis_cache_store
```

```ruby
class User < ApplicationRecord
  include RailsOnboarding::Caching
end

User.cached_steps(ttl: 1.hour)      # configuration lookups
current_user.cached_onboarding_progress  # per-user, defaults to 5 minutes

# Call after changing configuration
User.clear_config_cache
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

Contributions are welcome. In short:

1. Fork the repository and branch from `master`
2. Write a test for your change
3. Check it with `bin/rails test` and `bin/rubocop`
4. Add a changelog entry if the change is user-visible
5. Open a pull request

See [CONTRIBUTING.md](CONTRIBUTING.md) for setup, how the test suite is laid
out, and the conventions this project follows.

## Documentation

- [Advanced Features Guide](docs/ADVANCED_FEATURES.md)
- [Milestone System Guide](docs/MILESTONES_GUIDE.md)
- [Analytics Guide](docs/ANALYTICS_GUIDE.md)
- [Responsive Design Guide](docs/RESPONSIVE_DESIGN.md)
- [Performance & Scalability Guide](docs/PERFORMANCE_GUIDE.md)
- [API Documentation](docs/API_DOCUMENTATION.md)
- [Migration Guide](docs/MIGRATION_GUIDE.md)
- [ESBuild Setup Guide](docs/ESBUILD_SETUP.md)
- [Configuration Validation Guide](docs/CONFIGURATION_VALIDATION.md)

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

See [CHANGELOG.md](docs/CHANGELOG.md) for a list of changes.
