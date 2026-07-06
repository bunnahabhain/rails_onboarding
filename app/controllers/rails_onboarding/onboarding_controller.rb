module RailsOnboarding
  class OnboardingController < ApplicationController
    before_action :authenticate_user!
    before_action :check_onboarding_status, except: [ :complete, :skip, :restart ]
    before_action :set_step

    # Error handling for common scenarios.
    # rescue_from handlers are checked most-specific-last-registered-first, so
    # the generic StandardError handler must come first or it will swallow
    # RecordInvalid/RecordNotFound too (they're both StandardError subclasses)
    # and the specific handlers below become dead code.
    rescue_from StandardError, with: :handle_standard_error
    rescue_from ActiveRecord::RecordNotFound, with: :handle_not_found
    rescue_from ActiveRecord::RecordInvalid, with: :handle_validation_error

    def show
      unless @current_step
        # Reset onboarding to first step
        first_step = RailsOnboarding.configuration.steps.first

        unless first_step
          handle_configuration_error("No onboarding steps configured")
          return
        end

        current_user.update!(onboarding_current_step: first_step[:name])
        @current_step = current_user.current_onboarding_step
      end

      # Reset invalid step to first step
      if current_user.onboarding_current_step &&
         !RailsOnboarding.configuration.step_by_name(current_user.onboarding_current_step)
        first_step = RailsOnboarding.configuration.steps.first
        current_user.update!(onboarding_current_step: first_step[:name])
        @current_step = current_user.current_onboarding_step
      end

      # Track step view - use gem's analytics if enabled
      if RailsOnboarding.configuration.enable_analytics
        RailsOnboarding::AnalyticsEvent.track_custom_event(
          user: current_user,
          event_name: "onboarding_step_view",
          event_data: { step: @current_step[:name] }
        )
      end

      # Dynamic action based on current step
      step_template = @current_step[:name]

      # Render the appropriate template
      if template_exists?(step_template)
        render step_template
      else
        render :step
      end
    end

    def next
      unless @current_step
        respond_to do |format|
          format.html { redirect_to onboarding_path, alert: "Invalid step. Redirecting to current step." }
          format.turbo_stream do
            render turbo_stream: turbo_stream.replace(
              "flash-messages",
              partial: "rails_onboarding/shared/flash",
              locals: { alert: "Invalid step. Please try again." }
            )
          end
        end
        return
      end

      if params[:step_data].present?
        # Process any step-specific data
        process_step_data(@current_step[:name], params[:step_data])
      end

      # Award milestones for completing this step
      awarded_milestones = []
      if defined?(RailsOnboarding::MilestoneService)
        awarded_milestones = RailsOnboarding::MilestoneService.check_onboarding_step_milestones(
          current_user,
          @current_step[:name]
        ) || []
      end

      current_user.complete_onboarding_step!(@current_step[:name])

      if current_user.onboarding_completed?
        # Award completion milestones
        if defined?(RailsOnboarding::MilestoneService)
          completion_milestones = RailsOnboarding::MilestoneService.check_onboarding_completion_milestones(current_user) || []
          awarded_milestones.concat(completion_milestones)
        end

        respond_to do |format|
          format.html { redirect_to_after_completion(awarded_milestones) }
          format.turbo_stream do
            render turbo_stream: turbo_stream.action(
              :redirect,
              main_app.send(RailsOnboarding.configuration.redirect_after_completion)
            )
          end
        end
      else
        respond_to do |format|
          format.html { redirect_to onboarding_path(awarded_milestones: awarded_milestones.map { |m| m[:key] }) }
          format.turbo_stream { render :next }
        end
      end
    end

    def complete
      completion_milestones = []
      if defined?(RailsOnboarding::MilestoneService)
        completion_milestones = RailsOnboarding::MilestoneService.check_onboarding_completion_milestones(current_user) || []
      end

      current_user.complete_onboarding!

      respond_to do |format|
        format.html { redirect_to_after_completion(completion_milestones) }
        format.turbo_stream do
          render turbo_stream: turbo_stream.action(
            :redirect,
            main_app.send(RailsOnboarding.configuration.redirect_after_completion)
          )
        end
      end
    end

    def skip
      if params[:skip_all] == "true"
        current_user.skip_onboarding!
        redirect_to_after_skip
      elsif @current_step && @current_step[:skippable]
        current_user.skip_onboarding_step!(@current_step[:name])
        if current_user.onboarding_completed?
          respond_to do |format|
            format.html { redirect_to_after_completion }
            format.turbo_stream do
              render turbo_stream: turbo_stream.action(
                :redirect,
                main_app.send(RailsOnboarding.configuration.redirect_after_completion)
              )
            end
          end
        else
          respond_to do |format|
            format.html { redirect_to onboarding_path }
            format.turbo_stream { render :skip }
          end
        end
      else
        respond_to do |format|
          format.html do
            redirect_to onboarding_path, alert: "This step cannot be skipped."
          end
          format.turbo_stream do
            render turbo_stream: turbo_stream.replace(
              "flash-messages",
              partial: "rails_onboarding/shared/flash",
              locals: { alert: "This step cannot be skipped." }
            ), status: :unprocessable_entity
          end
        end
      end
    end

    def back
      unless current_user.can_go_back?
        respond_to do |format|
          format.html { redirect_to onboarding_path, alert: "Cannot go back from the first step." }
          format.turbo_stream do
            render turbo_stream: turbo_stream.replace(
              "flash-messages",
              partial: "rails_onboarding/shared/flash",
              locals: { alert: "Cannot go back from the first step." }
            ), status: :unprocessable_entity
          end
        end
        return
      end

      session_id = RailsOnboarding::SessionManager.session_id(current_user, session)
      current_user.go_back!(session_id: session_id)

      respond_to do |format|
        format.html { redirect_to onboarding_path }
        format.turbo_stream { render :back }
      end
    end

    def restart
      session_id = RailsOnboarding::SessionManager.session_id(current_user, session)
      current_user.restart_onboarding!(session_id: session_id)
      RailsOnboarding::SessionManager.clear_session(current_user, session)

      respond_to do |format|
        format.html { redirect_to onboarding_path, notice: "Onboarding has been restarted." }
        format.turbo_stream do
          render turbo_stream: turbo_stream.action(:redirect, onboarding_path)
        end
      end
    end

    private

    def authenticate_user!
      # This should be overridden by the host app
      # or use the host app's authentication
      Rails.logger.debug "authenticate_user! - respond_to?(:current_user): #{respond_to?(:current_user, true)}"
      Rails.logger.debug "authenticate_user! - current_user: #{current_user.inspect}"
      unless respond_to?(:current_user, true) && current_user.present?
        Rails.logger.debug "authenticate_user! - REDIRECTING to root"
        redirect_to main_app.root_path
      end
    end

    def check_onboarding_status
      if current_user.onboarding_completed?
        redirect_to_after_completion
      end
    end

    def set_step
      if current_user
        @current_step = current_user.current_onboarding_step
        @next_step = current_user.next_onboarding_step
        @progress = current_user.onboarding_progress
        @total_steps = RailsOnboarding.configuration.total_steps
      end

      @progress ||= 0
      @total_steps ||= 4
    end

    def redirect_to_after_completion(awarded_milestones = [])
      path = RailsOnboarding.configuration.redirect_after_completion
      notice = "Welcome! You've completed the onboarding."

      if awarded_milestones.any?
        milestone_text = awarded_milestones.map { |m| "#{m[:icon]} #{m[:title]}" }.join(", ")
        notice += " Milestones achieved: #{milestone_text}"
      end

      redirect_to main_app.send(path), notice: notice
    end

    def redirect_to_after_skip
      path = RailsOnboarding.configuration.redirect_after_skip
      redirect_to main_app.send(path), notice: "You can explore features at your own pace."
    end

    def process_step_data(step_name, data)
      # Sanitize input data before processing
      sanitized_data = sanitize_step_data(data)

      # Override in host app for custom processing
      # Example:
      # case step_name
      # when :profile
      #   current_user.update(sanitized_data.permit(:timezone, :notifications_enabled))
      # end

      # Log sanitized data for security auditing
      Rails.logger.info("Processing step data for #{step_name}: #{sanitized_data.inspect}")
    end

    def sanitize_step_data(data)
      return {} unless data.is_a?(ActionController::Parameters) || data.is_a?(Hash)

      # Convert to ActionController::Parameters if needed
      params_data = data.is_a?(ActionController::Parameters) ? data : ActionController::Parameters.new(data)

      # Remove any potentially dangerous keys
      dangerous_keys = %w[authenticity_token _method controller action]
      params_data.except(*dangerous_keys)
    end

    def template_exists?(name)
      lookup_context.exists?(name, [ "rails_onboarding/onboarding" ], false)
    end

    # Error handling methods

    def handle_validation_error(exception)
      Rails.logger.error("Validation error in onboarding: #{exception.message}")
      Rails.logger.error(exception.backtrace.join("\n")) if Rails.env.development?

      error_message = "Unable to save changes: #{exception.record.errors.full_messages.join(', ')}"

      respond_to do |format|
        format.html do
          redirect_to onboarding_path, alert: error_message
        end
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            "flash-messages",
            partial: "rails_onboarding/shared/flash",
            locals: { alert: error_message }
          ), status: :unprocessable_entity
        end
      end
    end

    def handle_not_found(exception)
      Rails.logger.error("Record not found in onboarding: #{exception.message}")

      respond_to do |format|
        format.html do
          redirect_to main_app.root_path, alert: "Resource not found. Please try again."
        end
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            "flash-messages",
            partial: "rails_onboarding/shared/flash",
            locals: { alert: "Resource not found. Please try again." }
          ), status: :not_found
        end
      end
    end

    def handle_standard_error(exception)
      Rails.logger.error("Error in onboarding controller: #{exception.class} - #{exception.message}")
      Rails.logger.error(exception.backtrace.join("\n"))

      error_message = if Rails.env.production?
                        "An unexpected error occurred. Please try again or contact support."
                      else
                        "Error: #{exception.message}"
                      end

      # Simple redirect for all error cases
      redirect_to onboarding_path, alert: error_message
    end

    def handle_configuration_error(message)
      Rails.logger.error("Configuration error: #{message}")

      error_message = "Onboarding configuration error. Please contact support."

      respond_to do |format|
        format.html do
          redirect_to main_app.root_path, alert: error_message
        end
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            "flash-messages",
            partial: "rails_onboarding/shared/flash",
            locals: { alert: error_message }
          ), status: :internal_server_error
        end
      end
    end
  end
end
