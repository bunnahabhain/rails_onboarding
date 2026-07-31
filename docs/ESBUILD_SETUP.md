# Rails Onboarding - ESBuild Setup Guide

If your app uses ESBuild for JavaScript bundling, you'll need to manually include the Rails Onboarding JavaScript files in your application.

## 1. Copy JavaScript Controllers

The easiest way - and the way to keep them current on future gem upgrades - is
the bundled generator:

```bash
bin/rails generate rails_onboarding:update
```

It force-copies every controller **directly into** `app/javascript/controllers/`
(the `admin/*` ones into `app/javascript/controllers/admin/`) and writes a
`.rails_onboarding_version` marker. Re-run it whenever you update the gem; the
engine logs a warning at boot when the vendored copy has drifted from the
installed version. It only touches these controllers - never your initializer,
migrations, `rails_onboarding_custom.css`, or your onboarding step views.

The **flat** destination matters. Stimulus derives each controller's identifier
from its path under the controllers root, using `--` for subfolders, and the
gem's views expect the flat identifiers below - nesting these under a
`rails_onboarding/` subfolder produces prefixed identifiers
(`rails-onboarding--onboarding`) that won't match the gem's views and will
silently fail to connect. The generator's `--path` can override the destination,
but the flat default is what the gem's views assume.

### Copying by hand instead

If you'd rather not use the generator, copy the controllers yourself - but note
`application.js` is deliberately excluded (it would overwrite your own
`app/javascript/controllers/application.js` entrypoint, and nothing imports it):

```bash
# From your Rails app root:
cp path/to/rails_onboarding/app/assets/javascripts/rails_onboarding/*_controller.js app/javascript/controllers/
cp path/to/rails_onboarding/app/assets/javascripts/rails_onboarding/admin/*_controller.js app/javascript/controllers/admin/
```

Or manually create these files in `app/javascript/controllers/`:

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

**Admin Interface** (only needed if you use the admin dashboard; in
`app/javascript/controllers/admin/`):
- `admin/chart_controller.js`
- `admin/filter_controller.js`
- `admin/flash_controller.js`
- `admin/flow_editor_controller.js`

If you don't use the admin dashboard, you can skip copying the four
`admin/*` controllers.

Since these land alongside your own app's controllers, watch for filename
collisions with anything you already have (e.g. an existing
`navigation_controller.js` or `flash_controller.js`) - rename on either side
if that happens, and update the corresponding `data-controller` usage.

## 2. Register Controllers in Application

If your app uses `stimulus-rails` (check for the auto-generated header
comment at the top of `app/javascript/controllers/index.js`), you don't need
to hand-write any imports. Just run:

```bash
./bin/rails stimulus:manifest:update
```

This scans `app/javascript/controllers/` and rewrites `index.js` with the
correct imports and `application.register(...)` calls for every controller
it finds, including the ones you just copied in Step 1. Open `index.js`
afterward and confirm the registered names match what the gem's views use:

| File | Expected identifier |
| --- | --- |
| `onboarding_controller.js` | `onboarding` |
| `progress_controller.js` | `progress` |
| `navigation_controller.js` | `navigation` |
| `tooltip_controller.js` | `tooltip` |
| `tooltip_scheduler_controller.js` | `tooltip-scheduler` |
| `tour_controller.js` | `tour` |
| `progressive_disclosure_controller.js` | `progressive-disclosure` |
| `milestone_celebration_controller.js` | `milestone-celebration` |
| `milestone_dashboard_controller.js` | `milestone-dashboard` |
| `milestone_detail_controller.js` | `milestone-detail` |
| `admin/chart_controller.js` | `admin--chart` |
| `admin/filter_controller.js` | `admin--filter` |
| `admin/flash_controller.js` | `admin--flash` |
| `admin/flow_editor_controller.js` | `admin--flow-editor` |

### Alternative: register manually

If you're not using `stimulus-rails`' manifest management (no auto-generated
header comment in `index.js`), add this to
`app/javascript/controllers/index.js` yourself:

