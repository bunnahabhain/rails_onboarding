# Integration Examples

This directory contains comprehensive integration examples for RailsOnboarding. Each file demonstrates how to integrate the gem with popular Rails frameworks and tools.

## Available Examples

### 1. Devise Integration (`devise_integration_example.rb`)

Learn how to integrate RailsOnboarding with Devise authentication:

- Automatic redirect after sign-in/sign-up
- Skip onboarding for admin users
- Handle unconfirmed users
- Custom Devise controller overrides
- Testing strategies

**Key Features:**
- Seamless authentication flow
- Admin bypass logic
- Post-confirmation redirects
- Integration tests

### 2. Turbo & Stimulus Integration (`turbo_integration_example.rb`)

Integrate with Rails 7+ Hotwire stack:

- Turbo Frames for step navigation
- Turbo Streams for real-time updates
- Broadcasting onboarding progress
- Stimulus controller patterns
- Turbo Native detection

**Key Features:**
- Frame-based navigation
- Real-time progress updates
- Stimulus data attributes
- Mobile app support

### 3. API Mode Integration (`api_integration_example.rb`)

Build headless onboarding APIs for mobile and SPAs:

- RESTful JSON endpoints
- Token authentication
- React Native examples
- Error handling
- Comprehensive testing

**Key Features:**
- Full JSON API
- Mobile app examples
- Custom endpoints
- API documentation

### 4. Background Jobs Integration (`background_jobs_example.rb`)

Use ActiveJob for emails, notifications, and analytics:

- Welcome and reminder emails
- Progress notifications
- Analytics tracking
- Milestone processing
- Sidekiq configuration

**Key Features:**
- Email automation
- Notification system integration
- Retry logic
- Email templates

### 5. Webhooks Integration (`webhooks_example.rb`)

Notify external systems of onboarding events:

- Event triggers
- Signature verification
- Multiple endpoints
- Zapier integration
- Slack notifications

**Key Features:**
- Secure webhook delivery
- External service integration
- Monitoring and logging
- Retry mechanisms

## Quick Start

### 1. Choose Your Integration

Review the example files to understand which integrations you need for your application.

### 2. Configure in Your Initializer

```ruby
# config/initializers/rails_onboarding.rb
RailsOnboarding.configure do |config|
  # Enable desired integrations
  config.devise_integration_enabled = true
  config.turbo_streams_enabled = true
  config.api_mode_enabled = true
  config.background_jobs_enabled = true
  config.webhooks_enabled = true

  # Configure each integration
  config.webhook_endpoints = [
    { url: ENV['WEBHOOK_URL'], events: [], enabled: true }
  ]
end
```

### 3. Include Modules in Your Code

```ruby
class ApplicationController < ActionController::Base
  include RailsOnboarding::DeviseIntegration
  include RailsOnboarding::TurboCompatibility
  include RailsOnboarding::Webhooks
  include RailsOnboarding::BackgroundJobs
end
```

### 4. Test Your Integration

Each example file includes testing patterns to verify your integration works correctly.

## Integration Checklist

### Devise
- [ ] Configure Devise integration in initializer
- [ ] Include DeviseIntegration in controllers
- [ ] Test redirect after sign-in
- [ ] Test admin bypass logic

### Turbo/Stimulus
- [ ] Enable Turbo Streams
- [ ] Add Turbo Frame tags to views
- [ ] Implement Stimulus controllers
- [ ] Test frame requests

### API Mode
- [ ] Enable API mode
- [ ] Set up authentication
- [ ] Mount API routes
- [ ] Test API endpoints

### Background Jobs
- [ ] Configure job queue
- [ ] Set up email templates
- [ ] Test job execution
- [ ] Configure Sidekiq/DelayedJob

### Webhooks
- [ ] Enable webhooks
- [ ] Configure endpoints
- [ ] Set up signature verification
- [ ] Test webhook delivery

## Common Patterns

### Multi-Integration Setup

Most applications will use multiple integrations together:

```ruby
# Example: SaaS application with all integrations
class OnboardingController < ApplicationController
  include RailsOnboarding::DeviseIntegration      # Authentication
  include RailsOnboarding::TurboCompatibility     # Modern UX
  include RailsOnboarding::BackgroundJobs         # Email/notifications
  include RailsOnboarding::Webhooks               # External services

  def complete
    if current_user.complete_onboarding!
      # Send completion email (background job)
      queue_onboarding_completion_email(current_user)

      # Notify external CRM (webhook)
      webhook_onboarding_completed(current_user)

      # Broadcast to user stream (Turbo)
      broadcast_onboarding_update(current_user, :completed)

      redirect_to dashboard_path
    end
  end
end
```

### Testing All Integrations

```ruby
RSpec.describe OnboardingController do
  let(:user) { create(:user) }

  before do
    sign_in user # Devise
  end

  it "completes onboarding with all integrations" do
    # Expect background job
    expect {
      # Expect webhook delivery
      stub_request(:post, webhook_url)

      # Make request with Turbo
      post complete_onboarding_path, headers: {
        "Accept" => "text/vnd.turbo-stream.html"
      }
    }.to have_enqueued_job(OnboardingMailerJob)

    expect(WebMock).to have_requested(:post, webhook_url)
    expect(response.content_type).to include("turbo-stream")
  end
end
```

## Production Considerations

### Performance
- Use async webhooks in production
- Configure proper queue workers (Sidekiq)
- Enable caching where appropriate

### Security
- Always verify webhook signatures
- Use secure API tokens
- Enable CSRF protection for web requests

### Monitoring
- Log webhook deliveries
- Monitor job queue health
- Track API request rates

## Additional Resources

- [INTEGRATION_GUIDE.md](../../docs/INTEGRATION_GUIDE.md) - Complete integration documentation
- [README.md](../../README.md) - Main documentation
- [API_DOCUMENTATION.md](../../docs/API_DOCUMENTATION.md) - API reference

## Support

For questions or issues with integrations:
- Review the main [INTEGRATION_GUIDE.md](../../docs/INTEGRATION_GUIDE.md)
- Check test files for working examples
- Open an issue on GitHub

## Contributing

Have a new integration example? Please contribute!

1. Create a new example file
2. Include comprehensive code examples
3. Add testing patterns
4. Update this README
5. Submit a pull request
