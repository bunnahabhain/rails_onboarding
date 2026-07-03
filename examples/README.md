# Rails Onboarding Examples

This directory contains complete working examples and code samples for integrating Rails Onboarding into your application.

## Table of Contents

- [Quick Start Examples](#quick-start-examples)
- [Integration Examples](#integration-examples)
- [Use Case Examples](#use-case-examples)
- [Configuration Templates](#configuration-templates)
- [Testing Examples](#testing-examples)

## Quick Start Examples

### Basic Setup

The simplest Rails Onboarding configuration:

```ruby
# config/initializers/rails_onboarding.rb
RailsOnboarding.configure do |config|
  config.user_class_name = 'User'

  config.steps = [
    { name: :welcome, title: 'Welcome', icon: '👋', skippable: true },
    { name: :profile, title: 'Complete Your Profile', icon: '👤', skippable: false }
  ]

  config.redirect_after_completion = :dashboard_path
  config.redirect_after_skip = :root_path
end
```

### User Model Setup

```ruby
# app/models/user.rb
class User < ApplicationRecord
  include RailsOnboarding::Onboardable

  # Optional: Set onboarding requirements
  def requires_onboarding?
    !onboarding_completed? && created_at > 1.day.ago
  end
end
```

### Controller Setup

```ruby
# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  include RailsOnboarding::ControllerHelpers

  # Optional: Skip onboarding for specific actions
  skip_onboarding_requirement only: [:logout, :help]
end
```

### Routes Setup

```ruby
# config/routes.rb
Rails.application.routes.draw do
  mount RailsOnboarding::Engine => "/", as: "rails_onboarding"

  # Your other routes...
end
```

## Integration Examples

Detailed integration examples are available in the [integrations/](integrations/) directory:

### Available Integrations

1. **[Devise Integration](integrations/devise_integration_example.rb)**
   - Seamless authentication integration
   - Post-signup onboarding redirect
   - Current user integration

2. **[Turbo/Stimulus Integration](integrations/turbo_integration_example.rb)**
   - Hotwire compatibility
   - Turbo Frame examples
   - Stimulus controller integration

3. **[API Mode Integration](integrations/api_integration_example.rb)**
   - RESTful API endpoints
   - Mobile app integration
   - React Native example

4. **[Background Jobs](integrations/background_jobs_example.rb)**
   - Sidekiq integration
   - Async email sending
   - Delayed webhook delivery

5. **[Webhooks](integrations/webhooks_example.rb)**
   - Zapier integration
   - Slack notifications
   - CRM sync examples

See [integrations/README.md](integrations/README.md) for detailed documentation.

## Use Case Examples

### SaaS Application

Complete onboarding flow for a SaaS product:

```ruby
# config/initializers/rails_onboarding.rb
RailsOnboarding.configure do |config|
  config.user_class_name = 'User'

  config.steps = [
    {
      name: :welcome,
      title: 'Welcome to Acme SaaS',
      icon: '🎉',
      skippable: false,
      description: 'Let\'s get you started'
    },
    {
      name: :team_setup,
      title: 'Create Your Team',
      icon: '👥',
      skippable: false,
      description: 'Invite team members'
    },
    {
      name: :workspace,
      title: 'Set Up Workspace',
      icon: '🏢',
      skippable: false,
      description: 'Configure your workspace'
    },
    {
      name: :first_project,
      title: 'Create First Project',
      icon: '🚀',
      skippable: true,
      description: 'Start your first project'
    },
    {
      name: :integrations,
      title: 'Connect Tools',
      icon: '🔌',
      skippable: true,
      description: 'Integrate with your tools'
    }
  ]

  # Milestones for engagement
  config.enable_milestones = true
  config.milestones = {
    account_created: { points: 10, name: 'Account Created' },
    team_created: { points: 25, name: 'First Team' },
    first_project: { points: 50, name: 'First Project' },
    invited_teammate: { points: 30, name: 'Invited Teammate' },
    first_integration: { points: 40, name: 'Connected Integration' }
  }

  # Analytics for funnel optimization
  config.enable_analytics = true

  # Tooltips for feature discovery
  config.enable_tooltips = true
  config.tooltips = {
    dashboard_projects: {
      title: 'Your Projects',
      content: 'All your projects appear here',
      target: '#projects-list',
      position: 'right'
    },
    create_project_button: {
      title: 'Create Project',
      content: 'Click here to start a new project',
      target: '#new-project-btn',
      position: 'bottom'
    }
  }

  # Redirects
  config.redirect_after_completion = :dashboard_path
  config.redirect_after_skip = :limited_dashboard_path

  # Webhooks for integrations
  config.webhooks = [
    {
      url: ENV['WEBHOOK_URL'],
      events: ['onboarding.completed', 'milestone.achieved'],
      secret_key: ENV['WEBHOOK_SECRET_KEY']
    }
  ]
end
```

### E-commerce Application

Onboarding for sellers on a marketplace:

```ruby
RailsOnboarding.configure do |config|
  config.user_class_name = 'Seller'

  config.steps = [
    {
      name: :welcome,
      title: 'Welcome to Marketplace',
      icon: '🛍️',
      skippable: false
    },
    {
      name: :store_setup,
      title: 'Set Up Your Store',
      icon: '🏪',
      skippable: false,
      description: 'Create your store profile'
    },
    {
      name: :payment_setup,
      title: 'Payment Information',
      icon: '💳',
      skippable: false,
      description: 'Set up payment processing'
    },
    {
      name: :first_product,
      title: 'Add Your First Product',
      icon: '📦',
      skippable: false,
      description: 'List your first item'
    },
    {
      name: :shipping,
      title: 'Shipping Settings',
      icon: '🚚',
      skippable: true,
      description: 'Configure shipping options'
    },
    {
      name: :policies,
      title: 'Store Policies',
      icon: '📋',
      skippable: true,
      description: 'Set return and refund policies'
    }
  ]

  # Milestones for seller engagement
  config.milestones = {
    store_created: { points: 10, name: 'Store Created' },
    payment_setup: { points: 20, name: 'Payment Configured' },
    first_product: { points: 50, name: 'First Product Listed' },
    first_sale: { points: 100, name: 'First Sale!' }
  }

  config.redirect_after_completion = :seller_dashboard_path
end
```

### Community/Social Platform

User onboarding for social features:

```ruby
RailsOnboarding.configure do |config|
  config.steps = [
    {
      name: :welcome,
      title: 'Join the Community',
      icon: '👋',
      skippable: false
    },
    {
      name: :profile,
      title: 'Create Your Profile',
      icon: '👤',
      skippable: false,
      description: 'Tell us about yourself'
    },
    {
      name: :interests,
      title: 'Choose Interests',
      icon: '❤️',
      skippable: false,
      description: 'What are you interested in?'
    },
    {
      name: :follow_users,
      title: 'Find People to Follow',
      icon: '👥',
      skippable: true,
      description: 'Connect with others'
    },
    {
      name: :first_post,
      title: 'Make Your First Post',
      icon: '✍️',
      skippable: true,
      description: 'Share something with the community'
    }
  ]

  # Progressive disclosure of features
  config.tooltips = {
    feed_explained: {
      title: 'Your Feed',
      content: 'See posts from people you follow',
      target: '#main-feed'
    },
    notifications: {
      title: 'Notifications',
      content: 'Stay updated with activity',
      target: '#notifications-bell'
    }
  }

  config.redirect_after_completion = :feed_path
end
```

### Educational Platform

Student onboarding for learning platform:

```ruby
RailsOnboarding.configure do |config|
  config.steps = [
    {
      name: :welcome,
      title: 'Welcome, Student!',
      icon: '🎓',
      skippable: false
    },
    {
      name: :learning_goals,
      title: 'Set Learning Goals',
      icon: '🎯',
      skippable: false,
      description: 'What do you want to learn?'
    },
    {
      name: :skill_assessment,
      title: 'Skill Assessment',
      icon: '📊',
      skippable: true,
      description: 'Help us understand your level'
    },
    {
      name: :choose_courses,
      title: 'Choose Your Courses',
      icon: '📚',
      skippable: false,
      description: 'Pick courses to start with'
    },
    {
      name: :first_lesson,
      title: 'Start Your First Lesson',
      icon: '🚀',
      skippable: true,
      description: 'Begin learning!'
    }
  ]

  # Achievement milestones
  config.milestones = {
    profile_completed: { points: 10, name: 'Profile Complete' },
    first_course: { points: 25, name: 'Enrolled in First Course' },
    first_lesson: { points: 50, name: 'Completed First Lesson' },
    streak_7days: { points: 100, name: '7-Day Streak' }
  }

  # Personalization based on learning goals
  config.enable_personalization = true
  config.personalizable_attribute = :learning_goal

  config.redirect_after_completion = :courses_path
end
```

## Configuration Templates

### Minimal Configuration

For quick setup with defaults:

```ruby
RailsOnboarding.configure do |config|
  config.user_class_name = 'User'
  config.steps = [
    { name: :welcome, title: 'Welcome' },
    { name: :profile, title: 'Profile Setup' }
  ]
end
```

### Full-Featured Configuration

All available options:

```ruby
RailsOnboarding.configure do |config|
  # Core Settings
  config.user_class_name = 'User'

  # Steps
  config.steps = [
    {
      name: :welcome,
      title: 'Welcome',
      icon: '👋',
      skippable: true,
      description: 'Welcome to our app',
      template: 'custom_welcome'  # Optional custom template
    }
  ]

  # Redirects
  config.redirect_after_completion = :dashboard_path
  config.redirect_after_skip = :root_path
  config.redirect_if_completed = :dashboard_path

  # Features
  config.enable_tooltips = true
  config.enable_milestones = true
  config.enable_analytics = true
  config.enable_ab_testing = true
  config.enable_personalization = true

  # Milestones
  config.milestones = {
    first_login: {
      name: 'First Login',
      points: 10,
      trigger: :on_step_complete,
      trigger_value: :welcome,
      celebration: true
    }
  }

  # Tooltips
  config.tooltips = {
    dashboard_welcome: {
      title: 'Your Dashboard',
      content: 'This is where you manage everything',
      target: '#dashboard',
      position: 'bottom',
      delay: 1000,
      dismissible: true
    }
  }

  # Onboarding Requirements
  config.onboarding_required_for = :new_users  # or :all_users, :none
  config.new_user_threshold = 1.day

  # Skipping
  config.allow_skip = true
  config.skip_button_text = 'Skip for now'
  config.confirm_skip = true

  # Caching
  config.cache_configuration = true
  config.cache_ttl = 1.hour

  # Background Processing
  config.send_emails_async = true
  config.process_webhooks_async = true

  # Webhooks
  config.webhooks = [
    {
      url: ENV['WEBHOOK_URL'],
      events: ['onboarding.completed', 'step.completed', 'milestone.achieved'],
      secret_key: ENV['WEBHOOK_SECRET_KEY'],
      headers: { 'X-Custom-Header' => 'value' },
      timeout: 30,
      retry_attempts: 3,
      retry_delay: 60
    }
  ]

  # API Mode
  config.api_mode = true

  # Analytics
  config.analytics_retention_days = 90

  # Multi-tenant
  config.multi_tenant = true
  config.tenant_attribute = :organization_id

  # Internationalization
  config.default_locale = :en
  config.available_locales = [:en, :es, :fr]

  # A/B Testing
  config.ab_tests = {
    onboarding_flow_v2: {
      variants: {
        control: { weight: 50 },
        variant_a: { weight: 25 },
        variant_b: { weight: 25 }
      }
    }
  }

  # Personalization
  config.personalizable_attribute = :user_type
  config.personalization_flows = {
    developer: [:welcome, :setup_api, :first_request],
    designer: [:welcome, :setup_design, :first_project]
  }

  # Rate Limiting
  config.enable_rate_limiting = true
  config.rate_limit = { limit: 100, period: 1.hour }
end
```

### Production-Ready Configuration

Recommended settings for production:

```ruby
RailsOnboarding.configure do |config|
  # Core
  config.user_class_name = 'User'

  # Steps (keep concise, 3-5 steps ideal)
  config.steps = [
    { name: :welcome, title: 'Welcome', icon: '👋', skippable: true },
    { name: :profile, title: 'Complete Profile', icon: '👤', skippable: false },
    { name: :first_action, title: 'Get Started', icon: '🚀', skippable: false }
  ]

  # Enable key features
  config.enable_analytics = true
  config.enable_milestones = true
  config.enable_tooltips = true

  # Performance
  config.cache_configuration = Rails.env.production?
  config.cache_ttl = 1.hour
  config.send_emails_async = true
  config.process_webhooks_async = true

  # Analytics retention
  config.analytics_retention_days = 90

  # Redirects
  config.redirect_after_completion = :dashboard_path
  config.redirect_after_skip = :dashboard_path

  # Webhooks (optional)
  if ENV['WEBHOOK_URL'].present?
    config.webhooks = [
      {
        url: ENV['WEBHOOK_URL'],
        events: ['onboarding.completed'],
        secret_key: ENV['WEBHOOK_SECRET_KEY'],
        timeout: 30,
        retry_attempts: 3
      }
    ]
  end

  # Security
  config.enable_rate_limiting = Rails.env.production?
  config.rate_limit = { limit: 100, period: 1.hour }
end
```

## Testing Examples

### RSpec Example

```ruby
# spec/features/onboarding_spec.rb
require 'rails_helper'

RSpec.describe 'User Onboarding', type: :feature do
  let(:user) { create(:user) }

  before { sign_in user }

  it 'completes onboarding flow' do
    visit root_path

    # Should redirect to onboarding
    expect(page).to have_current_path(rails_onboarding.onboarding_path)

    # Welcome step
    expect(page).to have_content('Welcome')
    click_button 'Next'

    # Profile step
    expect(page).to have_content('Complete Your Profile')
    fill_in 'Name', with: 'John Doe'
    fill_in 'Bio', with: 'Developer'
    click_button 'Next'

    # Should complete onboarding
    expect(page).to have_current_path(dashboard_path)
    expect(user.reload.onboarding_completed?).to be true
  end

  it 'tracks analytics events' do
    visit rails_onboarding.onboarding_path

    expect {
      click_button 'Next'
    }.to change { RailsOnboarding::AnalyticsEvent.count }.by(1)

    event = RailsOnboarding::AnalyticsEvent.last
    expect(event.event_name).to eq('step_completed')
    expect(event.properties['step']).to eq('welcome')
  end

  it 'awards milestones' do
    visit rails_onboarding.onboarding_path
    click_button 'Next' # Complete welcome step

    expect(user.reload.milestones_achieved).to include('first_step')
    expect(user.onboarding_points).to be > 0
  end
end
```

### Minitest Example

```ruby
# test/integration/onboarding_test.rb
require 'test_helper'

class OnboardingTest < ActionDispatch::IntegrationTest
  def setup
    @user = users(:one)
    sign_in @user
  end

  test "redirects to onboarding for new users" do
    get root_path
    assert_redirected_to rails_onboarding.onboarding_path
  end

  test "completes onboarding flow" do
    get rails_onboarding.onboarding_path
    assert_response :success

    # Complete welcome step
    post rails_onboarding.complete_step_path, params: {
      step_name: 'welcome',
      step_data: {}
    }
    assert_response :redirect

    # Verify step completed
    @user.reload
    assert @user.step_completed?(:welcome)
  end

  test "skips onboarding when allowed" do
    post rails_onboarding.skip_path
    assert_redirected_to root_path

    @user.reload
    assert @user.onboarding_skipped?
  end
end
```

### API Testing Example

```ruby
# test/integration/api_onboarding_test.rb
require 'test_helper'

class ApiOnboardingTest < ActionDispatch::IntegrationTest
  def setup
    @user = users(:one)
    @user.update(api_token: 'test_token_123')
  end

  test "gets current step via API" do
    get api_v1_onboarding_current_step_url,
      headers: { 'Authorization' => 'Bearer test_token_123' }

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal 'welcome', json['current_step']
  end

  test "completes step via API" do
    post api_v1_onboarding_complete_step_url,
      params: { step_name: 'welcome', step_data: {} }.to_json,
      headers: {
        'Authorization' => 'Bearer test_token_123',
        'Content-Type' => 'application/json'
      }

    assert_response :success
    @user.reload
    assert @user.step_completed?(:welcome)
  end
end
```

## Running Examples

### Try the Examples Locally

1. **Set up a test Rails app:**
   ```bash
   rails new test_app --database=postgresql
   cd test_app
   ```

2. **Add Rails Onboarding:**
   ```ruby
   # Gemfile
   gem 'rails_onboarding', path: '../rails_onboarding'
   ```

3. **Install and configure:**
   ```bash
   bundle install
   bundle exec rails generate rails_onboarding:install
   bundle exec rails db:migrate
   ```

4. **Copy example configuration:**
   ```bash
   # Copy one of the use case examples above to:
   # config/initializers/rails_onboarding.rb
   ```

5. **Start the server:**
   ```bash
   bundle exec rails server
   ```

6. **Test it out:**
   - Create a new user
   - Watch the onboarding flow
   - Check analytics in console

## Additional Resources

- **[Main README](../README.md)** - Full documentation
- **[API Authentication Guide](../API_AUTHENTICATION_GUIDE.md)** - Secure API setup
- **[Webhook Security Guide](../WEBHOOK_SECURITY_GUIDE.md)** - Webhook integration
- **[Deployment Guide](../docs/DEPLOYMENT_GUIDE.md)** - Production deployment
- **[Troubleshooting Guide](../docs/TROUBLESHOOTING.md)** - Common issues

## Contributing Examples

Have a great example to share?

1. Fork the repository
2. Add your example to this directory
3. Update this README
4. Submit a pull request

Examples we'd love to see:
- Industry-specific configurations
- Advanced personalization setups
- Custom integrations
- Multi-language implementations
- Accessibility-focused setups

## Questions?

- **GitHub Issues:** [Report issues](https://github.com/bunnahabhain/rails_onboarding/issues)
- **Discussions:** [Ask questions](https://github.com/bunnahabhain/rails_onboarding/discussions)
- **Documentation:** [Read the guides](../README.md)

Happy onboarding! 🚀