```javascript
import { application } from "controllers/application"

import OnboardingController from "./onboarding_controller"
import ProgressController from "./progress_controller"
import NavigationController from "./navigation_controller"
import TooltipController from "./tooltip_controller"
import TooltipSchedulerController from "./tooltip_scheduler_controller"
import TourController from "./tour_controller"
import ProgressiveDisclosureController from "./progressive_disclosure_controller"
import MilestoneCelebrationController from "./milestone_celebration_controller"
import MilestoneDashboardController from "./milestone_dashboard_controller"
import MilestoneDetailController from "./milestone_detail_controller"
import AdminChartController from "./admin/chart_controller"
import AdminFilterController from "./admin/filter_controller"
import AdminFlashController from "./admin/flash_controller"
import AdminFlowEditorController from "./admin/flow_editor_controller"

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

## 3. Include CSS Styles

The gem's CSS isn't part of your JavaScript bundle - it ships as plain
stylesheets that Propshaft (Rails' default asset pipeline since Rails 8, and
what you get alongside cssbundling-rails) serves directly, independent of
whatever bundler produces your own `app/assets/builds/application.css`.

`rails_onboarding/application.css` only contains the base styles and design
tokens. The rest of the gem's styling - tooltips, tours, milestones, mobile
responsiveness, admin UI, flash messages, accessibility helpers - lives in
separate files that Sprockets would auto-bundle via `require_tree`, but
Propshaft doesn't process bundling directives at all, so **each file needs
its own tag**. Add these to your layout (e.g.
`app/views/layouts/application.html.erb`), inside `<head>`:

```erb
<%= stylesheet_link_tag "rails_onboarding/application" %>
<%= stylesheet_link_tag "rails_onboarding/tooltips" %>
<%= stylesheet_link_tag "rails_onboarding/utilities" %>
<%= stylesheet_link_tag "rails_onboarding/accessibility" %>
<%= stylesheet_link_tag "rails_onboarding/milestones" %>
<%= stylesheet_link_tag "rails_onboarding/tour" %>
<%= stylesheet_link_tag "rails_onboarding/flash_messages" %>
<%= stylesheet_link_tag "rails_onboarding/progressive_disclosure" %>
<%= stylesheet_link_tag "rails_onboarding/admin" %>
<%= stylesheet_link_tag "rails_onboarding/mobile" %>
```

Keep `application` first (it defines the `--onboarding-*` custom properties
the others use) and `mobile` last (its media-query overrides need to win
cascade ties against the component files). The rest can be in any order.

If you don't use the admin dashboard, you can skip
`rails_onboarding/admin`.

This works whether or not cssbundling-rails is installed - it isn't
involved here at all, since these tags bypass your build pipeline entirely.

### Will these affect the rest of my app?

No. Every rule in these stylesheets is scoped to markup the engine owns -
`.onboarding-container` on engine pages, `.onboarding-banner` for the banner
rendered on your own pages - so it's safe to load them site-wide from your
layout, which is what the tags above do.

The scoping uses `:where()`, which contributes zero specificity. Practically
that means overriding a gem style takes a single class in your own
stylesheet; you don't have to out-specify anything.

Two exceptions, both deliberate. The gem defines `--onboarding-*` custom
properties on `:root` - that's the supported way to retheme it:

```css
:root {
  --onboarding-primary: #0f766e;
}
```

And `.onboarding-sr-only` / `.onboarding-skip-link` are namespaced rather
than scoped, since a skip link has to be the first focusable element in the
document and so lives above the container. If you're upgrading from a
version that named these `.sr-only` / `.skip-link` and referenced them in
your own markup, rename them.

If you're on a version before the scoping fix and see every link on your
homepage underlined, that's `accessibility.css` - it carried unscoped `a`,
`table`, `fieldset` and `button` selectors. Upgrading resolves it.

`accessibility.css` is not optional and isn't gated on a user preference:
focus indicators, touch targets and screen-reader text apply to everyone,
and the parts that *are* preference-dependent (`prefers-contrast`,
`prefers-reduced-motion`, `prefers-color-scheme`) are gated by the browser
off the user's OS setting, with nothing for your app to configure.

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
