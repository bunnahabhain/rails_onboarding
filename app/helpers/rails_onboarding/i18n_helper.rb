module RailsOnboarding
  # I18n Helper Module
  # Provides convenient methods for internationalization
  module I18nHelper
    # Translate a key with the rails_onboarding scope
    #
    # @param key [String, Symbol] Translation key
    # @param options [Hash] Translation options
    # @return [String] Translated string
    def t_onboarding(key, **options)
      I18n.t("rails_onboarding.#{key}", **options)
    end

    # Translate navigation text
    def t_nav(key, **options)
      t_onboarding("navigation.#{key}", **options)
    end

    # Translate action text
    def t_action(key, **options)
      t_onboarding("actions.#{key}", **options)
    end

    # Translate message text
    def t_message(key, **options)
      t_onboarding("messages.#{key}", **options)
    end

    # Translate error text
    def t_error(key, **options)
      t_onboarding("errors.#{key}", **options)
    end

    # Translate common text
    def t_common(key, **options)
      t_onboarding("common.#{key}", **options)
    end

    # Translate progress text
    def t_progress(key, **options)
      t_onboarding("progress.#{key}", **options)
    end

    # Translate milestone text
    def t_milestone(key, **options)
      t_onboarding("milestones.#{key}", **options)
    end

    # Get localized step title
    #
    # @param step [Hash] Step configuration
    # @return [String] Localized step title
    def localized_step_title(step)
      return step[:title] unless step[:title_key]

      I18n.t(step[:title_key], default: step[:title])
    end

    # Get localized step description
    #
    # @param step [Hash] Step configuration
    # @return [String] Localized step description
    def localized_step_description(step)
      return step[:description] unless step[:description_key]

      I18n.t(step[:description_key], default: step[:description] || "")
    end

    # Get localized milestone title
    #
    # @param milestone [Hash] Milestone configuration
    # @return [String] Localized milestone title
    def localized_milestone_title(milestone)
      return milestone[:title] unless milestone[:title_key]

      I18n.t(milestone[:title_key], default: milestone[:title])
    end

    # Get localized milestone description
    #
    # @param milestone [Hash] Milestone configuration
    # @return [String] Localized milestone description
    def localized_milestone_description(milestone)
      return milestone[:description] unless milestone[:description_key]

      I18n.t(milestone[:description_key], default: milestone[:description] || "")
    end

    # Get available locales for onboarding
    #
    # @return [Array<Symbol>] Available locale codes
    def onboarding_locales
      I18n.available_locales.select do |locale|
        I18n.exists?("rails_onboarding", locale: locale)
      end
    end

    # Check if a locale is available
    #
    # @param locale [Symbol, String] Locale code
    # @return [Boolean] True if locale is available
    def locale_available?(locale)
      I18n.available_locales.include?(locale.to_sym) &&
        I18n.exists?("rails_onboarding", locale: locale)
    end

    # Get user's preferred locale
    #
    # @param user [User] User object
    # @return [Symbol] Locale code
    def user_locale(user)
      return I18n.default_locale unless user

      # Try to get locale from user
      user_locale = if user.respond_to?(:locale)
                      user.locale
      elsif user.respond_to?(:language)
                      user.language
      elsif user.respond_to?(:preferred_language)
                      user.preferred_language
      end

      return I18n.default_locale unless user_locale

      locale_sym = user_locale.to_sym
      locale_available?(locale_sym) ? locale_sym : I18n.default_locale
    end

    # Execute block with user's locale
    #
    # @param user [User] User object
    # @yield Block to execute with user's locale
    def with_user_locale(user, &block)
      I18n.with_locale(user_locale(user), &block)
    end
  end
end
