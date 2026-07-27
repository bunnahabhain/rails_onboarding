# frozen_string_literal: true

module RailsOnboarding
  # Responsive layout helper module
  # Provides helper methods for implementing responsive design features in the host application
  module ResponsiveHelper
    # Returns the viewport meta tag for responsive design
    # This should be included in the host application's layout
    #
    # @param options [Hash] Optional configuration
    # @option options [String] :width The viewport width (default: 'device-width')
    # @option options [Float] :initial_scale The initial zoom level (default: 1.0)
    # @option options [Float] :maximum_scale The maximum zoom level (default: 5.0)
    # @option options [Float] :minimum_scale The minimum zoom level (default: 1.0)
    # @option options [Boolean] :user_scalable Whether user can zoom (default: true)
    # @option options [String] :viewport_fit How to handle notches/safe areas (default: 'cover')
    #
    # @return [String] The viewport meta tag HTML
    #
    # @example Basic usage in a layout
    #   <%= rails_onboarding_viewport_meta %>
    #
    # @example Custom configuration
    #   <%= rails_onboarding_viewport_meta(maximum_scale: 3.0, viewport_fit: 'contain') %>
    def rails_onboarding_viewport_meta(options = {})
      width = options[:width] || "device-width"
      initial_scale = options[:initial_scale] || 1.0
      maximum_scale = options[:maximum_scale] || 5.0
      minimum_scale = options[:minimum_scale] || 1.0
      user_scalable = options.fetch(:user_scalable, true) ? "yes" : "no"
      viewport_fit = options[:viewport_fit] || "cover"

      content = [
        "width=#{width}",
        "initial-scale=#{initial_scale}",
        "maximum-scale=#{maximum_scale}",
        "minimum-scale=#{minimum_scale}",
        "user-scalable=#{user_scalable}",
        "viewport-fit=#{viewport_fit}"
      ].join(", ")

      tag(:meta, name: "viewport", content: content)
    end

    # Returns theme color meta tag for mobile browsers
    #
    # @param color [String] The theme color (default: primary color from config)
    # @return [String] The theme-color meta tag HTML
    #
    # @example
    #   <%= rails_onboarding_theme_color %>
    #   <%= rails_onboarding_theme_color('#6366f1') %>
    def rails_onboarding_theme_color(color = nil)
      color ||= "#6366f1" # Default primary color
      tag(:meta, name: "theme-color", content: color)
    end

    # Checks if the current device is mobile based on user agent
    #
    # @return [Boolean] True if mobile device
    def mobile_device?
      return false unless request.present?

      user_agent = request.user_agent.to_s.downcase
      mobile_patterns = [
        /mobile/,
        /android/,
        /iphone/,
        /ipad/,
        /ipod/,
        /blackberry/,
        /windows phone/,
        /opera mini/,
        /kindle/,
        /silk/
      ]

      mobile_patterns.any? { |pattern| user_agent.match?(pattern) }
    end

    # Checks if the current device is a tablet
    #
    # @return [Boolean] True if tablet device
    def tablet_device?
      return false unless request.present?

      user_agent = request.user_agent.to_s.downcase
      tablet_patterns = [ /ipad/, /tablet/, /kindle/, /silk/, /playbook/ ]

      tablet_patterns.any? { |pattern| user_agent.match?(pattern) }
    end

    # Checks if the current device is a phone
    #
    # @return [Boolean] True if phone device
    def phone_device?
      mobile_device? && !tablet_device?
    end

    # Returns CSS classes for responsive context
    #
    # @return [String] Space-separated CSS classes
    #
    # @example In a view
    #   <div class="<%= responsive_device_classes %>">
    def responsive_device_classes
      classes = []
      classes << "is-mobile" if mobile_device?
      classes << "is-tablet" if tablet_device?
      classes << "is-phone" if phone_device?
      classes << "is-desktop" unless mobile_device?
      classes.join(" ")
    end

    # Returns data attributes for JavaScript device detection
    #
    # @return [Hash] Data attributes for HTML tags
    #
    # @example In a view
    #   <div <%= responsive_device_data %>>
    def responsive_device_data
      {
        "data-mobile" => mobile_device?,
        "data-tablet" => tablet_device?,
        "data-phone" => phone_device?
      }
    end

    # Apple-specific meta tags for iOS devices
    #
    # @return [String] Combined meta tags for iOS
    #
    # @example In a layout
    #   <%= rails_onboarding_ios_meta %>
    def rails_onboarding_ios_meta
      tags = []

      # Enable web app capable mode
      tags << tag(:meta, name: "apple-mobile-web-app-capable", content: "yes")

      # Status bar style
      tags << tag(:meta, name: "apple-mobile-web-app-status-bar-style", content: "default")

      # Disable phone number detection
      tags << tag(:meta, name: "format-detection", content: "telephone=no")

      safe_join(tags, "\n")
    end

    # Returns manifest link for PWA support
    #
    # @param manifest_path [String] Path to manifest.json
    # @return [String] Link tag for manifest
    #
    # @example
    #   <%= rails_onboarding_manifest_link %>
    def rails_onboarding_manifest_link(manifest_path = "/manifest.json")
      tag(:link, rel: "manifest", href: manifest_path)
    end

    # Helper to render responsive images
    #
    # @param src [String] Base image source
    # @param options [Hash] Image options
    # @option options [String] :alt Alt text
    # @option options [Hash] :srcset Responsive image sources
    # @option options [String] :sizes Media query sizes
    #
    # @example
    #   <%= responsive_image('welcome.jpg',
    #         alt: 'Welcome',
    #         srcset: { '1x' => 'welcome.jpg', '2x' => 'welcome@2x.jpg' },
    #         sizes: '(max-width: 768px) 100vw, 50vw') %>
    def responsive_image(src, options = {})
      alt = options[:alt] || ""
      srcset = options[:srcset]
      sizes = options[:sizes]
      css_class = options[:class] || ""

      img_options = { src: src, alt: alt, class: css_class }

      if srcset.present?
        srcset_value = srcset.map { |density, path| "#{path} #{density}" }.join(", ")
        img_options[:srcset] = srcset_value
      end

      img_options[:sizes] = sizes if sizes.present?

      tag(:img, img_options)
    end

    # Returns appropriate loading attribute for images
    #
    # @param eager [Boolean] Whether to load eagerly
    # @return [String] Loading attribute value
    def image_loading_strategy(eager: false)
      eager ? "eager" : "lazy"
    end

    # Checks if the viewport supports hover (desktop/laptop)
    #
    # @return [Boolean] True if hover is supported
    # Note: This is a server-side estimation; client-side detection is more accurate
    def supports_hover?
      !mobile_device?
    end

    # Returns touch-friendly attributes for interactive elements
    #
    # @return [Hash] Data attributes for touch optimization
    def touch_friendly_attrs
      {
        "data-touch-enabled" => mobile_device?,
        "style" => mobile_device? ? "touch-action: manipulation;" : nil
      }.compact
    end
  end
end
