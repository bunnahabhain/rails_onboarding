# Analytics & Metrics Implementation Guide

This guide explains how to implement and utilize the analytics and metrics system in your Rails application using the `rails_onboarding` gem.

## Overview

The analytics system provides comprehensive tracking and reporting for your onboarding flow, including:

- Step completion and abandonment rates
- User journey tracking with session data
- Tooltip engagement metrics
- Milestone achievement analytics
- Funnel analysis and conversion tracking
- Time-to-completion metrics

## Basic Setup

### 1. Install the Gem

Add to your Gemfile:
```ruby
gem 'rails_onboarding'
```

Run the generator (includes analytics migration):
```bash
rails generate rails_onboarding:install
rails db:migrate
```

### 2. Include the Onboardable Concern

Add the concern to your User model:
```ruby
# app/models/user.rb
class User < ApplicationRecord
  include RailsOnboarding::Onboardable
  
  # your existing code...
end
```

### 3. Enable Analytics

In your initializer:
```ruby
# config/initializers/rails_onboarding.rb
RailsOnboarding.configure do |config|
  config.enable_analytics = true
  config.analytics_data_retention_days = 365 # Keep data for 1 year
  config.analytics_session_timeout_minutes = 30 # Session timeout
  
  # other configuration...
end
```

## What Gets Tracked Automatically

The gem automatically tracks these events when users interact with onboarding:

### Onboarding Events
- **`onboarding_started`** - User begins onboarding flow
- **`onboarding_step_started`** - User reaches a step - the entry signal
  powering the admin step funnel. Recorded only on a user's first entry to
  each step, so refreshes and back-navigation don't record duplicates.
- **`onboarding_step_completed`** - User completes a step
- **`onboarding_step_skipped`** - User skips an optional step
- **`onboarding_completed`** - User finishes entire onboarding
- **`onboarding_skipped`** - User skips entire onboarding

### Tooltip Events
- **`tooltip_shown`** - Tooltip is displayed to user
- **`tooltip_clicked`** - User clicks on tooltip
- **`tooltip_dismissed`** - User dismisses tooltip

### Milestone Events
- **`milestone_achieved`** - User earns a milestone

## Manual Event Tracking

### Track Custom Events

While most events are tracked automatically, you can add custom tracking:

```ruby
# In your controllers or services
class UsersController < ApplicationController
  def complete_profile
    current_user.update!(profile_params)
    
    # Track custom completion with session
    current_user.complete_onboarding_step!(
      :profile, 
      session_id: session.id,
      time_spent: calculate_time_spent
    )
    
    redirect_to next_step_path
  end

  def show_feature_tooltip
    feature = params[:feature]
    
    # Manual tooltip tracking
    current_user.track_tooltip_interaction!(
      feature, 
      'shown', 
      session_id: session.id
    )
    
    render json: { success: true }
  end

  def dismiss_tooltip
    feature = params[:feature]
    
    current_user.track_tooltip_interaction!(
      feature, 
      'dismissed', 
      session_id: session.id
    )
    
    render json: { success: true }
  end

  private

  def calculate_time_spent
    # Your logic to calculate time spent on step
    session[:step_start_time] ? Time.current - session[:step_start_time] : nil
  end
end
```

### Track with Session Context

```ruby
# Track events with session information for better user journey analysis
class OnboardingController < ApplicationController
  before_action :start_session_tracking

  def show
    # Start tracking is automatic, but you can add context
    current_user.start_onboarding!(session_id: analytics_session_id)
  end

  def complete_step
    step_name = params[:step]
    time_spent = Time.current - session[:step_start_time]
    
    current_user.complete_onboarding_step!(
      step_name,
      session_id: analytics_session_id,
      time_spent: time_spent
    )
    
    session[:step_start_time] = Time.current # Reset for next step
  end

  private

  def start_session_tracking
    session[:step_start_time] ||= Time.current
  end

  def analytics_session_id
    session.id.to_s
  end
end
```

## Analytics Reporting

### Basic Metrics

