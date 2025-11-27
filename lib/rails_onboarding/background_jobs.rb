# frozen_string_literal: true

module RailsOnboarding
  # Background job support for queuing emails and notifications
  # Compatible with ActiveJob, Sidekiq, Resque, and DelayedJob
  module BackgroundJobs
    extend ActiveSupport::Concern

    # Throttling constants to prevent queue overflow
    MAX_JOBS_PER_USER_PER_HOUR = 100
    MAX_TOTAL_JOBS_PER_MINUTE = 1000

    module ClassMethods
      # Configure background job options
      def configure_background_jobs(options = {})
        @background_job_options = {
          adapter: options.fetch(:adapter, :active_job),
          queue: options.fetch(:queue, :default),
          enable_emails: options.fetch(:enable_emails, true),
          enable_notifications: options.fetch(:enable_notifications, true),
          retry_limit: options.fetch(:retry_limit, 3),
          retry_delay: options.fetch(:retry_delay, 5.minutes),
          enable_throttling: options.fetch(:enable_throttling, true),
          max_jobs_per_user_per_hour: options.fetch(:max_jobs_per_user_per_hour, MAX_JOBS_PER_USER_PER_HOUR),
          max_total_jobs_per_minute: options.fetch(:max_total_jobs_per_minute, MAX_TOTAL_JOBS_PER_MINUTE)
        }.merge(options)
      end

      def background_job_options
        @background_job_options || {}
      end
    end

    # Queue onboarding emails
    def queue_onboarding_welcome_email(user)
      return unless RailsOnboarding.active_job_available?
      return unless background_jobs_enabled?(:emails)
      return unless can_queue_job_for_user?(user)

      OnboardingMailerJob.perform_later(user.id, :welcome)
    end

    def queue_onboarding_reminder_email(user)
      return unless RailsOnboarding.active_job_available?
      return unless background_jobs_enabled?(:emails)
      return unless can_queue_job_for_user?(user)

      OnboardingMailerJob.set(wait: 1.day).perform_later(user.id, :reminder)
    end

    def queue_onboarding_completion_email(user)
      return unless RailsOnboarding.active_job_available?
      return unless background_jobs_enabled?(:emails)
      return unless can_queue_job_for_user?(user)

      OnboardingMailerJob.perform_later(user.id, :completion)
    end

    # Queue notifications
    def queue_onboarding_notification(user, notification_type, data = {})
      return unless RailsOnboarding.active_job_available?
      return unless background_jobs_enabled?(:notifications)
      return unless can_queue_job_for_user?(user)

      OnboardingNotificationJob.perform_later(user.id, notification_type, data)
    end

    # Queue analytics events
    def queue_analytics_event(event_name, user, data = {})
      return unless RailsOnboarding.active_job_available?
      return unless can_queue_job_for_user?(user)

      OnboardingAnalyticsJob.perform_later(event_name, user.id, data)
    end

    # Queue milestone achievements
    def queue_milestone_achievement(user, milestone_id)
      return unless RailsOnboarding.active_job_available?
      return unless can_queue_job_for_user?(user)

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

    # Check if we can queue a job for this user (throttling)
    def can_queue_job_for_user?(user)
      options = self.class.background_job_options
      return true unless options[:enable_throttling]

      # Check per-user rate limit
      user_job_count = get_user_job_count(user.id)
      if user_job_count >= options[:max_jobs_per_user_per_hour]
        Rails.logger.warn "RailsOnboarding: Job throttled for user #{user.id} (#{user_job_count} jobs/hour)"
        return false
      end

      # Check global rate limit
      total_job_count = get_total_job_count
      if total_job_count >= options[:max_total_jobs_per_minute]
        Rails.logger.warn "RailsOnboarding: Job throttled globally (#{total_job_count} jobs/minute)"
        return false
      end

      # Increment counters
      increment_user_job_count(user.id)
      increment_total_job_count

      true
    end

    # Get job count for user in the last hour
    def get_user_job_count(user_id)
      cache_key = "rails_onboarding:job_count:user:#{user_id}"
      Rails.cache.read(cache_key) || 0
    end

    # Increment job count for user
    def increment_user_job_count(user_id)
      cache_key = "rails_onboarding:job_count:user:#{user_id}"
      count = Rails.cache.increment(cache_key, 1, expires_in: 1.hour)
      count || Rails.cache.write(cache_key, 1, expires_in: 1.hour)
    end

    # Get total job count in the last minute
    def get_total_job_count
      cache_key = "rails_onboarding:job_count:total:#{Time.current.strftime('%Y%m%d%H%M')}"
      Rails.cache.read(cache_key) || 0
    end

    # Increment total job count
    def increment_total_job_count
      cache_key = "rails_onboarding:job_count:total:#{Time.current.strftime('%Y%m%d%H%M')}"
      count = Rails.cache.increment(cache_key, 1, expires_in: 1.minute)
      count || Rails.cache.write(cache_key, 1, expires_in: 1.minute)
    end
  end

  # Check if ActiveJob is available
  def self.active_job_available?
    defined?(::ActiveJob::Base)
  end

  # Check if ActionMailer is available
  def self.action_mailer_available?
    defined?(::ActionMailer::Base)
  end

  # Check if ActionMailer is properly configured
  def self.action_mailer_configured?
    return false unless action_mailer_available?

    # Check if delivery method is configured (not :test in production)
    if Rails.env.production?
      return false if ::ActionMailer::Base.delivery_method == :test
    end

    # Check if SMTP settings are present when using SMTP
    if ::ActionMailer::Base.delivery_method == :smtp
      smtp_settings = ::ActionMailer::Base.smtp_settings
      return false if smtp_settings.nil? || smtp_settings.empty?
    end

    true
  rescue => e
    Rails.logger.warn "RailsOnboarding: Error checking ActionMailer configuration: #{e.message}"
    false
  end

  # Base job class for RailsOnboarding (only defined if ActiveJob is available)
  if active_job_available?
    class ApplicationJob < ::ActiveJob::Base
      # Automatically retry jobs that encountered a deadlock
      retry_on ActiveRecord::Deadlocked

      # Most jobs are safe to ignore if the underlying records are no longer available
      discard_on ::ActiveJob::DeserializationError

      queue_as :default

      def self.queue_name
        RailsOnboarding::BackgroundJobs.background_job_options[:queue] || :default
      end
    end
  end

  # Job for sending onboarding emails (only defined if ActiveJob is available)
  if active_job_available?
    class OnboardingMailerJob < ApplicationJob
      queue_as { RailsOnboarding::BackgroundJobs.background_job_options[:queue] || :default }

      def perform(user_id, email_type)
        unless RailsOnboarding.action_mailer_configured?
          Rails.logger.warn "RailsOnboarding: ActionMailer not configured, skipping email"
          return
        end

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
  end

  # Job for sending onboarding notifications (only defined if ActiveJob is available)
  if active_job_available?
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
  end

  # Job for tracking analytics events (only defined if ActiveJob is available)
  if active_job_available?
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
  end

  # Job for processing milestone achievements (only defined if ActiveJob is available)
  if active_job_available?
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
  end

  # Mailer is now defined in app/mailers/rails_onboarding/onboarding_mailer.rb
  # and will be autoloaded by Rails when needed
end
