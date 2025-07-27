# Rails Onboarding - ESBuild Setup Guide

Since your LOLOL app uses ESBuild for JavaScript bundling, you'll need to manually include the Rails Onboarding JavaScript files in your application.

## 1. Copy JavaScript Controllers

Copy the following files from the gem to your app's JavaScript directory:

```bash
# From your Rails app root:
cp path/to/rails_onboarding/app/assets/javascripts/rails_onboarding/* app/javascript/controllers/rails_onboarding/
```

Or manually create these files in `app/javascript/controllers/rails_onboarding/`:

- `onboarding_controller.js`
- `progress_controller.js`
- `navigation_controller.js`
- `tooltip_controller.js`

## 2. Register Controllers in Application

Add to your `app/javascript/controllers/application.js`:

```javascript
import { application } from "./application"

// Import Rails Onboarding controllers
import OnboardingController from "./rails_onboarding/onboarding_controller"
import ProgressController from "./rails_onboarding/progress_controller"
import NavigationController from "./rails_onboarding/navigation_controller"
import TooltipController from "./rails_onboarding/tooltip_controller"

// Register Rails Onboarding controllers
application.register("onboarding", OnboardingController)
application.register("progress", ProgressController)
application.register("navigation", NavigationController)
application.register("tooltip", TooltipController)
```

## 3. Include CSS Styles

Add to your `app/assets/stylesheets/application.css`:

```css
/*
 *= require rails_onboarding/application
 */
```

## 4. Alternative: Use Asset Pipeline

If you prefer to use the asset pipeline for the JavaScript files, add this to your layout:

```erb
<%= javascript_include_tag "rails_onboarding/application", defer: true %>
```

## 5. Initialize Onboarding

Add this to your application layout or where you want onboarding to be available:

```erb
<%= content_for :head do %>
  <script>
    document.addEventListener('DOMContentLoaded', function() {
      // Initialize any global onboarding features
      if (typeof RailsOnboarding !== 'undefined') {
        console.log('Rails Onboarding initialized');
      }
    });
  </script>
<% end %>
```

## 6. Mount the Engine

Make sure you've mounted the engine in your `config/routes.rb`:

```ruby
mount RailsOnboarding::Engine => "/onboarding"
```

## 7. Configure Onboarding

Create `config/initializers/rails_onboarding.rb`:

```ruby
RailsOnboarding.configure do |config|
  config.user_class_name = 'User'
  config.redirect_after_completion = :dashboard_path
  config.redirect_after_skip = :dashboard_path
  config.enable_tooltips = true
  config.enable_milestones = true
  config.onboarding_required_for = :new_users
  
  # Customize steps for your LOLOL app
  config.steps = [
    {
      name: :welcome,
      title: 'Welcome to LOLOL',
      icon: '🎉',
      skippable: true
    },
    {
      name: :profile,
      title: 'Setup Your Profile',
      icon: '👤',
      skippable: false
    },
    {
      name: :first_action,
      title: 'Create Your First List',
      icon: '📝',
      skippable: false
    },
    {
      name: :explore,
      title: 'Explore Features',
      icon: '🔍',
      skippable: true
    }
  ]
end
```

Now your Rails Onboarding should work with your ESBuild setup!
