# frozen_string_literal: true

# Background Jobs Integration Example
# This file demonstrates how to use RailsOnboarding with ActiveJob, Sidekiq, etc.

# 1. Configure Background Jobs
# config/initializers/rails_onboarding.rb
RailsOnboarding.configure do |config|
  # Enable background jobs
  config.background_jobs_enabled = true

  # Set queue name
  config.background_jobs_queue = :onboarding

  # Configure mailer
  config.mailer_from = 'onboarding@example.com'
end

# 2. Configure ActiveJob adapter
# config/application.rb
class Application < Rails::Application
  # Use Sidekiq for background jobs
  config.active_job.queue_adapter = :sidekiq
end

# Or in production.rb
# config/environments/production.rb
Rails.application.configure do
  config.active_job.queue_adapter = :sidekiq
end

# 3. Include BackgroundJobs in your model
class User < ApplicationRecord
  include RailsOnboarding::Onboardable
  include RailsOnboarding::BackgroundJobs

  # Send welcome email after user creation
  after_create :send_onboarding_welcome_email

  # Send reminder if onboarding not completed after 24 hours
  after_create :schedule_onboarding_reminder

  private

  def send_onboarding_welcome_email
    queue_onboarding_welcome_email(self)
  end

  def schedule_onboarding_reminder
    queue_onboarding_reminder_email(self)
  end
end

# 4. Controller integration
class OnboardingController < ApplicationController
  include RailsOnboarding::BackgroundJobs

  def complete
    if current_user.complete_onboarding!
      # Send completion email in background
      queue_onboarding_completion_email(current_user)

      # Track analytics in background
      queue_analytics_event('onboarding_completed', current_user, {
        completed_at: current_user.onboarding_completed_at,
        time_taken: time_to_complete
      })

      redirect_to dashboard_path, notice: "Onboarding completed!"
    end
  end

  def complete_step
    step_name = params[:step]

    if current_user.complete_step(step_name)
      # Queue notification
      queue_onboarding_notification(current_user, :step_completed, {
        step: step_name,
        progress: current_user.onboarding_progress_percentage
      })

      # Check for milestone achievements
      check_milestone_achievements(step_name)

      redirect_to onboarding_path
    end
  end

  private

  def check_milestone_achievements(step_name)
    # Find milestones triggered by this step
    milestones = RailsOnboarding.configuration.milestones_for_trigger(
      :onboarding_step_completed,
      { step: step_name.to_sym }
    )

    milestones.each do |milestone|
      unless current_user.milestone_achieved?(milestone[:key])
        queue_milestone_achievement(current_user, milestone[:key])
      end
    end
  end

  def time_to_complete
    return 0 unless current_user.created_at && current_user.onboarding_completed_at
    (current_user.onboarding_completed_at - current_user.created_at).to_i
  end
end

# 5. Email templates
# app/views/rails_onboarding/onboarding_mailer/welcome_email.html.erb
class WelcomeEmailTemplate
  def template
    <<~ERB
      <!DOCTYPE html>
      <html>
        <head>
          <meta content='text/html; charset=UTF-8' http-equiv='Content-Type' />
          <style>
            body { font-family: Arial, sans-serif; line-height: 1.6; }
            .container { max-width: 600px; margin: 0 auto; padding: 20px; }
            .button {
              background-color: #4CAF50;
              color: white;
              padding: 10px 20px;
              text-decoration: none;
              border-radius: 5px;
              display: inline-block;
              margin: 20px 0;
            }
          </style>
        </head>
        <body>
          <div class="container">
            <h1>Welcome to <%= Rails.application.class.module_parent_name %>!</h1>
            <p>Hi <%= @user.email %>,</p>
            <p>We're excited to have you on board. Let's get you started with a quick onboarding process.</p>
            <p>
              <a href="<%= @onboarding_url %>" class="button">Start Onboarding</a>
            </p>
            <p>This will only take a few minutes and will help you get the most out of our platform.</p>
            <p>
              Best regards,<br>
              The <%= Rails.application.class.module_parent_name %> Team
            </p>
          </div>
        </body>
      </html>
    ERB
  end