```ruby
# Get completion rates
completion_rate = RailsOnboarding::Analytics.onboarding_completion_rate
# => 67.5

skip_rate = RailsOnboarding::Analytics.onboarding_skip_rate  
# => 15.2

# Average time to complete onboarding (in seconds)
avg_time = RailsOnboarding::Analytics.average_completion_time
# => 245.8

# Step-by-step completion rates
step_rates = RailsOnboarding::Analytics.step_completion_rates
# => {"welcome"=>85.2, "profile"=>72.1, "first_action"=>58.3}

# Tooltip engagement
tooltip_rate = RailsOnboarding::Analytics.tooltip_engagement_rate
# => 23.4

# Milestone achievement rates
milestone_rates = RailsOnboarding::Analytics.milestone_achievement_rates
# => {"welcome_completed"=>85.2, "profile_completed"=>72.1}
```

### Time-Ranged Analytics

```ruby
# Get metrics for specific date range
date_range = 30.days.ago..Date.current

completion_rate = RailsOnboarding::Analytics.onboarding_completion_rate(
  date_range: date_range
)

# Daily summary
today_summary = RailsOnboarding::Analytics.daily_summary(date: Date.current)
# => {
#   date: Date.current,
#   onboarding_started: 45,
#   onboarding_completed: 32,
#   onboarding_skipped: 5,
#   tooltips_shown: 123,
#   tooltips_clicked: 28,
#   milestones_achieved: 67
# }
```

### Funnel Analysis

```ruby
# Comprehensive funnel breakdown
funnel = RailsOnboarding::Analytics.funnel_analysis(
  date_range: 30.days.ago..Date.current
)

# => {
#   total_started: 1000,
#   overall_completion_rate: 65.2,
#   steps: [
#     {
#       step_name: :welcome,
#       step_index: 0,
#       step_title: "Welcome",
#       users_reached: 850,
#       retention_rate: 85.0
#     },
#     {
#       step_name: :profile,
#       step_index: 1, 
#       step_title: "Setup Profile",
#       users_reached: 721,
#       retention_rate: 72.1
#     }
#     # ... more steps
#   ]
# }
```

### Detailed Tooltip Analytics

```ruby
# Get detailed tooltip metrics by feature
tooltip_metrics = RailsOnboarding::Analytics.tooltip_metrics_by_feature(
  date_range: 7.days.ago..Date.current
)

# => [
#   {
#     feature: "getting_started",
#     shown: 234,
#     clicked: 45,
#     dismissed: 189,
#     engagement_rate: 19.2
#   },
#   {
#     feature: "quick_actions", 
#     shown: 156,
#     clicked: 67,
#     dismissed: 89,
#     engagement_rate: 42.9
#   }
# ]
```

## Using Analytics in Views

### Create Analytics Dashboard

```erb
<!-- app/views/admin/analytics.html.erb -->
<div class="analytics-dashboard">
  <h1>Onboarding Analytics</h1>
  
  <!-- Key Metrics -->
  <div class="metrics-grid">
    <div class="metric-card">
      <h3>Completion Rate</h3>
      <div class="metric-value"><%= @completion_rate %>%</div>
    </div>
    
    <div class="metric-card">
      <h3>Skip Rate</h3>
      <div class="metric-value"><%= @skip_rate %>%</div>
    </div>
    
    <div class="metric-card">
      <h3>Avg. Time</h3>
      <div class="metric-value"><%= time_ago_in_words(@avg_time.seconds.ago) %></div>
    </div>
    
    <div class="metric-card">
      <h3>Tooltip Engagement</h3>
      <div class="metric-value"><%= @tooltip_engagement %>%</div>
    </div>
  </div>

  <!-- Funnel Visualization -->
  <div class="funnel-section">
    <h2>Conversion Funnel</h2>
    <div class="funnel-chart">
      <% @funnel[:steps].each_with_index do |step, index| %>
        <div class="funnel-step" style="width: <%= step[:retention_rate] %>%">
          <span class="step-title"><%= step[:step_title] %></span>
          <span class="step-stats">
            <%= step[:users_reached] %> users (<%= step[:retention_rate] %>%)
          </span>
        </div>
      <% end %>
    </div>
  </div>

  <!-- Step Performance -->
  <div class="steps-section">
    <h2>Step Performance</h2>
    <table class="performance-table">
      <thead>
        <tr>
          <th>Step</th>
          <th>Completion Rate</th>
          <th>Skip Rate</th>
          <th>Avg. Time</th>
        </tr>
      </thead>
      <tbody>
        <% RailsOnboarding.configuration.steps.each do |step| %>
          <tr>
            <td><%= step[:title] %></td>
            <td><%= @step_rates[step[:name].to_s] || 0 %>%</td>
            <td><%= @skip_rates[step[:name].to_s] || 0 %>%</td>
            <td><%= @step_times[step[:name].to_s] || 0 %>s</td>
          </tr>
        <% end %>
      </tbody>
    </table>
  </div>

  <!-- Tooltip Performance -->
  <div class="tooltips-section">
    <h2>Tooltip Performance</h2>
    <table class="tooltip-table">
      <thead>
        <tr>
          <th>Feature</th>
          <th>Shown</th>
          <th>Clicked</th>
          <th>Engagement Rate</th>
        </tr>
      </thead>
      <tbody>
        <% @tooltip_metrics.each do |metric| %>
          <tr>
            <td><%= metric[:feature] %></td>
            <td><%= metric[:shown] %></td>
            <td><%= metric[:clicked] %></td>
            <td><%= metric[:engagement_rate] %>%</td>
          </tr>
        <% end %>
      </tbody>
    </table>
  </div>
</div>
```

