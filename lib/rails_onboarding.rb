require "rails_onboarding/version"
require "rails_onboarding/engine"
require "rails_onboarding/deprecation"
require "rails_onboarding/configuration_errors"
require "rails_onboarding/configuration_validator"
require "rails_onboarding/configuration"
require "rails_onboarding/requirements_validator"
require "rails_onboarding/controller_helpers"
require "rails_onboarding/responsive_helper"
require "rails_onboarding/error_recovery"
require "rails_onboarding/session_manager"
require "rails_onboarding/skip_logic"
require "rails_onboarding/multi_tenant"
require "rails_onboarding/devise_integration"
require "rails_onboarding/turbo_compatibility"
require "rails_onboarding/api_mode"
require "rails_onboarding/background_jobs"
require "rails_onboarding/webhooks"
require "rails_onboarding/caching"
require "rails_onboarding/lazy_loading"
require "rails_onboarding/cdn_support"

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