end

# app/views/rails_onboarding/onboarding_mailer/reminder_email.html.erb
class ReminderEmailTemplate
  def template
    <<~ERB
      <!DOCTYPE html>
      <html>
        <head>
          <meta content='text/html; charset=UTF-8' http-equiv='Content-Type' />
        </head>
        <body>
          <div class="container">
            <h1>Complete Your Onboarding</h1>
            <p>Hi <%= @user.email %>,</p>
            <p>We noticed you haven't finished setting up your account yet.</p>
            <p>You're <%= @progress %>% done! Just a few more steps to go.</p>
            <p>Current step: <%= @current_step.to_s.titleize %></p>
            <p>
              <a href="<%= @onboarding_url %>" class="button">Continue Onboarding</a>
            </p>
          </div>
        </body>
      </html>
    ERB
  end
end

# 6. Custom job with retry logic
class CustomOnboardingJob < RailsOnboarding::ApplicationJob
  queue_as :onboarding

  # Retry with exponential backoff
  retry_on StandardError, wait: :exponentially_longer, attempts: 5

  # Discard after max attempts
  discard_on ActiveJob::DeserializationError

  def perform(user_id, action, data = {})
    user = User.find(user_id)

    case action
    when :send_progress_update
      send_progress_update_email(user, data)
    when :award_bonus_points
      award_bonus_points(user, data)
    when :sync_to_crm
      sync_to_crm(user, data)
    end
  rescue StandardError => e
    Rails.logger.error("CustomOnboardingJob failed: #{e.message}")
    raise e if executions < 3 # Retry up to 3 times
  end

  private

  def send_progress_update_email(user, data)
    # Custom email logic
    OnboardingMailer.progress_update(user, data).deliver_now
  end

  def award_bonus_points(user, data)
    # Award points logic
    user.increment!(:bonus_points, data[:points])
  end

  def sync_to_crm(user, data)
    # CRM sync logic
    CRMService.update_user_onboarding_status(user, data)
  end
end

# 7. Sidekiq configuration
# config/sidekiq.yml
class SidekiqConfiguration
  def config
    <<~YAML
      :concurrency: 5
      :queues:
        - default
        - onboarding
        - mailers

      production:
        :concurrency: 10

      staging:
        :concurrency: 5
    YAML
  end
end

# 8. Integration with Noticed gem for notifications
class OnboardingNotifications
  # Define notification classes
  class StepCompletedNotification < Noticed::Base
    deliver_by :database
    deliver_by :email, mailer: 'RailsOnboarding::OnboardingMailer',
                      method: :step_completed_email
    deliver_by :action_cable, channel: 'NotificationsChannel'

    param :step_name
    param :progress

    def message
      "You completed the #{params[:step_name]} step!"
    end
  end

  class MilestoneAchievedNotification < Noticed::Base
    deliver_by :database
    deliver_by :email
    deliver_by :push_notification if: :mobile_device?

    param :milestone_id
    param :title

    def message
      "Congratulations! You achieved: #{params[:title]}"
    end

    def mobile_device?
      recipient.device_type == 'mobile'
    end
  end
end

# 9. Testing background jobs
RSpec.describe "Background Jobs" do
  include ActiveJob::TestHelper

  let(:user) { create(:user) }

  it "queues welcome email on user creation" do
    expect {
      User.create!(email: 'test@example.com')
    }.to have_enqueued_job(RailsOnboarding::OnboardingMailerJob)
      .with { |user_id, email_type|
        email_type == :welcome
      }
  end

  it "sends completion email when onboarding is completed" do
    perform_enqueued_jobs do
      user.complete_onboarding!
    end

    expect(ActionMailer::Base.deliveries.count).to eq(1)
    email = ActionMailer::Base.deliveries.last
    expect(email.to).to include(user.email)
    expect(email.subject).to include("Congratulations")
  end

  it "queues analytics event" do
    expect {
      controller.queue_analytics_event('step_completed', user, { step: 'welcome' })
    }.to have_enqueued_job(RailsOnboarding::OnboardingAnalyticsJob)
  end
end