### Analytics Controller

```ruby
# app/controllers/admin/analytics_controller.rb
class Admin::AnalyticsController < ApplicationController
  before_action :ensure_admin

  def index
    @date_range = date_range_from_params
    
    @completion_rate = RailsOnboarding::Analytics.onboarding_completion_rate(
      date_range: @date_range
    )
    @skip_rate = RailsOnboarding::Analytics.onboarding_skip_rate(
      date_range: @date_range
    )
    @avg_time = RailsOnboarding::Analytics.average_completion_time(
      date_range: @date_range
    )
    @tooltip_engagement = RailsOnboarding::Analytics.tooltip_engagement_rate(
      date_range: @date_range
    )
    
    @funnel = RailsOnboarding::Analytics.funnel_analysis(
      date_range: @date_range
    )
    @step_rates = RailsOnboarding::Analytics.step_completion_rates(
      date_range: @date_range
    )
    @skip_rates = RailsOnboarding::Analytics.step_skip_rates(
      date_range: @date_range
    )
    @step_times = RailsOnboarding::Analytics.average_step_completion_times(
      date_range: @date_range
    )
    @tooltip_metrics = RailsOnboarding::Analytics.tooltip_metrics_by_feature(
      date_range: @date_range
    )
  end

  def export
    # Export functionality using the rake task
    redirect_to admin_analytics_path, notice: "Export started"
  end

  private

  def date_range_from_params
    start_date = params[:start_date]&.to_date || 30.days.ago.to_date
    end_date = params[:end_date]&.to_date || Date.current
    start_date.beginning_of_day..end_date.end_of_day
  end

  def ensure_admin
    redirect_to root_path unless current_user&.admin?
  end
end
```

## Rake Tasks

The gem provides several rake tasks for analytics management:

### Generate Reports

```bash
# Generate analytics report for date range
bundle exec rake app:rails_onboarding:analytics:report["2024-01-01","2024-01-31"]

# Generate funnel analysis
bundle exec rake app:rails_onboarding:analytics:funnel["2024-01-01","2024-01-31"]

# Export data to CSV
bundle exec rake app:rails_onboarding:analytics:export["2024-01-01","2024-01-31","my_export.csv"]

# Clean up old data (based on retention policy)
bundle exec rake app:rails_onboarding:analytics:cleanup
```

### Automate with Cron

```bash
# Add to your crontab for regular cleanup
0 2 * * 0 cd /path/to/app && bundle exec rake app:rails_onboarding:analytics:cleanup

# Weekly reports
0 9 * * 1 cd /path/to/app && bundle exec rake app:rails_onboarding:analytics:report > /tmp/onboarding_report.txt
```

## API Integration

### REST API for Analytics

```ruby
# config/routes.rb
namespace :api do
  namespace :v1 do
    resources :analytics, only: [] do
      collection do
        get :completion_rate
        get :funnel
        get :tooltips
        post :track_event
      end
    end
  end
end

# app/controllers/api/v1/analytics_controller.rb
class Api::V1::AnalyticsController < ApplicationController
  def completion_rate
    rate = RailsOnboarding::Analytics.onboarding_completion_rate(
      date_range: date_range_from_params
    )
    render json: { completion_rate: rate }
  end

  def funnel
    funnel = RailsOnboarding::Analytics.funnel_analysis(
      date_range: date_range_from_params
    )
    render json: funnel
  end

  def tooltips
    metrics = RailsOnboarding::Analytics.tooltip_metrics_by_feature(
      date_range: date_range_from_params
    )
    render json: { tooltip_metrics: metrics }
  end

  def track_event
    # Allow frontend to track custom events
    user = current_user
    event_type = params[:event_type]
    properties = params[:properties] || {}
    
    RailsOnboarding::AnalyticsEvent.track_event(
      user: user,
      event_type: event_type,
      properties: properties,
      session_id: session.id
    )
    
    render json: { success: true }
  end

  private

  def date_range_from_params
    start_date = params[:start_date]&.to_date || 30.days.ago.to_date
    end_date = params[:end_date]&.to_date || Date.current
    start_date.beginning_of_day..end_date.end_of_day
  end
end
```

