# frozen_string_literal: true

module RailsOnboarding
  # CDN Support module for serving assets from a CDN
  #
  # This module provides helpers and configuration for serving
  # onboarding assets (JavaScript, CSS, images) from a CDN
  # to improve performance through better caching and geographic distribution
  module CdnSupport
    extend ActiveSupport::Concern

    class_methods do
      # Get the CDN host URL
      #
      # @return [String, nil] CDN host URL or nil if not configured
      def cdn_host
        @cdn_host ||= begin
          # Check Rails configuration first
          if defined?(Rails.application) && Rails.application.config.action_controller.asset_host
            Rails.application.config.action_controller.asset_host
          else
            ENV['RAILS_ONBOARDING_CDN_HOST']
          end
        end
      end

      # Set the CDN host URL
      #
      # @param host [String] CDN host URL
      def cdn_host=(host)
        @cdn_host = host
      end

      # Check if CDN is enabled
      #
      # @return [Boolean]
      def cdn_enabled?
        cdn_host.present? && !Rails.env.development?
      end

      # Get asset URL with CDN support
      #
      # @param asset_path [String] The asset path (e.g., 'rails_onboarding/application.css')
      # @param asset_type [Symbol] Asset type (:stylesheet, :javascript, :image)
      # @return [String] Full URL to the asset
      def cdn_asset_url(asset_path, asset_type: :stylesheet)
        if cdn_enabled?
          case asset_type
          when :stylesheet
            "#{cdn_host}/assets/#{asset_path}"
          when :javascript
            "#{cdn_host}/assets/#{asset_path}"
          when :image
            "#{cdn_host}/assets/#{asset_path}"
          else
            "#{cdn_host}/assets/#{asset_path}"
          end
        else
          # Fall back to local asset path
          "/assets/#{asset_path}"
        end
      end

      # Preload critical onboarding assets
      #
      # @return [Array<Hash>] Array of asset preload hints
      def preload_assets
        [
          {
            href: cdn_asset_url('rails_onboarding/application.css', asset_type: :stylesheet),
            as: 'style',
            type: 'text/css'
          },
          {
            href: cdn_asset_url('rails_onboarding/application.js', asset_type: :javascript),
            as: 'script',
            type: 'text/javascript'
          }
        ]
      end

      # Generate cache-busting URL with versioning
      #
      # @param asset_path [String] The asset path
      # @param version [String] Asset version (defaults to gem version)
      # @return [String] URL with version parameter
      def versioned_asset_url(asset_path, version: nil)
        version ||= RailsOnboarding::VERSION
        url = cdn_asset_url(asset_path)
        "#{url}?v=#{version}"
      end
    end

    module_function

    # Helper method for view templates
    # Generates link tags with CDN support and preload hints
    #
    # @param asset_path [String] Asset path
    # @param options [Hash] Additional options
    # @return [String] HTML link tag
    def stylesheet_link_tag_with_cdn(asset_path, **options)
      url = CdnSupport.versioned_asset_url(asset_path, asset_type: :stylesheet)

      preload = options.delete(:preload)
      crossorigin = options.delete(:crossorigin)

      tag_options = {
        rel: 'stylesheet',
        href: url
      }.merge(options)

      tag_options[:crossorigin] = crossorigin if crossorigin

      tags = ["<link #{tag_options.map { |k, v| "#{k}=\"#{v}\"" }.join(' ')} />"]

      if preload
        tags.unshift("<link rel=\"preload\" href=\"#{url}\" as=\"style\" />")
      end

      tags.join("\n").html_safe
    end

    # Helper method for JavaScript tags with CDN support
    #
    # @param asset_path [String] Asset path
    # @param options [Hash] Additional options
    # @return [String] HTML script tag
    def javascript_include_tag_with_cdn(asset_path, **options)
      url = CdnSupport.versioned_asset_url(asset_path, asset_type: :javascript)

      preload = options.delete(:preload)
      defer = options.delete(:defer) { true } # Default to defer
      async = options.delete(:async)

      tag_options = {
        src: url,
        type: 'text/javascript'
      }.merge(options)

      tag_options[:defer] = 'defer' if defer && !async
      tag_options[:async] = 'async' if async

      tags = ["<script #{tag_options.map { |k, v| "#{k}=\"#{v}\"" }.join(' ')}></script>"]

      if preload
        tags.unshift("<link rel=\"preload\" href=\"#{url}\" as=\"script\" />")
      end

      tags.join("\n").html_safe
    end

    # Generate resource hints for DNS prefetch and preconnect
    #
    # @return [String] HTML meta tags for resource hints
    def cdn_resource_hints
      return '' unless CdnSupport.cdn_enabled?

      cdn_host = CdnSupport.cdn_host
      <<~HTML.html_safe
        <!-- DNS Prefetch and Preconnect for CDN -->
        <link rel="dns-prefetch" href="#{cdn_host}" />
        <link rel="preconnect" href="#{cdn_host}" crossorigin />
      HTML
    end

    # Configure CDN headers for optimal caching
    #
    # @param max_age [Integer] Cache max age in seconds (default: 1 year)
    # @return [Hash] Headers for CDN caching
    def cdn_cache_headers(max_age: 31_536_000)
      {
        'Cache-Control' => "public, max-age=#{max_age}, immutable",
        'Expires' => max_age.seconds.from_now.httpdate,
        'Vary' => 'Accept-Encoding'
      }
    end
  end
end

# Extend ActionView helpers if in Rails context
if defined?(ActionView::Base)
  ActionView::Base.class_eval do
    include RailsOnboarding::CdnSupport
  end
end
