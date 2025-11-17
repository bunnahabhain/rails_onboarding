require "rails_onboarding/version"
require "rails_onboarding/engine"
require "rails_onboarding/configuration"
require "rails_onboarding/controller_helpers"
require "rails_onboarding/responsive_helper"

module RailsOnboarding
  class Error < StandardError; end

  class << self
    attr_accessor :configuration
  end

  def self.configure
    self.configuration ||= Configuration.new
    yield(configuration)
  end

  def self.reset_configuration!
    self.configuration = Configuration.new
  end

  # Default configuration
  self.configuration = Configuration.new
end