### JavaScript Integration

> **Note:** The example below is an *illustrative custom* client-side tracker.
> Its event names (`step_started`, `step_completed`) are arbitrary and are
> **not** the gem's built-in event types. The events the gem records
> automatically use the `onboarding_`-prefixed names listed under
> [What Gets Tracked Automatically](#what-gets-tracked-automatically)
> (e.g. `onboarding_step_completed`), with payload stored in the `properties`
> column under keys like `step_name`. If you build admin reporting or queries
> against stored events, match those built-in names and keys — not the custom
> names in this example.

```javascript
// app/assets/javascripts/analytics.js
class OnboardingAnalytics {
  constructor(sessionId) {
    this.sessionId = sessionId;
    this.stepStartTime = Date.now();
  }

  trackStepStart(stepName) {
    this.stepStartTime = Date.now();
    this.trackEvent('step_started', {
      step_name: stepName,
      timestamp: this.stepStartTime
    });
  }

  trackStepComplete(stepName) {
    const timeSpent = (Date.now() - this.stepStartTime) / 1000;
    this.trackEvent('step_completed', {
      step_name: stepName,
      time_spent_seconds: timeSpent
    });
  }

  trackTooltipInteraction(feature, action) {
    this.trackEvent('tooltip_interaction', {
      tooltip_feature: feature,
      action: action
    });
  }

  trackEvent(eventType, properties) {
    fetch('/api/v1/analytics/track_event', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
      },
      body: JSON.stringify({
        event_type: eventType,
        properties: properties,
        session_id: this.sessionId
      })
    });
  }
}

// Initialize analytics
const analytics = new OnboardingAnalytics(window.sessionId);

// Usage examples
document.getElementById('tooltip-button').addEventListener('click', () => {
  analytics.trackTooltipInteraction('getting_started', 'clicked');
});

document.getElementById('step-complete').addEventListener('click', () => {
  analytics.trackStepComplete('profile');
});
```

## Advanced Analytics

### Custom Analytics Models

Create your own analytics models for specific tracking:

```ruby
# app/models/user_journey.rb
class UserJourney < ApplicationRecord
  belongs_to :user
  
  scope :completed, -> { where.not(completed_at: nil) }
  scope :abandoned, -> { where(completed_at: nil) }

  def self.track_journey(user, session_id)
    create!(
      user: user,
      session_id: session_id,
      started_at: Time.current,
      user_agent: request.user_agent,
      ip_address: request.remote_ip
    )
  end

  def complete!
    update!(completed_at: Time.current)
  end

  def duration
    return nil unless completed_at
    completed_at - started_at
  end
end
```

### A/B Testing Integration

```ruby
# Track analytics by experiment variant
class OnboardingController < ApplicationController
  def show
    @variant = experiment_variant(:onboarding_flow)
    
    # Track with experiment context
    current_user.start_onboarding!(
      session_id: analytics_session_id
    )
    
    # Track the experiment variant
    RailsOnboarding::AnalyticsEvent.track_event(
      user: current_user,
      event_type: 'experiment_variant_shown',
      properties: {
        experiment: 'onboarding_flow',
        variant: @variant
      },
      session_id: analytics_session_id
    )
  end
end
```

### Cohort Analysis

```ruby
# app/services/cohort_analytics.rb
class CohortAnalytics
  def self.weekly_cohorts(weeks_back = 12)
    cohorts = []
    
    weeks_back.times do |i|
      week_start = i.weeks.ago.beginning_of_week
      week_end = week_start.end_of_week
      
      # Users who started onboarding this week
      cohort_users = RailsOnboarding::AnalyticsEvent
        .where(event_type: 'onboarding_started')
        .where(occurred_at: week_start..week_end)
        .pluck(:user_id)
      
      # Track their completion rates over following weeks
      completion_data = {}
      (0...[weeks_back - i]).each do |week_offset|
        check_week_end = (week_start + week_offset.weeks).end_of_week
        
        completed_count = RailsOnboarding::AnalyticsEvent
          .where(event_type: 'onboarding_completed')
          .where(user_id: cohort_users)
          .where(occurred_at: week_start..check_week_end)
          .count
        
        completion_data["week_#{week_offset}"] = completed_count
      end
      
      cohorts << {
        week: week_start,
        cohort_size: cohort_users.size,
        completions: completion_data
      }
    end
    
    cohorts
  end
end
```

## Performance Considerations

### Database Optimization

```ruby
# Add indexes for common queries
class AddAnalyticsIndexes < ActiveRecord::Migration[7.0]
  def change
    # Already included in the analytics migration, but for reference:
    add_index :rails_onboarding_analytics_events, :event_type
    add_index :rails_onboarding_analytics_events, :occurred_at
    add_index :rails_onboarding_analytics_events, [:user_type, :user_id, :event_type]
    add_index :rails_onboarding_analytics_events, :session_id
    
    # Additional custom indexes based on your queries
    add_index :rails_onboarding_analytics_events, [:event_type, :occurred_at]
    add_index :rails_onboarding_analytics_events, [:user_id, :occurred_at]
  end
end
```

### Background Processing

```ruby
# Process analytics in background for better performance
class AnalyticsProcessorJob < ApplicationJob
  def perform(user_id, event_type, properties, session_id)
    user = User.find(user_id)
    
    RailsOnboarding::AnalyticsEvent.track_event(
      user: user,
      event_type: event_type,
      properties: properties,
      session_id: session_id
    )
  end
end

# Usage in controllers
AnalyticsProcessorJob.perform_later(
  current_user.id,
  'custom_event',
  { key: 'value' },
  session.id
)
```

### Data Archiving

```ruby
# app/services/analytics_archiver.rb
class AnalyticsArchiver
  def self.archive_old_data(cutoff_date = 2.years.ago)
    old_events = RailsOnboarding::AnalyticsEvent
      .where("occurred_at < ?", cutoff_date)
    
    # Export to data warehouse or file storage
    export_to_warehouse(old_events)
    
    # Delete from primary database
    old_events.delete_all
  end

  private

  def self.export_to_warehouse(events)
    # Implementation depends on your data warehouse
    # Could be AWS Redshift, BigQuery, etc.
  end
end
```

## Testing Analytics

```ruby
# test/models/analytics_test.rb
class AnalyticsTest < ActiveSupport::TestCase
  def setup
    @user = User.create!(email: "test@example.com")
  end

  test "tracks onboarding start" do
    assert_difference "RailsOnboarding::AnalyticsEvent.count", 1 do
      @user.start_onboarding!(session_id: "test_session")
    end

    event = RailsOnboarding::AnalyticsEvent.last
    assert_equal "onboarding_started", event.event_type
    assert_equal @user, event.user
    assert_equal "test_session", event.session_id
  end

  test "calculates completion rate correctly" do
    # Create test data
    user1 = User.create!(email: "user1@example.com")
    user2 = User.create!(email: "user2@example.com")
    
    # User 1 starts and completes
    RailsOnboarding::AnalyticsEvent.create!(
      user: user1,
      event_type: "onboarding_started",
      occurred_at: 1.day.ago
    )
    RailsOnboarding::AnalyticsEvent.create!(
      user: user1,
      event_type: "onboarding_completed", 
      occurred_at: Time.current
    )
    
    # User 2 starts but doesn't complete
    RailsOnboarding::AnalyticsEvent.create!(
      user: user2,
      event_type: "onboarding_started",
      occurred_at: 1.day.ago
    )

    rate = RailsOnboarding::Analytics.onboarding_completion_rate
    assert_equal 50.0, rate
  end
end
```

## Configuration Options

```ruby
# config/initializers/rails_onboarding.rb
RailsOnboarding.configure do |config|
  # Enable/disable analytics
  config.enable_analytics = true
  
  # Data retention (days)
  config.analytics_data_retention_days = 365
  
  # Session timeout (minutes)
  config.analytics_session_timeout_minutes = 30
end
```

`analytics_retention_days` is an alias for `analytics_data_retention_days` -
setting either keeps both in sync, so use whichever reads better.

This analytics system provides comprehensive insights into your onboarding performance and user behavior, enabling data-driven optimization of your user experience.