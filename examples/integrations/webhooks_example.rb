# frozen_string_literal: true

# Webhooks Integration Example
# This file demonstrates how to use webhooks to notify external systems

# 1. Configure Webhooks
# config/initializers/rails_onboarding.rb
RailsOnboarding.configure do |config|
  # Enable webhooks
  config.webhooks_enabled = true

  # Set secret key for signature verification
  config.webhook_secret_key = ENV['WEBHOOK_SECRET_KEY']

  # Enable async delivery (recommended for production)
  config.webhook_async = true

  # Configure webhook endpoints
  config.webhook_endpoints = [
    {
      url: ENV['WEBHOOK_URL'],
      events: [], # Empty = all events
      headers: {
        'X-API-Key' => ENV['EXTERNAL_API_KEY']
      },
      enabled: true
    },
    {
      url: 'https://analytics.example.com/webhooks',
      events: ['onboarding.completed', 'onboarding.step_completed'],
      headers: {},
      enabled: true
    }
  ]
end

# 2. Include Webhooks in controller
class OnboardingController < ApplicationController
  include RailsOnboarding::Webhooks

  def show
    # Trigger webhook when user starts onboarding
    webhook_onboarding_started(current_user) if current_user.onboarding_just_started?

    @current_step = current_user.current_onboarding_step
  end

  def complete_step
    step_name = params[:step]

    if current_user.complete_step(step_name)
      # Trigger webhook for step completion
      webhook_step_completed(current_user, step_name)

      redirect_to onboarding_path
    end
  end

  def skip
    if params[:step]
      # Trigger webhook for step skip
      webhook_step_skipped(current_user, params[:step])
    end

    redirect_to onboarding_path
  end

  def complete
    if current_user.complete_onboarding!
      # Trigger webhook for onboarding completion
      webhook_onboarding_completed(current_user)

      redirect_to dashboard_path, notice: "Onboarding completed!"
    end
  end
end

# 3. Dynamic webhook registration
class WebhooksManagementService
  def self.register_webhook(url, events: [], headers: {})
    RailsOnboarding::Webhooks.register_webhook(
      url,
      events: events,
      headers: headers
    )
  end

  def self.unregister_webhook(url)
    RailsOnboarding::Webhooks.unregister_webhook(url)
  end

  # Example: Register webhook for a tenant
  def self.register_tenant_webhook(tenant)
    register_webhook(
      tenant.webhook_url,
      events: ['onboarding.completed'],
      headers: { 'X-Tenant-ID' => tenant.id.to_s }
    )
  end
end

# 4. Receiving webhooks in external application
class WebhooksController < ApplicationController
  include RailsOnboarding::WebhookVerification

  skip_before_action :verify_authenticity_token
  before_action :verify_webhook

  def receive
    payload = extract_webhook_payload(request)

    if payload
      process_webhook_event(payload[:event], payload[:data])
      render json: { status: 'success' }, status: :ok
    else
      render json: { error: 'Invalid payload' }, status: :bad_request
    end
  end

  private

  def verify_webhook
    secret = ENV['WEBHOOK_SECRET_KEY']

    unless verify_webhook_signature(request, secret)
      render json: { error: 'Invalid signature' }, status: :unauthorized
    end
  end

  def process_webhook_event(event, data)
    case event
    when 'onboarding.started'
      handle_onboarding_started(data)
    when 'onboarding.step_completed'
      handle_step_completed(data)
    when 'onboarding.completed'
      handle_onboarding_completed(data)
    when 'onboarding.skipped'
      handle_onboarding_skipped(data)
    when 'onboarding.milestone_achieved'
      handle_milestone_achieved(data)
    else
      Rails.logger.info "Unhandled webhook event: #{event}"
    end
  end

  def handle_onboarding_started(data)
    user_id = data['user_id']
    # Sync to CRM
    CRMService.update_user_status(user_id, 'onboarding_started')
    # Send to analytics
    AnalyticsService.track('Onboarding Started', data)
  end

  def handle_step_completed(data)
    user_id = data['user_id']
    step_name = data['step_name']
    progress = data['progress_percentage']

    # Update progress in external system
    ExternalService.update_progress(user_id, step_name, progress)
  end

  def handle_onboarding_completed(data)
    user_id = data['user_id']
    completed_at = data['completed_at']

    # Trigger downstream processes
    WelcomeSequenceService.start(user_id)
    RewardsService.award_completion_bonus(user_id)

    # Send to analytics
    AnalyticsService.track('Onboarding Completed', {
      user_id: user_id,
      completed_at: completed_at,
      total_steps: data['total_steps']
    })
  end

  def handle_milestone_achieved(data)
    user_id = data['user_id']
    milestone_id = data['milestone_id']

    # Award points in external system
    PointsService.award_milestone(user_id, milestone_id)
  end
end

