# frozen_string_literal: true

module RailsOnboarding
  # Deprecation warnings utility module
  # Provides consistent deprecation warnings across the gem
  module Deprecation
    class << self
      # Issue a deprecation warning
      # @param message [String] The deprecation message
      # @param version [String] The version when the feature will be removed
      def warn(message, version: nil)
        full_message = "[DEPRECATION] #{message}"
        full_message += " It will be removed in version #{version}." if version

        if defined?(ActiveSupport::Deprecation)
          ActiveSupport::Deprecation.warn(full_message)
        else
          Rails.logger.warn(full_message) if defined?(Rails)
        end
      end

      # Deprecate a method call
      # @param old_method [String] The deprecated method name
      # @param new_method [String] The replacement method name
      # @param version [String] The version when it will be removed
      def deprecate_method(old_method, new_method: nil, version: nil)
        message = "#{old_method} is deprecated"
        message += " and will be removed in version #{version}" if version
        message += ". Use #{new_method} instead" if new_method
        message += "."

        warn(message, version: version)
      end

      # Deprecate a configuration option
      # @param option [String] The deprecated configuration option
      # @param replacement [String] The replacement option
      # @param version [String] The version when it will be removed
      def deprecate_config(option, replacement: nil, version: nil)
        message = "Configuration option '#{option}' is deprecated"
        message += " and will be removed in version #{version}" if version
        message += ". Use '#{replacement}' instead" if replacement
        message += "."

        warn(message, version: version)
      end

      # Deprecate a data format
      # @param format [String] The deprecated format description
      # @param new_format [String] The new format description
      # @param version [String] The version when support will be removed
      def deprecate_format(format, new_format: nil, version: nil)
        message = "#{format} is deprecated"
        message += " and support will be removed in version #{version}" if version
        message += ". Please migrate to: #{new_format}" if new_format
        message += "."

        warn(message, version: version)
      end
    end
  end
end
