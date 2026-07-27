# frozen_string_literal: true

module RailsOnboarding
  # Comprehensive Turbo and Stimulus compatibility for Rails 7+
  # Provides seamless integration with Hotwire stack
  module TurboCompatibility
    extend ActiveSupport::Concern

    included do
      # Enable Turbo Stream responses
      before_action :set_turbo_frame_headers, if: :turbo_frame_request?
      after_action :turbo_stream_response_cleanup, if: :turbo_stream_request?
    end

    module ClassMethods
      # Check if Turbo is available
      def turbo_available?
        defined?(Turbo)
      end

      # Check if Stimulus is available
      def stimulus_available?
        defined?(Stimulus)
      end

      # Configure Turbo integration options
      def configure_turbo_integration(options = {})
        @turbo_integration_options = {
          enable_streams: true,
          enable_native_navigation: true,
          enable_morphing: options.fetch(:enable_morphing, false),
          broadcast_updates: options.fetch(:broadcast_updates, true)
        }.merge(options)
      end

      def turbo_integration_options
        @turbo_integration_options || {}
      end
    end

    # Turbo Frame helpers
    def turbo_frame_request?
      request.headers["Turbo-Frame"].present?
    end

    def turbo_frame_request_id
      request.headers["Turbo-Frame"]
    end

    def turbo_stream_request?
      request.format == :turbo_stream ||
      request.headers["Accept"]&.include?("text/vnd.turbo-stream.html")
    end

    def turbo_native_app?
      request.user_agent.to_s.match?(/Turbo Native/)
    end

    # Respond with appropriate format for Turbo
    def respond_with_turbo(options = {}, &block)
      respond_to do |format|
        format.html do
          if turbo_frame_request?
            render options.merge(layout: false)
          else
            render options
          end
        end

        format.turbo_stream do
          if block_given?
            yield
          else
            render turbo_stream: turbo_stream_actions(options)
          end
        end
      end
    end

    # Generate Turbo Stream actions
    def turbo_stream_actions(options = {})
      actions = []

      if options[:replace]
        actions << turbo_stream.replace(options[:replace], partial: options[:partial])
      end

      if options[:update]
        actions << turbo_stream.update(options[:update], partial: options[:partial])
      end

      if options[:append]
        actions << turbo_stream.append(options[:append], partial: options[:partial])
      end

      if options[:prepend]
        actions << turbo_stream.prepend(options[:prepend], partial: options[:partial])
      end

      if options[:remove]
        actions << turbo_stream.remove(options[:remove])
      end

      actions
    end

    # Broadcast onboarding updates via Turbo Streams
    def broadcast_onboarding_update(user, action, data = {})
      return unless self.class.turbo_integration_options[:broadcast_updates]
      return unless defined?(Turbo::StreamsChannel)

      Turbo::StreamsChannel.broadcast_update_to(
        "onboarding_#{user.id}",
        target: "onboarding-container",
        partial: "rails_onboarding/onboarding/#{action}",
        locals: { user: user, data: data }
      )
    end

    # Helper to safely navigate with Turbo
    def turbo_navigate_to(path, options = {})
      if turbo_stream_request?
        turbo_stream.action(:redirect, path)
      else
        redirect_to path, options
      end
    end

    # Turbo Morphing support (for Turbo 8+)
    def enable_turbo_morphing
      response.headers["X-Turbo-Morph"] = "true" if turbo_morph_supported?
    end

    def turbo_morph_supported?
      return false unless defined?(Turbo)
      # Check if Turbo version supports morphing (8.0+)
      Turbo::VERSION.to_f >= 8.0 rescue false
    end

    # Stimulus controller data attributes
    def stimulus_controller_data(controller_name, values = {})
      data = { controller: "rails-onboarding--#{controller_name}" }

      values.each do |key, value|
        data[:"rails-onboarding--#{controller_name}-#{key}-value"] = value
      end

      data
    end

    # Generate Stimulus action attributes
    def stimulus_action(event, controller, method, params = {})
      action_string = "#{event}->rails-onboarding--#{controller}##{method}"

      unless params.empty?
        param_string = params.map { |k, v| "#{k}:#{v}" }.join(" ")
        action_string += "(#{param_string})"
      end

      { action: action_string }
    end

    # Turbo Frame tag helper
    def turbo_frame_tag_for_onboarding(id, **options, &block)
      if defined?(turbo_frame_tag)
        turbo_frame_tag(id, **options, &block)
      else
        content_tag(:turbo-frame, id: id, **options, &block)
      end
    end

    # Turbo Stream tag helper
    def turbo_stream_tag_for_onboarding(action, target, **options, &block)
      if defined?(turbo_stream)
        turbo_stream.send(action, target, **options, &block)
      else
        # Fallback for older versions
        content_tag("turbo-stream", action: action, target: target, **options, &block)
      end
    end

    # Handle Turbo Confirm dialogs
    def turbo_confirm(message)
      { 'data-turbo-confirm': message }
    end

    # Handle Turbo Method overrides
    def turbo_method(method)
      { 'data-turbo-method': method }
    end

    # Disable Turbo for specific links/forms
    def disable_turbo
      { 'data-turbo': "false" }
    end

    # Enable Turbo permanent elements
    def turbo_permanent
      { 'data-turbo-permanent': "true" }
    end

    private

    def set_turbo_frame_headers
      response.headers["Turbo-Frame"] = turbo_frame_request_id if turbo_frame_request_id
    end

    def turbo_stream_response_cleanup
      # Ensure proper content type for Turbo Stream responses
      response.content_type = "text/vnd.turbo-stream.html" if turbo_stream_request?
    end
  end

  # Railtie for Turbo/Stimulus integration
  class TurboRailtie < Rails::Railtie
    initializer "rails_onboarding.turbo_compatibility", after: :load_config_initializers do
      ActiveSupport.on_load(:action_controller) do
        if defined?(Turbo) || defined?(Stimulus)
          Rails.logger.info "RailsOnboarding: Turbo/Stimulus compatibility enabled"

          # Add Turbo Stream MIME type if not already registered
          unless Mime::Type.lookup_by_extension(:turbo_stream)
            Mime::Type.register "text/vnd.turbo-stream.html", :turbo_stream
          end
        end
      end
    end
  end
end
