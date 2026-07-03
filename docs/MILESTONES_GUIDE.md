# Milestones Implementation Guide

This guide explains how to implement and customize the milestone system in your Rails application using the `rails_onboarding` gem.

## Overview

The milestone system gamifies your onboarding experience by rewarding users with points and achievements as they complete various actions. Users can earn milestones for completing onboarding steps, performing specific actions, or meeting certain criteria.

## Basic Setup

### 1. Install the Gem

Add to your Gemfile:
```ruby
gem 'rails_onboarding'
```

Run the generator:
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

### 3. Enable Milestones

In your initializer:
```ruby
# config/initializers/rails_onboarding.rb
RailsOnboarding.configure do |config|
  config.enable_milestones = true
  # other configuration...
end
```

## Default Milestones

The gem comes with these built-in milestones:

| Milestone | Trigger | Points | Description |
|-----------|---------|--------|-------------|
| `welcome_completed` | Complete welcome step | 10 | Welcome step completion |
| `profile_completed` | Complete profile step | 25 | Profile setup completion |
| `first_action_completed` | Complete first action step | 30 | First action taken |
| `onboarding_completed` | Complete entire onboarding | 50 | Full onboarding completion |
| `early_adopter` | Custom trigger | 100 | Early user bonus |

## Customizing Milestones

### Define Your Own Milestones

```ruby
# config/initializers/rails_onboarding.rb
RailsOnboarding.configure do |config|
  config.milestones = [
    {
      key: :profile_master,
      title: "Profile Master",
      description: "You've completed your profile setup",
      icon: "👤",
      points: 25,
      trigger: :onboarding_step_completed,
      conditions: { step: :profile }
    },
    {
      key: :social_butterfly,
      title: "Social Butterfly", 
      description: "You've connected with 5 friends",
      icon: "🦋",
      points: 50,
      trigger: :custom,
      conditions: { friends_count: 5 }
    },
    {
      key: :power_user,
      title: "Power User",
      description: "You've been active for 30 days",
      icon: "⚡",
      points: 100,
      trigger: :custom,
      conditions: { days_active: 30 }
    }
  ]
end
```

### Milestone Structure

Each milestone has these properties:

- **key**: Unique identifier (symbol)
- **title**: Display name for users
- **description**: What the user accomplished
- **icon**: Visual representation (emoji or CSS class)
- **points**: Points awarded for achievement
- **trigger**: When to check for this milestone
- **conditions**: Criteria that must be met

### Trigger Types

1. **`:onboarding_step_completed`** - Triggered when user completes a specific onboarding step
2. **`:onboarding_completed`** - Triggered when user finishes entire onboarding
3. **`:custom`** - Manually triggered by your application code

## Using Milestones in Your Application

### Check User's Milestones

```ruby
user = current_user

# Get all achieved milestones
user.achieved_milestones
# => ["welcome_completed", "profile_completed"]

# Check specific milestone
user.milestone_achieved?(:profile_completed)
# => true

# Get total points
user.total_milestone_points
# => 35

# Get recent milestones
user.recent_milestones(limit: 3)
# => [milestone_config_hash, ...]

# Get available (unachieved) milestones
user.milestones_available
# => [milestone_config_hash, ...]
```

### Award Custom Milestones

For milestones with `trigger: :custom`, you award them manually:

```ruby
# In your controller or service
class UsersController < ApplicationController
  def add_friend
    current_user.friends << friend
    
    # Check if user now has 5 friends
    if current_user.friends.count >= 5
      milestone = current_user.achieve_milestone!(:social_butterfly)
      if milestone
        flash[:success] = "🎉 Milestone achieved: #{milestone[:title]}!"
      end
    end
  end
end
```

### Service for Complex Logic

Create a service for more complex milestone logic:

