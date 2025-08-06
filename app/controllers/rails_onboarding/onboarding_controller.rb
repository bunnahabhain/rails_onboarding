module RailsOnboarding
  class OnboardingController < ApplicationController
    before_action :authenticate_user!
    before_action :check_onboarding_status, except: [:complete, :skip]
    before_action :set_step

    def show
      unless @current_step
        # Reset onboarding to first step
        current_user.update!(onboarding_current_step: RailsOnboarding.configuration.steps.first[:name])
        redirect_to onboarding_path and return
      end

      # Dynamic action based on current step
      step_template = @current_step[:name]

      if template_exists?(step_template)
        render step_template
      else
        render :step
      end
    end

    def next
      unless @current_step
        redirect_to onboarding_path and return
      end

      if params[:step_data].present?
        # Process any step-specific data
        process_step_data(@current_step[:name], params[:step_data])
      end

      current_user.complete_onboarding_step!(@current_step[:name])

      if current_user.onboarding_completed?
        redirect_to_after_completion
      else
        redirect_to onboarding_path
      end
    end

    def complete
      current_user.complete_onboarding!
      redirect_to_after_completion
    end

    def skip
      if @current_step && @current_step[:skippable]
        current_user.complete_onboarding_step!(@current_step[:name])
        redirect_to onboarding_path
      else
        current_user.skip_onboarding!
        redirect_to_after_skip
      end
    end

    private

    def authenticate_user!
      # This should be overridden by the host app
      # or use the host app's authentication
      unless defined?(current_user) && current_user
        redirect_to main_app.root_path
      end
    end

    def check_onboarding_status
      if current_user.onboarding_completed?
        redirect_to_after_completion
      end
    end

    def set_step
      @current_step = current_user.current_onboarding_step
      @next_step = current_user.next_onboarding_step
      @progress = current_user.onboarding_progress
      @total_steps = RailsOnboarding.configuration.total_steps

      @progress ||= 0
      @total_steps ||= 4
    end

    def redirect_to_after_completion
      path = RailsOnboarding.configuration.redirect_after_completion
      redirect_to main_app.send(path), notice: "Welcome! You've completed the onboarding."
    end

    def redirect_to_after_skip
      path = RailsOnboarding.configuration.redirect_after_skip
      redirect_to main_app.send(path), notice: "You can explore features at your own pace."
    end

    def process_step_data(step_name, data)
      # Override in host app for custom processing
      # Example:
      # case step_name
      # when :profile
      #   current_user.update(data.permit(:timezone, :notifications_enabled))
      # end
    end

    def template_exists?(name)
      lookup_context.exists?(name, ['rails_onboarding/onboarding'], false)
    end
  end
end
