# frozen_string_literal: true

module RailsOnboarding
  # Background job support for queuing emails and notifications
  # Compatible with ActiveJob, Sidekiq, Resque, and DelayedJob
  module BackgroundJobs
    extend ActiveSupport::Concern

    module ClassMethods
      # Configure background job options
      def configure_background_jobs(options = {})
        @background_job_options = {
          adapter: options.fetch(:adapter, :active_job),
          queue: options.fetch(:queue, :default),
          enable_emails: options.fetch(:enable_emails, true),
          enable_notifications: options.fetch(:enable_notifications, true),
          retry_limit: options.fetch(:retry_limit, 3),
          retry_delay: options.fetch(:retry_delay, 5.minutes)
        }.merge(options)
      end

      def background_job_options
        @background_job_options || {}
      end
    end

    # Queue onboarding emails
    def queue_onboarding_welcome_email(user)
      return unless background_jobs_enabled?(:emails)

      OnboardingMailerJob.perform_later(user.id, :welcome)
    end

    def queue_onboarding_reminder_email(user)
      return unless background_jobs_enabled?(:emails)

      OnboardingMailerJob.set(wait: 1.day).perform_later(user.id, :reminder)
    end

    def queue_onboarding_completion_email(user)
      return unless background_jobs_enabled?(:emails)

      OnboardingMailerJob.perform_later(user.id, :completion)
    end

    # Queue notifications
    def queue_onboarding_notification(user, notification_type, data = {})
      return unless background_jobs_enabled?(:notifications)

      OnboardingNotificationJob.perform_later(user.id, notification_type, data)
    end

    # Queue analytics events
    def queue_analytics_event(event_name, user, data = {})
      OnboardingAnalyticsJob.perform_later(event_name, user.id, data)
    end

    # Queue milestone achievements
    def queue_milestone_achievement(user, milestone_id)
      MilestoneAchievementJob.perform_later(user.id, milestone_id)
    end

    private

    def background_jobs_enabled?(type = nil)
      options = self.class.background_job_options
      return false if options.empty?

      case type
      when :emails
        options[:enable_emails]
      when :notifications
        options[:enable_notifications]
      else
        true
      end
    end
  end

  # Base job class for RailsOnboarding
  class ApplicationJob < ActiveJob::Base
    # Automatically retry jobs that encountered a deadlock
    retry_on ActiveRecord::Deadlocked

    # Most jobs are safe to ignore if the underlying records are no longer available
    discard_on ActiveJob::DeserializationError

    queue_as :default

    def self.queue_name
      RailsOnboarding::BackgroundJobs.background_job_options[:queue] || :default
    end
  end

  # Job for sending onboarding emails
  class OnboardingMailerJob < ApplicationJob
    queue_as { RailsOnboarding::BackgroundJobs.background_job_options[:queue] || :default }

    def perform(user_id, email_type)
      user = find_user(user_id)
      return unless user

      case email_type.to_sym
      when :welcome
        OnboardingMailer.welcome_email(user).deliver_now
      when :reminder
        # Only send reminder if onboarding is not completed
        OnboardingMailer.reminder_email(user).deliver_now unless user.onboarding_completed?
      when :completion
        OnboardingMailer.completion_email(user).deliver_now
      when :step_completed
        OnboardingMailer.step_completed_email(user).deliver_now
      else
        Rails.logger.warn "Unknown email type: #{email_type}"
      end
    rescue StandardError => e
      Rails.logger.error "Failed to send onboarding email: #{e.message}"
      raise e if should_retry?
    end

    private

    def find_user(user_id)
      user_class = RailsOnboarding.configuration.user_class_name.constantize
      user_class.find_by(id: user_id)
    end

    def should_retry?
      executions < (RailsOnboarding::BackgroundJobs.background_job_options[:retry_limit] || 3)
    end
  end

  # Job for sending onboarding notifications
  class OnboardingNotificationJob < ApplicationJob
    queue_as { RailsOnboarding::BackgroundJobs.background_job_options[:queue] || :default }

    def perform(user_id, notification_type, data = {})
      user = find_user(user_id)
      return unless user

      # Create notification record if notification system exists
      if defined?(Noticed) && user.respond_to?(:notifications)
        # Using Noticed gem
        create_noticed_notification(user, notification_type, data)
      elsif user.respond_to?(:notify)
        # Custom notification system
        user.notify(notification_type, data)
      else
        # Fallback: log notification
        Rails.logger.info "Onboarding notification for user #{user_id}: #{notification_type}"
      end
    rescue StandardError => e
      Rails.logger.error "Failed to send notification: #{e.message}"
      raise e if should_retry?
    end

    private

    def find_user(user_id)
      user_class = RailsOnboarding.configuration.user_class_name.constantize
      user_class.find_by(id: user_id)
    end

    def create_noticed_notification(user, notification_type, data)
      notification_class = "RailsOnboarding::#{notification_type.to_s.camelize}Notification"

      if Object.const_defined?(notification_class)
        notification_class.constantize.with(data).deliver(user)
      else
        Rails.logger.warn "Notification class not found: #{notification_class}"
      end
    end

    def should_retry?
      executions < (RailsOnboarding::BackgroundJobs.background_job_options[:retry_limit] || 3)
    end
  end

  # Job for tracking analytics events
  class OnboardingAnalyticsJob < ApplicationJob
    queue_as { RailsOnboarding::BackgroundJobs.background_job_options[:queue] || :default }

    def perform(event_name, user_id, data = {})
      user = find_user(user_id)
      return unless user

      # Create analytics event
      if defined?(RailsOnboarding::AnalyticsEvent)
        RailsOnboarding::AnalyticsEvent.create!(
          event_name: event_name,
          user_id: user_id,
          event_data: data,
          occurred_at: Time.current
        )
      end

      # Send to external analytics services
      track_external_analytics(event_name, user, data)
    rescue StandardError => e
      Rails.logger.error "Failed to track analytics event: #{e.message}"
      # Don't retry analytics events - they're not critical
    end

    private

    def find_user(user_id)
      user_class = RailsOnboarding.configuration.user_class_name.constantize
      user_class.find_by(id: user_id)
    end

    def track_external_analytics(event_name, user, data)
      # Integrate with external analytics services
      # Segment
      if defined?(Analytics)
        Analytics.track(
          user_id: user.id,
          event: "Onboarding: #{event_name}",
          properties: data
        )
      end

      # Mixpanel
      if defined?(Mixpanel)
        Mixpanel.track(user.id, "Onboarding: #{event_name}", data)
      end

      # Google Analytics 4
      if defined?(Gabba)
        # Track with GA4
      end
    rescue StandardError => e
      Rails.logger.warn "Failed to track to external analytics: #{e.message}"
      # Don't raise - external analytics failures shouldn't break the job
    end
  end

  # Job for processing milestone achievements
  class MilestoneAchievementJob < ApplicationJob
    queue_as { RailsOnboarding::BackgroundJobs.background_job_options[:queue] || :default }

    def perform(user_id, milestone_id)
      user = find_user(user_id)
      return unless user

      milestone = find_milestone(milestone_id)
      return unless milestone

      # Award milestone
      if user.respond_to?(:award_milestone)
        user.award_milestone(milestone)
      end

      # Send celebration notification
      if defined?(RailsOnboarding::OnboardingNotificationJob)
        RailsOnboarding::OnboardingNotificationJob.perform_later(
          user_id,
          :milestone_achieved,
          { milestone_id: milestone_id, title: milestone[:title] }
        )
      end

      # Track analytics
      if defined?(RailsOnboarding::OnboardingAnalyticsJob)
        RailsOnboarding::OnboardingAnalyticsJob.perform_later(
          'milestone_achieved',
          user_id,
          { milestone_id: milestone_id }
        )
      end
    rescue StandardError => e
      Rails.logger.error "Failed to process milestone achievement: #{e.message}"
      raise e if should_retry?
    end

    private

    def find_user(user_id)
      user_class = RailsOnboarding.configuration.user_class_name.constantize
      user_class.find_by(id: user_id)
    end

    def find_milestone(milestone_id)
      RailsOnboarding.configuration.milestones.find { |m| m[:id] == milestone_id }
    end

    def should_retry?
      executions < (RailsOnboarding::BackgroundJobs.background_job_options[:retry_limit] || 3)
    end
  end

  # Mailer for onboarding emails
  class OnboardingMailer < ActionMailer::Base
    default from: -> { RailsOnboarding.configuration.mailer_from || 'noreply@example.com' }

    def welcome_email(user)
      @user = user
      @onboarding_url = Rails.application.routes.url_helpers.rails_onboarding_onboarding_url

      mail(
        to: user.email,
        subject: I18n.t('rails_onboarding.mailer.welcome.subject', default: 'Welcome! Get Started')
      )
    end

    def reminder_email(user)
      @user = user
      @current_step = user.onboarding_current_step
      @progress = user.onboarding_progress_percentage
      @onboarding_url = Rails.application.routes.url_helpers.rails_onboarding_onboarding_url

      mail(
        to: user.email,
        subject: I18n.t('rails_onboarding.mailer.reminder.subject', default: 'Complete Your Onboarding')
      )
    end

    def completion_email(user)
      @user = user
      @completed_at = user.onboarding_completed_at

      mail(
        to: user.email,
        subject: I18n.t('rails_onboarding.mailer.completion.subject', default: 'Congratulations! Onboarding Complete')
      )
    end

    def step_completed_email(user)
      @user = user
      @step = user.onboarding_current_step
      @progress = user.onboarding_progress_percentage

      mail(
        to: user.email,
        subject: I18n.t('rails_onboarding.mailer.step_completed.subject', default: 'Step Completed!')
      )
    end
  end
end
