module RailsOnboarding
  class Engine < ::Rails::Engine
    isolate_namespace RailsOnboarding

    # Make engine's helpers available to the main app
    config.to_prepare do
      ApplicationController.helper(RailsOnboarding::Engine.helpers)
      ApplicationController.helper(RailsOnboarding::ResponsiveHelper)
    end

    # Load migrations
    initializer :append_migrations do |app|
      unless app.root.to_s.match?(root.to_s)
        config.paths["db/migrate"].expanded.each do |expanded_path|
          app.config.paths["db/migrate"] << expanded_path
        end
      end
    end

    # Load JavaScript and CSS assets
    initializer "rails_onboarding.assets" do |app|
      # Detect which asset pipeline is in use
      asset_pipeline = Engine.detect_asset_pipeline(app)

      # Configure assets based on the pipeline
      case asset_pipeline
      when :sprockets
        Engine.configure_sprockets_assets(app)
      when :propshaft
        Engine.configure_propshaft_assets(app)
      when :importmap
        Engine.configure_importmap_assets(app)
      else
        # Fallback configuration for modern bundlers (ESBuild, Webpack, etc.)
        Engine.configure_modern_bundler_assets(app)
      end

      Rails.logger.info "RailsOnboarding: Detected asset pipeline: #{asset_pipeline}"
    end

    # Add engine's controller methods to ApplicationController
    initializer "rails_onboarding.controller_helpers" do
      ActiveSupport.on_load(:action_controller_base) do
        include RailsOnboarding::ControllerHelpers
      end
    end

    # Add view paths for the engine
    initializer "rails_onboarding.view_paths" do |app|
      ActiveSupport.on_load(:action_controller_base) do
        # Add engine views to the view path
        view_path = RailsOnboarding::Engine.root.join("app", "views")

        # Ensure the view path exists before adding it
        if File.directory?(view_path)
          append_view_path view_path
          Rails.logger.debug "RailsOnboarding: Added view path: #{view_path}"
        else
          Rails.logger.warn "RailsOnboarding: View path not found: #{view_path}"
        end
      end

      # Also add to ActionMailer if available
      ActiveSupport.on_load(:action_mailer) do
        view_path = RailsOnboarding::Engine.root.join("app", "views")
        if File.directory?(view_path)
          append_view_path view_path
          Rails.logger.debug "RailsOnboarding: Added mailer view path: #{view_path}"
        end
      end
    end

    # Optional: Setup Stimulus integration if available
    config.after_initialize do |app|
      Engine.setup_stimulus_integration(app) if Engine.stimulus_available?(app)
      Engine.setup_importmap_integration(app) if Engine.importmap_available?(app)
    end

    # NOTE: everything below is internal to the engine, not part of its public API.
    # It can't actually be marked `private` (bare `private` has no effect on `def self.x`
    # methods, and `private_class_method` would break the initializers above: those run
    # via `instance_exec` with the Rails::Railtie *instance* as `self`, not this class, so
    # they must call these as `Engine.method_name(...)` with an explicit receiver).

    # Detect which asset pipeline is being used
    def self.detect_asset_pipeline(app)
      if defined?(Propshaft)
        :propshaft
      elsif defined?(Sprockets) && app.config.respond_to?(:assets)
        :sprockets
      elsif importmap_available?(app)
        :importmap
      else
        :modern_bundler
      end
    end

    # Configure Sprockets-based asset pipeline
    def self.configure_sprockets_assets(app)
      app.config.assets.paths << root.join("app", "assets", "stylesheets")
      app.config.assets.paths << root.join("app", "assets", "javascripts")

      # Precompile all CSS and JavaScript assets
      app.config.assets.precompile += %w[
        rails_onboarding/application.css
        rails_onboarding/tooltips.css
        rails_onboarding/utilities.css
        rails_onboarding/accessibility.css
        rails_onboarding/tour.css
        rails_onboarding/mobile.css
        rails_onboarding/milestones.css
        rails_onboarding/progressive_disclosure.css
        rails_onboarding/flash_messages.css
        rails_onboarding/admin.css
        rails_onboarding/application.js
        rails_onboarding/*.js
      ]

      Rails.logger.info "RailsOnboarding: Configured Sprockets asset pipeline"
    end

    # Configure Propshaft-based asset pipeline
    def self.configure_propshaft_assets(app)
      # Propshaft automatically includes all assets from engine paths
      app.config.assets.paths << root.join("app", "assets", "stylesheets")
      app.config.assets.paths << root.join("app", "assets", "javascripts")

      Rails.logger.info "RailsOnboarding: Configured Propshaft asset pipeline"
    end

    # Configure Importmap-based asset loading
    def self.configure_importmap_assets(app)
      # Importmap handles JavaScript, but we still need stylesheets
      if app.config.respond_to?(:assets)
        app.config.assets.paths << root.join("app", "assets", "stylesheets")
      end

      Rails.logger.info "RailsOnboarding: Configured Importmap asset loading"
    end

    # Configure for modern bundlers (ESBuild, Webpack, etc.)
    def self.configure_modern_bundler_assets(app)
      # Add asset paths if assets config is available
      if app.config.respond_to?(:assets)
        app.config.assets.paths << root.join("app", "assets", "stylesheets")
        app.config.assets.paths << root.join("app", "assets", "javascripts")
      end

      Rails.logger.info "RailsOnboarding: Configured for modern bundler (ESBuild/Webpack/etc.)"
    end

    def self.stimulus_available?(app)
      defined?(StimulusRails) &&
        app.config.respond_to?(:stimulus) &&
        app.config.stimulus.respond_to?(:paths)
    end

    def self.setup_stimulus_integration(app)
      begin
        app.config.stimulus.paths << root.join("app", "assets", "javascripts", "rails_onboarding")
        Rails.logger.info "RailsOnboarding: Stimulus integration enabled"
      rescue => e
        Rails.logger.warn "RailsOnboarding: Could not setup Stimulus integration: #{e.message}"
      end
    end

    def self.importmap_available?(app)
      defined?(Importmap) &&
        defined?(Importmap::Map) &&
        app.config.respond_to?(:importmap)
    end

    def self.setup_importmap_integration(app)
      begin
        importmap_path = root.join("config", "importmap.rb")
        if File.exist?(importmap_path)
          # importmap-rails draws app.config.importmap.paths into app.importmap
          # during its own "importmap" initializer, which has already run by the
          # time this after_initialize hook fires - appending to that array here
          # would be a no-op. Draw directly into the live map instead so the
          # engine's pins actually get registered.
          app.importmap.draw(importmap_path)
          Rails.logger.info "RailsOnboarding: Importmap integration enabled"
        end
      rescue => e
        Rails.logger.warn "RailsOnboarding: Could not setup importmap integration: #{e.message}"
      end
    end
  end
end
