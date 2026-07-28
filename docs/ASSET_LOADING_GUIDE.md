# Asset Loading Guide

This guide explains how the Rails Onboarding gem loads and integrates assets (CSS and JavaScript) with different Rails asset pipeline configurations.

## Overview

The Rails Onboarding engine supports multiple asset pipeline strategies to ensure compatibility with any Rails application:

- **Sprockets** (Traditional Asset Pipeline)
- **Propshaft** (Rails 7+ Asset Pipeline)
- **Importmap** (Import Maps for JavaScript)
- **Modern Bundlers** (ESBuild, Webpack, Vite, etc.)

## How Asset Detection Works

The engine automatically detects which asset pipeline your application uses during initialization:

```ruby
# lib/rails_onboarding/engine.rb
def self.detect_asset_pipeline(app)
  if defined?(Propshaft)
    :propshaft
  elsif defined?(Sprockets) && app.config.respond_to?(:assets)
    :sprockets
  elsif importmap_available?(app)
    :importmap
  else
    :modern_bundler
  end
end
```

Based on the detected pipeline, the appropriate configuration is applied automatically.

## Asset Pipeline Configurations

### Sprockets

When using Sprockets, the engine:
- Adds asset paths for stylesheets and javascripts
- Precompiles all CSS and JavaScript files
- Supports `require` directives in manifests

**Host Application Integration:**

```ruby
# app/assets/stylesheets/application.css
/*
 *= require rails_onboarding/application
 */
```

```ruby
# app/assets/javascripts/application.js
//= require rails_onboarding/application
```

### Propshaft

When using Propshaft, the engine:
- Adds asset paths (Propshaft automatically includes all assets)
- No precompilation configuration needed
- Assets are served directly

Propshaft has no bundling-directive processor, so `application.css`'s
internal Sprockets `require` comments do nothing here - it only contains its
own base styles/tokens. The gem's other stylesheets (tooltips, tours,
milestones, mobile responsiveness, admin UI, flash messages, accessibility,
progressive disclosure) need their own `stylesheet_link_tag` each, or
they'll silently never load.

**Host Application Integration:**

```erb
<!-- app/views/layouts/application.html.erb -->
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
<%= javascript_include_tag "rails_onboarding/application" %>
```

Keep `application` first (it defines the `--onboarding-*` custom properties
the rest use) and `mobile` last (its media-query overrides need to win
cascade ties). Skip `admin` if you don't use the admin dashboard. This
applies whether or not you also use cssbundling-rails for your own styles -
these tags are served by Propshaft directly and don't go through your build
pipeline.

### Importmap

When using Importmap for JavaScript, the engine:
- Registers all JavaScript controllers via `config/importmap.rb`
- Adds stylesheet paths for CSS (CSS still needs traditional loading)
- Supports Stimulus controller auto-loading

**Host Application Integration:**

```ruby
# config/importmap.rb
# The engine's importmap is automatically loaded

# Or manually pin if needed:
pin_all_from "app/assets/javascripts/rails_onboarding", under: "rails_onboarding"
```

```erb
<!-- app/views/layouts/application.html.erb -->
<!-- JavaScript loaded via importmap automatically -->
```

Importmap only covers JavaScript. CSS loading depends on whichever asset
pipeline handles stylesheets underneath (Propshaft or Sprockets - see those
sections above for the tags you need; on Propshaft that's one
`stylesheet_link_tag` per gem stylesheet, not just `application`).

### Modern Bundlers (ESBuild, Webpack, Vite)

When using modern JavaScript bundlers, the engine:
- Adds asset paths if assets config is available
- Allows direct imports in your build configuration
- Provides flexible integration options

**Host Application Integration with ESBuild:**

```javascript
// app/javascript/application.js
import "rails_onboarding/application"
```

```css
/* app/assets/stylesheets/application.css */
@import "rails_onboarding/application";
```

**Build Configuration:**

