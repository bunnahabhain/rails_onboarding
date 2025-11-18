# Configuration Validation Guide

The Rails Onboarding gem includes comprehensive configuration validation to help catch configuration errors early and provide helpful error messages.

## Overview

The configuration validation system checks:

1. **Step Validation** - Step names are unique and properly formatted
2. **Milestone Validation** - Milestone keys, points, and trigger configurations are valid
3. **Redirect Path Validation** - Redirect paths are valid routes or symbols
4. **Type Checking** - All configuration values have the correct types
5. **Required Options** - Required configuration options are present
6. **Configuration Errors** - Helpful error messages for misconfiguration

## Usage

### Automatic Validation

By default, validation does not run automatically to allow for flexible configuration. You can manually validate your configuration:

```ruby
# config/initializers/rails_onboarding.rb
RailsOnboarding.configure do |config|
  config.steps = [
    { name: :welcome, title: 'Welcome', icon: '🎉', skippable: true },
    { name: :profile, title: 'Setup Profile', icon: '👤', skippable: false }
  ]
end

# Validate after configuration
RailsOnboarding.configuration.validate!
```

### Manual Validation

You can check if a configuration is valid without raising an exception:

```ruby
if RailsOnboarding.configuration.valid?
  puts "Configuration is valid!"
else
  puts "Configuration errors:"
  RailsOnboarding.configuration.validation_errors.each do |error|
    puts "  - #{error.message}"
  end
end
```

## Validation Rules

### Step Validation

**Valid step configuration:**

```ruby
config.steps = [
  { name: :welcome, title: 'Welcome', icon: '🎉', skippable: true },
  { name: :profile_setup, title: 'Profile', icon: '👤', skippable: false }
]
```

**Common errors:**

```ruby
# ❌ Empty steps
config.steps = []
# Error: At least one step must be defined

# ❌ Duplicate step names
config.steps = [
  { name: :welcome, title: 'Welcome' },
  { name: :welcome, title: 'Welcome Again' }
]
# Error: Duplicate step name found: 'welcome'

# ❌ Invalid step name format
config.steps = [{ name: 'invalid-name' }]
# Error: Step 'invalid-name' has invalid format. Use alphanumeric characters and underscores only

# ❌ Missing required name field
config.steps = [{ title: 'Welcome' }]
# Error: Step at index 0 is missing required :name field

# ❌ Invalid types
config.steps = [{ name: :welcome, title: 123 }]
# Error: Step 'welcome' has invalid :title type. Must be a String

config.steps = [{ name: :welcome, skippable: "yes" }]
# Error: Step 'welcome' has invalid :skippable type. Must be a Boolean
```

### Milestone Validation

**Valid milestone configuration:**

```ruby
config.enable_milestones = true
config.milestones = [
  {
    key: :welcome_completed,
    title: "Welcome Aboard!",
    description: "You completed the welcome step",
    icon: "🎉",
    points: 10,
    trigger: :onboarding_step_completed,
    conditions: { step: :welcome }
  }
]
```

**Valid triggers:**

- `:onboarding_step_completed`
- `:onboarding_completed`
- `:tooltip_shown`
- `:tooltip_clicked`
- `:custom`

**Common errors:**

```ruby
# ❌ Missing required fields
config.milestones = [{ key: :test }]
# Error: Milestone 'test' is missing required :trigger field

# ❌ Invalid trigger
config.milestones = [{ key: :test, trigger: :invalid }]
# Error: Milestone 'test' has invalid trigger 'invalid'. Valid triggers: ...

# ❌ Duplicate keys
config.milestones = [
  { key: :test, trigger: :custom },
  { key: :test, trigger: :custom }
]
# Error: Duplicate milestone key found: 'test'

# ❌ Invalid points
config.milestones = [{ key: :test, trigger: :custom, points: -10 }]
# Error: Milestone 'test' has negative points. Points must be non-negative

# ❌ Invalid step reference
config.milestones = [
  { key: :test, trigger: :onboarding_step_completed, conditions: { step: :nonexistent } }
]
# Error: Milestone 'test' references undefined step 'nonexistent' in conditions
```

