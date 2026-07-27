# frozen_string_literal: true

module RailsOnboarding
  # API Mode support for headless/API-only applications
  # Provides JSON API endpoints for mobile apps and SPAs
  module ApiMode
    extend ActiveSupport::Concern

    included do
      # Skip CSRF for API requests (only works with ActionController classes)
      begin
        skip_before_action :verify_authenticity_token, if: :api_request?, raise: false
      rescue NoMethodError
        # Not an ActionController class, skip this setup
      end

      # Set API response format (only works with ActionController classes)
      begin
        before_action :set_api_response_format, if: :api_request?
      rescue NoMethodError
        # Not an ActionController class, skip this setup
      end

      # Error handling (only works with ActionController classes)
      begin
        rescue_from StandardError, with: :handle_api_error if :api_request?
      rescue NoMethodError
        # Not an ActionController class, skip this setup
      end
    end

    module ClassMethods
      # Enable API mode for specific actions
      def enable_api_mode(options = {})
        @api_mode_options = {
          version: options.fetch(:version, "v1"),
          authentication: options.fetch(:authentication, :token),
          serializer: options.fetch(:serializer, :active_model_serializers),
          rate_limiting: options.fetch(:rate_limiting, true),
          pagination: options.fetch(:pagination, true)
        }.merge(options)
      end

      def api_mode_options
        @api_mode_options || {}
      end

      # Check if API mode is enabled
      def api_mode_enabled?
        @api_mode_options.present?
      end
    end

    # Detect API requests
    def api_request?
      request.format.json? ||
      request.path.start_with?("/api/") ||
      request.headers["Accept"]&.include?("application/json") ||
      request.headers["Content-Type"]&.include?("application/json")
    end

    # API response helpers
    def render_api_success(data, status: :ok, meta: {})
      render json: {
        success: true,
        data: serialize_for_api(data),
        meta: build_api_meta(meta)
      }, status: status
    end

    def render_api_error(message, status: :unprocessable_entity, errors: {})
      render json: {
        success: false,
        error: {
          message: message,
          details: errors
        },
        meta: build_api_meta
      }, status: status
    end

    # Onboarding-specific API methods
    def api_onboarding_status
      render_api_success({
        onboarding_completed: current_user.onboarding_completed?,
        onboarding_skipped: current_user.onboarding_skipped?,
        current_step: current_user.onboarding_current_step,
        progress_percentage: current_user.onboarding_progress_percentage,
        steps: api_format_steps,
        next_step: api_next_step,
        previous_step: api_previous_step
      })
    end

    def api_complete_step
      step_name = params[:step_name] || params[:step]

      if current_user.complete_step(step_name)
        render_api_success({
          message: "Step '#{step_name}' completed successfully",
          current_step: current_user.onboarding_current_step,
          progress_percentage: current_user.onboarding_progress_percentage,
          onboarding_completed: current_user.onboarding_completed?
        })
      else
        render_api_error("Failed to complete step '#{step_name}'", errors: current_user.errors.full_messages)
      end
    end

    def api_skip_step
      step_name = params[:step_name] || params[:step]

      if current_user.skip_step(step_name)
        render_api_success({
          message: "Step '#{step_name}' skipped successfully",
          current_step: current_user.onboarding_current_step,
          progress_percentage: current_user.onboarding_progress_percentage
        })
      else
        render_api_error("Failed to skip step '#{step_name}'", errors: current_user.errors.full_messages)
      end
    end

    def api_complete_onboarding
      if current_user.complete_onboarding!
        render_api_success({
          message: "Onboarding completed successfully",
          completed_at: current_user.onboarding_completed_at
        })
      else
        render_api_error("Failed to complete onboarding", errors: current_user.errors.full_messages)
      end
    end

    def api_restart_onboarding
      if current_user.restart_onboarding!
        render_api_success({
          message: "Onboarding restarted successfully",
          current_step: current_user.onboarding_current_step,
          progress_percentage: 0
        })
      else
        render_api_error("Failed to restart onboarding", errors: current_user.errors.full_messages)
      end
    end

    def api_tooltips_list
      tooltips = current_user.available_tooltips

      render_api_success({
        tooltips: tooltips.map do |tooltip|
          {
            id: tooltip[:id],
            title: tooltip[:title],
            content: tooltip[:content],
            target: tooltip[:target],
            position: tooltip[:position],
            shown: current_user.tooltip_shown?(tooltip[:id])
          }
        end
      })
    end

    def api_dismiss_tooltip
      tooltip_id = params[:tooltip_id]

      if current_user.dismiss_tooltip(tooltip_id)
        render_api_success({
          message: "Tooltip dismissed successfully",
          tooltip_id: tooltip_id
        })
      else
        render_api_error("Failed to dismiss tooltip")
      end
    end

    # API authentication
    def authenticate_api_request!
      return if current_user.present?

      token = extract_api_token

      if token.blank?
        render_api_error("Missing authentication token", status: :unauthorized)
        return
      end

      user = authenticate_with_token(token)

      if user
        # Set current_user for the request
        instance_variable_set(:@current_user, user)
      else
        render_api_error("Invalid authentication token", status: :unauthorized)
      end
    end

    # Current user accessor for API requests
    def current_user
      @current_user ||= begin
        token = extract_api_token
        authenticate_with_token(token) if token.present?
      end
    end

    private

    # Serialize data for API response
    def serialize_for_api(data)
      case self.class.api_mode_options[:serializer]
      when :active_model_serializers
        # Use ActiveModel::Serializers if available
        if defined?(ActiveModel::Serializer)
          ActiveModelSerializers::SerializableResource.new(data).as_json
        else
          data.as_json
        end
      when :jsonapi
        # Use JSONAPI::Serializer if available
        if defined?(JSONAPI::Serializer)
          data.to_json
        else
          data.as_json
        end
      else
        # Default to as_json
        data.respond_to?(:as_json) ? data.as_json : data
      end
    end

    # Build API metadata
    def build_api_meta(custom_meta = {})
      {
        timestamp: Time.current.iso8601,
        version: self.class.api_mode_options[:version] || "v1",
        request_id: request.request_id
      }.merge(custom_meta)
    end

    # Format steps for API
    def api_format_steps
      RailsOnboarding.configuration.steps.map do |step|
        {
          name: step[:name],
          title: step[:title],
          description: step[:description],
          icon: step[:icon],
          skippable: step[:skippable],
          completed: current_user.step_completed?(step[:name])
        }
      end
    end

    # Get next step for API
    def api_next_step
      next_step = current_user.next_step
      return nil unless next_step

      {
        name: next_step[:name],
        title: next_step[:title],
        description: next_step[:description]
      }
    end

    # Get previous step for API
    def api_previous_step
      prev_step = current_user.previous_step
      return nil unless prev_step

      {
        name: prev_step[:name],
        title: prev_step[:title],
        description: prev_step[:description]
      }
    end

    # Extract the API token from the request. Tokens are only read from
    # request headers, never from query parameters: a token in the URL leaks
    # into server and proxy access logs, browser history, and the Referer
    # header sent to third parties.
    def extract_api_token
      authorization = request.headers["Authorization"]
      # Authorization: Bearer <token> (also tolerates a bare token value)
      return authorization.split(" ").last if authorization.present?

      # Custom header for clients that can't set Authorization
      request.headers["X-API-Token"].presence
    end

    # Authenticate user with token
    def authenticate_with_token(token)
      # This should be implemented by the host application
      # Default implementation uses a simple token check
      user_class = RailsOnboarding.configuration.user_class_name.constantize

      if user_class.respond_to?(:find_by_api_token)
        user_class.find_by_api_token(token)
      elsif user_class.column_names.include?("api_token")
        user_class.find_by(api_token: token)
      else
        # Raise error if no token authentication method is available
        raise NotImplementedError,
          "API token authentication not configured. Please add an 'api_token' column to your User model " \
          "or implement a custom 'find_by_api_token' class method. See documentation for more details."
      end
    end

    # Set API response format
    def set_api_response_format
      request.format = :json
    end

    # Handle API errors
    def handle_api_error(exception)
      Rails.logger.error("API Error: #{exception.class} - #{exception.message}")
      Rails.logger.error(exception.backtrace.join("\n"))

      render_api_error(
        "An error occurred: #{exception.message}",
        status: :internal_server_error
      )
    end
  end

  # API Controller for dedicated API endpoints
  class ApiController < ActionController::API
    include RailsOnboarding::ApiMode

    before_action :authenticate_api_request!

    # GET /api/onboarding/status
    def status
      api_onboarding_status
    end

    # POST /api/onboarding/steps/:step_name/complete
    def complete_step
      api_complete_step
    end

    # POST /api/onboarding/steps/:step_name/skip
    def skip_step
      api_skip_step
    end

    # POST /api/onboarding/complete
    def complete
      api_complete_onboarding
    end

    # POST /api/onboarding/restart
    def restart
      api_restart_onboarding
    end

    # GET /api/onboarding/tooltips
    def tooltips
      api_tooltips_list
    end

    # POST /api/onboarding/tooltips/:tooltip_id/dismiss
    def dismiss_tooltip
      api_dismiss_tooltip
    end
  end
end
