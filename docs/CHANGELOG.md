# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.3.3] - 2026-07-27

Patch: additive and opt-in. Leave the new setting unset and nothing changes.

### Added

- **`config.admin_user_search`**, an override for the admin User Management
  search box. The built-in search is SQL, so it can't see through an encrypted
  email column — 0.3.2 made that failure honest (exact match under
  deterministic encryption, no email clause under non-deterministic) but
  partial matching over ciphertext isn't reachable from SQL at any price. Only
  the host app knows what it's willing to trade for it, so it can now supply
  the strategy: the lambda receives the scope already narrowed by the status
  and step filters plus the raw term, and returns a relation, so sorting and
  pagination still apply. Left unset, the built-in behavior is unchanged.

## [0.3.2] - 2026-07-27

Patch: no new dependencies and no API changes. Admin user search was
unusable on MySQL and actively misleading on any app with an encrypted
email column.

### Fixed

- **Admin User Management search raised a SQL syntax error on MySQL.** The
  search built `CAST(id AS TEXT)`, which is valid on PostgreSQL and SQLite but
  a syntax error on MySQL — it spells that type `CHAR`. Every search on a
  MySQL-backed app 500'd and redirected to the dashboard. The cast target now
  follows the adapter (`CHAR` on mysql2/trilogy, `TEXT` elsewhere; PostgreSQL
  can't simply use `CHAR`, which it reads as `character(1)` and would truncate
  the id to its first digit). The dummy app runs on SQLite, which accepts
  either spelling, so the test suite never saw it — the adapter mapping is now
  unit-tested directly for all three.
- **Search matched against ciphertext when the host app encrypts its email
  column.** With `encrypts :email`, the column holds ciphertext, so a
  substring `LIKE` can never match the plaintext an admin types — but it does
  match ciphertext that happens to contain the term, which surfaced as
  confident nonsense (in one real app, searching `4` returned 26 of 39 users).
  Search is now encryption-aware: deterministic encryption falls back to exact
  equality, which it supports; non-deterministic encryption drops the email
  clause entirely, since there is nothing searchable there. Searching by ID is
  unaffected either way.
- **Non-numeric searches no longer cast the id column at all.** An id renders
  as digits, so a term containing anything else can never be a substring of
  one. The clause was pure work — a full-table cast scan on every email
  search — and dropping it is exactly semantics-preserving.

## [0.3.1] - 2026-07-27

Patch: no new dependencies and no API changes, but it unblocks the admin for
any application that installed the gem on top of an existing `users` table.

### Added

- **`rails_onboarding:backfill_existing_users` rake task**, for applications
  that installed the gem on top of a populated `users` table. Those users have
  empty onboarding columns, so the admin reports every one of them as "Not
  Started" and `onboarding_required_for = :all_users` pushes them into a flow
  they don't need. The task marks them complete in batched `update_all`
  statements, dating `onboarding_completed_at` from each user's own `created_at`
  so completion-over-time charts don't spike on backfill day. Only users who
  never engaged are touched — not completed, not skipped, on no current step —
  so anyone mid-flow is left alone and the task is safe to re-run on a live app.
  Supports `BEFORE=`, `DRY_RUN=true`, and `BATCH_SIZE=`. Deliberately records no
  analytics events: these users never went through onboarding, and synthesizing
  events for them would put fiction into the funnel metrics. The underlying
  `RailsOnboarding::Backfill` module is public, and its `pending_scope` lets you
  inspect or further narrow the affected set from a console.

### Fixed

- **Admin user detail page 500'd on users with a `NULL` `created_at` or
  `updated_at`** with `undefined method 'strftime' for nil`, redirecting the
  admin back to the dashboard with a flash. Such rows are common in
  applications where the `users` table predates its timestamp columns or was
  populated by an import. The rest of the admin already handled this — the
  index renders `N/A`, the CSV export uses `&.iso8601` — but the show view
  called `strftime` unguarded. It now renders `N/A` to match. The activity
  timeline also drops entries with no timestamp rather than raising in its
  sort.
- **`needs_onboarding?` raised on a `NULL` `created_at`** under the
  `:new_users` strategy, which compared it against `1.hour.ago` — so a single
  legacy row broke every request that user made. An unknown signup time is now
  treated as "not recent", putting those users on the existing-user path.

## [0.3.0] - 2026-07-27

Minor rather than patch: pagy becomes a runtime dependency of the engine, so
this version pulls a new gem into every host application.

### Added

