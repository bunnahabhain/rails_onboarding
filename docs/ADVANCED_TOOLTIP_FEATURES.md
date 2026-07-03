# Advanced Tooltip System Features

This document outlines the advanced tooltip features implemented in the Rails Onboarding gem.

## Overview

The tooltip system has been significantly enhanced with smart positioning, contextual behavior, advanced animations, and progressive disclosure capabilities.

## Key Features

### 1. Smart Positioning with Collision Detection

**Location**: `app/assets/javascripts/rails_onboarding/tooltip_controller.js`

- **Intelligent Position Selection**: Automatically finds the best position (top/bottom/left/right) based on viewport space
- **Collision Avoidance**: Detects and avoids overlapping with fixed/sticky elements like navigation bars
- **Dynamic Adjustment**: Adjusts arrow positioning when tooltips are repositioned for viewport constraints
- **Scoring System**: Uses a scoring algorithm to select optimal placement

**Usage**:
```html
<div data-controller="rails-onboarding--tooltip"
     data-rails-onboarding--tooltip-position-value="top">
```

### 2. Context-Aware Triggers

**Multiple Trigger Types**:
- `hover` (default) - Show on mouse hover/focus
- `click` - Show on click, hide on outside click
- `focus` - Show only on focus events
- `idle` - Show after period of inactivity
- `scroll` - Show when element becomes visible
- `contextual` - Show based on user behavior patterns

**Usage**:
```html
<div data-controller="rails-onboarding--tooltip"
     data-rails-onboarding--tooltip-trigger-value="contextual"
     data-rails-onboarding--tooltip-idle-time-value="3000"
     data-rails-onboarding--tooltip-priority-value="8">
```

### 3. User Behavior Tracking

**Behavioral Data Collected**:
- User interaction patterns
- Time spent on pages
- Struggling areas (repeated interactions without progress)
- Tooltip dismissal patterns
- Daily usage limits

**Smart Display Logic**:
- Respects user attention (doesn't interrupt active interactions)
- Limits concurrent tooltips to avoid overwhelm
- Adapts based on user experience level
- Implements daily show limits per tooltip

### 4. Enhanced Animations

**Animation Types**:
- `fade` - Smooth opacity transition
- `slide` - Direction-aware sliding motion
- `bounce` - Playful bounce effect with easing
- `scale` - Scale animation from optimal origin point
- `none` - Instant display

**Usage**:
```html
<div data-controller="rails-onboarding--tooltip"
     data-rails-onboarding--tooltip-animation-value="bounce"
     data-rails-onboarding--tooltip-duration-value="300">
```

### 5. Progressive Disclosure System

**Location**: `app/assets/javascripts/rails_onboarding/tooltip_scheduler_controller.js`

A complete scheduling system for managing sequences of tooltips:

**Features**:
- **Sequential Display**: Show tooltips in predefined order
- **Priority-Based**: Display high-priority tooltips first
- **Adaptive Sequencing**: Adjust order based on user behavior
- **Pause/Resume**: Intelligent pausing during user interaction
- **Concurrent Limits**: Control how many tooltips show simultaneously

**Configuration Example**:
```html
<div data-controller="rails-onboarding--tooltip-scheduler"
     data-rails-onboarding--tooltip-scheduler-sequence-value='[
       {
         "id": "welcome",
         "selector": ".welcome-button",
         "content": "<h4>Welcome!</h4><p>Let us show you around.</p>",
         "priority": 9,
         "duration": 5000,
         "animation": "bounce"
       },
       {
         "id": "create_first_item",
         "selector": ".create-button", 
         "content": "Create your first item here",
         "priority": 8,
         "conditions": {"element_visible": ".empty-state"}
       }
     ]'
     data-rails-onboarding--tooltip-scheduler-auto-start-value="true">
</div>
```

## Configuration Options

### Tooltip Controller Values

| Value | Type | Default | Description |
|-------|------|---------|-------------|
| `position` | String | "top" | Preferred position (top/bottom/left/right) |
| `trigger` | String | "hover" | How tooltip is triggered |
| `delay` | Number | 0 | Delay before showing (ms) |
| `priority` | Number | 5 | Priority level (1-10) |
| `maxDaily` | Number | 3 | Max shows per day |
| `animation` | String | "fade" | Animation type |
| `duration` | Number | 200 | Animation duration (ms) |
| `contextual` | Boolean | false | Enable contextual behavior |
| `idleTime` | Number | 3000 | Idle time for idle trigger (ms) |
| `scrollThreshold` | Number | 0.5 | Visibility ratio for scroll trigger |

### Scheduler Values

| Value | Type | Default | Description |
|-------|------|---------|-------------|
| `sequence` | String | "[]" | JSON array of tooltip configs |
| `autoStart` | Boolean | false | Start sequence automatically |
| `delay` | Number | 1000 | Delay between tooltips (ms) |
| `maxConcurrent` | Number | 1 | Max concurrent tooltips |
| `priority` | String | "sequential" | Sequencing strategy |
| `pauseOnHover` | Boolean | true | Pause when hovering tooltips |
| `pauseOnInteraction` | Boolean | true | Pause during user interaction |

## Data Storage

The system uses localStorage to persist:

**`rails_onboarding_seen_tooltips`**: Permanently dismissed tooltips
```json
{
  "feature_name": "2023-12-01T10:30:00.000Z"
}
```

**`rails_onboarding_behavior`**: User behavior analytics
```json
{
  "2023-12-01": {
    "tooltipsShown": {"welcome": 2, "help": 1},
    "interactions": 45,
    "strugglingAreas": ["checkout"],
    "timeOnPage": 180000,
    "pageViews": 12
  }
}
```

## API Methods

### Tooltip Controller
- `show()` - Force show tooltip
- `hide()` - Force hide tooltip
- `toggle()` - Toggle visibility
- `dismiss()` - Permanently dismiss tooltip
- `updateContent(newContent)` - Update tooltip content

### Scheduler Controller
- `start()` - Start the sequence
- `pause()` - Pause the sequence
- `resume()` - Resume after pause
- `stop()` - Stop and reset
- `skipCurrent()` - Skip current tooltip
- `skipAll()` - Skip entire sequence
- `showTooltipById(id)` - Show specific tooltip

## Events

### Tooltip Events
- `rails-onboarding--tooltip:show` - Tooltip shown
- `rails-onboarding--tooltip:hide` - Tooltip hidden
- `rails-onboarding--tooltip:dismiss` - Tooltip dismissed

### Scheduler Events
- `rails-onboarding--tooltip-scheduler:complete` - Sequence completed
- `rails-onboarding--tooltip-scheduler:paused` - Sequence paused
- `rails-onboarding--tooltip-scheduler:resumed` - Sequence resumed

## Best Practices

1. **Priority Management**: Use priority 8-10 for critical onboarding steps, 5-7 for helpful hints, 1-4 for nice-to-know information

2. **Contextual Timing**: Enable contextual behavior for tooltips that should adapt to user patterns

3. **Animation Choice**: Use `bounce` for important notifications, `fade` for subtle hints, `slide` for directional guidance

4. **Sequence Design**: Keep sequences short (3-5 tooltips max) and focused on specific workflows

5. **Daily Limits**: Set appropriate daily limits to avoid tooltip fatigue

6. **Responsive Design**: The system automatically adapts to mobile with overlay modes

## Browser Support

- Modern browsers with ES6+ support
- Stimulus 3.0+ required
- Works with Turbo and traditional page loads
- Graceful degradation for older browsers