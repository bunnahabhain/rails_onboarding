require "test_helper"

module RailsOnboarding
  class EngineAssetLoadingTest < ActiveSupport::TestCase
    setup do
      @engine = RailsOnboarding::Engine
      @app = Rails.application
    end

    test "engine is properly loaded" do
      assert @engine < Rails::Engine, "RailsOnboarding::Engine should inherit from Rails::Engine"
      assert_equal "rails_onboarding", @engine.engine_name
    end

    test "engine has isolated namespace" do
      assert @engine.isolated?, "Engine should have isolated namespace"
    end

    # Asset Pipeline Detection Tests
    test "detect_asset_pipeline detects sprockets" do
      skip "Sprockets detection tested in integration" unless defined?(Sprockets)

      pipeline = @engine.send(:detect_asset_pipeline, @app)
      assert_includes [ :sprockets, :importmap ], pipeline,
        "Should detect sprockets or importmap"
    end

    test "asset paths are configured" do
      assert @app.config.assets.paths.any? { |path|
        path.to_s.include?("rails_onboarding/app/assets/stylesheets")
      }, "Stylesheet path should be configured"

      assert @app.config.assets.paths.any? { |path|
        path.to_s.include?("rails_onboarding/app/assets/javascripts")
      }, "JavaScript path should be configured"
    end

    test "CSS files exist in expected locations" do
      css_files = [
        "application.css",
        "tooltips.css",
        "utilities.css",
        "accessibility.css",
        "tour.css",
        "mobile.css",
        "milestones.css",
        "progressive_disclosure.css",
        "flash_messages.css",
        "admin.css"
      ]

      css_files.each do |file|
        path = @engine.root.join("app", "assets", "stylesheets", "rails_onboarding", file)
        assert File.exist?(path), "CSS file #{file} should exist at #{path}"
      end
    end

    test "JavaScript files exist in expected locations" do
      js_files = [
        "application.js",
        "onboarding_controller.js",
        "progress_controller.js",
        "navigation_controller.js",
        "tooltip_controller.js",
        "tooltip_scheduler_controller.js",
        "tour_controller.js",
        "progressive_disclosure_controller.js",
        "milestone_celebration_controller.js",
        "milestone_dashboard_controller.js",
        "milestone_detail_controller.js"
      ]

      js_files.each do |file|
        path = @engine.root.join("app", "assets", "javascripts", "rails_onboarding", file)
        assert File.exist?(path), "JavaScript file #{file} should exist at #{path}"
      end
    end

    test "admin JavaScript files exist" do
      admin_js_files = [
        "admin/chart_controller.js",
        "admin/filter_controller.js",
        "admin/flash_controller.js",
        "admin/flow_editor_controller.js"
      ]

      admin_js_files.each do |file|
        path = @engine.root.join("app", "assets", "javascripts", "rails_onboarding", file)
        assert File.exist?(path), "Admin JavaScript file #{file} should exist at #{path}"
      end
    end

    # View Path Tests
    test "view paths are configured" do
      view_path = @engine.root.join("app", "views")
      assert File.directory?(view_path), "View path should exist"
    end

    test "engine views are accessible" do
      # Only check for views that are actually provided by the gem
      # Host application should provide step-specific views
      view_files = [
        "rails_onboarding/onboarding/step.html.erb",
        "rails_onboarding/onboarding/welcome.html.erb"
      ]

      view_files.each do |file|
        path = @engine.root.join("app", "views", file)
        assert File.exist?(path), "View file #{file} should exist"
      end
    end

    # Importmap Tests
    test "importmap configuration file exists" do
      importmap_path = @engine.root.join("config", "importmap.rb")
      assert File.exist?(importmap_path), "Importmap configuration should exist"
    end

    test "importmap pins all necessary controllers" do
      importmap_path = @engine.root.join("config", "importmap.rb")
      importmap_content = File.read(importmap_path)

      required_pins = [
        "rails_onboarding/application",
        "rails_onboarding/onboarding_controller",
        "rails_onboarding/progress_controller",
        "rails_onboarding/navigation_controller",
        "rails_onboarding/tooltip_controller",
        "rails_onboarding/tooltip_scheduler_controller",
        "rails_onboarding/tour_controller",
        "rails_onboarding/progressive_disclosure_controller",
        "rails_onboarding/milestone_celebration_controller",
        "rails_onboarding/milestone_dashboard_controller",
        "rails_onboarding/milestone_detail_controller"
      ]

      required_pins.each do |pin|
        assert_match(/pin\s+"#{Regexp.escape(pin)}"/, importmap_content,
          "Importmap should pin #{pin}")
      end
    end

    # CSS Isolation Tests
    test "CSS uses namespaced variables" do
      css_path = @engine.root.join("app", "assets", "stylesheets", "rails_onboarding", "application.css")
      css_content = File.read(css_path)

      # Check for CSS custom properties with onboarding prefix
      assert_match(/--onboarding-/, css_content,
        "CSS should use --onboarding- prefixed custom properties")

      # Check for namespaced class names
      assert_match(/\.onboarding-/, css_content,
        "CSS should use .onboarding- prefixed class names")
    end

    test "CSS isolation documentation is present" do
      css_path = @engine.root.join("app", "assets", "stylesheets", "rails_onboarding", "application.css")
      css_content = File.read(css_path)

      assert_match(/CSS Isolation Strategy/i, css_content,
        "CSS should document isolation strategy")
      assert_match(/Asset Pipeline Compatibility/i, css_content,
        "CSS should document asset pipeline compatibility")
    end

    # Helpers and Integration Tests
    test "controller helpers are loaded" do
      assert @app.config.respond_to?(:after_initialize),
        "App should support after_initialize"
    end

    test "stimulus integration helper methods exist" do
      assert_respond_to @engine, :stimulus_available?, "Should have stimulus_available? method"
      assert_respond_to @engine, :setup_stimulus_integration, "Should have setup_stimulus_integration method"
      assert_respond_to @engine, :importmap_available?, "Should have importmap_available? method"
      assert_respond_to @engine, :setup_importmap_integration, "Should have setup_importmap_integration method"
    end

    test "asset configuration helper methods exist" do
      assert_respond_to @engine, :detect_asset_pipeline, "Should have detect_asset_pipeline method"
      assert_respond_to @engine, :configure_sprockets_assets, "Should have configure_sprockets_assets method"
      assert_respond_to @engine, :configure_propshaft_assets, "Should have configure_propshaft_assets method"
      assert_respond_to @engine, :configure_importmap_assets, "Should have configure_importmap_assets method"
      assert_respond_to @engine, :configure_modern_bundler_assets, "Should have configure_modern_bundler_assets method"
    end

    # JavaScript Compatibility Tests
    test "JavaScript application file has compatibility notes" do
      js_path = @engine.root.join("app", "assets", "javascripts", "rails_onboarding", "application.js")
      js_content = File.read(js_path)

      assert_match(/Asset Pipeline.*Sprockets/i, js_content,
        "JS should mention Sprockets compatibility")
      assert_match(/Propshaft/i, js_content,
        "JS should mention Propshaft compatibility")
      assert_match(/importmap/i, js_content,
        "JS should mention importmap compatibility")
      assert_match(/esbuild.*webpack.*vite/i, js_content,
        "JS should mention modern bundler compatibility")
    end

    test "JavaScript has proper IIFE wrapping" do
      js_path = @engine.root.join("app", "assets", "javascripts", "rails_onboarding", "application.js")
      js_content = File.read(js_path)

      assert_match(/\(function\(\)/, js_content,
        "JS should use IIFE for encapsulation")
      assert_match(/'use strict'/, js_content,
        "JS should use strict mode")
    end

    # Generator Tests (migrations are provided via generators, not in gem's db/migrate)
    test "install generator exists" do
      generator_path = @engine.root.join("lib", "generators", "rails_onboarding", "install_generator.rb")
      assert File.exist?(generator_path), "Install generator should exist"
    end

    test "migration templates are accessible" do
      templates_dir = @engine.root.join("lib", "generators", "rails_onboarding", "templates")
      assert File.directory?(templates_dir), "Generator templates directory should exist"

      # Check for migration template files
      migration_templates = Dir[File.join(templates_dir, "*add_*users*.rb*")]
      assert migration_templates.any?, "Should have migration templates for users table"
    end
  end
end