```json
// package.json
{
  "scripts": {
    "build": "esbuild app/javascript/*.* --bundle --outdir=app/assets/builds --public-path=/assets"
  }
}
```

Add the engine's asset paths to your build configuration:

```javascript
// esbuild.config.js
const path = require('path')

module.exports = {
  // ...
  paths: [
    path.join(process.cwd(), 'app/javascript'),
    path.join(process.cwd(), 'node_modules'),
    // Add Rails Onboarding gem paths
    path.join(__dirname, '../../path/to/gem/app/assets/javascripts')
  ]
}
```

## CSS Isolation

All CSS in the Rails Onboarding gem follows strict namespacing to prevent conflicts with host applications:

### Naming Conventions

1. **CSS Custom Properties (Variables):** All variables use the `--onboarding-` prefix
   ```css
   :root {
     --onboarding-primary: #6366f1;
     --onboarding-background: #ffffff;
   }
   ```

2. **Class Names:** All classes use `onboarding-` or `rails-onboarding-` prefixes
   ```css
   .onboarding-container { }
   .onboarding-step { }
   .rails-onboarding-tooltip { }
   ```

3. **No Global Selectors:** Element selectors are always scoped, using
   `:where()` to carry the scope
   ```css
   /* ❌ Avoid - restyles every link in the host application */
   a { text-decoration: underline; }

   /* ✅ Correct */
   :where(.onboarding-container) a { text-decoration: underline; }
   ```

   `:where()` contributes **zero specificity**, so the scoped rule competes
   in the cascade exactly as the bare selector did. That matters in both
   directions: the gem's own stylesheets keep their existing override
   relationships (`mobile.css`'s media queries still win the ties they won
   before), and your application's styles beat the gem's on equal footing
   rather than having to out-specify an extra class.

   A plain descendant prefix (`.onboarding-container a`) would work for
   isolation but raise specificity from `(0,0,1)` to `(0,1,1)`, silently
   changing which rule wins wherever the gem's own files overlap.

### Scoping Strategy

Onboarding UI lives under one of two scope roots. Engine pages are wrapped
in `.onboarding-container` by the engine's layout:

```html
<div class="onboarding-container">
  <!-- All onboarding content -->
</div>
```

The banner rendered on **your** pages
(`render "rails_onboarding/shared/onboarding_banner"`) sits outside that
wrapper, so it carries its own root, `.onboarding-banner`. Rules that need
to reach it are scoped to both:

```css
:where(.onboarding-container, .onboarding-banner) .progress-fill { }
```

Together these ensure gem styles only apply within onboarding contexts. It
is safe to bundle the gem's CSS into your global stylesheet.

### Deliberate exceptions

Three things are intentionally **not** scoped:

1. **`--onboarding-*` custom properties on `:root`.** This is the supported
   theming hook — redefine them from your own stylesheet to retheme the gem.
   Nothing outside the gem reads them.

2. **`.onboarding-sr-only` and `.onboarding-skip-link`.** These are opt-in
   utilities meant for use outside the container; a skip link in particular
   has to be the first focusable element in the document, which places it
   above `.onboarding-container` in the DOM. The `onboarding-` prefix, not a
   scope, is what keeps them from colliding. (Earlier versions named these
   `.sr-only` and `.skip-link`, which collided with the identically named
   classes in Bootstrap and Tailwind.)

3. **`prefers-contrast` / `prefers-color-scheme` blocks that only reassign
   `--onboarding-*` properties.** They can't affect anything the gem doesn't
   style.

Note that `prefers-reduced-motion` *is* scoped. Disabling animation across
the whole page is the host application's decision, not a mounted engine's,
so the gem only quiets its own components.

## JavaScript Integration

### Stimulus Controllers

The gem provides multiple Stimulus controllers. Registering them is a manual
step in every asset pipeline - pinning or adding an asset path only makes a
controller's JavaScript *loadable*, it doesn't register it with your
Stimulus `Application` instance.

#### Manual Registration (required)