```ruby
# app/services/milestone_checker.rb
class MilestoneChecker
  def self.check_activity_milestones(user)
    days_active = (Date.current - user.created_at.to_date).to_i
    
    case days_active
    when 7
      user.achieve_milestone!(:week_warrior)
    when 30
      user.achieve_milestone!(:monthly_master)
    when 365
      user.achieve_milestone!(:yearly_champion)
    end
  end
end

# Call from a background job or cron task
MilestoneChecker.check_activity_milestones(user)
```

## Displaying Milestones in Views

### Show User's Progress

```erb
<!-- app/views/users/profile.html.erb -->
<div class="milestones-section">
  <h3>Your Achievements</h3>
  <div class="points-total">
    <span class="points"><%= current_user.total_milestone_points %></span> points
  </div>
  
  <div class="milestones-grid">
    <% current_user.achieved_milestones.each do |milestone_key| %>
      <% milestone = RailsOnboarding.configuration.milestone_by_key(milestone_key) %>
      <div class="milestone achieved">
        <span class="icon"><%= milestone[:icon] %></span>
        <h4><%= milestone[:title] %></h4>
        <p><%= milestone[:description] %></p>
        <span class="points">+<%= milestone[:points] %> pts</span>
      </div>
    <% end %>
  </div>
  
  <h4>Available Achievements</h4>
  <div class="milestones-grid">
    <% current_user.milestones_available.each do |milestone| %>
      <div class="milestone available">
        <span class="icon gray"><%= milestone[:icon] %></span>
        <h4><%= milestone[:title] %></h4>
        <p><%= milestone[:description] %></p>
        <span class="points">+<%= milestone[:points] %> pts</span>
      </div>
    <% end %>
  </div>
</div>
```

### Milestone Celebration Modal

```erb
<!-- app/views/shared/_milestone_modal.html.erb -->
<div id="milestone-modal" class="modal" style="display: none;">
  <div class="modal-content">
    <h2>🎉 Milestone Achieved!</h2>
    <div class="milestone-details">
      <span class="milestone-icon" id="modal-icon"></span>
      <h3 id="modal-title"></h3>
      <p id="modal-description"></p>
      <div class="points-earned">
        +<span id="modal-points"></span> points
      </div>
    </div>
    <button onclick="closeMilestoneModal()">Awesome!</button>
  </div>
</div>

<script>
function showMilestoneModal(milestone) {
  document.getElementById('modal-icon').textContent = milestone.icon;
  document.getElementById('modal-title').textContent = milestone.title;
  document.getElementById('modal-description').textContent = milestone.description;
  document.getElementById('modal-points').textContent = milestone.points;
  document.getElementById('milestone-modal').style.display = 'block';
}

function closeMilestoneModal() {
  document.getElementById('milestone-modal').style.display = 'none';
}
</script>
```

### CSS for Milestones

```css
/* app/assets/stylesheets/milestones.css */
.milestones-section {
  padding: 20px;
  background: #f8f9fa;
  border-radius: 8px;
}

.points-total {
  text-align: center;
  margin-bottom: 20px;
}

.points-total .points {
  font-size: 2em;
  font-weight: bold;
  color: #007bff;
}

.milestones-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(250px, 1fr));
  gap: 15px;
  margin-bottom: 30px;
}

.milestone {
  background: white;
  padding: 20px;
  border-radius: 8px;
  text-align: center;
  box-shadow: 0 2px 4px rgba(0,0,0,0.1);
  transition: transform 0.2s;
}

.milestone:hover {
  transform: translateY(-2px);
}

.milestone.achieved {
  border: 2px solid #28a745;
}

.milestone.available {
  border: 2px solid #dee2e6;
  opacity: 0.7;
}

.milestone .icon {
  font-size: 3em;
  display: block;
  margin-bottom: 10px;
}

.milestone .icon.gray {
  filter: grayscale(100%);
}

.milestone h4 {
  margin: 10px 0 5px 0;
  color: #333;
}

.milestone p {
  color: #666;
  font-size: 0.9em;
  margin-bottom: 10px;
}

.milestone .points {
  background: #007bff;
  color: white;
  padding: 4px 8px;
  border-radius: 12px;
  font-size: 0.8em;
  font-weight: bold;
}
```

