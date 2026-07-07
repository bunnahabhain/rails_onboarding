# frozen_string_literal: true

require 'test_helper'

module RailsOnboarding
  class CdnSupportTest < ActiveSupport::TestCase
    setup do
      @original_cdn_host = CdnSupport.cdn_host
      @original_env = Rails.env
    end

    teardown do
      CdnSupport.cdn_host = @original_cdn_host
      Rails.env = @original_env
    end

    # CDN host configuration tests

    test 'cdn_host returns configured host' do
      CdnSupport.cdn_host = 'https://cdn.example.com'
      assert_equal 'https://cdn.example.com', CdnSupport.cdn_host
    end

    test 'cdn_host returns nil when not configured' do
      CdnSupport.cdn_host = nil
      ENV['RAILS_ONBOARDING_CDN_HOST'] = nil

      assert_nil CdnSupport.cdn_host
    end

    test 'cdn_host reads from environment variable' do
      CdnSupport.instance_variable_set(:@cdn_host, nil)
      ENV['RAILS_ONBOARDING_CDN_HOST'] = 'https://cdn.env.example.com'

      assert_equal 'https://cdn.env.example.com', CdnSupport.cdn_host

      # Clean up
      ENV.delete('RAILS_ONBOARDING_CDN_HOST')
      CdnSupport.instance_variable_set(:@cdn_host, nil)
    end

    test 'cdn_enabled? returns true when host configured in production' do
      Rails.env = 'production'
      CdnSupport.cdn_host = 'https://cdn.example.com'

      assert CdnSupport.cdn_enabled?

      # Reset
      Rails.env = @original_env
    end

    test 'cdn_enabled? returns false in development even with host' do
      Rails.env = 'development'
      CdnSupport.cdn_host = 'https://cdn.example.com'

      refute CdnSupport.cdn_enabled?

      # Reset
      Rails.env = @original_env
    end

    test 'cdn_enabled? returns false when host not configured' do
      CdnSupport.cdn_host = nil

      refute CdnSupport.cdn_enabled?
    end

    # Asset URL generation tests

    test 'cdn_asset_url returns CDN URL when enabled' do
      Rails.env = 'production'
      CdnSupport.cdn_host = 'https://cdn.example.com'

      url = CdnSupport.cdn_asset_url('rails_onboarding/application.css')
      assert_equal 'https://cdn.example.com/assets/rails_onboarding/application.css', url

      # Reset
      Rails.env = @original_env
    end

    test 'cdn_asset_url returns local path when CDN disabled' do
      CdnSupport.cdn_host = nil

      url = CdnSupport.cdn_asset_url('rails_onboarding/application.css')
      assert_equal '/assets/rails_onboarding/application.css', url
    end

    test 'cdn_asset_url works with different asset types' do
      Rails.env = 'production'
      CdnSupport.cdn_host = 'https://cdn.example.com'

      css_url = CdnSupport.cdn_asset_url('app.css', asset_type: :stylesheet)
      js_url = CdnSupport.cdn_asset_url('app.js', asset_type: :javascript)
      img_url = CdnSupport.cdn_asset_url('logo.png', asset_type: :image)

      assert_equal 'https://cdn.example.com/assets/app.css', css_url
      assert_equal 'https://cdn.example.com/assets/app.js', js_url
      assert_equal 'https://cdn.example.com/assets/logo.png', img_url

      # Reset
      Rails.env = @original_env
    end

    test 'versioned_asset_url includes version parameter' do
      Rails.env = 'production'
      CdnSupport.cdn_host = 'https://cdn.example.com'

      url = CdnSupport.versioned_asset_url('app.css', version: '1.2.3')
      assert_equal "https://cdn.example.com/assets/app.css?v=1.2.3", url

      # Reset
      Rails.env = @original_env
    end

    test 'versioned_asset_url uses gem version by default' do
      Rails.env = 'production'
      CdnSupport.cdn_host = 'https://cdn.example.com'

      url = CdnSupport.versioned_asset_url('app.css')
      assert_includes url, "?v=#{RailsOnboarding::VERSION}"

      # Reset
      Rails.env = @original_env
    end

    # Preload assets tests

    test 'preload_assets returns array of asset hashes' do
      assets = CdnSupport.preload_assets

      assert_instance_of Array, assets
      assert assets.size >= 2  # At least CSS and JS

      first_asset = assets.first
      assert_includes first_asset.keys, :href
      assert_includes first_asset.keys, :as
      assert_includes first_asset.keys, :type
    end

    test 'preload_assets includes CSS and JS' do
      assets = CdnSupport.preload_assets

      css_asset = assets.find { |a| a[:as] == 'style' }
      js_asset = assets.find { |a| a[:as] == 'script' }

      assert_not_nil css_asset
      assert_not_nil js_asset
      assert_includes css_asset[:href], 'application.css'
      assert_includes js_asset[:href], 'application.js'
    end

    # Cache headers tests

    test 'cdn_cache_headers returns correct headers' do
      headers = CdnSupport.cdn_cache_headers

      assert_includes headers.keys, 'Cache-Control'
      assert_includes headers.keys, 'Expires'
      assert_includes headers.keys, 'Vary'

      assert_includes headers['Cache-Control'], 'public'
      assert_includes headers['Cache-Control'], 'max-age='
      assert_includes headers['Cache-Control'], 'immutable'
      assert_equal 'Accept-Encoding', headers['Vary']
    end

    test 'cdn_cache_headers accepts custom max_age' do
      headers = CdnSupport.cdn_cache_headers(max_age: 3600)

      assert_includes headers['Cache-Control'], 'max-age=3600'
    end

    test 'cdn_cache_headers sets expiry time correctly' do
      max_age = 86400  # 1 day
      headers = CdnSupport.cdn_cache_headers(max_age: max_age)

      # Parse the expiry time
      expires_time = Time.httpdate(headers['Expires'])
      expected_time = Time.now + max_age

      # Allow 5 second difference for test execution time
      assert_in_delta expected_time.to_i, expires_time.to_i, 5
    end

    # Resource hints tests

    test 'cdn_resource_hints returns empty string when CDN disabled' do
      CdnSupport.cdn_host = nil

      hints = CdnSupport.cdn_resource_hints
      assert_equal '', hints
    end

    test 'cdn_resource_hints returns HTML tags when CDN enabled' do
      Rails.env = 'production'
      CdnSupport.cdn_host = 'https://cdn.example.com'

      hints = CdnSupport.cdn_resource_hints

      assert_includes hints, 'dns-prefetch'
      assert_includes hints, 'preconnect'
      assert_includes hints, 'https://cdn.example.com'

      # Reset
      Rails.env = @original_env
    end

    # Helper method tests

    test 'stylesheet_link_tag_with_cdn generates link tag' do
      Rails.env = 'production'
      CdnSupport.cdn_host = 'https://cdn.example.com'

      tag = CdnSupport.stylesheet_link_tag_with_cdn('app.css')

      assert_includes tag, '<link'
      assert_includes tag, 'rel="stylesheet"'
      assert_includes tag, 'https://cdn.example.com/assets/app.css'

      # Reset
      Rails.env = @original_env
    end

    test 'stylesheet_link_tag_with_cdn includes preload when requested' do
      Rails.env = 'production'
      CdnSupport.cdn_host = 'https://cdn.example.com'

      tag = CdnSupport.stylesheet_link_tag_with_cdn('app.css', preload: true)

      assert_includes tag, 'rel="preload"'
      assert_includes tag, 'as="style"'

      # Reset
      Rails.env = @original_env
    end

    test 'javascript_include_tag_with_cdn generates script tag' do
      Rails.env = 'production'
      CdnSupport.cdn_host = 'https://cdn.example.com'

      tag = CdnSupport.javascript_include_tag_with_cdn('app.js')

      assert_includes tag, '<script'
      assert_includes tag, 'https://cdn.example.com/assets/app.js'
      assert_includes tag, 'defer="defer"'  # Default behavior

      # Reset
      Rails.env = @original_env
    end

    test 'javascript_include_tag_with_cdn supports async option' do
      Rails.env = 'production'
      CdnSupport.cdn_host = 'https://cdn.example.com'

      tag = CdnSupport.javascript_include_tag_with_cdn('app.js', async: true)

      assert_includes tag, 'async="async"'
      refute_includes tag, 'defer'

      # Reset
      Rails.env = @original_env
    end

    test 'javascript_include_tag_with_cdn includes preload when requested' do
      Rails.env = 'production'
      CdnSupport.cdn_host = 'https://cdn.example.com'

      tag = CdnSupport.javascript_include_tag_with_cdn('app.js', preload: true)

      assert_includes tag, 'rel="preload"'
      assert_includes tag, 'as="script"'

      # Reset
      Rails.env = @original_env
    end

    # Output escaping

    test 'stylesheet_link_tag_with_cdn escapes a host that tries to break out of the attribute' do
      Rails.env = 'production'
      CdnSupport.cdn_host = 'https://evil.example.com/"><script>alert(1)</script>'

      tag = CdnSupport.stylesheet_link_tag_with_cdn('app.css')

      refute_includes tag, '"><script>'
      assert_includes tag, '&lt;script&gt;'

      Rails.env = @original_env
    end

    test 'javascript_include_tag_with_cdn escapes a host that tries to break out of the attribute' do
      Rails.env = 'production'
      CdnSupport.cdn_host = 'https://evil.example.com/"></script><script>alert(1)</script>'

      tag = CdnSupport.javascript_include_tag_with_cdn('app.js')

      refute_includes tag, '"></script><script>'
      assert_includes tag, '&lt;/script&gt;'

      Rails.env = @original_env
    end

    test 'cdn_resource_hints escapes a host that tries to break out of the attribute' do
      Rails.env = 'production'
      CdnSupport.cdn_host = 'https://evil.example.com/"><script>alert(1)</script>'

      hints = CdnSupport.cdn_resource_hints

      refute_includes hints, '"><script>'
      assert_includes hints, '&lt;script&gt;'

      Rails.env = @original_env
    end
  end
end
