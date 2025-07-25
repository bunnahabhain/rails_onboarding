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

    # Load JavaScript and CSS
    initializer "rails_onboarding.assets" do |app|
      app.config.assets.paths << root.join("app", "assets", "stylesheets")
      app.config.assets.paths << root.join("app", "assets", "javascripts")
      app.config.assets.precompile += %w(
        rails_onboarding/application.css
        rails_onboarding/application.js
      )
    end

    # Include concerns in host app models
    initializer "rails_onboarding.include_concerns" do
      ActiveSupport.on_load(:active_record) do
        include RailsOnboarding::Onboardable if defined?(RailsOnboarding::Onboardable)
      end
    end

    # Add engine's controller methods to ApplicationController
    initializer "rails_onboarding.controller_helpers" do
      ActiveSupport.on_load(:action_controller_base) do
        include RailsOnboarding::ControllerHelpers
      end
    end
  end
end
