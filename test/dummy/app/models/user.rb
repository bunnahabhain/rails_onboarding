class User < ApplicationRecord
  include RailsOnboarding::Onboardable
  include RailsOnboarding::Caching
  include RailsOnboarding::LazyLoading

  # Rails 8 compatibility for polymorphic associations
  def self.has_query_constraints?
    false
  end

  def self.composite_primary_key?
    false
  end

  # Test-only stand-in for the host app's real admin check, so the
  # engine's admin controller tests have something to authenticate against.
  def admin?
    email == "admin@example.com"
  end
end