## Integration with Controllers

### Flash Messages for Achievements

```ruby
# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  protected

  def award_milestone_with_notification(milestone_key)
    milestone = current_user.achieve_milestone!(milestone_key)
    if milestone
      flash[:milestone] = {
        title: milestone[:title],
        description: milestone[:description],
        icon: milestone[:icon],
        points: milestone[:points]
      }
    end
  end
end

# In your controllers
class OnboardingController < ApplicationController
  def complete_step
    # ... step completion logic ...
    
    # This happens automatically, but you can also do it manually
    award_milestone_with_notification(:custom_milestone)
  end
end
```

## Background Processing

For performance, consider processing milestones in background jobs:

```ruby
# app/jobs/milestone_check_job.rb
class MilestoneCheckJob < ApplicationJob
  def perform(user_id, trigger, conditions = {})
    user = User.find(user_id)
    RailsOnboarding::MilestoneService.check_and_award_milestones(
      user, trigger, conditions
    )
  end
end

# Usage
MilestoneCheckJob.perform_later(user.id, :custom, { friends_count: user.friends.count })
```

## API Integration

### RESTful Endpoints

```ruby
# config/routes.rb
Rails.application.routes.draw do
  resources :milestones, only: [:index] do
    member do
      post :achieve
    end
  end
end

# app/controllers/milestones_controller.rb
class MilestonesController < ApplicationController
  def index
    render json: {
      achieved: current_user.achieved_milestones.map { |key|
        RailsOnboarding.configuration.milestone_by_key(key)
      },
      available: current_user.milestones_available,
      total_points: current_user.total_milestone_points
    }
  end

  def achieve
    milestone = current_user.achieve_milestone!(params[:key])
    if milestone
      render json: { milestone: milestone, success: true }
    else
      render json: { error: "Milestone not achieved" }, status: 422
    end
  end
end
```

## Testing Milestones

```ruby
# test/models/user_test.rb
class UserTest < ActiveSupport::TestCase
  test "user can achieve milestones" do
    user = User.create!(email: "test@example.com")
    
    # Test milestone achievement
    milestone = user.achieve_milestone!(:early_adopter)
    assert milestone
    assert user.milestone_achieved?(:early_adopter)
    assert_equal 100, user.total_milestone_points
  end

  test "prevents duplicate milestone achievements" do
    user = User.create!(email: "test@example.com")
    
    # Achieve milestone once
    user.achieve_milestone!(:early_adopter)
    original_points = user.total_milestone_points
    
    # Try to achieve again
    result = user.achieve_milestone!(:early_adopter)
    assert_not result
    assert_equal original_points, user.total_milestone_points
  end
end
```

## Best Practices

1. **Keep milestones achievable** - Don't make requirements too difficult
2. **Provide clear descriptions** - Users should understand what they need to do
3. **Use meaningful rewards** - Points should feel valuable
4. **Show progress** - Let users see how close they are to achievements
5. **Celebrate achievements** - Use modals, animations, or notifications
6. **Track engagement** - Monitor which milestones motivate users most
7. **Update regularly** - Add new milestones to keep users engaged

## Troubleshooting

### Common Issues

1. **Milestones not triggering**: Check that `enable_milestones` is true in configuration
2. **Database errors**: Ensure you've run the migrations
3. **Missing milestones**: Verify milestone keys match your configuration

### Debug Mode

```ruby
# Add to your configuration for debugging
RailsOnboarding.configure do |config|
  config.enable_milestones = true
  # Add logging to see milestone checks
end

# In your code
Rails.logger.info "Checking milestone for user #{user.id}"
milestone = user.achieve_milestone!(:test_milestone)
Rails.logger.info "Milestone result: #{milestone ? 'achieved' : 'not achieved'}"
```

This milestone system will enhance user engagement and provide clear progression through your application's key features and workflows.