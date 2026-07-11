# Rails Onboarding - ESBuild Setup Guide

If your app uses ESBuild for JavaScript bundling, you'll need to manually include the Rails Onboarding JavaScript files in your application.

## 1. Copy JavaScript Controllers

Copy the following files from the gem to your app's JavaScript directory:

```bash
# From your Rails app root:
cp path/to/rails_onboarding/app/assets/javascripts/rails_onboarding/* app/javascript/controllers/rails_onboarding/
```

Or manually create these files in `app/javascript/controllers/rails_onboarding/`:

**Core Controllers:**
- `onboarding_controller.js`
- `progress_controller.js`
- `navigation_controller.js`

**Tooltip System:**
- `tooltip_controller.js`
- `tooltip_scheduler_controller.js`

**Tour & Guides:**
- `tour_controller.js`
- `progressive_disclosure_controller.js`

**Milestone System:**
- `milestone_celebration_controller.js`
- `milestone_dashboard_controller.js`
- `milestone_detail_controller.js`

**Admin Interface** (only needed if you use the admin dashboard):
- `admin/chart_controller.js`
- `admin/filter_controller.js`
- `admin/flash_controller.js`
- `admin/flow_editor_controller.js`

If you don't use the admin dashboard, you can skip copying, importing, and
registering the four `admin/*` controllers throughout this guide.

## 2. Register Controllers in Application

Add to your `app/javascript/controllers/index.js`:

```javascript
// Import and register all your controllers from the importmap under controllers/*

import { application } from "controllers/application"

// Eager load all controllers defined in the import map under controllers/**/*_controller
import { eagerLoadControllersFrom } from "@hotwired/stimulus-loading"
eagerLoadControllersFrom("controllers", application)

// Import Rails Onboarding controllers
import OnboardingController from "./rails_onboarding/onboarding_controller"
import ProgressController from "./rails_onboarding/progress_controller"
import NavigationController from "./rails_onboarding/navigation_controller"
import TooltipController from "./rails_onboarding/tooltip_controller"
import TooltipSchedulerController from "./rails_onboarding/tooltip_scheduler_controller"
import TourController from "./rails_onboarding/tour_controller"
import ProgressiveDisclosureController from "./rails_onboarding/progressive_disclosure_controller"
import MilestoneCelebrationController from "./rails_onboarding/milestone_celebration_controller"
import MilestoneDashboardController from "./rails_onboarding/milestone_dashboard_controller"
import MilestoneDetailController from "./rails_onboarding/milestone_detail_controller"
import AdminChartController from "./rails_onboarding/admin/chart_controller"
import AdminFilterController from "./rails_onboarding/admin/filter_controller"
import AdminFlashController from "./rails_onboarding/admin/flash_controller"
import AdminFlowEditorController from "./rails_onboarding/admin/flow_editor_controller"

// Register Rails Onboarding controllers
application.register("onboarding", OnboardingController)
application.register("progress", ProgressController)
application.register("navigation", NavigationController)
application.register("tooltip", TooltipController)
application.register("tooltip-scheduler", TooltipSchedulerController)
application.register("tour", TourController)
application.register("progressive-disclosure", ProgressiveDisclosureController)
application.register("milestone-celebration", MilestoneCelebrationController)
application.register("milestone-dashboard", MilestoneDashboardController)
application.register("milestone-detail", MilestoneDetailController)
application.register("admin--chart", AdminChartController)
application.register("admin--filter", AdminFilterController)
application.register("admin--flash", AdminFlashController)
application.register("admin--flow-editor", AdminFlowEditorController)
```

**Alternative approach** - Create a separate file `app/javascript/controllers/rails_onboarding.js`:

