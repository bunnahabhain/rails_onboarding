# Rails Onboarding - Robustness & Edge Cases Guide

This guide covers the robustness features implemented in the Rails Onboarding gem to handle edge cases, errors, and complex scenarios gracefully.

## Table of Contents

1. [Error Recovery](#error-recovery)
2. [Session Management](#session-management)
3. [Skip Logic](#skip-logic)
4. [Rollback & Navigation](#rollback--navigation)
5. [Multi-Tenant Support](#multi-tenant-support)
6. [Internationalization](#internationalization)
7. [Best Practices](#best-practices)

---

## Error Recovery

The `RailsOnboarding::ErrorRecovery` service provides automatic retry logic and error state management for failed operations.

### Features

- **Automatic Retries**: Operations automatically retry up to 3 times (configurable)
- **Error Tracking**: All errors are logged for analytics and debugging
- **Graceful Degradation**: System continues to function even when errors occur
- **Recovery Actions**: Failed actions can be retried manually

### Usage

#### Wrap Operations with Error Recovery

```ruby
result = RailsOnboarding::ErrorRecovery.with_recovery(current_user, :complete_step) do
  current_user.complete_onboarding_step!(:profile)
end

if result
  redirect_to next_step_path
else
  # Handle failure after all retries
  flash[:error] = "Unable to complete step. Please try again later."
end
```

#### Custom Retry Configuration

```ruby
RailsOnboarding::ErrorRecovery.with_recovery(
  current_user,
  :save_profile,
  max_retries: 5
) do
  # Your operation here
end
```

#### Check for Errors

```ruby
if RailsOnboarding::ErrorRecovery.has_errors?(current_user)
  failed_actions = RailsOnboarding::ErrorRecovery.failed_actions(current_user)
  # Display error recovery UI
end
```

#### Reset Error State

```ruby
RailsOnboarding::ErrorRecovery.reset_errors(current_user)
```

### Database Fields Required

Add to your User model migration:

```ruby
add_column :users, :onboarding_errors, :text
add_column :users, :onboarding_failed_actions, :text
```

---

## Session Management

The `RailsOnboarding::SessionManager` handles browser refresh, navigation, and session persistence to ensure users can resume onboarding seamlessly.

### Features

- **Session Persistence**: State saved in both Rails session and database
- **Form Data Storage**: Preserve user input across page refreshes
- **Step History**: Track user's journey through onboarding
- **Automatic Timeout**: Sessions expire after 2 hours of inactivity (configurable)
- **Resume Capability**: Users can continue where they left off

### Usage

#### Initialize Session (Automatic)

Session is automatically initialized in the OnboardingController, but you can do it manually:

```ruby
session_data = RailsOnboarding::SessionManager.initialize_session(current_user, session)
```

#### Save Form Data

```ruby
# In your controller
RailsOnboarding::SessionManager.save_step_data(
  current_user,
  session,
  :profile,
  params.permit(:name, :bio, :avatar)
)
```

#### Retrieve Form Data

```ruby
# Pre-populate form with saved data
@profile_data = RailsOnboarding::SessionManager.get_step_data(
  current_user,
  session,
  :profile
)
```

#### Check Session History

```ruby
history = RailsOnboarding::SessionManager.step_history(current_user, session)
# Returns: [
#   { step: :welcome, completed_at: "2024-01-01T12:00:00Z" },
#   { step: :profile, completed_at: "2024-01-01T12:05:00Z" }
# ]
```

#### Get Session ID for Analytics

```ruby
session_id = RailsOnboarding::SessionManager.session_id(current_user, session)
```

### Database Fields Required

```ruby
add_column :users, :onboarding_session_data, :text
```

### Configuration

```ruby
# config/initializers/rails_onboarding.rb
RailsOnboarding::SessionManager::SESSION_TIMEOUT = 4.hours
```

---

## Skip Logic

The `RailsOnboarding::SkipLogic` service provides conditional step skipping based on user data and custom conditions.

### Features

- **Conditional Skipping**: Skip steps based on user attributes or custom logic
- **Multiple Condition Types**: Proc, Symbol, or Hash-based conditions
- **Auto-Skip**: Automatically skip steps that meet conditions
- **Progress Calculation**: Calculate progress excluding skipped steps

### Configuration

```ruby
RailsOnboarding.configure do |config|
  config.steps = [
    {
      name: :welcome,
      title: "Welcome",
      skippable: true
    },
    {
      name: :team_setup,
      title: "Setup Team",
      skippable: true,
      # Skip if user is not an admin
      skip_if: ->(user) { !user.admin? }
    },
    {
      name: :integration,
      title: "Connect Tools",
      skippable: true,
      # Skip if user already has integrations
      skip_if: { has_attribute: :integrations },
      auto_skip: true # Automatically skip without showing
    },
    {
      name: :profile,
      title: "Setup Profile",
      skippable: false,
      # Skip if profile is complete
      skip_if: :profile_complete?
    }
  ]
end
```

### Condition Types

#### Proc Condition

```ruby
skip_if: ->(user) { user.created_at > 1.month.ago }
```

#### Symbol Condition

```ruby
skip_if: :skip_this_step?

# In User model:
def skip_this_step?
  self.some_attribute.present?
end
```

#### Hash Conditions

```ruby
# Has attribute
skip_if: { has_attribute: :phone_number }

# Missing attribute
skip_if: { missing_attribute: :organization_id }

# Attribute equals
skip_if: { attribute_equals: { role: 'viewer' } }

# Attribute not equals
skip_if: { attribute_not_equals: { plan: 'enterprise' } }

# Has role (if using a role system)
skip_if: { has_role: :admin }

# Custom proc in hash
skip_if: { custom: ->(user) { user.some_complex_logic } }

# Multiple conditions with operators
skip_if: {
  operator: :all, # or :any, :none
  has_attribute: :email,
  attribute_equals: { verified: true }
}
```

### Usage in Code

#### Check if Step Should Be Skipped

```ruby
step = RailsOnboarding.configuration.step_by_name(:team_setup)
should_skip = RailsOnboarding::SkipLogic.should_skip_step?(current_user, step)
```

#### Find Next Unskipped Step

```ruby
next_step = RailsOnboarding::SkipLogic.next_unskipped_step(
  current_user,
  current_user.onboarding_current_step
)
```

#### Get Required vs Skippable Steps

```ruby
# Steps user must complete
required = RailsOnboarding::SkipLogic.required_steps(current_user)

# Steps that will be skipped
skippable = RailsOnboarding::SkipLogic.skippable_steps(current_user)
```

#### Calculate Accurate Progress

```ruby
# Excludes skipped steps from calculation
progress = RailsOnboarding::SkipLogic.progress_excluding_skipped(current_user)
```

---

## Rollback & Navigation

Users can go back to previous steps, jump to specific steps, or restart the entire onboarding.

### Features

- **Go Back**: Navigate to the previous step
- **Jump to Step**: Go directly to any step
- **Restart**: Begin onboarding from the beginning
- **History Tracking**: All navigation is tracked in analytics

### User Model Methods

#### Go Back

```ruby
if current_user.can_go_back?
  current_user.go_back!
end
```

#### Jump to Specific Step

```ruby
current_user.go_to_step!(:profile)
```

#### Restart Onboarding

```ruby
current_user.restart_onboarding!
```

#### Get Previous Step

```ruby
prev_step = current_user.previous_onboarding_step
# Returns: { name: :welcome, title: "Welcome", ... }
```

### Controller Actions

The OnboardingController includes `back` and `restart` actions:

```ruby
# In your views
<%= button_to "Back", back_onboarding_path, method: :post if current_user.can_go_back? %>
<%= button_to "Restart", restart_onboarding_path, method: :post,
    data: { confirm: "Are you sure you want to restart?" } %>
```

### Routes

```ruby
# Available routes
rails_onboarding.back_onboarding_path     # POST /onboarding/back
rails_onboarding.restart_onboarding_path   # POST /onboarding/restart
```

---

## Multi-Tenant Support

The `RailsOnboarding::MultiTenant` service allows different onboarding configurations per organization or tenant.

### Features

- **Per-Tenant Configuration**: Each organization can have unique steps, tooltips, and settings
- **Configuration Inheritance**: Tenant configs merge with defaults
- **Dynamic Loading**: Configuration loaded based on user's tenant
- **Easy Management**: Copy configurations between tenants

### Setup

#### Add Tenant Configuration Field

For your Organization/Account/Tenant model:

```ruby
# Migration
add_column :organizations, :onboarding_configuration, :text
```

#### Associate User with Tenant

```ruby
# User model
class User < ApplicationRecord
  belongs_to :organization
  # or :account, :tenant, :team, :company
end
```

### Configuration

#### Set Tenant-Specific Configuration

```ruby
organization = Organization.find(1)

config = {
  steps: [
    { name: :welcome, title: "Welcome to Acme Corp!", icon: "🎉" },
    { name: :setup_workspace, title: "Setup Workspace", icon: "💼" },
    { name: :invite_team, title: "Invite Team", icon: "👥" }
  ],
  enable_tooltips: true,
  enable_milestones: true,
  redirect_after_completion: :workspace_path
}

RailsOnboarding::MultiTenant.set_configuration(organization, config)
```

#### Use Tenant Configuration

```ruby
# Automatically detect tenant from user
tenant = RailsOnboarding::MultiTenant.tenant_from_user(current_user)

# Get tenant-specific steps
steps = RailsOnboarding::MultiTenant.steps_for(tenant)

# Get tenant-specific tooltips
tooltips = RailsOnboarding::MultiTenant.tooltips_for(tenant)

# Check if feature is enabled for tenant
if RailsOnboarding::MultiTenant.feature_enabled?(tenant, :milestones)
  # Show milestone UI
end
```

#### Apply Tenant Configuration Temporarily

```ruby
RailsOnboarding::MultiTenant.with_tenant_configuration(current_user.organization) do
  # All onboarding operations use tenant config
  current_user.complete_onboarding_step!(:welcome)
end
```

#### Copy Configuration Between Tenants

```ruby
source_org = Organization.find(1)
target_org = Organization.find(2)

RailsOnboarding::MultiTenant.copy_configuration(source_org, target_org)
```

#### Reset to Default

```ruby
RailsOnboarding::MultiTenant.reset_configuration(organization)
```

### Integration with Controllers

```ruby
# In OnboardingController or ApplicationController
before_action :apply_tenant_configuration

private

def apply_tenant_configuration
  tenant = RailsOnboarding::MultiTenant.tenant_from_user(current_user)
  @tenant_steps = RailsOnboarding::MultiTenant.steps_for(tenant) if tenant
end
```

---

## Internationalization

Full I18n support with translations for English, Spanish, and French included. Easy to add more languages.

### Features

- **Multiple Languages**: Built-in support for en, es, fr
- **Easy Extension**: Simple YAML format for adding languages
- **Helper Methods**: Convenient translation helpers
- **User Locale Detection**: Automatic detection from user preferences
- **Step Localization**: Translate step titles and descriptions

### Configuration

#### Set Available Locales

```ruby
# config/application.rb
config.i18n.available_locales = [:en, :es, :fr, :de]
config.i18n.default_locale = :en
```

#### Set User Locale

```ruby
# User model
class User < ApplicationRecord
  # Add locale column
  # Or use preferred_language, language, etc.
end
```

### Adding New Languages

Create a new locale file:

```yaml
# config/locales/de.yml
de:
  rails_onboarding:
    navigation:
      next: "Weiter"
      back: "Zurück"
      skip: "Überspringen"
      finish: "Fertig"
    messages:
      welcome: "Willkommen!"
      completed: "Glückwunsch! Sie haben das Onboarding abgeschlossen."
    # ... more translations
```

### Using Translations

#### In Views

```erb
<%= t('rails_onboarding.navigation.next') %>
<%= t('rails_onboarding.messages.welcome') %>
```

#### With Helper Methods

```erb
<%= t_nav(:next) %>
<%= t_message(:welcome) %>
<%= t_action(:complete) %>
<%= t_error(:failed_to_save) %>
```

#### Localized Step Configuration

```ruby
RailsOnboarding.configure do |config|
  config.steps = [
    {
      name: :welcome,
      title: "Welcome", # Fallback
      title_key: "onboarding.steps.welcome.title", # Translation key
      description_key: "onboarding.steps.welcome.description"
    }
  ]
end
```

```yaml
# config/locales/en.yml
en:
  onboarding:
    steps:
      welcome:
        title: "Welcome to Our Platform!"
        description: "Let's get you set up in just a few steps."
```

#### In Controllers

```ruby
I18n.with_locale(current_user.locale) do
  flash[:notice] = t('rails_onboarding.messages.completed')
end
```

#### Helper Module

```ruby
include RailsOnboarding::I18nHelper

# Then use:
t_onboarding('navigation.next')
t_nav(:back)
t_message(:welcome)
localized_step_title(step)
user_locale(current_user)
```

### User Locale Detection

The system automatically detects user locale:

```ruby
# Checks in order:
# 1. user.locale
# 2. user.language
# 3. user.preferred_language
# Falls back to I18n.default_locale
```

---

## Best Practices

### Error Handling

1. **Always Use Error Recovery for Critical Operations**
   ```ruby
   RailsOnboarding::ErrorRecovery.with_recovery(user, :save_profile) do
     # Critical operation
   end
   ```

2. **Provide User Feedback**
   ```ruby
   if result
     flash[:success] = t_message(:saved)
   else
     flash[:error] = t_error(:failed_to_save)
   end
   ```

3. **Log Errors for Monitoring**
   ```ruby
   Rails.logger.error("Onboarding error for user #{user.id}: #{error.message}")
   ```

### Session Management

1. **Save Form Data Frequently**
   ```ruby
   # Save on blur or change events
   RailsOnboarding::SessionManager.save_step_data(user, session, step_name, data)
   ```

2. **Clear Data After Successful Completion**
   ```ruby
   RailsOnboarding::SessionManager.clear_step_data(user, session, step_name)
   ```

3. **Handle Session Expiration**
   ```ruby
   if RailsOnboarding::SessionManager.session_expired?(session_data)
     # Prompt user to refresh or re-authenticate
   end
   ```

### Skip Logic

1. **Keep Conditions Simple**
   ```ruby
   # Good
   skip_if: ->(user) { user.admin? }

   # Avoid complex logic in skip conditions
   ```

2. **Use Auto-Skip Sparingly**
   ```ruby
   # Only auto-skip when user definitely doesn't need the step
   skip_if: :already_completed?,
   auto_skip: true
   ```

3. **Provide Feedback for Skipped Steps**
   ```ruby
   flash[:info] = "We've skipped some steps based on your profile"
   ```

### Multi-Tenant

1. **Cache Tenant Configuration**
   ```ruby
   @tenant_config ||= RailsOnboarding::MultiTenant.configuration_for(tenant)
   ```

2. **Validate Configuration**
   ```ruby
   # Ensure steps array is not empty
   # Validate required fields
   ```

3. **Provide Tenant Admin UI**
   - Allow tenants to customize their onboarding
   - Preview changes before applying
   - Version control for configurations

### Internationalization

1. **Always Provide Fallbacks**
   ```ruby
   title: I18n.t(title_key, default: default_title)
   ```

2. **Test All Locales**
   ```ruby
   I18n.available_locales.each do |locale|
     I18n.with_locale(locale) do
       # Test translations
     end
   end
   ```

3. **Use Interpolation for Dynamic Content**
   ```yaml
   progress: "Step %{current} of %{total}"
   ```

---

## Migration Guide

### Adding Robustness Features to Existing Installation

1. **Run the robustness migration:**
   ```bash
   bundle exec rails generate migration AddRobustnessFieldsToUsers
   ```

2. **Update your User model:**
   ```ruby
   class User < ApplicationRecord
     include RailsOnboarding::Onboardable

     serialize :onboarding_errors, coder: JSON
     serialize :onboarding_failed_actions, coder: JSON
   end
   ```

3. **Add routes (already done if using latest version):**
   ```ruby
   mount RailsOnboarding::Engine => "/onboarding"
   ```

4. **Update your views to use new features:**
   ```erb
   <%= button_to t_nav(:back), back_onboarding_path if current_user.can_go_back? %>
   ```

---

## Troubleshooting

### Session Not Persisting

- Check that session middleware is enabled
- Verify database field exists: `onboarding_session_data`
- Check session cookie settings

### Skip Logic Not Working

- Verify condition syntax is correct
- Check that user object has required methods/attributes
- Enable debug logging to see evaluation results

### Translations Missing

- Ensure locale file exists in `config/locales/`
- Check that locale is in `I18n.available_locales`
- Verify YAML syntax is correct

### Multi-Tenant Configuration Not Loading

- Check that tenant has `onboarding_configuration` field
- Verify user is associated with tenant
- Check JSON syntax in configuration

---

## Testing

Run the robustness test suite:

```bash
# All robustness tests
bundle exec rails test test/integration/robustness_test.rb

# Specific feature tests
bundle exec rails test test/lib/rails_onboarding/error_recovery_test.rb
bundle exec rails test test/lib/rails_onboarding/session_manager_test.rb
bundle exec rails test test/lib/rails_onboarding/skip_logic_test.rb
```

---

## API Reference

See individual classes for detailed API documentation:

- `RailsOnboarding::ErrorRecovery`
- `RailsOnboarding::SessionManager`
- `RailsOnboarding::SkipLogic`
- `RailsOnboarding::MultiTenant`
- `RailsOnboarding::I18nHelper`

---

## Contributing

To add new robustness features:

1. Add feature implementation in `lib/rails_onboarding/`
2. Add comprehensive tests
3. Update this guide with documentation
4. Add example usage in test dummy app

---

## License

Same as the main Rails Onboarding gem.
