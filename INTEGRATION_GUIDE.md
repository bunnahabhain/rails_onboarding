# Integration & Compatibility Guide

This guide covers how to integrate RailsOnboarding with various frameworks, authentication systems, and third-party services.

## Table of Contents

1. [Devise Integration](#devise-integration)
2. [Turbo & Stimulus Compatibility](#turbo--stimulus-compatibility)
3. [API Mode Support](#api-mode-support)
4. [Background Jobs](#background-jobs)
5. [Webhooks](#webhooks)
6. [Configuration Examples](#configuration-examples)

---

## Devise Integration

RailsOnboarding seamlessly integrates with Devise authentication out of the box.

### Features

- **Automatic Redirect**: Users are redirected to onboarding after sign-in/sign-up
- **Skip for Admins**: Optionally skip onboarding for admin users
- **Unconfirmed Users**: Handle users who haven't confirmed their email
- **Path Helpers**: Proper integration with Devise's `stored_location_for`

### Setup

1. **Enable Devise Integration** (enabled by default):

```ruby
# config/initializers/rails_onboarding.rb
RailsOnboarding.configure do |config|
  config.devise_integration_enabled = true
end
```

2. **Configure Redirect Behavior**:

```ruby
RailsOnboarding.configure do |config|
  # Redirect unconfirmed users to onboarding after confirmation
  config.redirect_unconfirmed_to_onboarding = false

  # Onboarding is required for new users only (default)
  config.onboarding_required_for = :new_users
end
```

3. **Skip Onboarding for Admins** (optional):

The integration automatically skips onboarding for users with an `admin?` method that returns true. You can customize this behavior by extending the `DeviseControllerExtension`.

### Advanced Configuration

```ruby
# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  include RailsOnboarding::DeviseIntegration

  # Configure devise integration for this controller
  configure_devise_integration(
    skip_for_admin: true,
    admin_check: ->(user) { user.role == 'admin' }
  )
end
```

### How It Works

When a user signs in or signs up through Devise, the integration:

1. Checks if the user should see onboarding
2. Redirects to the onboarding flow if needed
3. Stores the intended destination to return after completion
4. Skips onboarding for admins (if configured)

---

## Turbo & Stimulus Compatibility

Full support for Rails 7+ Hotwire stack with Turbo and Stimulus.

### Features

- **Turbo Frames**: Support for frame requests and responses
- **Turbo Streams**: Live updates without page refresh
- **Turbo Morphing**: Support for Turbo 8+ morphing
- **Stimulus Helpers**: Easy integration with Stimulus controllers
- **Turbo Native**: Detection and support for mobile apps

### Setup

1. **Enable Turbo Streams** (enabled by default):

```ruby
# config/initializers/rails_onboarding.rb
RailsOnboarding.configure do |config|
  config.turbo_streams_enabled = true
  config.turbo_morphing_enabled = false # Enable for Turbo 8+
end
```

2. **Include in Your Controllers**:

```ruby
# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  include RailsOnboarding::TurboCompatibility
end
```

### Using Turbo Frames

```erb
<!-- app/views/onboarding/show.html.erb -->
<%= turbo_frame_tag_for_onboarding "onboarding-container" do %>
  <%= render "step", step: @current_step %>
<% end %>
```

### Using Turbo Streams

```ruby
# app/controllers/rails_onboarding/onboarding_controller.rb
def complete_step
  if @user.complete_step(params[:step])
    respond_with_turbo(
      replace: "onboarding-container",
      partial: "rails_onboarding/onboarding/step"
    )
  end
end
```

### Broadcasting Updates

```ruby
# Broadcast onboarding progress to user's stream
broadcast_onboarding_update(current_user, :step_completed, {
  step: 'profile',
  progress: 50
})
```

### Stimulus Integration

```erb
<!-- Using Stimulus controller data helper -->
<div <%= stimulus_controller_data('onboarding', step: 'welcome', progress: 0).map { |k, v| "data-#{k}='#{v}'" }.join(' ').html_safe %>>
  <!-- content -->
</div>

<!-- Using Stimulus action helper -->
<button <%= stimulus_action('click', 'onboarding', 'nextStep').map { |k, v| "data-#{k}='#{v}'" }.join(' ').html_safe %>>
  Next Step
</button>
```

### Turbo Helpers

```ruby
# Disable Turbo for specific links
link_to "Skip", skip_path, **disable_turbo

# Add Turbo confirm dialog
link_to "Delete", delete_path, **turbo_confirm("Are you sure?")

# Change HTTP method
link_to "Complete", complete_path, **turbo_method(:post)
```

---

## Background Jobs

Queue emails, notifications, and analytics events using ActiveJob.

### Features

- **Email Notifications**: Welcome, reminder, and completion emails
- **Custom Notifications**: Integration with notification systems
- **Analytics Tracking**: Background analytics event processing
- **Milestone Achievements**: Async milestone processing
- **Retry Logic**: Automatic retry with exponential backoff

### Setup

1. **Enable Background Jobs**:

```ruby
# config/initializers/rails_onboarding.rb
RailsOnboarding.configure do |config|
  config.background_jobs_enabled = true
  config.background_jobs_queue = :onboarding
  config.mailer_from = 'onboarding@example.com'
end
```

2. **Include in Your Model**:

```ruby
# app/models/user.rb
class User < ApplicationRecord
  include RailsOnboarding::Onboardable
  include RailsOnboarding::BackgroundJobs

  after_create :send_welcome_email

  def send_welcome_email
    queue_onboarding_welcome_email(self)
  end
end
```

### Email Jobs

```ruby
# Send welcome email when user signs up
queue_onboarding_welcome_email(user)

# Send reminder email (queued for 1 day later)
queue_onboarding_reminder_email(user)

# Send completion email
queue_onboarding_completion_email(user)
```

### Notification Jobs

```ruby
# Queue a notification
queue_onboarding_notification(user, :step_completed, {
  step: 'profile',
  progress: 50
})

# Works with Noticed gem
# The notification will be delivered via your Noticed notifications
```

### Analytics Jobs

```ruby
# Track analytics events in background
queue_analytics_event('step_completed', user, {
  step: 'welcome',
  time_spent: 120
})
```

### Milestone Jobs

```ruby
# Process milestone achievements in background
queue_milestone_achievement(user, :onboarding_completed)
```

### Email Templates

Create email templates in your application:

```
app/views/rails_onboarding/onboarding_mailer/
  ├── welcome_email.html.erb
  ├── reminder_email.html.erb
  ├── completion_email.html.erb
  └── step_completed_email.html.erb
```

Example welcome email:

```erb
<!-- app/views/rails_onboarding/onboarding_mailer/welcome_email.html.erb -->
<!DOCTYPE html>
<html>
  <head>
    <meta content='text/html; charset=UTF-8' http-equiv='Content-Type' />
  </head>
  <body>
    <h1>Welcome, <%= @user.email %>!</h1>
    <p>We're excited to have you on board.</p>
    <p>
      <%= link_to "Get Started", @onboarding_url %>
    </p>
  </body>
</html>
```

### Custom Job Configuration

```ruby
# Configure retry behavior
class MyOnboardingJob < RailsOnboarding::ApplicationJob
  retry_on StandardError, wait: 5.minutes, attempts: 5

  def perform(user_id)
    # Custom job logic
  end
end
```

---

## Webhooks

Notify external systems of onboarding events.

### Features

- **Event Triggers**: Automatic webhooks for key events
- **Multiple Endpoints**: Support for multiple webhook URLs
- **Signature Verification**: HMAC signatures for security
- **Retry Logic**: Automatic retry with exponential backoff
- **Async Delivery**: Non-blocking webhook delivery

### Setup

1. **Enable Webhooks**:

```ruby
# config/initializers/rails_onboarding.rb
RailsOnboarding.configure do |config|
  config.webhooks_enabled = true
  config.webhook_secret_key = ENV['WEBHOOK_SECRET_KEY']
  config.webhook_async = true

  config.webhook_endpoints = [
    {
      url: 'https://example.com/webhooks/onboarding',
      events: [], # empty = all events
      headers: {
        'X-API-Key' => ENV['EXTERNAL_API_KEY']
      },
      enabled: true
    }
  ]
end
```

2. **Include in Your Controller**:

```ruby
# app/controllers/rails_onboarding/onboarding_controller.rb
class OnboardingController < ApplicationController
  include RailsOnboarding::Webhooks

  def complete_step
    if current_user.complete_step(params[:step])
      webhook_step_completed(current_user, params[:step])
    end
  end
end
```

### Available Webhook Events

```ruby
# Onboarding started
webhook_onboarding_started(user)

# Step completed
webhook_step_completed(user, 'profile')

# Step skipped
webhook_step_skipped(user, 'explore')

# Onboarding completed
webhook_onboarding_completed(user)

# Onboarding skipped
webhook_onboarding_skipped(user)

# Milestone achieved
webhook_milestone_achieved(user, :early_adopter)

# Tooltip shown
webhook_tooltip_shown(user, 'getting_started')

# Tooltip dismissed
webhook_tooltip_dismissed(user, 'getting_started')
```

### Webhook Payload Format

```json
{
  "event": "onboarding.step_completed",
  "data": {
    "user_id": 123,
    "step_name": "profile",
    "current_step": "first_action",
    "progress_percentage": 50,
    "completed_at": "2024-01-15T10:30:00Z"
  },
  "timestamp": "2024-01-15T10:30:00Z",
  "webhook_id": "550e8400-e29b-41d4-a716-446655440000"
}
```

### Receiving Webhooks

Create a webhook receiver in your external application:

```ruby
# app/controllers/webhooks_controller.rb
class WebhooksController < ApplicationController
  include RailsOnboarding::WebhookVerification

  skip_before_action :verify_authenticity_token

  def receive
    secret = ENV['WEBHOOK_SECRET_KEY']

    if verify_webhook_signature(request, secret)
      payload = extract_webhook_payload(request)
      process_webhook(payload)

      render json: { status: 'success' }, status: :ok
    else
      render json: { error: 'Invalid signature' }, status: :unauthorized
    end
  end

  private

  def process_webhook(payload)
    case payload[:event]
    when 'onboarding.completed'
      # Handle onboarding completion
      user_id = payload[:data][:user_id]
      # Your logic here
    when 'onboarding.step_completed'
      # Handle step completion
    end
  end
end
```

### Dynamic Webhook Registration

```ruby
# Register a webhook at runtime
RailsOnboarding::Webhooks.register_webhook(
  'https://example.com/webhook',
  events: ['onboarding.completed', 'onboarding.step_completed'],
  headers: { 'Authorization' => 'Bearer token' }
)

# Unregister a webhook
RailsOnboarding::Webhooks.unregister_webhook('https://example.com/webhook')
```

### Webhook Security

Webhooks include an HMAC signature in the `X-Webhook-Signature` header:

```ruby
# Signature generation
data = "#{event_name}:#{payload.to_json}:#{timestamp}"
signature = OpenSSL::HMAC.hexdigest('SHA256', secret_key, data)
```

Always verify signatures before processing webhook payloads!

---

## Configuration Examples

### Complete Integration Setup

```ruby
# config/initializers/rails_onboarding.rb
RailsOnboarding.configure do |config|
  # Basic Configuration
  config.user_class_name = 'User'
  config.redirect_after_completion = :dashboard_path
  config.redirect_after_skip = :dashboard_path

  # Devise Integration
  config.devise_integration_enabled = true
  config.redirect_unconfirmed_to_onboarding = false

  # Turbo/Stimulus
  config.turbo_streams_enabled = true
  config.turbo_morphing_enabled = false

  # API Mode
  config.api_mode_enabled = true
  config.api_authentication_method = :token

  # Background Jobs
  config.background_jobs_enabled = true
  config.background_jobs_queue = :onboarding
  config.mailer_from = 'onboarding@example.com'

  # Webhooks
  config.webhooks_enabled = true
  config.webhook_secret_key = ENV['WEBHOOK_SECRET_KEY']
  config.webhook_async = true
  config.webhook_endpoints = [
    {
      url: ENV['WEBHOOK_URL'],
      events: ['onboarding.completed'],
      headers: { 'X-API-Key' => ENV['API_KEY'] }
    }
  ]

  # Onboarding Steps
  config.steps = [
    { name: :welcome, title: 'Welcome', icon: '🎉', skippable: true },
    { name: :profile, title: 'Setup Profile', icon: '👤', skippable: false },
    { name: :first_action, title: 'First Action', icon: '🚀', skippable: false },
    { name: :explore, title: 'Explore Features', icon: '🔍', skippable: true }
  ]
end
```

### Production Configuration

```ruby
# config/environments/production.rb
Rails.application.configure do
  # Use Sidekiq for background jobs
  config.active_job.queue_adapter = :sidekiq

  # Configure action mailer for production
  config.action_mailer.delivery_method = :smtp
  config.action_mailer.smtp_settings = {
    address: ENV['SMTP_ADDRESS'],
    port: ENV['SMTP_PORT'],
    authentication: :plain,
    user_name: ENV['SMTP_USERNAME'],
    password: ENV['SMTP_PASSWORD'],
    enable_starttls_auto: true
  }
end
```

### Testing Configuration

```ruby
# test/test_helper.rb
class ActiveSupport::TestCase
  setup do
    # Disable async jobs in tests
    RailsOnboarding.configure do |config|
      config.background_jobs_enabled = false
      config.webhooks_enabled = false
    end
  end
end
```

---

## Troubleshooting

### Devise Not Redirecting to Onboarding

**Issue**: Users aren't being redirected after sign-in.

**Solution**: Ensure you've included the DeviseControllerExtension:

```ruby
# config/initializers/devise.rb
Devise.setup do |config|
  # ... other config
end

# After devise initializer
if defined?(Devise)
  Devise::SessionsController.include(RailsOnboarding::DeviseControllerExtension)
  Devise::RegistrationsController.include(RailsOnboarding::DeviseControllerExtension)
end
```

### Turbo Frames Not Loading

**Issue**: Turbo frames show loading indicator indefinitely.

**Solution**: Ensure your controller responds with `layout: false` for frame requests:

```ruby
def show
  if turbo_frame_request?
    render layout: false
  else
    render :show
  end
end
```

### Background Jobs Not Running

**Issue**: Emails and notifications aren't being sent.

**Solution**: Ensure you have a job processor running:

```bash
# For Sidekiq
bundle exec sidekiq -q default -q onboarding

# For DelayedJob
bundle exec rake jobs:work
```

### Webhooks Not Delivering

**Issue**: External services aren't receiving webhook events.

**Solution**: Check webhook configuration and logs:

```ruby
# Enable webhook logging
Rails.logger.level = :debug

# Test webhook delivery manually
delivery = RailsOnboarding::WebhookDelivery.new(
  endpoint,
  'test.event',
  { test: 'data' },
  RailsOnboarding.configuration.webhook_options
)
delivery.deliver
```

---

## Additional Resources

- [Main README](README.md)
- [Milestones Guide](MILESTONES_GUIDE.md)
- [Analytics Guide](ANALYTICS_GUIDE.md)
- [Advanced Features](ADVANCED_FEATURES.md)
- [Responsive Design](RESPONSIVE_DESIGN.md)

---

## Support

For issues and feature requests, please visit:
https://github.com/yourusername/rails_onboarding/issues
