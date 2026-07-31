# Contributing to Rails Onboarding

Thanks for your interest in improving the gem. Bug reports, documentation
fixes, and pull requests are all welcome.

## Getting Set Up

The gem targets Ruby >= 3.4.9 and Rails >= 8.0. Development happens on the
version in `.ruby-version`.

```bash
git clone https://github.com/bunnahabhain/rails_onboarding.git
cd rails_onboarding
bundle install
bin/rails db:test:prepare
bin/rails test
```

A clean checkout should report 0 failures and 0 errors. If it doesn't, that's a
bug worth reporting before you change anything.

## Running the Tests

```bash
bin/rails test                                  # everything
bin/rails test test/integration/navigation_test.rb
bin/rails test test/models -n /milestone/       # by name
```

Use `bin/rails`, not `bundle exec rails`. The binstub is what CI runs.

Run `bin/rails db:test:prepare` as a **separate command** before the suite, not
chained as `db:test:prepare test`. In an engine, `bin/rails` loads
`rails/engine/commands`, whose router can't chain a rake task and a command in
one argv the way a full application's `bin/rails` can - the chained form fails
with `Unrecognized command "test"`.

Don't run the suite in parallel with anything else that boots Rails (a second
test run, `gem build`, a console). They share one SQLite test database and will
produce spurious failures.

## Linting

```bash
bin/rubocop        # check
bin/rubocop -a     # autocorrect
```

Style is [rails-omakase](https://github.com/rails/rubocop-rails-omakase) with a
short exclude list in `.rubocop.yml`. Generator templates are excluded because
they're ERB, not Ruby - the migration version in their class declaration parses
as a syntax error. CI runs the lint job separately from tests, so both must
pass.

## How the Suite Is Laid Out

Tests run against a dummy Rails application at `test/dummy`, which mounts the
engine the way a host app would.

| Directory | Covers |
|---|---|
| `test/controllers` | Engine controllers, including the `Admin::` namespace |
| `test/integration` | Full request flows through the onboarding steps |
| `test/lib` | The modules under `lib/rails_onboarding` |
| `test/models` | `Onboardable` and the other host-side concerns |
| `test/generators` | The install and update generators |
| `test/mailers`, `test/services`, `test/performance` | As named |
| `test/manual` | Visual checks that need a browser, not automated |

Fixtures live in `test/fixtures` (`users.yml`); the suite uses fixtures rather
than factories. `test/test_helper.rb` provides a `sign_in(user)` helper backed
by a test-only route.

Two things about the dummy app are worth knowing when a test passes locally but
you suspect it shouldn't:

- It runs on **SQLite with plaintext columns**. Real host applications may use
  MySQL or PostgreSQL with encrypted attributes, so SQL, timestamp, and
  email-handling code can pass here and still break there.
- `turbo-rails` is a development-only dependency, so `:turbo_stream` isn't
  registered as a MIME type the way it would be in a real host app.
  `test_helper.rb` registers it explicitly; without that, every
  `format.turbo_stream` block raises.

## Making a Change

1. Fork and branch from `master`.
2. Write a test. Bug fixes should include one that fails before the change.
3. Run `bin/rails test` and `bin/rubocop`.
4. Add an entry under `## [Unreleased]` in
   [docs/CHANGELOG.md](docs/CHANGELOG.md) if the change is user-visible. The
   format is [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
5. Open a pull request describing what changed and why.

### Configuration changes

Every reader and writer on `Configuration` is part of the gem's public API -
host apps set these in a `RailsOnboarding.configure` block, so renaming or
removing one breaks every existing installation. Add new options to the
relevant module under `lib/rails_onboarding/configuration/` rather than to
`configuration.rb` itself, and document them in the README.

If you add an option, check that the documentation matches: the guides describe
options that must actually exist, and a snippet naming one that doesn't will
raise `NoMethodError` in a reader's initializer.

## Commit Messages

Write in the imperative mood, and explain *why* in the body when the reason
isn't obvious from the diff:

```
Fix guided-tour daily-limit tracking (count, not timestamp)

The limit compared a stored timestamp against a count, so the tour
re-displayed after the first dismissal each day.
```

No prefixes or conventional-commit tags - the history doesn't use them.

## Documentation

Published documentation is Markdown in `docs/`. Working notes belong in
`docs/*.txt`, which `.gitignore` excludes, so scratch never reaches the
repository.

`docs/CHANGELOG.md` is a historical record. Add entries; don't rewrite old ones
to match the present, even when paths or APIs have since moved.

Note that `docs/` is **not** packaged into the gem - the gemspec ships only
`{app,config,db,lib}`, `MIT-LICENSE`, `Rakefile` and `README.md`. Anything a
host app needs at runtime has to live under one of those directories, and
documentation that installed apps need to reach should be linked to on GitHub
rather than copied.

## Reporting Bugs

Open an issue at
https://github.com/bunnahabhain/rails_onboarding/issues including:

- Gem, Rails and Ruby versions
- Your `config/initializers/rails_onboarding.rb`, minus any secrets
- What you expected and what happened, with the full backtrace

`bin/rails rails_onboarding:validate` checks that your application still meets
the gem's requirements and is often quicker than a round trip.

For anything security-sensitive, email david@davidsfolly.com rather than
opening a public issue.

## Releases

Maintainer notes, for reference:

1. Land the change on `master`.
2. Move the `[Unreleased]` entries under a new version heading in the
   changelog.
3. Bump `lib/rails_onboarding/version.rb` in a **separate** commit
   (`Bump version to X.Y.Z`).
4. Tag it `vX.Y.Z` - the gemspec's `source_code_uri` points at that tag, and the
   RubyGems listing links to it.

## License

Contributions are accepted under the [MIT License](MIT-LICENSE), the same terms
as the project.