# 5. Custom webhook delivery with retry logic
class CustomWebhookDelivery
  def self.deliver_with_retry(endpoint, event_name, payload)
    max_attempts = 5
    attempt = 0

    begin
      attempt += 1
      deliver_webhook(endpoint, event_name, payload)
    rescue StandardError => e
      if attempt < max_attempts
        delay = [2**attempt, 60].min # Exponential backoff, max 60 seconds
        sleep(delay)
        retry
      else
        Rails.logger.error("Webhook delivery failed after #{max_attempts} attempts: #{e.message}")
        # Store failed webhook for manual retry
        FailedWebhook.create!(
          endpoint_url: endpoint[:url],
          event_name: event_name,
          payload: payload,
          error_message: e.message,
          attempts: max_attempts
        )
      end
    end
  end

  def self.deliver_webhook(endpoint, event_name, payload)
    delivery = RailsOnboarding::WebhookDelivery.new(
      endpoint,
      event_name,
      payload,
      RailsOnboarding.configuration
    )
    delivery.deliver
  end
end

# 6. Webhook monitoring and logging
class WebhookMonitoring
  def self.log_webhook_delivery(endpoint_url, event_name, success, response_code = nil, error = nil)
    WebhookLog.create!(
      endpoint_url: endpoint_url,
      event_name: event_name,
      delivered: success,
      response_code: response_code,
      error_message: error&.message,
      delivered_at: Time.current
    )
  end

  def self.webhook_statistics(days = 7)
    WebhookLog.where('created_at >= ?', days.days.ago).group(:event_name).count
  end

  def self.failed_webhooks(days = 1)
    WebhookLog.where(delivered: false)
              .where('created_at >= ?', days.days.ago)
              .order(created_at: :desc)
  end
end

# 7. Zapier integration example
class ZapierWebhookIntegration
  def self.configure_zapier
    RailsOnboarding.configure do |config|
      config.webhook_endpoints << {
        url: ENV['ZAPIER_WEBHOOK_URL'],
        events: ['onboarding.completed'],
        headers: {},
        enabled: true
      }
    end
  end

  # Zapier payload format
  def self.format_for_zapier(user, event_data)
    {
      user: {
        id: user.id,
        email: user.email,
        name: user.name
      },
      event: event_data,
      timestamp: Time.current.iso8601
    }
  end
end

# 8. Slack notification via webhook
class SlackWebhookIntegration
  def self.send_completion_to_slack(user)
    webhook_url = ENV['SLACK_WEBHOOK_URL']
    return unless webhook_url

    payload = {
      text: "🎉 New user completed onboarding!",
      attachments: [
        {
          color: "good",
          fields: [
            {
              title: "User",
              value: user.email,
              short: true
            },
            {
              title: "Completed At",
              value: user.onboarding_completed_at.strftime("%Y-%m-%d %H:%M"),
              short: true
            },
            {
              title: "Milestones Achieved",
              value: user.achieved_milestones.count.to_s,
              short: true
            }
          ]
        }
      ]
    }

    HTTP.post(webhook_url, json: payload)
  end
end

# 9. Testing webhooks
RSpec.describe "Webhooks Integration" do
  let(:user) { create(:user) }
  let(:webhook_url) { 'https://example.com/webhook' }

  before do
    RailsOnboarding.configure do |config|
      config.webhooks_enabled = true
      config.webhook_secret_key = 'test_secret'
      config.webhook_async = false # Test synchronously
      config.webhook_endpoints = [
        { url: webhook_url, events: [], enabled: true }
      ]
    end
  end

  it "delivers webhook on onboarding completion" do
    stub_request(:post, webhook_url)
      .to_return(status: 200, body: '{"status": "success"}')

    user.complete_onboarding!

    expect(WebMock).to have_requested(:post, webhook_url)
      .with { |req|
        body = JSON.parse(req.body)
        body['event'] == 'onboarding.completed' &&
        body['data']['user_id'] == user.id
      }
  end

  it "includes signature in webhook headers" do
    stub_request(:post, webhook_url)

    user.complete_onboarding!

    expect(WebMock).to have_requested(:post, webhook_url)
      .with(headers: {'X-Webhook-Signature' => /.+/})
  end

  it "verifies webhook signatures" do
    controller = WebhooksController.new
    request = double('request')
    allow(request).to receive(:headers).and_return({
      'X-Webhook-Signature' => 'valid_signature',
      'X-Webhook-Event' => 'onboarding.completed'
    })
    allow(request).to receive(:body).and_return(double(read: '{"event":"onboarding.completed"}'))

    # Mock verification
    expect(controller).to receive(:verify_webhook_signature).and_return(true)
  end
end

# 10. Rake task to retry failed webhooks
namespace :webhooks do
  desc "Retry failed webhook deliveries"
  task retry_failed: :environment do
    FailedWebhook.where(retried: false).find_each do |failed|
      puts "Retrying webhook: #{failed.event_name} to #{failed.endpoint_url}"

      begin
        CustomWebhookDelivery.deliver_webhook(
          { url: failed.endpoint_url },
          failed.event_name,
          failed.payload
        )

        failed.update(retried: true, retried_at: Time.current)
        puts "✓ Success"
      rescue StandardError => e
        puts "✗ Failed: #{e.message}"
      end
    end
  end
end
