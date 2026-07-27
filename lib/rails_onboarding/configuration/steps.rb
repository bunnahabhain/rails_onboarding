module RailsOnboarding
  class Configuration
    # Onboarding step configuration and lookups.
    module Steps
      attr_accessor :onboarding_required_for

      # Reads the active RailsOnboarding::Flow from the admin Flow Editor when one
      # exists, falling back to the statically-configured steps otherwise. This
      # keeps "activate a flow" a real, shared, durable change instead of a
      # per-process global mutation - every process re-checks the database
      # instead of caching a value that could go stale the moment another
      # process (or another admin) activates a different flow.
      def steps
        flow_steps = active_flow_steps
        return hydrate_code_options(flow_steps) if flow_steps

        tenant_override(:steps, @steps)
      end

      # Override setter to clear cache when configuration changes
      def steps=(value)
        clear_cache!
        @steps = value
      end

      def total_steps
        @total_steps ||= steps.size
      end

      def step_by_name(name)
        return nil if name.nil?

        @step_by_name_cache ||= {}
        @step_by_name_cache[name.to_sym] ||= steps.find do |s|
          next false unless s.is_a?(Hash) && s[:name]
          s[:name].to_sym == name.to_sym
        end
      end

      def step_index(name)
        return nil if name.nil?

        @step_index_cache ||= {}
        @step_index_cache[name.to_sym] ||= steps.find_index do |s|
          next false unless s.is_a?(Hash) && s[:name]
          s[:name].to_sym == name.to_sym
        end
      end

      private

      def active_flow_steps
        return nil unless defined?(RailsOnboarding::Flow)
        return nil unless RailsOnboarding::Flow.table_exists?

        RailsOnboarding::Flow.active.first&.steps
      rescue StandardError
        nil
      end

      # A flow persisted by the admin Flow Editor is stored as JSON, so any
      # Proc-valued step option (:path, :complete_if, or a custom callable) was
      # silently dropped on write - JSON can't serialize a Proc. Merge those
      # code-only options back in from the statically-configured step of the
      # same name, so activating a flow never disables a path-based step or its
      # completion criteria. Presentation and ordering still come entirely from
      # the flow; only behavior that can only live in code is re-hydrated.
      def hydrate_code_options(flow_steps)
        config_by_name = Array(@steps).each_with_object({}) do |step, index|
          index[step[:name].to_sym] = step if step.is_a?(Hash) && step[:name]
        end
        return Array(flow_steps) if config_by_name.empty?

        Array(flow_steps).map do |flow_step|
          name = flow_step[:name] if flow_step.respond_to?(:[])
          config_step = name && config_by_name[name.to_sym]
          next flow_step unless config_step

          code_options = config_step.select { |_key, value| value.is_a?(Proc) }
          next flow_step if code_options.empty?

          hydrated = flow_step.dup
          code_options.each { |key, value| hydrated[key] = value }
          hydrated
        end
      end

      def initialize_steps
        @onboarding_required_for = :new_users # :new_users, :all_users, or a Proc

        # Default steps - can be customized
        @steps = [
          {
            name: :welcome,
            title: "Welcome",
            icon: "🎉",
            skippable: true
          },
          {
            name: :profile,
            title: "Setup Profile",
            icon: "👤",
            skippable: false
          },
          {
            name: :first_action,
            title: "First Action",
            icon: "🚀",
            skippable: false
          },
          {
            name: :explore,
            title: "Explore Features",
            icon: "🔍",
            skippable: true
          }
        ]
      end
    end
  end
end
