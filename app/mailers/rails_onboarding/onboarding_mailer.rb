module RailsOnboarding
  class OnboardingMailer < ApplicationMailer
    include RailsOnboarding::Engine.routes.url_helpers

    default from: -> { RailsOnboarding.configuration.mailer_from || 'noreply@example.com' }

    def default_url_options
      if defined?(Rails) && Rails.application
        Rails.application.config.action_mailer.default_url_options || { host: 'localhost', port: 3000 }
      else
        { host: 'localhost', port: 3000 }
      end
    end

    def welcome_email(user)
      @user = user
      @onboarding_url = onboarding_url

      mail(
        to: user.email,
        subject: I18n.t('rails_onboarding.mailer.welcome.subject', default: 'Welcome! Get Started')
      ) do |format|
        format.text
        format.html
      end
    end

    def reminder_email(user)
      @user = user
      @current_step = user.onboarding_current_step
      @progress = user.onboarding_progress_percentage
      @onboarding_url = onboarding_url

      mail(
        to: user.email,
        subject: I18n.t('rails_onboarding.mailer.reminder.subject', default: 'Complete Your Onboarding')
      ) do |format|
        format.text
        format.html
      end
    end

    def completion_email(user)
      @user = user
      @completed_at = user.onboarding_completed_at
      @milestone_points = user.respond_to?(:milestone_points) ? user.milestone_points : 0

      mail(
        to: user.email,
        subject: I18n.t('rails_onboarding.mailer.completion.subject', default: 'Congratulations! Onboarding Complete')
      ) do |format|
        format.text
        format.html
      end
    end

    def step_completed_email(user)
      @user = user
      @step = user.onboarding_current_step
      @progress = user.onboarding_progress_percentage
      @onboarding_url = onboarding_url

      mail(
        to: user.email,
        subject: I18n.t('rails_onboarding.mailer.step_completed.subject', default: 'Step Completed!')
      ) do |format|
        format.text
        format.html
      end
    end
  end
end
