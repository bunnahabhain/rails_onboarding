# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.4] - 2026-07-13

### Fixed

- Fixed `db:migrate` failing on MySQL/MariaDB with "BLOB, TEXT, GEOMETRY or
  JSON column 'milestones_achieved' can't have a default value".
  `add_milestone_tracking_to_users` set a literal `default: "[]"` on a
  `:text` column, which MySQL/MariaDB reject outright. Dropped the DB-level
  default - `Onboardable` already treats a nil `milestones_achieved` as an
  empty array in Ruby, so nothing else needed to change. Added a test that
  statically scans all migration templates for this class of bug.

## [0.1.3] - 2026-07-13

### Fixed

- The install generator now actually wires up the `add_milestone_tracking_to_users`,
  `add_onboarding_indexes`, and `add_robustness_fields_to_users` migration
  templates. They existed in the gem since the milestones system was added
  but were never invoked, so `rails generate rails_onboarding:install`
  silently skipped them - the generator now creates six migrations instead
  of three.
- Fixed a duplicate index name in `add_onboarding_indexes` that collided
  with an index already created by `add_analytics_to_rails_onboarding` for
  a different column set, which made `db:migrate` fail with "index already
  exists" on every fresh install. Added a regression test that runs the
  generated migrations against a real database, up and down.
- Fixed the engine's Importmap integration: it appended the engine's pins
  to `config.importmap.paths` inside `config.after_initialize`, but
  importmap-rails had already drawn that array into the live map earlier
  in boot, so the append was a no-op and none of the gem's Stimulus
  controllers were ever registered. Verified all 15 controller pins now
  register correctly.
- Corrected the "protect your controllers" instructions in both the
  generated README and the main README: they referenced
  `before_action :require_onboarding` and `skip_onboarding_requirement`,
  neither of which exist. The real API is `needs_onboarding?` (a
  predicate you call from your own `before_action`) and
  `skip_onboarding_check`.
- Replaced the generated README's Sprockets-only CSS include snippet,
  which Propshaft (Rails 8's default asset pipeline) silently ignores,
  with `stylesheet_link_tag`/`javascript_include_tag`, verified against a
  fresh Propshaft app.
- Removed the generated README's reference to `ESBUILD_SETUP.md`, which
  the gemspec doesn't ship to installed apps; it now links to the GitHub
  repository instead.
- Moved `ESBUILD_SETUP.md` to the project root (it's installation
  documentation and belongs next to `README.md`) and updated it to list
  all 14 Stimulus controllers the gem ships, not just the original 4.

## [0.1.2] - 2026-07-10

### Fixed

- Removed leftover references to the original host app ("LOLOL") from the
  generated `config/initializers/rails_onboarding.rb`, the onboarding step
  navigation help text, and the ESBuild setup guide. The generated
  initializer now uses generic defaults (e.g. `:root_path` instead of an
  app-specific `:dashboard_path`) and includes guidance comments explaining
  each configuration option.

## [0.1.1] - 2026-07-10

### Fixed

- Install generator's `next_migration_number` no longer generates duplicate
  timestamps when creating multiple migrations in the same second, which
  caused `ActiveRecord::DuplicateMigrationVersionError` on `db:migrate`.

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

[Unreleased]: https://github.com/bunnahabhain/rails_onboarding/compare/v0.1.4...HEAD
[0.1.4]: https://github.com/bunnahabhain/rails_onboarding/compare/v0.1.3...v0.1.4
[0.1.3]: https://github.com/bunnahabhain/rails_onboarding/compare/v0.1.2...v0.1.3
[0.1.2]: https://github.com/bunnahabhain/rails_onboarding/compare/v0.1.1...v0.1.2
[0.1.1]: https://github.com/bunnahabhain/rails_onboarding/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/bunnahabhain/rails_onboarding/releases/tag/v0.1.0