- **Pagination on the admin user list, backed by [pagy](https://github.com/ddnexus/pagy)**
  (now a runtime dependency, `~> 43.6`). The users index renders a page series
  nav plus a "Displaying users 1-25 of 38 in total" summary, styled to the
  existing admin theme. Page links carry the active search, status, and sort
  parameters, so paging no longer drops a filter. The pre-existing `?per_page=`
  parameter still works and is now capped at `MAX_PER_PAGE` (100) so a crafted
  URL can't request the whole table in one query.
- **Pagination on the admin Flows and A/B Tests screens.** All three index
  screens now go through one `Admin::BaseController#paginate` helper and share
  the `page`/`per_page` parameters and the `DEFAULT_PER_PAGE` / `MAX_PER_PAGE`
  constants. On Flows, the "Active Flow" banner is looked up independently of the
  page so it still shows when the active flow is on another page. A/B tests are
  config-defined rather than stored, so that list rarely reaches a second page;
  because the screen renders Active and Inactive sections off one collection, the
  combined list is paginated (active first) and the current page split back into
  the two sections, with the stat cards continuing to report whole-collection
  totals.

### Fixed

- **Admin User Management showed only the first 25 users with no way to reach
  the rest.** The controller applied a `limit`/`offset` by hand, but the view's
  pagination block was guarded on `@users.respond_to?(:total_pages)` - a
  Kaminari-ism left over from before any pagination gem was installed. A plain
  `ActiveRecord::Relation` never responds to `total_pages`, so the guard was
  always false and the page controls were silently skipped. Every user past the
  first page was unreachable through the UI.
- **The "Export CSV" button on admin User Management did nothing.** It was
  rendered as `link_to "Export CSV", "#"` - a placeholder that had never been
  wired up. There was no `export` route, no controller action, and no CSV
  generation behind it, so clicking it just jumped to the top of the page. Added
  the route (`GET /admin/users/export`), the action, and the export itself. The
  button now carries the filters in effect (`search`, `status`, `step`, `sort`,
  `direction`) through to the export, so the file matches the table on screen;
  `page`/`per_page` are ignored, since the export covers every matching user
  rather than the page being viewed. Columns are ID, Email (omitted when the user
  model has no `email` column), Status, Current Step, Progress (%), Completed At,
  Created At, and Last Activity, with timestamps in ISO 8601. Unlike the A/B test
  export this action doesn't use `respond_to`: CSV is its only representation,
  and a bare `/admin/users/export` would otherwise raise `UnknownFormat` and get
  turned into a dashboard redirect by the admin error handler.
- **CI had not run successfully in months, on any branch.** Three independent
  breaks were stacked: `Gemfile.lock` listed only `arm64-darwin` while the
  workflow runs on `x86_64-linux`, so bundler refused to install; both jobs
  pinned `ruby-3.4.4`, below the gemspec's own `required_ruby_version` floor of
  `>= 3.4.9`, while `.ruby-version` said `4.0.5`; and the test step ran
  `bin/rails db:test:prepare test`, which this engine's `bin/rails` cannot
  parse - it loads `rails/engine/commands`, whose router hands the whole argv to
  rake once the first argument matches a task, leaving no `test` task to land on.
  Each break only became visible once the one before it was fixed.
- **No merge to `master` ever produced a CI build.** The workflow triggered
  post-merge runs on `push: branches: [main]`, naming a branch this repository
  has never had. The gemspec's `changelog_uri` was wrong the same way and then
  some, pointing at `/blob/main/CHANGELOG.md` when the file lives at
  `docs/CHANGELOG.md` - a 404 in either half, and the "Changelog" link on the
  eventual RubyGems listing.

### Changed

- **Rubocop is clean across the project.** With CI running again for the first
  time in months, the lint job surfaced a backlog of 840 offences that had never
  been enforced. 773 were fixed by `bin/rubocop -a` (safe autocorrect only,
  no `-A`), overwhelmingly `Style/StringLiterals` and
  `Layout/SpaceInsideArrayLiteralBrackets`. The remaining 16 were false
  positives: generator templates under `lib/generators/**/templates/` are ERB,
  not Ruby, and are now excluded along with `test/dummy/db/schema.rb` and
  `coverage/`.

## [0.2.8] - 2026-07-26

### Fixed

- **Activating a saved flow silently broke path-based steps.** A flow
  persisted by the admin Flow Editor is stored as JSON, and JSON can't hold a
  Proc, so any `path:` or `complete_if:` option was dropped when the flow was
  written. Once such a flow was active (`Flow.seed_default!` marks the
  seeded-from-config flow active), `Configuration#steps` returned the
  proc-less flow steps: a path-based step lost its `:path` and rendered the
  "This step is not yet fully configured" fallback instead of redirecting to
  its host-app page, and lost its `:complete_if` so it could never
  auto-advance. `Configuration#steps` now re-hydrates the code-only,
  Proc-valued options from the statically-configured step of the same name
  when an active flow is used - the flow still owns presentation and ordering,
  but behavior that can only live in code is restored. Added an end-to-end
  regression test that seeds an active flow from a config whose profile step
  has a Proc `path`/`complete_if` and asserts the step still redirects and
  auto-advances.

## [0.2.7] - 2026-07-26

### Fixed

- **The onboarding layout never loaded any JavaScript.**
  `application.html.erb` (used for the welcome/step/onboarding pages)
  only linked stylesheets, so none of the engine's own Stimulus
  controllers (progress bar, milestone celebration, tooltips, tour,
  navigation) ever had a chance to run there - `admin.html.erb` already
  included this same tag. Added the matching
  `javascript_include_tag "rails_onboarding/application"`; verified in a
  live browser session that it loads without errors. Note: this alone
  doesn't make those controllers register - nothing imports/registers
  them for the engine's own pages yet, that's left to the host app's
  importmap/Stimulus manifest per the existing docs.

## [0.2.6] - 2026-07-26

### Changed

- **Removed inline styles across the admin/onboarding views and their
  Stimulus controllers**, following on from the 0.2.5 funnel bar fix.
  Progress-fill bars (admin user list/detail, onboarding banner, progress
  indicator) now drive their width via CSS custom properties instead of
  literal `style="width:...%"`; static one-off inline styles (the flows
  preview alert's margin, the milestone celebration's `display: none`, the
  step debug panel's styling) moved into real CSS classes.
- `progress_controller.js` sets `--onboarding-progress-width` via
  `style.setProperty` instead of `style.width`, drops the now-redundant
  manual transition/rAF dance (CSS already transitions `width` on
  `.progress-fill`), toggles a `.step-marker-pulse` class instead of
  `style.animation`, and moves the step tooltip's static styling into a
  real `.step-tooltip` CSS rule - previously dead code, since only the
  class name (with no matching CSS) was ever set on the element.
- `milestone_celebration_controller.js` toggles `.is-hidden`/`.is-fading`
  classes instead of writing `display`/`opacity`/`transition` directly.
- Left inline styles where they're actually necessary: mailer templates
  (most email clients strip `<style>` blocks) and per-instance random
  confetti/tooltip positioning that can't be expressed as a CSS class.

## [0.2.5] - 2026-07-26

### Added

- **`onboarding_step_started` analytics event** for a true entry funnel. The
  onboarding controller records this first-class event on a user's first entry
  to each step (refreshes and back-navigation don't duplicate it), replacing
  the ad-hoc `onboarding_step_view` custom event, whose `step` key didn't match
  the `step_name` convention. The admin dashboard funnel counts distinct users
  who *reached* each step, and the flows report's "started" vs "completed"
  columns are now genuinely distinct instead of showing identical completion
  counts.

### Fixed

- **Onboarding funnel bar hid its own label at 0%.** The step title/user-count
  label was rendered *inside* the percentage-width `.admin-funnel-bar`, so a
  step with `percentage: 0` (e.g. a fresh install where `@onboarding_started`
  is still zero) collapsed the label along with the bar, truncating the
  display. The label now renders in its own full-width `.admin-funnel-label`
  above a fixed-width `.admin-funnel-track`, so it stays visible regardless of
  the fill percentage. Also replaced the funnel bar's and daily-completions
  chart's literal inline `style="width: ...%"` / `style="height: ...%"`
  declarations with CSS custom properties (`--admin-funnel-width`,
  `--admin-bar-height`) consumed by `admin.css`, keeping all actual styling
  out of the view.

- **Admin dashboard crashed when there were no onboarding completions in the
  last 7 days.** The Daily Completions chart divided each bar by `max_count`,
  which was 0 whenever every day's count was 0 (`.max || 1` doesn't catch a
  `0`), so `count / 0` produced `NaN` and `Float#round` raised
  `FloatDomainError: NaN`. `BaseController#handle_admin_error` swallowed it
  into a redirect back to the dashboard, making the page unreachable for
  essentially every fresh install. The divisor is now clamped to at least 1.
  (Previously undetected because every dashboard controller test was skipped;
  the dashboard now has real render coverage.)

- **Admin analytics crashed against MySQL/SQLite.** The admin dashboard,
  flows, and user-detail controllers queried a non-existent `metadata`
  column (with a `step` key) using the SQL JSON operator `->>`. Analytics
  payloads are actually stored in the `properties` column — a
  JSON-serialized text column — keyed by `step_name`/`tooltip_feature`, and
  `->>` only works on a native `json`/`jsonb` column. On MySQL the dashboard
  logged `Unknown column 'metadata'` (rescued into a degraded "Error loading
  analytics"), the step funnel and flow stats silently reported zero, and a
  user's detail page raised `NoMethodError: undefined method 'metadata'`.
  These now read `event.properties` with the correct keys and the real
  built-in event types (`onboarding_step_completed`), filtering in Ruby so
  the reporting is portable across PostgreSQL, MySQL, and SQLite.
- **A/B test results crashed on non-`jsonb` databases.** `AbTestsController`
  filtered users with `ab_test_assignments->>'test' = ?` and the
  PostgreSQL-only `ab_test_assignments ? key` operator. Because
  `ab_test_assignments` is a serialized text column except when it is a
  native `jsonb` column, variant counts, conversion/skip rates, completion
  times, and the per-variant funnel now compute in Ruby via
  `AbTestable#ab_test_variant`, matching `Admin::AbTestsController`.

## [0.2.0] - 2026-07-19

### Changed

- **Breaking (URLs only):** the onboarding flow is now anchored at the
  engine's mount point (`resource :onboarding, path: ""`), so mounting at
  `/onboarding` yields `/onboarding` instead of the doubled
  `/onboarding/onboarding` (and `/onboarding/next`, `/onboarding/skip`,
  etc.). Route helpers (`onboarding_path`, `next_onboarding_path`, ...)
  are unchanged, so helper-based code needs no migration - only
  hardcoded URLs and bookmarks are affected. Existing installs that want
  the old URLs back can change their mount point to
  `mount RailsOnboarding::Engine => "/onboarding/onboarding"`.
- `needs_onboarding?`'s onboarding-page check and the onboarding banner's
  self-hide check are now segment-aware: a host page like
  `/onboarding_help` no longer counts as being "on" an engine mounted at
  `/onboarding` just because it shares the prefix.

### Fixed

- The onboarding banner partial leaked part of its own header comment
  ("Self-contained on purpose: ...") into the page: the comment embedded
  an example ERB tag, and an ERB comment terminates at the first `%>`
  sequence it contains, cutting the comment short and rendering the rest
  as text. The example no longer uses ERB delimiters, and a regression
  test asserts no comment text reaches the page.

## [0.1.9] - 2026-07-17

### Added

- Steps can now live on real host-app pages instead of gem-rendered
  templates, eliminating the need to duplicate existing views and
  controller logic into `app/views/rails_onboarding/onboarding/`:
  - New `path:` step option (Symbol/String route helper or Proc). When the
    current step has one, `/onboarding` redirects to that page and the host
    app's own controller and view do the work. If the path can't be
    resolved, the gem logs an error and falls back to rendering a template
    rather than stranding the user.
  - New `complete_if:` step option - a predicate called with the user on
    each visit to `/onboarding`. Every consecutive satisfied step is
    completed automatically (milestones and analytics included), so host
    controllers don't need to know onboarding exists. A raising predicate
    is logged and treated as not-yet-complete instead of erroring.
  - New `advance_onboarding!(step_name)` helper in
    `RailsOnboarding::ControllerHelpers` for explicit completion from a
    host controller action; deliberately a no-op unless the named step is
    the user's current step.
  - New `rails_onboarding/shared/onboarding_banner` partial: self-guarding
    onboarding chrome (progress, current step, continue/skip) that host
    layouts can render unconditionally on their own pages.
  - `needs_onboarding?` now returns false on the current step's own page,
    so a host-app `redirect_to onboarding_path if needs_onboarding?` guard
    can't ping-pong with the step-page redirect.
  - The configuration validator accepts the new options and warns about
    `path:` steps that define neither `complete_if:` nor `skippable: true`,
    since those can only advance via an explicit `advance_onboarding!`
    call.

## [0.1.8] - 2026-07-16

### Fixed

- `getFeatureTooltipContent()` in `tooltip_controller.js` had a hardcoded
  dictionary of 5 feature names left over from the gem's original host
  app, silently ignored `config.feature_tooltips` entirely, and showed a
  generic message for any other feature. Replaced it with a console
  warning pointing at the `data-tooltip-target="content"` /
  `data-tooltip-text` path, since static JS can't read server-side Ruby
  config.
- `markTooltipSeen()` POSTed to a hardcoded
  `/rails_onboarding/tooltips/mark_shown` URL with the wrong engine mount
  prefix and the wrong route shape, so dismissing a tooltip never
  actually persisted server-side. Added a `dismissUrl` Stimulus value so
  the host app supplies the real `dismiss_tooltip_path`, and switched
  from `Rails.ajax` (requires rails-ujs, which many Turbo-only Rails 7/8
  apps don't load) to `fetch`.
- Updated README's "Working with Tooltips" section, which referenced a
  `tooltip_tag` helper that doesn't exist anywhere in the gem.

## [0.1.7] - 2026-07-16

### Fixed

- The post-install README never told users they need a view per
  configured step - the gem only ships `welcome.html.erb`, so the other
  default steps (`profile`, `first_action`, `explore`) silently render a
  generic "not yet configured" placeholder until real views are added.
  Added a step covering this, with an example.
- Fixed `next_step_onboarding_path`, which doesn't exist as a route, to
  the real `next_onboarding_path` helper, in `README.md`, the
  post-install README, and `docs/MIGRATION_GUIDE.md`'s upgrade test
  example.

## [0.1.6] - 2026-07-14

### Fixed

- Fixed the post-install README's "visit /onboarding to test your setup"
  instruction - the engine is mounted at `/onboarding` and the onboarding
  flow is a singular `:show` resource under that, so the real path is
  `/onboarding/onboarding`.

## [0.1.5] - 2026-07-14

### Fixed

- Fixed CSS silently missing on Propshaft (Rails 8's default asset
  pipeline, including with cssbundling-rails): `application.css` bundles
  the gem's other stylesheets (tooltips, tour, milestones, mobile, flash
  messages, utilities, accessibility, progressive disclosure) via
  Sprockets `require` directives, which Propshaft doesn't process. Every
  doc and the engine's own onboarding layout only linked
  `rails_onboarding/application`, so most of the gem's styling never
  loaded on Propshaft - including on the engine's own `/onboarding`
  pages, not just host app integration. Fixed the layout to link every
  partial when Propshaft is detected, and updated `ESBUILD_SETUP.md`,
  `README.md`, `docs/ASSET_LOADING_GUIDE.md`, and the generator's printed
  post-install README with Propshaft-specific instructions.
- Reworked `ESBUILD_SETUP.md`'s Stimulus registration steps: copying
  controllers into a `rails_onboarding/` subfolder made
  `stimulus:manifest:update` derive prefixed identifiers
  (`rails_onboarding--onboarding`) that don't match the flat identifiers
  the gem's views render (`onboarding`, `tooltip`, etc). Controllers now
  get copied flat into `app/javascript/controllers/` so manifest-based
  auto-registration actually works instead of silently registering under
  the wrong name.

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

[Unreleased]: https://github.com/bunnahabhain/rails_onboarding/compare/v0.3.3...HEAD
[0.3.3]: https://github.com/bunnahabhain/rails_onboarding/compare/v0.3.2...v0.3.3
[0.3.2]: https://github.com/bunnahabhain/rails_onboarding/compare/v0.3.1...v0.3.2
[0.3.1]: https://github.com/bunnahabhain/rails_onboarding/compare/v0.3.0...v0.3.1
[0.3.0]: https://github.com/bunnahabhain/rails_onboarding/compare/v0.2.8...v0.3.0
[0.2.8]: https://github.com/bunnahabhain/rails_onboarding/compare/v0.2.7...v0.2.8
[0.2.7]: https://github.com/bunnahabhain/rails_onboarding/compare/v0.2.6...v0.2.7
[0.2.6]: https://github.com/bunnahabhain/rails_onboarding/compare/v0.2.5...v0.2.6
[0.2.5]: https://github.com/bunnahabhain/rails_onboarding/compare/v0.1.8...v0.2.5
[0.1.8]: https://github.com/bunnahabhain/rails_onboarding/compare/v0.1.7...v0.1.8
[0.1.7]: https://github.com/bunnahabhain/rails_onboarding/compare/v0.1.6...v0.1.7
[0.1.6]: https://github.com/bunnahabhain/rails_onboarding/compare/v0.1.5...v0.1.6
[0.1.5]: https://github.com/bunnahabhain/rails_onboarding/compare/v0.1.4...v0.1.5
[0.1.4]: https://github.com/bunnahabhain/rails_onboarding/compare/v0.1.3...v0.1.4
[0.1.3]: https://github.com/bunnahabhain/rails_onboarding/compare/v0.1.2...v0.1.3
[0.1.2]: https://github.com/bunnahabhain/rails_onboarding/compare/v0.1.1...v0.1.2
[0.1.1]: https://github.com/bunnahabhain/rails_onboarding/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/bunnahabhain/rails_onboarding/releases/tag/v0.1.0
