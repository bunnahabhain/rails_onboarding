# Advanced Features Guide

This guide covers all advanced features available in the Rails Onboarding gem, including A/B Testing, Personalization, Progressive Disclosure, Interactive Tours, and Onboarding Templates.

## Table of Contents

1. [A/B Testing](#ab-testing)
2. [Personalization](#personalization)
3. [Progressive Disclosure](#progressive-disclosure)
4. [Interactive Tours](#interactive-tours)
5. [Onboarding Templates](#onboarding-templates)
6. [Integration Examples](#integration-examples)

---

## A/B Testing

Test different onboarding flows to optimize conversion rates and user engagement.

### Configuration

```ruby
# config/initializers/rails_onboarding.rb
RailsOnboarding.configure do |config|
  config.enable_ab_testing = true

  config.ab_tests = {
    onboarding_flow: {
      variants: ['original', 'simplified', 'gamified'],
      weights: [50, 25, 25], # Percentage distribution
      enabled: true
    },
    welcome_message: {
      variants: ['formal', 'casual'],
      weights: [50, 50],
      enabled: true
    }
  }
end
```

### Database Migration

Add A/B testing fields to your User model:

```ruby
class AddAbTestingToUsers < ActiveRecord::Migration[7.0]
  def change
    add_column :users, :ab_test_assignments, :jsonb, default: {}
  end
end
```

### Model Setup

Include the `AbTestable` concern in your User model:

```ruby
class User < ApplicationRecord
  include RailsOnboarding::Onboardable
  include RailsOnboarding::AbTestable
end
```

### Usage

#### Automatic Assignment

Users are automatically assigned to variants when they're created:

```ruby
user = User.create(email: 'user@example.com')
user.ab_test_variant(:onboarding_flow)
# => "simplified"
```

#### Check Variant

```ruby
# In your controller or view
if current_user.in_variant?(:onboarding_flow, :simplified)
  render 'simplified_onboarding'
else
  render 'standard_onboarding'
end
```

#### Manual Assignment

```ruby
# Assign a specific user to a variant
user.assign_variant(:onboarding_flow, :gamified)
```

#### Track Conversions

```ruby
# Track when a user completes an important action
current_user.track_ab_conversion(:onboarding_flow, :completed, {
  time_spent: 300,
  steps_completed: 4
})
```

### Viewing Results

Access A/B test results at `/rails_onboarding/ab_tests`:

```ruby
# In your routes.rb
mount RailsOnboarding::Engine => "/rails_onboarding"
```

Or retrieve results programmatically:

```ruby
# GET /rails_onboarding/ab_tests/onboarding_flow/results.json
{
  "results": {
    "original": {
      "participants": 1000,
      "completions": 650,
      "conversion_rate": 65.0,
      "average_time": 420.5,
      "skip_rate": 15.2
    },
    "simplified": {
      "participants": 500,
      "completions": 380,
      "conversion_rate": 76.0,
      "average_time": 280.3,
      "skip_rate": 8.5
    }
  }
}
```

---

## Personalization

Adapt onboarding flows based on user type, role, or other attributes.

### Configuration

```ruby
RailsOnboarding.configure do |config|
  config.personalization_enabled = true
  config.user_type_method = :account_type # Method to call on User

  config.personalized_flows = {
    individual: [
      { name: :welcome, title: "Welcome", icon: "🎉", skippable: true },
      { name: :profile, title: "Setup Profile", icon: "👤", skippable: false },
      { name: :preferences, title: "Preferences", icon: "⚙️", skippable: true }
    ],
    business: [
      { name: :welcome, title: "Welcome", icon: "🎉", skippable: true },
      { name: :company, title: "Company Info", icon: "🏢", skippable: false },
      { name: :team, title: "Team Setup", icon: "👥", skippable: false },
      { name: :billing, title: "Billing", icon: "💳", skippable: false }
    ],
    enterprise: [
      { name: :welcome, title: "Welcome", icon: "🎉", skippable: true },
      { name: :organization, title: "Organization", icon: "🏢", skippable: false },
      { name: :sso_setup, title: "SSO Setup", icon: "🔐", skippable: false },
      { name: :team, title: "Team Structure", icon: "👥", skippable: false },
      { name: :integrations, title: "Integrations", icon: "🔌", skippable: true }
    ]
  }
end
```

### Model Setup

Add a database column to track personalized flow type (optional):

```ruby
class AddPersonalizationToUsers < ActiveRecord::Migration[7.0]
  def change
    add_column :users, :personalized_flow_type, :string
  end
end
```

Include the `Personalizable` concern:

```ruby
class User < ApplicationRecord
  include RailsOnboarding::Onboardable
  include RailsOnboarding::Personalizable

  # Define the method specified in user_type_method configuration
  def account_type
    # Your logic to determine user type
    subscription_plan || :individual
  end
end
```

### Usage

#### Get Personalized Steps

```ruby
# Automatically returns the right flow based on user type
current_user.personalized_steps
# => [{name: :welcome, ...}, {name: :company, ...}, ...]
```

#### Check Progress

```ruby
current_user.personalized_progress_percentage
# => 50

current_user.personalized_next_step
# => {name: :team, title: "Team Setup", ...}
```

#### In Views

```erb
<!-- Show content only for specific user types -->
<%= for_user_types(:business, :enterprise) do %>
  <div class="enterprise-features">
    <h3>Enterprise Features</h3>
    <!-- Enterprise-specific content -->
  </div>
<% end %>

<!-- Personalized messages -->
<h1><%= personalized_message({
  business: "Welcome to Your Business Dashboard",
  enterprise: "Welcome to Your Enterprise Console",
  individual: "Welcome to Your Personal Space"
}, default: "Welcome!") %></h1>

<!-- Personalized CTAs -->
<%= link_to personalized_cta(:next), next_step_path, class: 'btn btn-primary' %>
```

---

## Progressive Disclosure

Show features gradually over time based on user behavior and engagement.

### Configuration

```ruby
RailsOnboarding.configure do |config|
  config.progressive_disclosure_enabled = true

  config.progressive_features = [
    # Time-based reveal
    {
      key: :advanced_settings,
      title: "Advanced Settings",
      description: "Now that you're familiar with the basics, unlock advanced features",
      reveal_condition: :time_based,
      delay: 7.days
    },

    # Action-based reveal
    {
      key: :team_collaboration,
      title: "Team Collaboration",
      description: "Ready to invite your team?",
      reveal_condition: :action_based,
      check_method: :has_created_first_project?
    },

    # Step-based reveal
    {
      key: :integrations,
      title: "Integrations",
      description: "Connect your favorite tools",
      reveal_condition: :step_based,
      after_step: :profile
    },

    # Milestone-based reveal
    {
      key: :pro_features,
      title: "Pro Features",
      description: "You've earned access to Pro features!",
      reveal_condition: :milestone_based,
      required_milestone: :power_user
    },

    # Engagement-based reveal
    {
      key: :analytics,
      title: "Analytics Dashboard",
      description: "Track your progress and insights",
      reveal_condition: :engagement_based,
      min_events: 10,
      event_type: :onboarding_step_completed
    }
  ]
end
```

### Database Migration

```ruby
class AddProgressiveDisclosureToUsers < ActiveRecord::Migration[7.0]
  def change
    add_column :users, :revealed_features, :jsonb, default: []
  end
end
```

### Model Setup

```ruby
class User < ApplicationRecord
  include RailsOnboarding::Onboardable
  include RailsOnboarding::ProgressiveDisclosure

  # Define custom check methods for action-based reveals
  def has_created_first_project?
    projects.any?
  end
end
```

### Usage

#### Check Feature Status

```ruby
# Check if a feature has been revealed
current_user.feature_revealed?(:advanced_settings)
# => false

# Get features ready to reveal
current_user.features_ready_to_reveal
# => [{key: :team_collaboration, title: "...", ...}]

# Reveal all ready features
current_user.reveal_ready_features!
# => ["team_collaboration", "integrations"]
```

#### In Views

```erb
<!-- Show feature only if revealed -->
<% if current_user.feature_revealed?(:advanced_settings) %>
  <div class="advanced-settings">
    <!-- Advanced settings content -->
  </div>
<% end %>

<!-- Using the configuration helper -->
<% if RailsOnboarding.configuration.show_progressive_feature?(:analytics, current_user) %>
  <%= link_to "View Analytics", analytics_path %>
<% end %>
```

#### Frontend Integration

Add the Stimulus controller to automatically check and reveal features:

```erb
<div data-controller="progressive-disclosure"
     data-progressive-disclosure-check-interval-value="60000"
     data-progressive-disclosure-auto-reveal-value="true">
  <!-- Your content -->
</div>
```

#### API Endpoints

```javascript
// Check which features are ready
fetch('/rails_onboarding/progressive_features/ready')
  .then(res => res.json())
  .then(features => console.log('Ready features:', features))

// Manually reveal a feature
fetch('/rails_onboarding/progressive_features/advanced_settings/reveal', {
  method: 'POST',
  headers: {
    'X-CSRF-Token': csrfToken,
    'Content-Type': 'application/json'
  }
})
```

---

## Interactive Tours

Create guided walkthroughs with spotlight effects and step-by-step navigation.

### Configuration

Define tours in your views or JavaScript:

```erb
<div data-controller="rails-onboarding--tour"
     data-rails-onboarding--tour-steps-value='<%= tour_steps.to_json %>'
     data-rails-onboarding--tour-tour-id-value="dashboard-tour"
     data-rails-onboarding--tour-auto-start-value="true">
</div>
```

### Tour Steps Definition

```ruby
# In your controller or helper
def dashboard_tour_steps
  [
    {
      id: 'welcome',
      title: 'Welcome to Your Dashboard',
      content: 'Let us show you around!',
      position: 'center',
      highlightStyle: 'none'
    },
    {
      id: 'sidebar',
      selector: '.sidebar',
      title: 'Navigation',
      content: 'Use this sidebar to navigate between sections',
      position: 'right',
      highlightStyle: 'spotlight'
    },
    {
      id: 'create-button',
      selector: '.create-new-btn',
      title: 'Create New Items',
      content: 'Click here to create your first item',
      position: 'bottom',
      highlightStyle: 'glow'
    },
    {
      id: 'profile',
      selector: '.user-profile',
      title: 'Your Profile',
      content: 'Manage your account settings here',
      position: 'left',
      highlightStyle: 'border'
    }
  ]
end
```

### Tour Options

```javascript
// All available options
{
  steps: [], // Array of step configurations
  autoStart: false, // Start tour automatically
  showProgress: true, // Show progress indicator
  allowSkip: true, // Allow users to skip the tour
  overlayOpacity: 0.7, // Overlay darkness (0-1)
  highlightStyle: 'spotlight', // spotlight, border, glow, none
  scrollBehavior: 'smooth', // smooth, auto, none
  scrollOffset: 80, // Offset from top when scrolling
  persistProgress: true, // Save progress in localStorage
  tourId: 'my-tour' // Unique identifier
}
```

### Step Configuration

```javascript
{
  id: 'step-1',
  selector: '.target-element', // CSS selector for element to highlight
  title: 'Step Title',
  content: 'Step description with <strong>HTML</strong> support',
  position: 'auto', // auto, top, bottom, left, right, center
  highlightStyle: 'spotlight', // spotlight, border, glow, none
  highlightPadding: 10, // Padding around highlighted element
  showNext: true, // Show next button
  showPrev: true, // Show previous button
  showSkip: true, // Show skip button
  nextLabel: 'Next',
  prevLabel: 'Previous',
  skipLabel: 'Skip Tour',
  completeLabel: 'Complete',
  width: 400, // Popup width in pixels
  beforeShow: 'myCallbackFunction', // Function to run before showing
  afterShow: 'myCallbackFunction', // Function to run after showing
  beforeHide: 'myCallbackFunction', // Function to run before hiding
  onComplete: 'myCallbackFunction' // Function to run on completion
}
```

### Programmatic Control

```javascript
// Start a tour
const tourController = document.querySelector('[data-controller="rails-onboarding--tour"]')
tourController.dispatchEvent(new CustomEvent('tour:start'))

// Or access the controller directly
const controller = application.getControllerForElementAndIdentifier(
  tourController,
  'rails-onboarding--tour'
)

controller.start() // Start tour
controller.stop() // Stop tour
controller.next() // Go to next step
controller.previous() // Go to previous step
controller.goToStep(2) // Go to specific step
controller.skip() // Skip tour
controller.complete() // Complete tour
```

### Events

Listen to tour events:

```javascript
tourElement.addEventListener('rails-onboarding--tour:start', (event) => {
  console.log('Tour started:', event.detail.tourId)
})

tourElement.addEventListener('rails-onboarding--tour:complete', (event) => {
  console.log('Tour completed:', event.detail)
  // { tourId: 'dashboard-tour', stepsCompleted: 5, totalSteps: 5 }
})

tourElement.addEventListener('rails-onboarding--tour:step-shown', (event) => {
  console.log('Step shown:', event.detail.step, event.detail.index)
})

tourElement.addEventListener('rails-onboarding--tour:skip', (event) => {
  console.log('Tour skipped')
})
```

---

## Onboarding Templates

Pre-built onboarding flows for common use cases.

### Available Templates

The gem includes 5 pre-built templates:

1. **SaaS Application** - For software-as-a-service products
2. **E-commerce Platform** - For online stores
3. **Marketplace** - For two-sided marketplaces
4. **Community Platform** - For social/community apps
5. **Educational Platform** - For learning management systems

### Applying a Template

```ruby
# In your initializer
RailsOnboarding.configure do |config|
  config.apply_template(:saas)
end
```

Or apply dynamically:

```ruby
# In a controller
def setup_onboarding
  template_key = params[:template] || :saas
  RailsOnboarding.configuration.apply_template(template_key)
  redirect_to onboarding_path
end
```

### Template Structure

Each template includes:

```ruby
{
  name: "Template Name",
  description: "What this template is for",
  steps: [
    { name: :step1, title: "Step 1", icon: "🎉", skippable: false },
    { name: :step2, title: "Step 2", icon: "👤", skippable: true },
    # ...
  ],
  suitable_for: "Who should use this template"
}
```

### Viewing Templates

Access the templates interface at `/rails_onboarding/templates`:

```ruby
# In your routes.rb
mount RailsOnboarding::Engine => "/rails_onboarding"
```

### Helper Methods

```ruby
# Get all available templates
available_templates
# => { saas: {...}, ecommerce: {...}, ... }

# Get a specific template
get_template(:saas)
# => { name: "SaaS Application", steps: [...], ... }

# Get recommended template based on context
recommended_template(industry: :ecommerce, team_size: 1)
# => :ecommerce

# Compare templates
compare_templates(:saas, :marketplace)
# => { saas: { total_steps: 5, ... }, marketplace: { total_steps: 5, ... } }

# Get template metadata
template_metadata(:saas)
# => { name: "...", estimated_time: "5-15 minutes", difficulty: :medium, ... }
```

### Creating Custom Templates

Save your current configuration as a custom template:

```ruby
# POST /rails_onboarding/templates/custom
{
  "template_name": "My Custom Flow",
  "template_key": "custom_flow",
  "description": "Our specialized onboarding"
}
```

---

## Integration Examples

### Complete Integration Example

```ruby
# config/initializers/rails_onboarding.rb
RailsOnboarding.configure do |config|
  # Basic configuration
  config.user_class_name = 'User'

  # Enable all advanced features
  config.enable_ab_testing = true
  config.personalization_enabled = true
  config.progressive_disclosure_enabled = true
  config.enable_milestones = true
  config.enable_analytics = true

  # A/B Testing
  config.ab_tests = {
    onboarding_flow: {
      variants: ['standard', 'simplified'],
      weights: [50, 50],
      enabled: true
    }
  }

  # Personalization
  config.user_type_method = :account_type
  config.personalized_flows = {
    individual: [
      { name: :welcome, title: "Welcome", icon: "🎉" },
      { name: :profile, title: "Profile", icon: "👤" }
    ],
    business: [
      { name: :welcome, title: "Welcome", icon: "🎉" },
      { name: :company, title: "Company", icon: "🏢" },
      { name: :team, title: "Team", icon: "👥" }
    ]
  }

  # Progressive Disclosure
  config.progressive_features = [
    {
      key: :advanced_features,
      title: "Advanced Features",
      reveal_condition: :time_based,
      delay: 7.days
    }
  ]

  # Apply a template (or configure custom steps)
  config.apply_template(:saas)
end
```

### User Model

```ruby
class User < ApplicationRecord
  include RailsOnboarding::Onboardable
  include RailsOnboarding::AbTestable
  include RailsOnboarding::Personalizable
  include RailsOnboarding::ProgressiveDisclosure

  def account_type
    enterprise? ? :enterprise : (business? ? :business : :individual)
  end

  def has_created_first_project?
    projects.exists?
  end
end
```

### Migration

```ruby
class AddRailsOnboardingFieldsToUsers < ActiveRecord::Migration[7.0]
  def change
    # Basic onboarding fields
    add_column :users, :onboarding_completed, :boolean, default: false
    add_column :users, :onboarding_completed_at, :datetime
    add_column :users, :onboarding_current_step, :string
    add_column :users, :onboarding_skipped, :boolean, default: false

    # Advanced features
    add_column :users, :ab_test_assignments, :jsonb, default: {}
    add_column :users, :personalized_flow_type, :string
    add_column :users, :revealed_features, :jsonb, default: []
    add_column :users, :feature_tooltips_shown, :jsonb, default: {}
    add_column :users, :earned_milestones, :jsonb, default: []
    add_column :users, :milestone_points, :integer, default: 0

    add_index :users, :onboarding_completed
    add_index :users, :onboarding_current_step
  end
end
```

### Controller

```ruby
class OnboardingController < ApplicationController
  include RailsOnboarding::ControllerHelpers

  def show
    # Use personalized steps if enabled
    @steps = current_user.personalized_steps
    @current_step = current_user.onboarding_current_step

    # Check A/B test variant
    @variant = current_user.ab_test_variant(:onboarding_flow)

    # Get ready progressive features
    @new_features = current_user.features_ready_to_reveal

    render "onboarding/#{@variant || 'show'}"
  end
end
```

### Views

```erb
<!-- app/views/onboarding/show.html.erb -->
<div class="onboarding-container"
     data-controller="progressive-disclosure rails-onboarding--tour"
     data-progressive-disclosure-auto-reveal-value="true"
     data-rails-onboarding--tour-steps-value='<%= onboarding_tour_steps.to_json %>'
     data-rails-onboarding--tour-tour-id-value="main-onboarding">

  <h1>
    <%= personalized_message({
      business: "Welcome to Your Business Account",
      enterprise: "Welcome to #{company_name}",
      individual: "Welcome!"
    }) %>
  </h1>

  <!-- Progress indicator -->
  <%= personalized_progress_indicator %>

  <!-- Current step content -->
  <%= render "onboarding/steps/#{@current_step}" %>

  <!-- Navigation -->
  <div class="onboarding-actions">
    <%= link_to personalized_cta(:next), next_onboarding_step_path, class: 'btn btn-primary' %>
  </div>

  <!-- Show newly revealed features -->
  <% @new_features.each do |feature| %>
    <div class="feature-notification">
      <h3><%= feature[:title] %></h3>
      <p><%= feature[:description] %></p>
    </div>
  <% end %>
</div>
```

---

## Best Practices

1. **A/B Testing**
   - Run tests with sufficient sample sizes (100+ users per variant)
   - Test one variable at a time
   - Track the metrics that matter (completion rate, time, engagement)

2. **Personalization**
   - Keep flows focused - don't add too many steps
   - Make personalization criteria clear and consistent
   - Test personalized flows separately

3. **Progressive Disclosure**
   - Don't reveal too many features at once
   - Time reveals strategically to match user journey
   - Provide clear value proposition for new features

4. **Interactive Tours**
   - Keep tours short (4-7 steps maximum)
   - Make tours skippable
   - Focus on essential features only
   - Test tours on different screen sizes

5. **Templates**
   - Choose templates that match your use case
   - Customize templates to fit your brand
   - Update templates based on user feedback

---

## Troubleshooting

### A/B Tests Not Working

- Ensure `enable_ab_testing` is `true`
- Check that `ab_test_assignments` column exists
- Verify variants are properly configured

### Personalization Not Applied

- Confirm `personalization_enabled` is `true`
- Check that `user_type_method` exists on User model
- Verify personalized flows are configured

### Features Not Being Revealed

- Enable `progressive_disclosure_enabled`
- Ensure `revealed_features` column exists
- Check reveal conditions are properly configured
- Verify check methods exist on User model

### Tours Not Appearing

- Confirm Stimulus controller is loaded
- Check that tour steps are valid JSON
- Verify target elements exist in the DOM
- Check browser console for JavaScript errors

---

## API Reference

For detailed API documentation, see:
- [Milestone System Guide](MILESTONES_GUIDE.md)
- [Analytics Guide](ANALYTICS_GUIDE.md)
- [Responsive Design Guide](RESPONSIVE_DESIGN.md)

---

## Support

For issues, questions, or contributions, please visit:
[GitHub Repository](https://github.com/your-repo/rails-onboarding)
