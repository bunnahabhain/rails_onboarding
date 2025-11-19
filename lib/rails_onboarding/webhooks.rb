# frozen_string_literal: true

require 'net/http'
require 'uri'
require 'json'

module RailsOnboarding
  # Webhook support for notifying external systems of onboarding events
  # Supports multiple webhook endpoints with retry logic and signature verification
  module Webhooks
    extend ActiveSupport::Concern

    module ClassMethods
      # Configure webhook options
      def configure_webhooks(options = {})
        @webhook_options = {
          enabled: options.fetch(:enabled, true),
          endpoints: options.fetch(:endpoints, []),
          secret_key: options.fetch(:secret_key, nil),
          timeout: options.fetch(:timeout, 30),
          retry_limit: options.fetch(:retry_limit, 3),
          retry_delay: options.fetch(:retry_delay, 5),
          verify_ssl: options.fetch(:verify_ssl, true),
          async: options.fetch(:async, true)
        }.merge(options)
      end

      def webhook_options
        @webhook_options || {}
      end

      # Register a webhook endpoint
      def register_webhook(url, events: [], headers: {})
        options = webhook_options
        options[:endpoints] ||= []
        options[:endpoints] << {
          url: url,
          events: events,
          headers: headers,
          enabled: true
        }
        @webhook_options = options
      end

      # Unregister a webhook endpoint
      def unregister_webhook(url)
        options = webhook_options
        options[:endpoints]&.reject! { |endpoint| endpoint[:url] == url }
        @webhook_options = options
      end
    end

    # Trigger webhook for an event
    def trigger_webhook(event_name, payload = {})
      return unless webhooks_enabled?

      endpoints = webhook_endpoints_for_event(event_name)
      return if endpoints.empty?

      endpoints.each do |endpoint|
        if async_webhooks?
          WebhookDeliveryJob.perform_later(endpoint, event_name, payload)
        else
          deliver_webhook(endpoint, event_name, payload)
        end
      end
    end

    # Webhook event helpers
    def webhook_onboarding_started(user)
      trigger_webhook('onboarding.started', {
        user_id: user.id,
        email: user.email,
        started_at: Time.current.iso8601
      })
    end

    def webhook_step_completed(user, step_name)
      trigger_webhook('onboarding.step_completed', {
        user_id: user.id,
        step_name: step_name,
        current_step: user.onboarding_current_step,
        progress_percentage: user.onboarding_progress_percentage,
        completed_at: Time.current.iso8601
      })
    end

    def webhook_step_skipped(user, step_name)
      trigger_webhook('onboarding.step_skipped', {
        user_id: user.id,
        step_name: step_name,
        current_step: user.onboarding_current_step,
        skipped_at: Time.current.iso8601
      })
    end

    def webhook_onboarding_completed(user)
      trigger_webhook('onboarding.completed', {
        user_id: user.id,
        email: user.email,
        completed_at: user.onboarding_completed_at.iso8601,
        total_steps: RailsOnboarding.configuration.steps.size
      })
    end

    def webhook_onboarding_skipped(user)
      trigger_webhook('onboarding.skipped', {
        user_id: user.id,
        email: user.email,
        skipped_at: Time.current.iso8601,
        progress_percentage: user.onboarding_progress_percentage
      })
    end

    def webhook_milestone_achieved(user, milestone_id)
      trigger_webhook('onboarding.milestone_achieved', {
        user_id: user.id,
        milestone_id: milestone_id,
        achieved_at: Time.current.iso8601
      })
    end

    def webhook_tooltip_shown(user, tooltip_id)
      trigger_webhook('onboarding.tooltip_shown', {
        user_id: user.id,
        tooltip_id: tooltip_id,
        shown_at: Time.current.iso8601
      })
    end

    def webhook_tooltip_dismissed(user, tooltip_id)
      trigger_webhook('onboarding.tooltip_dismissed', {
        user_id: user.id,
        tooltip_id: tooltip_id,
        dismissed_at: Time.current.iso8601
      })
    end

    private

    def webhooks_enabled?
      self.class.webhook_options[:enabled] == true
    end

    def async_webhooks?
      self.class.webhook_options[:async] == true
    end

    def webhook_endpoints_for_event(event_name)
      endpoints = self.class.webhook_options[:endpoints] || []
      endpoints.select do |endpoint|
        endpoint[:enabled] != false &&
        (endpoint[:events].empty? || endpoint[:events].include?(event_name))
      end
    end

    def deliver_webhook(endpoint, event_name, payload)
      WebhookDelivery.new(endpoint, event_name, payload, self.class.webhook_options).deliver
    end
  end

  # Webhook delivery class
  class WebhookDelivery
    attr_reader :endpoint, :event_name, :payload, :options

    def initialize(endpoint, event_name, payload, options = {})
      @endpoint = endpoint
      @event_name = event_name
      @payload = payload
      @options = options
    end

    def deliver
      attempt = 0
      max_attempts = options[:retry_limit] || 3

      begin
        attempt += 1
        send_webhook_request
      rescue StandardError => e
        if attempt < max_attempts
          sleep(options[:retry_delay] || 5)
          retry
        else
          log_webhook_failure(e)
          raise e if options[:raise_on_failure]
        end
      end
    end

    private

    def send_webhook_request
      start_time = Time.current
      uri = URI.parse(endpoint[:url])
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == 'https'
      http.verify_mode = options[:verify_ssl] ? OpenSSL::SSL::VERIFY_PEER : OpenSSL::SSL::VERIFY_NONE
      http.read_timeout = options[:timeout] || 30
      http.open_timeout = options[:timeout] || 30

      request = Net::HTTP::Post.new(uri.path)
      request['Content-Type'] = 'application/json'
      request['User-Agent'] = 'RailsOnboarding-Webhook/1.0'
      request['X-Webhook-Event'] = event_name

      # Add custom headers
      endpoint[:headers]&.each do |key, value|
        request[key] = value
      end

      # Add signature if secret key is configured
      if options[:secret_key]
        request['X-Webhook-Signature'] = generate_signature
      end

      # Build webhook payload
      webhook_payload = {
        event: event_name,
        data: payload,
        timestamp: Time.current.iso8601,
        webhook_id: SecureRandom.uuid
      }

      request.body = webhook_payload.to_json

      response = http.request(request)
      duration = Time.current - start_time

      unless response.is_a?(Net::HTTPSuccess)
        # Track failed delivery
        track_webhook_monitoring(
          success: false,
          response_code: response.code,
          error_message: "HTTP #{response.code}: #{response.body}",
          duration: duration
        )
        raise WebhookError, "Webhook failed with status #{response.code}: #{response.body}"
      end

      # Track successful delivery
      track_webhook_monitoring(
        success: true,
        response_code: response.code,
        duration: duration
      )

      log_webhook_success(response)
      response
    rescue StandardError => e
      duration = Time.current - start_time
      # Track failed delivery
      track_webhook_monitoring(
        success: false,
        error_message: e.message,
        duration: duration
      )
      raise
    end

    def generate_signature
      # Use UTC timestamp to avoid timezone edge cases
      # This ensures consistent signature generation regardless of server timezone
      timestamp = Time.now.utc.to_i
      data = "#{event_name}:#{payload.to_json}:#{timestamp}"
      OpenSSL::HMAC.hexdigest('SHA256', options[:secret_key], data)
    end

    def log_webhook_success(response)
      Rails.logger.info "Webhook delivered successfully: #{event_name} to #{endpoint[:url]} (#{response.code})"
    end

    def log_webhook_failure(error)
      Rails.logger.error "Webhook delivery failed: #{event_name} to #{endpoint[:url]} - #{error.message}"
    end

    def track_webhook_monitoring(success:, response_code: nil, error_message: nil, duration: nil)
      return unless defined?(RailsOnboarding::WebhookMonitoring)

      RailsOnboarding::WebhookMonitoring.track_delivery(
        webhook_url: endpoint[:url],
        event_type: event_name,
        success: success,
        response_code: response_code,
        error_message: error_message,
        duration: duration
      )
    rescue StandardError => e
      Rails.logger.warn "Failed to track webhook monitoring: #{e.message}"
    end
  end

  # Custom webhook error
  class WebhookError < StandardError; end

  # Webhook delivery job for async processing
  class WebhookDeliveryJob < ApplicationJob
    queue_as { RailsOnboarding::BackgroundJobs.background_job_options[:queue] || :default }

    retry_on WebhookError, wait: :exponentially_longer, attempts: 3

    def perform(endpoint, event_name, payload)
      options = RailsOnboarding::Webhooks.webhook_options
      delivery = WebhookDelivery.new(endpoint, event_name, payload, options)
      delivery.deliver
    end
  end

  # Webhook verification helper
  module WebhookVerification
    # Verify webhook signature in receiving application
    def verify_webhook_signature(request, secret_key)
      signature = request.headers['X-Webhook-Signature']
      return false unless signature

      event = request.headers['X-Webhook-Event']
      body = request.body.read
      timestamp = JSON.parse(body)['timestamp']

      # Reconstruct signature
      data = "#{event}:#{JSON.parse(body)['data'].to_json}:#{Time.parse(timestamp).to_i}"
      expected_signature = OpenSSL::HMAC.hexdigest('SHA256', secret_key, data)

      ActiveSupport::SecurityUtils.secure_compare(signature, expected_signature)
    rescue StandardError => e
      Rails.logger.error "Webhook signature verification failed: #{e.message}"
      false
    end

    # Extract webhook payload
    def extract_webhook_payload(request)
      body = request.body.read
      JSON.parse(body, symbolize_names: true)
    rescue JSON::ParserError => e
      Rails.logger.error "Failed to parse webhook payload: #{e.message}"
      nil
    end
  end

  # Webhook receiver controller (for testing/development)
  class WebhookReceiverController < ActionController::Base
    include WebhookVerification

    skip_before_action :verify_authenticity_token

    def receive
      if verify_webhook_signature(request, Rails.application.credentials.webhook_secret)
        payload = extract_webhook_payload(request)

        if payload
          process_webhook_event(payload[:event], payload[:data])
          render json: { status: 'success' }, status: :ok
        else
          render json: { error: 'Invalid payload' }, status: :bad_request
        end
      else
        render json: { error: 'Invalid signature' }, status: :unauthorized
      end
    end

    private

    def process_webhook_event(event, data)
      # Process webhook event
      Rails.logger.info "Received webhook event: #{event}"
      Rails.logger.debug "Webhook data: #{data.inspect}"

      # Implement your webhook processing logic here
      case event
      when 'onboarding.started'
        # Handle onboarding started
      when 'onboarding.completed'
        # Handle onboarding completed
      when 'onboarding.step_completed'
        # Handle step completed
      # ... other events
      end
    end
  end
end