```javascript
import { application } from "controllers/application"

// Import Rails Onboarding controllers
import OnboardingController from "./rails_onboarding/onboarding_controller"
import ProgressController from "./rails_onboarding/progress_controller"
import NavigationController from "./rails_onboarding/navigation_controller"
import TooltipController from "./rails_onboarding/tooltip_controller"
import TooltipSchedulerController from "./rails_onboarding/tooltip_scheduler_controller"
import TourController from "./rails_onboarding/tour_controller"
import ProgressiveDisclosureController from "./rails_onboarding/progressive_disclosure_controller"
import MilestoneCelebrationController from "./rails_onboarding/milestone_celebration_controller"
import MilestoneDashboardController from "./rails_onboarding/milestone_dashboard_controller"
import MilestoneDetailController from "./rails_onboarding/milestone_detail_controller"
import AdminChartController from "./rails_onboarding/admin/chart_controller"
import AdminFilterController from "./rails_onboarding/admin/filter_controller"
import AdminFlashController from "./rails_onboarding/admin/flash_controller"
import AdminFlowEditorController from "./rails_onboarding/admin/flow_editor_controller"

// Register Rails Onboarding controllers
application.register("onboarding", OnboardingController)
application.register("progress", ProgressController)
application.register("navigation", NavigationController)
application.register("tooltip", TooltipController)
application.register("tooltip-scheduler", TooltipSchedulerController)
application.register("tour", TourController)
application.register("progressive-disclosure", ProgressiveDisclosureController)
application.register("milestone-celebration", MilestoneCelebrationController)
application.register("milestone-dashboard", MilestoneDashboardController)
application.register("milestone-detail", MilestoneDetailController)
application.register("admin--chart", AdminChartController)
application.register("admin--filter", AdminFilterController)
application.register("admin--flash", AdminFlashController)
application.register("admin--flow-editor", AdminFlowEditorController)
```

Then import this in your `app/javascript/controllers/index.js`:

```javascript
import "./rails_onboarding"
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

## 5. Initialize Onboarding (Optional)

This step is **optional** and mainly useful for debugging or adding custom initialization logic.

### What this does:
- Runs JavaScript code after the page loads
- Checks if the Rails Onboarding JavaScript has loaded properly
- Provides a place to add custom onboarding initialization

### When you might need this:
- **Debugging**: To verify that the JavaScript controllers loaded correctly
- **Custom initialization**: If you want to auto-show tooltips or trigger onboarding on certain pages
- **Analytics setup**: To initialize tracking when onboarding becomes available

### Where to add it:
You can add this to your main layout file (`app/views/layouts/application.html.erb`) or to specific pages where onboarding is used:

```erb
<%= content_for :head do %>
  <script>
    document.addEventListener('DOMContentLoaded', function() {
      // Check if Rails Onboarding JavaScript loaded properly
      if (typeof RailsOnboarding !== 'undefined') {
        console.log('Rails Onboarding initialized successfully');
        
        // Optional: Add custom initialization here
        // Example: Auto-show tooltips for new users
        // if (currentUser.isNew) {
        //   RailsOnboarding.showTooltip(document.querySelector('#getting-started'), 'Welcome! Click here to begin.');
        // }
      } else {
        console.warn('Rails Onboarding JavaScript not loaded');
      }
    });
  </script>
<% end %>
```

### Alternative: Add to your JavaScript files
Instead of inline script tags, you could add this initialization to your `app/javascript/application.js`:

```javascript
document.addEventListener('DOMContentLoaded', function() {
  if (typeof RailsOnboarding !== 'undefined') {
    console.log('Rails Onboarding ready');
    
    // Your custom initialization code here
  }
});
```

### For most users:
**You can skip this step entirely** - the onboarding will work without it. The Stimulus controllers will automatically initialize when the page loads and finds elements with the appropriate `data-controller` attributes.

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
  config.redirect_after_completion = :root_path
  config.redirect_after_skip = :root_path
  config.enable_tooltips = true
  config.enable_milestones = true
  config.onboarding_required_for = :new_users
  
  # Customize steps for your app
  config.steps = [
    {
      name: :welcome,
      title: 'Welcome',
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
      title: 'Try Your First Action',
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