### Redirect Path Validation

**Valid redirect paths:**

```ruby
# Symbol (recommended)
config.redirect_after_completion = :dashboard_path
config.redirect_after_skip = :home_url

# Absolute path string
config.redirect_after_completion = "/dashboard"

# Proc for dynamic paths
config.redirect_after_completion = ->(user) { "/users/#{user.id}/dashboard" }
```

**Common errors:**

```ruby
# ❌ Invalid type
config.redirect_after_completion = 123
# Error: redirect_after_completion must be a Symbol, String, or Proc

# ❌ Symbol not ending with _path or _url
config.redirect_after_completion = :dashboard
# Error: redirect_after_completion symbol 'dashboard' should end with '_path' or '_url'

# ❌ String not starting with /
config.redirect_after_completion = "dashboard"
# Error: redirect_after_completion string 'dashboard' should be an absolute path starting with '/'
```

### Type Validation

**Valid types:**

```ruby
config.user_class_name = "User"                    # String
config.enable_tooltips = true                       # Boolean
config.analytics_data_retention_days = 365          # Integer (positive)
config.steps = [{ name: :welcome }]                 # Array
config.feature_tooltips = { test: { text: "Hi" } } # Hash
config.onboarding_required_for = :new_users         # Symbol or Proc
config.api_authentication_method = :token           # Valid enum value
```

**Common errors:**

```ruby
# ❌ Wrong type for boolean
config.enable_tooltips = "true"
# Error: enable_tooltips must be a Boolean

# ❌ Wrong type for integer
config.analytics_data_retention_days = "365"
# Error: analytics_data_retention_days must be an Integer

# ❌ Zero or negative when positive required
config.analytics_data_retention_days = 0
# Error: analytics_data_retention_days must be positive

# ❌ Invalid enum value
config.onboarding_required_for = :some_users
# Error: onboarding_required_for must be :new_users, :all_users, or a Proc
```

### Feature Tooltip Validation

**Valid tooltip configuration:**

```ruby
config.enable_tooltips = true
config.feature_tooltips = {
  getting_started: {
    text: "Click here to get started!",
    delay: 1000,
    position: "bottom"
  }
}
```

**Valid positions:** `top`, `bottom`, `left`, `right`

**Common errors:**

```ruby
# ❌ Missing text
config.feature_tooltips = { test: { delay: 1000 } }
# Error: Tooltip 'test' must have a :text field of type String

# ❌ Invalid delay type
config.feature_tooltips = { test: { text: "Hi", delay: "1000" } }
# Error: Tooltip 'test' has invalid :delay type. Must be an Integer (milliseconds)

# ❌ Invalid position
config.feature_tooltips = { test: { text: "Hi", position: "center" } }
# Error: Tooltip 'test' has invalid :position 'center'. Valid positions: top, bottom, left, right
```

### Progressive Disclosure Validation

**Valid progressive feature configuration:**

```ruby
config.progressive_disclosure_enabled = true
config.progressive_features = [
  {
    key: :advanced_settings,
    reveal_condition: :time_based,
    delay: 86400  # 24 hours in seconds
  },
  {
    key: :power_features,
    reveal_condition: :step_based,
    after_step: :profile
  }
]
```

**Valid reveal conditions:**

- `:time_based` - Requires `:delay` (Integer in seconds)
- `:action_based` - Requires `:check_method` (Symbol)
- `:step_based` - Requires `:after_step` (Symbol referencing valid step)
- `:milestone_based`
- `:engagement_based`

**Common errors:**

```ruby
# ❌ time_based without delay
config.progressive_features = [
  { key: :test, reveal_condition: :time_based }
]
# Error: Progressive feature 'test' with :time_based condition must have :delay

# ❌ step_based with invalid step
config.progressive_features = [
  { key: :test, reveal_condition: :step_based, after_step: :nonexistent }
]
# Error: Progressive feature 'test' references undefined step 'nonexistent'
```

### Mailer Configuration Validation

**Valid mailer configuration:**

