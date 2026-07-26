# Rails Onboarding - API Documentation

Complete API reference for all public methods, classes, and modules in the Rails Onboarding gem.

## Table of Contents

- [Concerns](#concerns)
  - [Onboardable](#onboardable)
  - [AbTestable](#abtestable)
  - [ProgressiveDisclosure](#progressivedisclosure)
  - [Personalizable](#personalizable)
- [Controllers](#controllers)
  - [OnboardingController](#onboardingcontroller)
  - [TooltipsController](#tooltipscontroller)
  - [MilestonesController](#milestonescontroller)
- [Models](#models)
  - [Analytics](#analytics)
  - [AnalyticsEvent](#analyticsevent)
- [Helpers](#helpers)
  - [ControllerHelpers](#controllerhelpers)
  - [ResponsiveHelper](#responsivehelper)
- [Configuration](#configuration)
- [Services](#services)

---

## Concerns

### Onboardable

Include in your User model to enable onboarding functionality.

```ruby
include RailsOnboarding::Onboardable
```

#### Status Methods

##### `needs_onboarding?`

Returns true if the user needs to complete onboarding.

```ruby
current_user.needs_onboarding?
# => true
```

**Returns:** `Boolean`

**Logic:** Returns `true` if:
- `onboarding_completed` is `false` AND
- `onboarding_skipped` is `false`

---

##### `onboarding_completed?`

Returns true if onboarding has been completed.

```ruby
current_user.onboarding_completed?
# => true
```

**Returns:** `Boolean`

---

##### `onboarding_in_progress?`

Returns true if onboarding is currently in progress.

```ruby
current_user.onboarding_in_progress?
# => true
```

**Returns:** `Boolean`

**Logic:** Same as `needs_onboarding?`

---

##### `onboarding_skipped?`

Returns true if the user skipped onboarding.

```ruby
current_user.onboarding_skipped?
# => false
```

**Returns:** `Boolean`

---

#### Navigation Methods

##### `current_step_index`

Returns the index of the current onboarding step.

```ruby
current_user.current_step_index
# => 2
```

**Returns:** `Integer` - Zero-based index of current step
**Returns:** `0` if current step not found

---

##### `next_step`

Returns the name of the next step.

```ruby
current_user.next_step
# => :profile
```

**Returns:** `Symbol` - Name of next step
**Returns:** `nil` if on last step

---

##### `previous_step`

Returns the name of the previous step.

```ruby
current_user.previous_step
# => :welcome
```

**Returns:** `Symbol` - Name of previous step
**Returns:** `nil` if on first step

---

##### `can_go_back?`

Returns true if user can navigate to previous step.

```ruby
current_user.can_go_back?
# => true
```

**Returns:** `Boolean`

---

##### `last_step?`

Returns true if user is on the last step.

```ruby
current_user.last_step?
# => false
```

**Returns:** `Boolean`

---

#### Action Methods

##### `advance_step!`

Moves user to the next step. If on last step, completes onboarding.

```ruby
current_user.advance_step!
```

**Returns:** `Boolean` - Result of `save`
**Side Effects:**
- Updates `onboarding_current_step`
- May set `onboarding_completed` and `onboarding_completed_at` if on last step
- Triggers analytics event

---

##### `go_back!`

Moves user to the previous step.

```ruby
current_user.go_back!
```

**Returns:** `Boolean` - Result of `save`
**Side Effects:**
- Updates `onboarding_current_step`
- Does nothing if already on first step

---

##### `complete_onboarding!`

Marks onboarding as complete.

```ruby
current_user.complete_onboarding!
```

**Returns:** `Boolean` - Result of `save`
**Side Effects:**
- Sets `onboarding_completed` to `true`
- Sets `onboarding_completed_at` to current time
- Triggers webhooks
- Triggers analytics event

---

##### `skip_onboarding!`

Marks onboarding as skipped.

```ruby
current_user.skip_onboarding!
```

**Returns:** `Boolean` - Result of `save`
**Side Effects:**
- Sets `onboarding_skipped` to `true`
- Triggers analytics event

---

##### `restart_onboarding!`

Restarts onboarding from the beginning.

```ruby
current_user.restart_onboarding!
```

**Returns:** `Boolean` - Result of `save`
**Side Effects:**
- Sets `onboarding_completed` to `false`
- Sets `onboarding_completed_at` to `nil`
- Sets `onboarding_skipped` to `false`
- Resets `onboarding_current_step` to first step

---

#### Progress Methods

##### `onboarding_progress`

Returns onboarding completion percentage.

```ruby
current_user.onboarding_progress
# => 50
```

**Returns:** `Integer` - Percentage from 0 to 100
**Returns:** `100` if onboarding is completed

---

#### Tooltip Methods

##### `tooltip_shown?(tooltip_id)`

Checks if a specific tooltip has been shown.

```ruby
current_user.tooltip_shown?('feature_dashboard')
# => false
```

**Parameters:**
- `tooltip_id` (String) - Unique identifier for the tooltip

**Returns:** `Boolean`

---

##### `mark_tooltip_shown!(tooltip_id)`

Marks a tooltip as shown.

```ruby
current_user.mark_tooltip_shown!('feature_dashboard')
```

**Parameters:**
- `tooltip_id` (String) - Unique identifier for the tooltip

**Returns:** `Boolean` - Result of `save`
**Side Effects:**
- Updates `feature_tooltips_shown` hash
- Triggers analytics event

---

##### `reset_tooltips!`

Resets all tooltips (marks all as not shown).

```ruby
current_user.reset_tooltips!
```

**Returns:** `Boolean` - Result of `save`
**Side Effects:**
- Clears `feature_tooltips_shown` hash

---

#### Milestone Methods

##### `milestone_achieved?(milestone_id)`

Checks if a specific milestone has been achieved.

```ruby
current_user.milestone_achieved?('profile_complete')
# => true
```

**Parameters:**
- `milestone_id` (String) - Unique identifier for the milestone

**Returns:** `Boolean`

---

##### `achieve_milestone!(milestone_id, points)`

Records a milestone achievement.

```ruby
current_user.achieve_milestone!('profile_complete', 100)
```

**Parameters:**
- `milestone_id` (String) - Unique identifier for the milestone
- `points` (Integer) - Points to award

**Returns:** `Boolean` - Result of `save`
**Side Effects:**
- Adds milestone_id to `onboarding_milestones_achieved` array
- Adds points to `onboarding_milestone_points`
- Triggers celebration
- Triggers webhooks
- Triggers analytics event
- Does nothing if milestone already achieved

---

#### Scopes

##### `needs_onboarding`

Returns users who need onboarding.

```ruby
User.needs_onboarding
```

**Returns:** `ActiveRecord::Relation`

---

##### `onboarding_completed`

Returns users who completed onboarding.

```ruby
User.onboarding_completed
```

**Returns:** `ActiveRecord::Relation`

---

##### `onboarding_in_progress`

Returns users currently in onboarding.

```ruby
User.onboarding_in_progress
```

**Returns:** `ActiveRecord::Relation`

---

### AbTestable

Include in your User model to enable A/B testing.

```ruby
include RailsOnboarding::AbTestable
```

#### Methods

##### `assign_ab_variant(test_name, variant_name)`

Assigns user to an A/B test variant.

```ruby
current_user.assign_ab_variant('flow_test', 'variant_b')
```

**Parameters:**
- `test_name` (String) - Name of the test
- `variant_name` (String) - Name of the variant

**Returns:** `Boolean` - Result of `save`

---

##### `ab_variant(test_name)`

Gets the assigned variant for a test.

```ruby
current_user.ab_variant('flow_test')
# => 'variant_b'
```

**Parameters:**
- `test_name` (String) - Name of the test

**Returns:** `String` - Variant name or nil

---

##### `track_ab_conversion(test_name, metadata = {})`

Tracks a conversion for an A/B test.

```ruby
current_user.track_ab_conversion('flow_test', { completed_at: Time.current })
```

**Parameters:**
- `test_name` (String) - Name of the test
- `metadata` (Hash) - Optional additional data

**Returns:** `void`
**Side Effects:** Creates analytics event

---

### ProgressiveDisclosure

Include in controllers to support progressive feature revelation.

```ruby
include RailsOnboarding::ProgressiveDisclosure
```

#### Methods

##### `feature_unlocked_for?(user, feature)`

Checks if a feature is unlocked for a user.

```ruby
feature_unlocked_for?(current_user, progressive_feature)
# => true
```

**Parameters:**
- `user` (User) - The user to check
- `feature` (ProgressiveFeature) - The feature to check

**Returns:** `Boolean`

---

### Personalizable

Include in your User model to enable personalization.

```ruby
include RailsOnboarding::Personalizable
```

#### Methods

##### `personalized_onboarding_flow`

Returns the personalized onboarding flow for the user.

```ruby
current_user.personalized_onboarding_flow
# => { steps: [...], ... }
```

**Returns:** `Hash` - Personalized flow configuration

---

## Controllers

### OnboardingController

Handles the main onboarding flow.

**Routes:**
- `GET /onboarding` - Show current step
- `POST /onboarding/next_step` - Advance to next step
- `POST /onboarding/previous_step` - Go to previous step
- `POST /onboarding/complete` - Complete onboarding
- `POST /onboarding/skip` - Skip onboarding
- `POST /onboarding/restart` - Restart onboarding

---

### TooltipsController

Manages tooltip interactions.

**Routes:**
- `POST /tooltips/dismiss` - Dismiss a tooltip
- `POST /tooltips/show` - Mark tooltip as shown
- `POST /tooltips/reset` - Reset all tooltips
- `GET /tooltips/:tooltip_id/status` - Get tooltip status

#### Actions

##### `dismiss`

Dismisses a specific tooltip.

**Parameters:**
- `tooltip_id` (String) - Required

**Response:** JSON
```json
{
  "success": true,
  "message": "Tooltip dismissed"
}
```

---

### MilestonesController

Manages milestone achievements.

**Routes:**
- `GET /milestones` - List all milestones
- `GET /milestones/progress` - Get user progress
- `GET /milestones/:id/check` - Check milestone status
- `POST /milestones/trigger` - Trigger milestone achievement
- `GET /milestones/available` - Get available milestones

#### Actions

##### `trigger`

Triggers a milestone achievement.

**Parameters:**
- `milestone_id` (String) - Required

**Response:** JSON
```json
{
  "success": true,
  "milestone_id": "profile_complete",
  "points_awarded": 100,
  "total_points": 250,
  "celebration": true
}
```

---

## Models

### Analytics

Provides analytics and reporting methods.

#### Class Methods

##### `completion_rate(date_range)`

Calculates onboarding completion rate.

```ruby
RailsOnboarding::Analytics.completion_rate(30.days.ago..Time.current)
# => 0.75
```

**Parameters:**
- `date_range` (Range) - Date range to analyze

**Returns:** `Float` - Completion rate from 0.0 to 1.0

---

##### `average_completion_time`

Calculates average time to complete onboarding.

```ruby
RailsOnboarding::Analytics.average_completion_time
# => 320.5
```

**Returns:** `Float` - Average time in seconds

---

##### `step_funnel`

Returns step-by-step funnel data.

```ruby
RailsOnboarding::Analytics.step_funnel
# => { welcome: { started: 100, completed: 95 }, ... }
```

**Returns:** `Hash` - Funnel data for each step

---

##### `drop_off_points`

Identifies steps with highest drop-off rates.

```ruby
RailsOnboarding::Analytics.drop_off_points
# => [{ step: 'profile', drop_off_rate: 0.15 }, ...]
```

**Returns:** `Array<Hash>` - Steps sorted by drop-off rate

---

##### `tooltip_engagement`

Returns tooltip engagement metrics.

```ruby
RailsOnboarding::Analytics.tooltip_engagement
# => { 'feature_dashboard' => { views: 100, dismissals: 80 }, ... }
```

**Returns:** `Hash` - Engagement data per tooltip

---

### AnalyticsEvent

Tracks individual analytics events.

#### Attributes

- `user_id` (Integer) - User who triggered the event
- `event_type` (String) - Type of event
- `session_id` (String) - Session identifier
- `metadata` (JSON) - Additional event data
- `created_at` (DateTime) - When event occurred

#### Scopes

##### `event_type(type)`

Filters events by type.

```ruby
AnalyticsEvent.event_type('step_completed')
```

---

##### `for_user(user_id)`

Filters events for a specific user.

```ruby
AnalyticsEvent.for_user(current_user.id)
```

---

##### `in_date_range(range)`

Filters events within a date range.

```ruby
AnalyticsEvent.in_date_range(7.days.ago..Time.current)
```

---

## Helpers

### ControllerHelpers

Include in ApplicationController to add onboarding enforcement.

```ruby
include RailsOnboarding::ControllerHelpers
```

#### Methods

##### `require_onboarding`

Before action that redirects users needing onboarding.

```ruby
before_action :require_onboarding
```

**Returns:** `void` or redirect
**Side Effects:** Redirects to onboarding if needed

---

##### `skip_onboarding_requirement`

Skips onboarding requirement for specific actions.

```ruby
skip_onboarding_requirement only: [:edit, :update]
```

**Parameters:**
- Standard before_action options (`:only`, `:except`, `:if`, `:unless`)

---

##### `user_needs_onboarding?`

Checks if current user needs onboarding.

```ruby
if user_needs_onboarding?
  # ...
end
```

**Returns:** `Boolean`

---

### ResponsiveHelper

Provides responsive design utilities.

#### Methods

##### `viewport_meta_tag`

Generates viewport meta tag for responsive design.

```ruby
viewport_meta_tag
# => <meta name="viewport" content="width=device-width, initial-scale=1.0">
```

**Returns:** `String` - HTML meta tag

---

##### `mobile_device?(request)`

Detects if request is from mobile device.

```ruby
mobile_device?(request)
# => true
```

**Parameters:**
- `request` (ActionDispatch::Request)

**Returns:** `Boolean`

---

##### `responsive_class(base_class, mobile_class = nil)`

Returns responsive CSS class.

```ruby
responsive_class('container', 'container-mobile')
# => 'container container-mobile' (on mobile)
# => 'container' (on desktop)
```

**Parameters:**
- `base_class` (String) - Base CSS class
- `mobile_class` (String) - Optional mobile-specific class

**Returns:** `String`

---

## Configuration

### Configuration Class

Configure the gem behavior.

```ruby
RailsOnboarding.configure do |config|
  # Configuration options
end
```

#### Configuration Options

##### `user_class_name`

Name of the user model class.

```ruby
config.user_class_name = 'User'
```

**Type:** `String`
**Default:** `'User'`

---

##### `redirect_after_completion`

Where to redirect after completing onboarding.

```ruby
config.redirect_after_completion = :dashboard_path
```

**Type:** `Symbol` or `String`
**Default:** `:root_path`

---

##### `redirect_after_skip`

Where to redirect after skipping onboarding.

```ruby
config.redirect_after_skip = :root_path
```

**Type:** `Symbol` or `String`
**Default:** `:root_path`

---

##### `enable_tooltips`

Enable tooltip system.

```ruby
config.enable_tooltips = true
```

**Type:** `Boolean`
**Default:** `true`

---

##### `enable_milestones`

Enable milestone system.

```ruby
config.enable_milestones = true
```

**Type:** `Boolean`
**Default:** `false`

---

##### `enable_analytics`

Enable analytics tracking.

```ruby
config.enable_analytics = true
```

**Type:** `Boolean`
**Default:** `false`

---

##### `steps`

Define onboarding steps.

```ruby
config.steps = [
  { name: :welcome, title: 'Welcome', icon: '👋', skippable: true },
  # ...
]
```

**Type:** `Array<Hash>`
**Default:** Default 4-step flow

---

##### `milestones`

Define milestones.

```ruby
config.milestones = [
  { id: 'first_login', title: 'First Login', points: 10 },
  # ...
]
```

**Type:** `Array<Hash>`
**Default:** `[]`

---

##### `webhook_url`

Webhook endpoint URL.

```ruby
config.webhook_url = 'https://example.com/webhook'
```

**Type:** `String`
**Default:** `nil`

---

##### `webhook_events`

Events to send to webhook.

```ruby
config.webhook_events = [:onboarding_completed, :milestone_achieved]
```

**Type:** `Array<Symbol>`
**Default:** `[]`

---

#### Class Methods

##### `RailsOnboarding.configuration`

Returns current configuration.

```ruby
config = RailsOnboarding.configuration
```

**Returns:** `Configuration` instance

---

##### `RailsOnboarding.configure { |config| ... }`

Configures the gem.

```ruby
RailsOnboarding.configure do |config|
  config.enable_tooltips = true
end
```

**Yields:** `Configuration` instance

---

##### `RailsOnboarding.reset_configuration!`

Resets configuration to defaults.

```ruby
RailsOnboarding.reset_configuration!
```

---

## Services

### ErrorRecovery

Handles error recovery for failed steps.

#### Methods

##### `log_error(user, step, error)`

Logs an error for a step.

```ruby
RailsOnboarding::ErrorRecovery.log_error(user, 'profile', error)
```

---

### Webhooks

Triggers webhooks for events.

#### Methods

##### `trigger(event, user, data = {})`

Triggers a webhook.

```ruby
RailsOnboarding::Webhooks.trigger(:onboarding_completed, user)
```

---

### SessionManager

Manages onboarding sessions.

#### Methods

##### `save_session(user)`

Saves onboarding session state.

```ruby
RailsOnboarding::SessionManager.save_session(user)
```

---

##### `restore_session(user)`

Restores onboarding session state.

```ruby
RailsOnboarding::SessionManager.restore_session(user)
```

---

### SkipLogic

Handles conditional step skipping.

#### Methods

##### `should_skip_step?(user, step)`

Determines if step should be skipped.

```ruby
RailsOnboarding::SkipLogic.should_skip_step?(user, 'profile')
# => true
```

---

## Event Types

Analytics events tracked by the system:

- `onboarding_started` - User started onboarding
- `onboarding_step_started` - User reached (viewed) a step
- `onboarding_step_completed` - User completed a step
- `onboarding_step_skipped` - User skipped an optional step
- `onboarding_completed` - User completed entire onboarding
- `onboarding_skipped` - User skipped onboarding
- `tooltip_shown` - Tooltip was shown to the user
- `tooltip_clicked` - User clicked a tooltip
- `tooltip_dismissed` - User dismissed a tooltip
- `milestone_achieved` - User achieved a milestone

Event payloads are stored in the `properties` column (JSON), keyed by
`step_name`, `step_index`, `tooltip_feature`, etc.
- `error_occurred` - An error occurred during onboarding

---

## Error Handling

All controllers rescue from standard errors:

- `ActiveRecord::RecordNotFound` - Returns 404
- `ActionController::ParameterMissing` - Returns 400
- `StandardError` - Returns 500 with error logging

---

## Thread Safety

All class-level configuration methods are thread-safe. Instance methods assume single-threaded access per user.

---

## Deprecations

None currently. Future deprecations will be announced via CHANGELOG.md.

---

## Version Information

This documentation is for Rails Onboarding gem version 0.1.0+.

For version-specific changes, see [CHANGELOG.md](CHANGELOG.md).
For migration between versions, see [MIGRATION_GUIDE.md](MIGRATION_GUIDE.md).
