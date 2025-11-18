module RailsOnboarding
  # Base error class for all configuration errors
  class ConfigurationError < StandardError; end

  # Raised when step configuration is invalid
  class InvalidStepError < ConfigurationError; end

  # Raised when milestone configuration is invalid
  class InvalidMilestoneError < ConfigurationError; end

  # Raised when redirect path configuration is invalid
  class InvalidRedirectPathError < ConfigurationError; end

  # Raised when a configuration value has the wrong type
  class InvalidTypeError < ConfigurationError; end

  # Raised when a required configuration option is missing
  class MissingRequiredOptionError < ConfigurationError; end
end
