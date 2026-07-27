# RailsOnboarding Admin Interface Guide

Complete guide to using the RailsOnboarding admin interface for managing onboarding flows, monitoring user progress, and analyzing metrics.

## Table of Contents

- [Overview](#overview)
- [Setup](#setup)
- [Authentication](#authentication)
- [Dashboard](#dashboard)
- [User Management](#user-management)
- [Flow Editor](#flow-editor)
- [A/B Test Management](#ab-test-management)
- [API Reference](#api-reference)
- [Customization](#customization)

---

## Overview

The RailsOnboarding admin interface provides a comprehensive web-based dashboard for:

- **Analytics Dashboard**: View onboarding completion rates, funnel analysis, and user metrics
- **User Management**: Monitor and manage individual user onboarding progress
- **Flow Editor**: Create and edit onboarding flows visually
- **A/B Testing**: Manage and analyze A/B tests for optimization

The admin interface is automatically mounted at `/admin` within the RailsOnboarding engine namespace.

---

## Setup

### 1. Mount the Admin Routes

The admin routes are automatically included when you mount the RailsOnboarding engine:

```ruby
# config/routes.rb
Rails.application.routes.draw do
  mount RailsOnboarding::Engine => "/onboarding"
  # Admin will be available at /onboarding/admin
end
```

### 2. Configure Admin Access

The admin interface requires authentication. There are two ways to set this up:

#### Option 1: Using the `admin?` method (Recommended)

Add an `admin?` method to your User model:

```ruby
# app/models/user.rb
class User < ApplicationRecord
  include RailsOnboarding::Onboardable

  # Simple boolean column approach
  def admin?
    self.admin == true
  end

  # Or role-based approach
  def admin?
    role == 'admin' || role == 'superadmin'
  end
end
```

Don't forget to add the `admin` column to your users table:

```ruby
rails generate migration AddAdminToUsers admin:boolean
rails db:migrate
```

#### Option 2: Custom Authentication Method

Define a custom authentication method in your ApplicationController:

```ruby
# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  def authenticate_rails_onboarding_admin!
    unless current_user&.has_role?(:admin)
      flash[:alert] = "You must be an administrator to access this page"
      redirect_to root_path
    end
  end
end
```

---

## Authentication

### Security Considerations

The admin interface includes several security measures:

1. **Authentication Required**: All admin routes require authentication
2. **Authorization Check**: Users must have admin privileges
3. **CSRF Protection**: All forms include CSRF tokens
4. **Error Handling**: Graceful handling of unauthorized access

### Customizing Authentication

You can customize the authentication behavior by overriding the `authenticate_admin!` method:

```ruby
# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  def authenticate_rails_onboarding_admin!
    # Custom logic here
    unless current_user&.can_access_admin?
      flash[:alert] = "Access denied"
      redirect_to root_path
    end
  end
end
```

---

## Dashboard

### Accessing the Dashboard

Navigate to `/onboarding/admin` to access the dashboard.

### Features

#### 1. Overview Statistics

The dashboard displays key metrics:

- **Total Users**: Total number of users in the system
- **Onboarding Started**: Users who have begun onboarding
- **Completed**: Users who finished onboarding
- **Avg. Time to Complete**: Average time from start to completion

#### 2. Daily Completion Trend

Visual chart showing onboarding completions over the last 7 days.

#### 3. Onboarding Funnel

Step-by-step breakdown showing:
- Number of users who reached each step
- Percentage of users completing each step
- Drop-off points in the flow

#### 4. Top Milestones

Most frequently achieved milestones with achievement counts.

#### 5. Recent Activity

Timeline of recent onboarding events.

### Date Range Filtering

Use the date range selector to filter analytics:
- Last 7 days
- Last 30 days
- Last 90 days
- All time

---

## User Management

### Viewing Users

Navigate to **Admin → Users** to see all users and their onboarding status.

### User List Features

#### 1. Status Filters

Filter users by onboarding status:
- **Completed**: Users who finished onboarding
- **In Progress**: Users currently in onboarding
- **Not Started**: Users who haven't begun
- **Skipped**: Users who skipped onboarding

#### 2. Search

Search users by email or ID using the search box.

#### 3. Bulk Actions

Select multiple users and perform bulk actions:
- Reset Onboarding
- Complete Onboarding

### User Details

Click on any user to view detailed information:

#### User Information
- User ID and email
- Onboarding status and progress
- Current step
- Completion date (if applicable)

#### Activity Timeline
- Complete history of onboarding events
- Milestone achievements
- Step transitions

#### Actions
- **Reset Onboarding**: Start the user's onboarding from scratch
- **Complete Onboarding**: Mark onboarding as complete

### Example: Resetting User Onboarding

```ruby
# Programmatically reset a user's onboarding
user = User.find(123)
user.reset_onboarding!

# Or via the admin interface:
# 1. Navigate to Admin → Users
# 2. Click on the user
# 3. Click "Reset Onboarding"
```

---

## Flow Editor

### Overview

The Flow Editor allows you to create and manage onboarding flows visually without writing code.

### Creating a New Flow

1. Navigate to **Admin → Flows**
2. Click **New Flow**
3. Fill in flow details:
   - **Name**: Descriptive name for the flow
   - **Description**: Optional description
4. Add steps to the flow
5. Click **Create Flow**

### Adding Steps

For each step, configure:

- **Step Name**: Internal identifier (e.g., `welcome`, `profile`)
- **Display Title**: User-facing title
- **Icon**: Emoji icon for the step
- **Skippable**: Whether users can skip this step
- **Description**: Optional description

### Managing Flows

#### Activating a Flow

Only one flow can be active at a time. To activate a flow:

1. Navigate to the flow details
2. Click **Activate Flow**
3. Confirm the activation

The activated flow will be used for all new users starting onboarding.

#### Duplicating a Flow

To create a copy of an existing flow:

1. Go to **Admin → Flows**
2. Find the flow you want to duplicate
3. Click **Duplicate**
4. Edit the duplicated flow as needed

#### Previewing a Flow

Before activating, preview how the flow will look:

1. Open the flow details
2. Click **Preview Flow**
3. View the flow in a new window

### Using Templates

Start with pre-built templates for common use cases:

- **SaaS Application**: Standard SaaS onboarding
- **E-commerce**: Online store onboarding
- **Marketplace**: Two-sided marketplace flow
- **Community**: Social/community platform
- **Education**: Learning platform flow

### Example Flow Configuration

```ruby
# Manual configuration (in initializer)
RailsOnboarding.configure do |config|
  config.steps = [
    {
      name: :welcome,
      title: 'Welcome',
      icon: '👋',
      skippable: true,
      description: 'Welcome to our platform'
    },
    {
      name: :profile,
      title: 'Setup Profile',
      icon: '👤',
      skippable: false,
      description: 'Complete your profile information'
    },
    {
      name: :preferences,
      title: 'Set Preferences',
      icon: '⚙️',
      skippable: true,
      description: 'Customize your experience'
    }
  ]
end
```

---

## A/B Test Management

### Overview

The A/B Testing interface allows you to create, manage, and analyze experiments to optimize your onboarding flow.

### Creating an A/B Test

1. Navigate to **Admin → A/B Tests**
2. Click **New A/B Test**
3. Configure test details:
   - **Name**: Test name
   - **Description**: What you're testing
   - **Goal Metric**: What you're measuring (completion rate, time, etc.)
4. Add variants:
   - **Control**: The existing flow
   - **Variant A, B, etc.**: Alternative flows
5. Set traffic percentages for each variant
6. Save as draft

### Managing Tests

#### Starting a Test

1. Ensure your test is configured correctly
2. Click **Start** on the test card
3. Confirm to begin the test

Once started:
- Users will be randomly assigned to variants
- Data collection begins automatically
- Results update in real-time

#### Stopping a Test

1. Click **Stop** on an active test
2. The test status changes to completed
3. Users are no longer assigned to variants

#### Viewing Results

The results page shows:

- **Conversion Rate**: Percentage of users completing onboarding
- **Average Completion Time**: Time from start to finish
- **Engagement Metrics**: Number of interactions per user
- **Statistical Significance**: Confidence level in results

### Declaring a Winner

When you have sufficient data:

1. Review the results
2. Identify the best-performing variant
3. Click **Declare Winner**
4. Choose the winning variant
5. Optionally, activate the winning flow

### Example: Creating an A/B Test

```ruby
# Via the admin interface:
# 1. Create a new test
# 2. Add control variant (current flow)
# 3. Add variant A (modified flow with different copy)
# 4. Set 50/50 traffic split
# 5. Start the test

# Programmatic example:
test = RailsOnboarding::AbTest.create!(
  name: 'Welcome Message Test',
  description: 'Testing different welcome messages',
  goal_metric: 'completion_rate',
  status: 'draft'
)

# Add variants
test.variants.create!(
  name: 'control',
  description: 'Current welcome message',
  traffic_percentage: 50,
  configuration: { welcome_text: 'Welcome to our app!' }
)

test.variants.create!(
  name: 'variant_a',
  description: 'Friendlier welcome message',
  traffic_percentage: 50,
  configuration: { welcome_text: 'Hey there! Let\'s get started!' }
)

# Start the test
test.start!
```

### Exporting Results

Export test results to CSV for external analysis:

1. Open the test details
2. Click **Export**
3. Choose CSV format
4. Download the file

---

## API Reference

### Admin Controllers

#### DashboardController

**Route**: `GET /onboarding/admin`

Returns the analytics dashboard with:
- Overall statistics
- Daily completion trend
- Step funnel data
- Milestone achievements
- Recent activity

**Query Parameters**:
- `date_range`: `7`, `30`, `90`, or `all` (default: `30`)

#### UsersController

**Routes**:
- `GET /onboarding/admin/users` - List all users
- `GET /onboarding/admin/users/:id` - User details
- `POST /onboarding/admin/users/:id/reset_onboarding` - Reset user
- `POST /onboarding/admin/users/:id/complete_onboarding` - Complete user
- `POST /onboarding/admin/users/bulk_action` - Bulk actions
- `GET /onboarding/admin/users/export` - Export users as CSV

**Query Parameters** (index and export):
- `status`: `completed`, `in_progress`, `not_started`, `skipped`
- `step`: Filter by current step
- `search`: Search term
- `sort`: Column to sort by
- `direction`: `asc` or `desc`
- `page`: Page number
- `per_page`: Results per page (default: 25, capped at 100)

Pagination is provided by [pagy](https://github.com/ddnexus/pagy), a runtime
dependency of the engine. Page links preserve the `search`, `status`, `sort`,
and `direction` parameters that are in effect.

**CSV export.** The "Export CSV" button carries the filters currently in effect
(`search`, `status`, `step`, `sort`, `direction`) through to the export, so the
file matches the table on screen. It is deliberately *not* paginated - `page` and
`per_page` are ignored and every matching user is written out, in the chosen sort
order. Columns: ID, Email (omitted when the user model has no `email` column),
Status, Current Step, Progress (%), Completed At, Created At, Last Activity.

Because the export honours the sort, it iterates the ordered relation rather than
using `find_each`, which would replace the `ORDER BY` with a primary-key scan.
That means the matching rows are loaded to build the file; if you expect to export
very large result sets, filter first.

All three admin index screens (users, flows, A/B tests) paginate through the same
`Admin::BaseController#paginate` helper, so they share the `page`/`per_page`
parameters and the `DEFAULT_PER_PAGE` (25) / `MAX_PER_PAGE` (100) constants
defined on `Admin::BaseController`.

#### FlowsController

**Routes**:
- `GET /onboarding/admin/flows` - List flows
- `GET /onboarding/admin/flows/:id` - Flow details
- `POST /onboarding/admin/flows` - Create flow
- `PATCH /onboarding/admin/flows/:id` - Update flow
- `DELETE /onboarding/admin/flows/:id` - Delete flow
- `POST /onboarding/admin/flows/:id/activate` - Activate flow
- `POST /onboarding/admin/flows/:id/duplicate` - Duplicate flow
- `GET /onboarding/admin/flows/:id/preview` - Preview flow

**Query Parameters** (index):
- `page`: Page number
- `per_page`: Results per page (default: 25, capped at 100)

The "Active Flow" banner at the top of the index is looked up independently of
the current page, so it shows even when the active flow sits on another page.

#### AbTestsController

**Routes**:
- `GET /onboarding/admin/ab_tests` - List tests
- `GET /onboarding/admin/ab_tests/:id` - Test details
- `POST /onboarding/admin/ab_tests` - Create test
- `PATCH /onboarding/admin/ab_tests/:id` - Update test
- `DELETE /onboarding/admin/ab_tests/:id` - Delete test
- `POST /onboarding/admin/ab_tests/:id/start` - Start test
- `POST /onboarding/admin/ab_tests/:id/stop` - Stop test
- `POST /onboarding/admin/ab_tests/:id/declare_winner` - Declare winner
- `GET /onboarding/admin/ab_tests/:id/export` - Export results

**Query Parameters** (index):
- `page`: Page number
- `per_page`: Results per page (default: 25, capped at 100)

A/B tests are defined in `config.ab_tests`, not stored in the database, so this
list only grows when a developer edits the initializer - in practice it rarely
reaches a second page. The index renders two sections off one collection, so the
combined list is paginated (active tests first) and the current page is split back
into the Active and Inactive sections; a page holding only inactive tests renders
just that heading. The stat cards always report whole-collection totals.

---

## Customization

### Customizing the Admin Layout

Override the admin layout by creating your own:

```erb
<!-- app/views/layouts/rails_onboarding/admin.html.erb -->
<!DOCTYPE html>
<html>
<head>
  <title>My Custom Admin</title>
  <%= stylesheet_link_tag "rails_onboarding/admin" %>
  <%= stylesheet_link_tag "my_custom_admin" %>
</head>
<body>
  <!-- Your custom layout -->
  <%= yield %>
</body>
</html>
```

### Adding Custom Styles

Add your own CSS to customize the admin interface:

```css
/* app/assets/stylesheets/admin_customization.css */
:root {
  --admin-primary: #your-brand-color;
  --admin-sidebar-bg: #your-sidebar-color;
}

.admin-sidebar {
  /* Your custom styles */
}
```

### Extending Admin Controllers

Add custom actions to admin controllers:

```ruby
# app/controllers/rails_onboarding/admin/dashboard_controller.rb
module RailsOnboarding
  module Admin
    class DashboardController < BaseController
      def custom_report
        # Your custom logic
        @report_data = generate_custom_report
      end
    end
  end
end
```

Add the route:

```ruby
# config/routes.rb
RailsOnboarding::Engine.routes.draw do
  namespace :admin do
    get 'custom_report', to: 'dashboard#custom_report'
  end
end
```

### Custom Analytics

Integrate with your own analytics:

```ruby
# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  after_action :track_admin_activity, if: -> { admin_user? }

  private

  def track_admin_activity
    # Send to your analytics service
    Analytics.track(
      user_id: current_user.id,
      event: 'admin_page_view',
      properties: {
        path: request.path,
        timestamp: Time.current
      }
    )
  end
end
```

---

## Best Practices

### 1. Regular Monitoring

- Check the dashboard daily for unusual patterns
- Review completion rates weekly
- Analyze drop-off points monthly

### 2. A/B Testing

- Test one variable at a time
- Run tests for at least 2 weeks
- Ensure statistical significance before declaring winners
- Document test results and learnings

### 3. User Management

- Monitor users stuck on specific steps
- Proactively reach out to users with low engagement
- Use bulk actions carefully

### 4. Flow Optimization

- Keep flows concise (3-5 steps ideal)
- Make critical steps non-skippable
- Use clear, action-oriented titles
- Test flows before activating

### 5. Security

- Limit admin access to trusted users
- Regularly audit admin actions
- Use strong authentication
- Enable 2FA for admin users (if available)

---

## Troubleshooting

### Issue: Can't Access Admin Interface

**Solution**:
1. Ensure your user has `admin: true` or the `admin?` method returns true
2. Check that authentication is configured correctly
3. Verify the routes are mounted properly

### Issue: Analytics Not Showing

**Solution**:
1. Ensure AnalyticsEvent model exists
2. Check that events are being tracked
3. Verify the date range filter

### Issue: Flow Changes Not Appearing

**Solution**:
1. Make sure you activated the new flow
2. Clear browser cache
3. Check that configuration is loaded correctly

### Issue: A/B Test Not Assigning Users

**Solution**:
1. Verify the test is in "active" status
2. Check traffic percentages sum to 100
3. Ensure variant configurations are valid

---

## Support

For issues or questions:

1. Check the [main README](../README.md)
2. Review the [GitHub Issues](https://github.com/yourusername/rails_onboarding/issues)
3. Consult other guides:
   - [Analytics Guide](ANALYTICS_GUIDE.md)
   - [Milestones Guide](MILESTONES_GUIDE.md)
   - [Advanced Features](ADVANCED_FEATURES.md)

---

## Changelog

### Version 1.0.0 (Current)

- Initial admin interface release
- Dashboard with analytics
- User management
- Flow editor
- A/B test management
- Comprehensive documentation

---

*Last updated: 2024*