```ruby
config.background_jobs_enabled = true
config.mailer_from = "noreply@example.com"
```

**Common errors:**

```ruby
# ❌ Invalid email format
config.mailer_from = "invalid-email"
# Error: mailer_from 'invalid-email' is not a valid email address
```

## Error Messages

The validation system provides detailed, helpful error messages:

### Single Error

```ruby
config.steps = []
config.validate!

# ConfigurationError: Configuration validation failed with 1 error(s):
#   1. At least one step must be defined
```

### Multiple Errors

```ruby
config.steps = []
config.user_class_name = nil
config.redirect_after_completion = 123

config.validate!

# ConfigurationError: Configuration validation failed with 3 error(s):
#   1. User class name is required
#   2. At least one step must be defined
#   3. redirect_after_completion must be a Symbol, String, or Proc, got Integer
```

## Best Practices

1. **Validate early** - Call `validate!` in your initializer to catch errors during app boot
2. **Use symbols for step names** - Symbols are more efficient than strings
3. **Follow naming conventions** - Use snake_case for step and milestone names
4. **Use descriptive error checking** - Use `valid?` and `validation_errors` in tests
5. **Document custom configurations** - Add comments explaining complex configuration

## Example: Complete Validated Configuration

```ruby
# config/initializers/rails_onboarding.rb
RailsOnboarding.configure do |config|
  # Basic settings
  config.user_class_name = 'User'
  config.redirect_after_completion = :dashboard_path
  config.redirect_after_skip = :root_path

  # Features
  config.enable_tooltips = true
  config.enable_milestones = true
  config.enable_analytics = true

  # Steps
  config.steps = [
    { name: :welcome, title: 'Welcome', icon: '🎉', skippable: true },
    { name: :profile, title: 'Setup Profile', icon: '👤', skippable: false },
    { name: :first_action, title: 'First Action', icon: '🚀', skippable: false },
    { name: :explore, title: 'Explore Features', icon: '🔍', skippable: true }
  ]

  # Milestones
  config.milestones = [
    {
      key: :welcome_completed,
      title: "Welcome Aboard!",
      description: "You completed the welcome step",
      icon: "🎉",
      points: 10,
      trigger: :onboarding_step_completed,
      conditions: { step: :welcome }
    },
    {
      key: :onboarding_completed,
      title: "Onboarding Champion",
      description: "You completed the entire onboarding flow",
      icon: "🏆",
      points: 50,
      trigger: :onboarding_completed
    }
  ]

  # Tooltips
  config.feature_tooltips = {
    getting_started: {
      text: "Click here to get started!",
      delay: 1000,
      position: "bottom"
    },
    dashboard_overview: {
      text: "This is your dashboard",
      delay: 2000,
      position: "top"
    }
  }

  # Analytics
  config.analytics_data_retention_days = 365
  config.analytics_session_timeout_minutes = 30
end

# Validate the configuration
begin
  RailsOnboarding.configuration.validate!
  Rails.logger.info "Rails Onboarding configuration is valid!"
rescue RailsOnboarding::ConfigurationError => e
  Rails.logger.error "Rails Onboarding configuration error: #{e.message}"
  raise
end
```

## Error Classes

The following error classes are available:

- `RailsOnboarding::ConfigurationError` - Base error for all configuration errors
- `RailsOnboarding::InvalidStepError` - Step configuration is invalid
- `RailsOnboarding::InvalidMilestoneError` - Milestone configuration is invalid
- `RailsOnboarding::InvalidRedirectPathError` - Redirect path is invalid
- `RailsOnboarding::InvalidTypeError` - Configuration value has wrong type
- `RailsOnboarding::MissingRequiredOptionError` - Required option is missing

You can rescue specific error types:

```ruby
begin
  RailsOnboarding.configuration.validate!
rescue RailsOnboarding::InvalidStepError => e
  # Handle step errors specifically
  puts "Step configuration error: #{e.message}"
rescue RailsOnboarding::ConfigurationError => e
  # Handle any other configuration error
  puts "Configuration error: #{e.message}"
end
```
