class User < ApplicationRecord
  include RailsOnboarding::Onboardable
  
  # Rails 8 compatibility for polymorphic associations
  def self.has_query_constraints?
    false
  end
  
  def self.composite_primary_key?
    false
  end
end
