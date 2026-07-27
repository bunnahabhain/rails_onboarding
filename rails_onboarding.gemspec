require_relative "lib/rails_onboarding/version"

Gem::Specification.new do |spec|
  spec.name        = "rails_onboarding"
  spec.version     = RailsOnboarding::VERSION
  spec.authors     = [ "David Lewis" ]
  spec.email       = [ "david@davidsfolly.com" ]
  spec.homepage    = "https://github.com/bunnahabhain/rails_onboarding"
  spec.summary     = "Flexible onboarding engine for Rails applications"
  spec.description = "A mountable Rails engine that provides a customizable onboarding flow with progress tracking, tooltips, and milestones"
  spec.license     = "MIT"

  # Allow pushing to RubyGems.org
  spec.metadata["allowed_push_host"] = "https://rubygems.org"

  spec.metadata["homepage_uri"] = spec.homepage
  # Pinned to the release tag rather than repeating the homepage: RubyGems warns
  # when two metadata keys carry the same URI, and "the source for this exact
  # version" is more use to someone reading the listing than a second link to the
  # repository root. Relies on the release flow tagging v<VERSION> - see
  # docs/CHANGELOG.md for the versions that have shipped.
  spec.metadata["source_code_uri"] = "#{spec.homepage}/tree/v#{spec.version}"
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/master/docs/CHANGELOG.md"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]
  end

  spec.required_ruby_version = ">= 3.4.9"

  spec.add_dependency "rails", ">= 8.0.0"
  spec.add_dependency "csv" # no longer a default gem as of Ruby 3.4, used for admin CSV exports
  spec.add_dependency "pagy", "~> 43.6" # pagination for the admin index screens

  spec.add_development_dependency "minitest", "~> 6.0"
  spec.add_development_dependency "factory_bot_rails", "~> 6.0"
  spec.add_development_dependency "sqlite3", "~> 2.0"

  # Optional dependencies for enhanced functionality
  spec.add_development_dependency "stimulus-rails", ">= 1.0.0"
  spec.add_development_dependency "turbo-rails", ">= 1.0.0"
end
