require "rails/generators/base"
require "rails_onboarding/version"

module RailsOnboarding
  module Generators
    # Re-copies the gem's Stimulus controllers into a bundler-based host app so
    # that a gem upgrade actually reaches the app. esbuild/webpack/vite apps
    # bundle their own copy of these controllers (see docs/ESBUILD_SETUP.md) rather
    # than importing them from the engine the way importmap apps do, so the copy
    # goes stale on every gem bump unless it is re-synced. This generator is that
    # re-sync step - run it after updating the gem:
    #
    #   bin/rails generate rails_onboarding:update
    #   bin/rails generate rails_onboarding:update --path some/other/dir
    #
    # It copies the controllers flat into app/javascript/controllers (so Stimulus
    # derives the flat identifiers the gem's views use - onboarding, tooltip,
    # progress, ... - not prefixed rails-onboarding--* ones; see docs/ESBUILD_SETUP.md).
    # The gem's application.js is intentionally NOT copied: it would clobber the
    # host's own controllers/application.js entrypoint, and nothing imports it.
    #
    # It overwrites the vendored controllers unconditionally (that is the point -
    # they are meant to mirror the gem, so there is nothing to preserve), but is
    # deliberately scoped to those files ONLY: it never touches your initializer,
    # migrations, rails_onboarding_custom.css, or your onboarding step views.
    # Importmap apps don't need it (they import the controllers from the gem).
    class UpdateGenerator < Rails::Generators::Base
      source_root File.expand_path("../../../app/assets/javascripts/rails_onboarding", __dir__)

      # Written into the destination so the engine's boot-time staleness check
      # (see Engine.warn_if_controllers_stale) can tell which gem version the
      # copied controllers came from. Keep in sync with that constant.
      VERSION_MARKER = ".rails_onboarding_version".freeze

      class_option :path, type: :string,
                          default: "app/javascript/controllers",
                          desc: "Destination directory for the copied Stimulus controllers"

      def copy_controllers
        controller_paths.each do |rel|
          copy_file rel, File.join(dest_dir, rel), force: true
        end
      end

      def stamp_version
        create_file File.join(dest_dir, VERSION_MARKER),
                    "#{RailsOnboarding::VERSION}\n", force: true
      end

      def print_next_steps
        say ""
        say "rails_onboarding: synced #{controller_paths.size} controller(s) to " \
            "#{dest_dir} (v#{RailsOnboarding::VERSION}).", :green
        say "Next, re-register the controllers and rebuild your JS bundle:", :yellow
        say "  bin/rails stimulus:manifest:update   # if you use stimulus-rails", :yellow
        say "  yarn build                           # or your bundler's build command", :yellow
      end

      private

      def dest_dir
        options[:path]
      end

      # Every *_controller.js the gem ships (top-level + the admin/ subfolder,
      # which yields admin--* identifiers), as paths relative to source_root.
      # Globbing *_controller.js deliberately excludes application.js.
      def controller_paths
        @controller_paths ||= Dir.glob("**/*_controller.js", base: self.class.source_root).sort
      end
    end
  end
end
