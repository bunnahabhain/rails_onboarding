# Responsive Design Guide

This guide explains the comprehensive mobile-responsive design features built into the Rails Onboarding gem.

## Overview

The gem includes advanced responsive design features optimized for:
- Mobile phones (portrait and landscape)
- Tablets (portrait and landscape)
- Desktop computers
- Foldable devices
- Devices with notches and safe areas

## Table of Contents

1. [Breakpoints](#breakpoints)
2. [CSS Features](#css-features)
3. [Helper Methods](#helper-methods)
4. [Mobile Optimizations](#mobile-optimizations)
5. [Touch-Friendly Design](#touch-friendly-design)
6. [Best Practices](#best-practices)

## Breakpoints

The gem uses a mobile-first approach with the following breakpoints:

| Breakpoint | Range | Devices |
|------------|-------|---------|
| Extra Small | < 480px | Small phones (portrait) |
| Small | 480px - 767px | Large phones, small tablets (portrait) |
| Medium | 768px - 1023px | Tablets (portrait), small laptops |
| Large | 1024px+ | Tablets (landscape), laptops, desktops |

### Landscape Orientation

Special handling for landscape orientation on mobile devices:
- Optimized layouts for limited vertical space
- Compact navigation and progress indicators
- Horizontal button layouts

## CSS Features

### Mobile-Specific Variables

```css
:root {
  --mobile-space-xs: 0.25rem;
  --mobile-space-sm: 0.375rem;
  --mobile-space-md: 0.75rem;
  --mobile-space-lg: 1rem;
  --mobile-space-xl: 1.5rem;

  --mobile-text-xs: 0.6875rem;
  --mobile-text-sm: 0.8125rem;
  --mobile-text-base: 0.9375rem;
  --mobile-text-lg: 1.0625rem;
  --mobile-text-xl: 1.1875rem;
  --mobile-text-2xl: 1.375rem;
  --mobile-text-3xl: 1.625rem;
}
```

### Utility Classes

#### Visibility

```html
<!-- Hide on mobile -->
<div class="mobile-hidden">Only visible on desktop</div>

<!-- Show only on mobile -->
<div class="mobile-only">Only visible on mobile</div>

<!-- Always visible -->
<div class="mobile-visible">Visible on all devices</div>
```

#### Layout

```html
<!-- Stack vertically on mobile -->
<div class="mobile-stack">
  <div>Item 1</div>
  <div>Item 2</div>
</div>

<!-- Full width on mobile -->
<button class="mobile-full">Full width button</button>

<!-- Center on mobile -->
<div class="mobile-center">Centered content</div>

<!-- Compact padding on mobile -->
<div class="mobile-compact">Compact spacing</div>
```

### Responsive Typography

Fluid typography that scales appropriately:

```css
.step-title {
  font-size: clamp(1.375rem, 5vw, 1.875rem);
}
```

## Helper Methods

### Viewport Meta Tag

Add this to your application layout:

```erb
<!DOCTYPE html>
<html>
<head>
  <%= rails_onboarding_viewport_meta %>
  <!-- Rest of your head content -->
</head>
```

#### Custom Viewport Settings

```erb
<%= rails_onboarding_viewport_meta(
  maximum_scale: 3.0,
  viewport_fit: 'contain'
) %>
```

### iOS-Specific Meta Tags

```erb
<%= rails_onboarding_ios_meta %>
```

This includes:
- Web app capable mode
- Status bar styling
- Phone number detection settings

### Theme Color

```erb
<%= rails_onboarding_theme_color %>
<!-- or with custom color -->
<%= rails_onboarding_theme_color('#6366f1') %>
```

### Device Detection

```erb
<% if mobile_device? %>
  <p>You're on a mobile device!</p>
<% end %>

<% if tablet_device? %>
  <p>You're on a tablet!</p>
<% end %>

<% if phone_device? %>
  <p>You're on a phone!</p>
<% end %>
```

### Device Classes

Add device-specific CSS classes:

```erb
<body class="<%= responsive_device_classes %>">
  <!-- is-mobile, is-tablet, is-phone, or is-desktop -->
</body>
```

### Device Data Attributes

For JavaScript detection:

```erb
<div <%= responsive_device_data %>>
  <!-- data-mobile, data-tablet, data-phone attributes -->
</div>
```

### Responsive Images

```erb
<%= responsive_image('welcome.jpg',
  alt: 'Welcome',
  srcset: {
    '1x' => 'welcome.jpg',
    '2x' => 'welcome@2x.jpg',
    '3x' => 'welcome@3x.jpg'
  },
  sizes: '(max-width: 768px) 100vw, 50vw'
) %>
```

### Touch-Friendly Attributes

```erb
<button <%= touch_friendly_attrs %>>
  Tap me!
</button>
```

## Mobile Optimizations

### Safe Area Support

The gem automatically handles notches and safe areas on modern devices:

```css
.onboarding-content {
  padding-left: max(var(--mobile-space-md), var(--safe-area-inset-left));
  padding-right: max(var(--mobile-space-md), var(--safe-area-inset-right));
  padding-bottom: max(var(--mobile-space-lg), var(--safe-area-inset-bottom));
}
```

### Performance Optimizations

On mobile devices:
- Simplified animations (fade instead of complex transforms)
- Reduced gradient usage
- Disabled hover effects (uses active states instead)
- Lazy loading images by default

### Input Handling

#### Prevent iOS Zoom

Input fields are automatically sized to prevent zoom:

```css
input[type="text"],
input[type="email"],
select,
textarea {
  font-size: 16px; /* Prevents iOS zoom */
}
```

#### Better Keyboard Handling

The layout automatically adjusts when the keyboard appears.

## Touch-Friendly Design

### Minimum Touch Targets

All interactive elements meet the 48x48px minimum touch target:

```css
@media (hover: none) and (pointer: coarse) {
  button,
  input[type="button"],
  a.primary-action,
  a.secondary-action {
    min-height: 3rem; /* 48px */
    min-width: 3rem;
  }
}
```

### Increased Spacing

Touch devices get larger spacing between interactive elements:

```css
.onboarding-actions {
  gap: var(--mobile-space-lg);
}
```

### Active States

Touch devices use active states instead of hover:

```css
.primary-action:active:not(:disabled) {
  transform: scale(0.98);
  opacity: 0.9;
}
```

## Best Practices

### 1. Use Helper Methods in Layouts

```erb
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <%= rails_onboarding_viewport_meta %>
  <%= rails_onboarding_theme_color %>
  <%= rails_onboarding_ios_meta %>
  <%= stylesheet_link_tag "application" %>
  <%= javascript_importmap_tags %>
</head>
<body class="<%= responsive_device_classes %>">
  <%= yield %>
</body>
</html>
```

### 2. Design Mobile-First

Start with mobile layouts and enhance for larger screens:

```css
/* Mobile first (base styles) */
.container {
  padding: 1rem;
}

/* Enhanced for tablets and up */
@media (min-width: 768px) {
  .container {
    padding: 2rem;
  }
}
```

### 3. Test on Real Devices

While browser dev tools are helpful, always test on actual devices:
- iPhone (various sizes)
- Android phones
- iPads
- Android tablets
- Devices with notches

### 4. Consider Touch vs. Mouse

Use the `(hover: none) and (pointer: coarse)` media query for touch-specific styles:

```css
@media (hover: none) and (pointer: coarse) {
  /* Touch-specific styles */
}
```

### 5. Handle Landscape Orientation

Mobile landscape often needs special handling:

```css
@media screen and (max-width: 767px) and (orientation: landscape) {
  /* Landscape-specific adjustments */
}
```

### 6. Optimize Images

Use responsive images with appropriate sizes:

```erb
<%= responsive_image('hero.jpg',
  alt: 'Hero image',
  srcset: {
    '1x' => 'hero-mobile.jpg',
    '2x' => 'hero-mobile@2x.jpg'
  },
  sizes: '(max-width: 768px) 100vw, (max-width: 1200px) 50vw, 800px'
) %>
```

### 7. Accessibility

Ensure mobile accessibility:
- Large enough tap targets (48x48px minimum)
- Good color contrast
- Keyboard navigation support
- Screen reader support

### 8. Performance

Optimize for mobile performance:
- Minimize animations
- Use lazy loading
- Optimize images
- Reduce JavaScript execution

## Foldable Device Support

The gem includes experimental support for foldable devices:

```css
@media (horizontal-viewport-segments: 2) {
  .onboarding-content {
    display: grid;
    grid-template-columns: env(viewport-segment-width 0 0) env(viewport-segment-width 1 0);
    gap: env(viewport-segment-right 0 0);
  }
}
```

## Dark Mode

The responsive styles work seamlessly with dark mode:

```css
@media screen and (max-width: 767px) and (prefers-color-scheme: dark) {
  .onboarding-container {
    background: #000000;
  }
}
```

## Reduced Motion

Respects user's motion preferences:

```css
@media (prefers-reduced-motion: reduce) {
  * {
    animation-duration: 0.01ms !important;
    transition-duration: 0.01ms !important;
  }
}
```

## High Contrast Mode

Enhanced contrast for users who need it:

```css
@media (prefers-contrast: high) {
  .primary-action,
  .secondary-action {
    border-width: 3px;
    font-weight: 700;
  }
}
```

## Testing Checklist

- [ ] iPhone SE (small phone)
- [ ] iPhone 14 Pro (standard phone with notch)
- [ ] iPhone 14 Pro Max (large phone)
- [ ] iPad (tablet portrait)
- [ ] iPad (tablet landscape)
- [ ] Android phone (various sizes)
- [ ] Android tablet
- [ ] Desktop (1920x1080)
- [ ] Portrait orientation
- [ ] Landscape orientation
- [ ] Dark mode
- [ ] Light mode
- [ ] High contrast mode
- [ ] Reduced motion
- [ ] Touch interactions
- [ ] Keyboard navigation
- [ ] Screen reader

## Troubleshooting

### Issue: Content too small on mobile

Make sure you have the viewport meta tag:

```erb
<%= rails_onboarding_viewport_meta %>
```

### Issue: Layout breaking on small screens

Check that you're using the responsive utility classes:

```erb
<div class="mobile-stack mobile-full">
  <!-- Content -->
</div>
```

### Issue: Buttons too small to tap

Ensure touch-friendly attributes are applied:

```erb
<button <%= touch_friendly_attrs %>>
  Click me
</button>
```

### Issue: Images not scaling

Use the responsive image helper:

```erb
<%= responsive_image(image_path, srcset: {...}) %>
```

## Additional Resources

- [README.md](../README.md) - Project overview
- [MILESTONES_GUIDE.md](MILESTONES_GUIDE.md) - Milestone system
- [ANALYTICS_GUIDE.md](ANALYTICS_GUIDE.md) - Analytics and metrics
- [MDN: Responsive Design](https://developer.mozilla.org/en-US/docs/Learn/CSS/CSS_layout/Responsive_Design)
- [Web.dev: Responsive Design](https://web.dev/responsive-web-design-basics/)
- [Apple: Designing for iOS](https://developer.apple.com/design/human-interface-guidelines/ios/overview/themes/)
