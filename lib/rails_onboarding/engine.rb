module RailsOnboarding
  class Engine < ::Rails::Engine
    isolate_namespace RailsOnboarding

    # Make engine's helpers available to the main app
    config.to_prepare do
      ApplicationController.helper(RailsOnboarding::Engine.helpers)
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
      app.config.assets.paths << root.join("app", "assets", "stylesheets")
      app.config.assets.paths << root.join("app", "assets", "javascripts")

      # Precompile assets
      app.config.assets.precompile += %w(
        rails_onboarding/application.css
        rails_onboarding/application.js
        rails_onboarding/onboarding_controller.js
        rails_onboarding/progress_controller.js
        rails_onboarding/navigation_controller.js
        rails_onboarding/tooltip_controller.js
      )
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
        append_view_path RailsOnboarding::Engine.root.join("app", "views")
      end
    end

    # Configure ActionView to find our templates
    config.after_initialize do
      if defined?(ActionView)
        ActionView::Base.prepend_view_path(root.join("app", "views"))
      end
    end

    # Optional: Setup Stimulus integration if available
    config.after_initialize do |app|
      setup_stimulus_integration(app) if stimulus_available?(app)
      setup_importmap_integration(app) if importmap_available?(app)
    end

    private

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
          app.config.importmap.paths << importmap_path
          Rails.logger.info "RailsOnboarding: Importmap integration enabled"
        end
      rescue => e
        Rails.logger.warn "RailsOnboarding: Could not setup importmap integration: #{e.message}"
      end
    end
  end
end