```javascript
// app/javascript/controllers/index.js
import { Application } from "@hotwired/stimulus"

import OnboardingController from "rails_onboarding/onboarding_controller"
import TooltipController from "rails_onboarding/tooltip_controller"

const application = Application.start()

application.register("onboarding", OnboardingController)
application.register("tooltip", TooltipController)
```

Only register the controllers you actually use in your views - see
[Available Controllers](#available-controllers) below for the full list and
what each one is for.

#### Manifest-based discovery (Sprockets/Propshaft + stimulus-rails)

If your app uses `stimulus-rails`, adding the engine's JS directory to
`config.stimulus.paths` (which the engine does automatically) lets
`bin/rails stimulus:manifest:update` discover these controllers and add them
to `app/javascript/controllers/index.js` for you. Run that command after
installing the gem, then check the generated `index.js` - you still need to
verify the identifiers it picked (typically derived from the filename, e.g.
`tooltip_controller.js` &rarr; `tooltip`) match what the gem's views expect
before relying on it.

### Available Controllers

The gem includes these Stimulus controllers:

**Core Controllers:**
- `onboarding_controller` - Main onboarding flow navigation
- `progress_controller` - Progress tracking and display
- `navigation_controller` - Step-by-step navigation

**Tooltip System:**
- `tooltip_controller` - Individual tooltip management
- `tooltip_scheduler_controller` - Progressive tooltip disclosure

**Tour & Guides:**
- `tour_controller` - Guided tours with spotlights
- `progressive_disclosure_controller` - Feature revelation system

**Milestone System:**
- `milestone_celebration_controller` - Achievement celebrations
- `milestone_dashboard_controller` - Milestone overview
- `milestone_detail_controller` - Individual milestone details

**Admin Interface:**
- `admin/chart_controller` - Analytics charts
- `admin/filter_controller` - Data filtering
- `admin/flash_controller` - Flash message handling
- `admin/flow_editor_controller` - Visual flow editor

## View Path Loading

The engine automatically adds its view paths to both ActionController and ActionMailer:

```ruby
# lib/rails_onboarding/engine.rb
initializer "rails_onboarding.view_paths" do |app|
  ActiveSupport.on_load(:action_controller_base) do
    view_path = RailsOnboarding::Engine.root.join("app", "views")
    append_view_path view_path if File.directory?(view_path)
  end

  ActiveSupport.on_load(:action_mailer) do
    view_path = RailsOnboarding::Engine.root.join("app", "views")
    append_view_path view_path if File.directory?(view_path)
  end
end
```

This ensures engine views are accessible from anywhere in your application.

## Troubleshooting

### Assets Not Loading

**Problem:** CSS or JavaScript files are not loading

**Solutions:**
1. Check that assets are precompiled in production:
   ```bash
   rails assets:precompile
   ```

2. Verify asset paths in development:
   ```bash
   rails console
   Rails.application.config.assets.paths
   # Should include paths to rails_onboarding assets
   ```

3. Check your layout includes the assets. On Sprockets, one tag each is
   enough; on Propshaft you need one `stylesheet_link_tag` per gem
   stylesheet (see the [Propshaft](#propshaft) section above) - a single
   `rails_onboarding/application` tag on Propshaft only gets you the base
   styles, not tooltips/tour/milestones/mobile/etc.
   ```erb
   <%= stylesheet_link_tag "rails_onboarding/application" %>
   <%= javascript_include_tag "rails_onboarding/application" %>
   ```

### Stimulus Controllers Not Registering

**Problem:** Stimulus controllers are not found

**Solutions:**
1. Verify Stimulus is loaded in your application:
   ```javascript
   console.log(window.Stimulus)
   // Should show Stimulus application object
   ```

2. Check the browser console for registration messages:
   ```
   RailsOnboarding: Using existing Stimulus application
   ```

3. Manually register if auto-registration fails (see Manual Registration above)

### CSS Conflicts

**Problem:** Styles conflict with host application

Every rule in the gem's stylesheets is scoped to markup the engine owns
(see [CSS Isolation](#css-isolation)), so bundling the gem's CSS globally
should not affect your own pages.

**Solutions:**

1. **Retheme with custom properties.** This is the intended customization
   path and needs no specificity fight:
   ```css
   /* In your application.css */
   :root {
     --onboarding-primary: #0f766e;
     --onboarding-primary-hover: #115e59;
   }
   ```

2. **Override individual rules.** Because the gem scopes with `:where()`
   (zero specificity), a single class in your own stylesheet is enough —
   you do not need to match the gem's scope:
   ```css
   /* In your application.css, loaded after the gem's */
   .primary-action {
     border-radius: 0;
   }
   ```

3. **If gem styles are reaching your own pages**, you are on a version
   before the scoping fix. Symptoms: every link underlined and recoloured,
   tables and fieldsets restyled, buttons forced to a 44px minimum, or
   anything with `role="dialog"` yanked to the centre of the viewport.
   Under Sprockets, `*= require rails_onboarding/application` pulls in
   every gem stylesheet via `require_tree`, so one directive is enough to
   apply all of it globally. Upgrade, or drop the `require` from your host
   `application.css` and link only the stylesheets you need.

4. **If your own styles are reaching onboarding pages**, that's the
   host-app reset or framework applying to engine markup. The engine layout
   only loads your `application.css` when
   `config.include_host_styles` is enabled — turn it off if you want the
   onboarding pages fully insulated.

### Importmap Issues

**Problem:** Importmap pins not working

**Solutions:**
1. Verify the engine's importmap is loaded:
   ```ruby
   # config/importmap.rb
   # Should automatically include engine pins
   ```

2. Check importmap output:
   ```bash
   bin/importmap json
   # Should show rails_onboarding pins
   ```

3. Manually clear importmap cache:
   ```bash
   rm -rf tmp/cache/assets
   ```

## Production Considerations

### Asset Precompilation

**Sprockets** needs the gem's entry points added to the precompile list:

```ruby
# config/initializers/assets.rb
Rails.application.config.assets.precompile += %w[
  rails_onboarding/application.css
  rails_onboarding/application.js
]
```

The engine handles this automatically for Sprockets, but verify in production logs.

**Propshaft** has no precompile list - it serves every file under its
configured load paths automatically, including the engine's. There's
nothing to add here; just make sure every `stylesheet_link_tag` from the
[Propshaft](#propshaft) section is in your layout, since those are what
determine what actually loads, in both development and production.

### CDN Integration

If using a CDN for assets, ensure the engine's assets are included:

```ruby
# config/environments/production.rb
config.asset_host = 'https://your-cdn.cloudfront.net'
```

The engine's assets will automatically be served from your CDN.

### Performance

For optimal performance:

1. **Lazy Load:** Only load onboarding assets on pages that need them
2. **Cache:** Use HTTP caching headers for static assets
3. **Compress:** Enable gzip/brotli compression for CSS and JavaScript
4. **CDN:** Serve assets from a CDN in production

## Testing Asset Loading

Run the comprehensive asset loading test suite:

```bash
bundle exec rake test test/lib/rails_onboarding/engine_asset_loading_test.rb
```

This tests:
- Asset pipeline detection
- File existence
- CSS isolation
- JavaScript compatibility
- Importmap configuration
- View path loading

## Summary

The Rails Onboarding engine provides flexible, automatic asset loading that works with:

✅ Sprockets (Asset Pipeline)
✅ Propshaft (Rails 7+)
✅ Importmap (JavaScript)
✅ ESBuild, Webpack, Vite (Modern Bundlers)

The detection and configuration happen automatically, requiring minimal setup in most cases. CSS is fully isolated with namespacing, and JavaScript integrates seamlessly with Stimulus or can be used standalone.

For most applications, simply including the engine in your Gemfile is sufficient - the rest is handled automatically!
