# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2025-11-18

### Added

#### Core Features
- Rails engine for customizable onboarding flows
- Configuration system for defining onboarding steps, tooltips, and redirects
- Onboardable concern for User models with progress tracking
- Controller helpers for enforcing onboarding requirements
- Installation generator with migration templates
- Database migration support for onboarding fields

#### Views & UI
- Complete view templates for all onboarding steps (welcome, profile, first_action, explore)
- Progress indicator and step navigation partials
- Responsive design with comprehensive mobile support
- Dark mode support
- Accessibility features (ARIA labels, keyboard navigation, screen reader support)

#### JavaScript/Stimulus
- Onboarding controller for step navigation
- Progress tracker controller
- Advanced tooltip system with smart positioning and collision detection
- Tooltip scheduler for progressive disclosure
- Tour controller with spotlight effects and guided walkthroughs
- Navigation controller with Turbo support

#### CSS & Styling
- Complete stylesheet suite (application, tooltips, utilities, accessibility)
- Tour styles with modal/overlay support
- Responsive mobile styles with advanced features
- Animation and transition effects

#### Advanced Features
- **Milestone System**: Complete achievement tracking with points, celebrations, and customizable triggers
- **Analytics & Metrics**: Comprehensive event tracking, funnel analysis, and user journey metrics
- **Smart Tooltips**: Context-aware tooltips based on user behavior
- **A/B Testing**: Test different onboarding flows with variant assignment and conversion tracking
- **Personalization**: Adaptive onboarding flows based on user type/role
- **Progressive Disclosure**: Feature revelation with multiple condition types
- **Interactive Tours**: Guided walkthroughs with step-by-step navigation
- **Onboarding Templates**: 5 pre-built flows (SaaS, E-commerce, Marketplace, Community, Education)

#### Robustness
- Error recovery with retry logic and error tracking
- Session management with browser refresh/navigation support
- Skip logic with conditional step skipping
- Rollback support for restarting or going back in onboarding
- Multi-tenant support with configuration inheritance
- Internationalization (i18n) support for multiple languages (en, es, fr)

#### Integration & Compatibility
- Devise integration for authentication
- Full Turbo/Stimulus compatibility for Rails 8+
- Background job support for emails and notifications
- Complete integration examples with tests

#### Admin Interface
- Analytics dashboard with visual reporting
- Flow editor for creating onboarding flows
- User management to track onboarding progress
- A/B test management interface

#### Performance & Scalability
- Caching for onboarding state and configuration
- Database optimization with proper indexing
- Lazy loading for onboarding components
- CDN support for assets

#### Documentation
- Comprehensive README with examples
- MILESTONES_GUIDE.md for milestone system implementation
- ANALYTICS_GUIDE.md for metrics and tracking
- RESPONSIVE_DESIGN.md for mobile optimization
- PERFORMANCE_GUIDE.md for scalability
- ADVANCED_FEATURES.md covering all advanced features
- API documentation for all public methods
- Migration guide for version upgrades
- Complete code examples for all integrations

#### Testing
- Comprehensive minitest test suite
- Integration tests for core components
- Example applications for different use cases

### Dependencies
- Rails >= 8.0.0
- Ruby >= 3.4.9
- csv (runtime; no longer a Ruby default gem as of Ruby 3.4)
- Optional: stimulus-rails >= 1.0.0
- Optional: turbo-rails >= 1.0.0

[Unreleased]: https://github.com/bunnahabhain/rails_onboarding/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/bunnahabhain/rails_onboarding/releases/tag/v0.1.0
