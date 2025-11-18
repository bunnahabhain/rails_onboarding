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
end
