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

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the "allowed_push_host"
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  spec.metadata["allowed_push_host"] = "TODO: Set to 'https://mygemserver.com'"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]
  end

  spec.required_ruby_version = ">= 3.2.5"

  spec.add_dependency "rails", ">= 8.0.0"

  spec.add_development_dependency "minitest", "~> 5.0"
  spec.add_development_dependency "minitest-rails", "~> 8.0"
  spec.add_development_dependency "factory_bot_rails", "~> 6.0"
  spec.add_development_dependency "sqlite3", "~> 2.0"

  # Optional dependencies for enhanced functionality
  spec.add_development_dependency "stimulus-rails", ">= 1.0.0"
  spec.add_development_dependency "turbo-rails", ">= 1.0.0"
end
