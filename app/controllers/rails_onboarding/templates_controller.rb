# frozen_string_literal: true

module RailsOnboarding
  # Controller for managing onboarding templates
  # Provides pre-built flows for common use cases
  class TemplatesController < ApplicationController
    include RailsOnboarding::AdminAuthorization

    # apply/create_custom mutate the process-wide RailsOnboarding
    # configuration (the onboarding flow every user sees), so this whole
    # controller is admin-only - the same gate as the Admin dashboard.
    before_action :authenticate_admin!
    before_action :verify_admin_authorization!

    rescue_from UnauthorizedError, with: :handle_admin_unauthorized
    rescue_from NotImplementedError, with: :handle_admin_not_implemented

    # GET /templates
    # List all available onboarding templates
    def index
      @templates = RailsOnboarding.configuration.onboarding_templates

      respond_to do |format|
        format.html
        format.json { render json: @templates }
      end
    end

    # GET /templates/:template_key
    # Show details for a specific template
    def show
      @template_key = params[:template_key] || params[:id]
      @template = RailsOnboarding.configuration.template(@template_key)

      unless @template
        respond_to do |format|
          format.html do
            flash[:error] = "Template not found: #{@template_key}"
            redirect_to templates_path
          end
          format.json { render json: { error: "Template not found" }, status: :not_found }
        end
        return
      end

      respond_to do |format|
        format.html
        format.json { render json: { template_key: @template_key, template: @template } }
      end
    end

    # POST /templates/:template_key/apply
    # Apply a template to the current configuration
    def apply
      template_key = params[:template_key] || params[:id]
      template = RailsOnboarding.configuration.template(template_key)

      unless template
        respond_to do |format|
          format.html do
            flash[:error] = "Template not found: #{template_key}"
            redirect_to templates_path
          end
          format.json { render json: { error: "Template not found" }, status: :not_found }
        end
        return
      end

      if RailsOnboarding.configuration.apply_template(template_key)
        respond_to do |format|
          format.html do
            flash[:success] = "Template '#{template[:name]}' has been applied successfully!"
            redirect_to onboarding_path
          end
          format.json do
            render json: {
              success: true,
              template_key: template_key,
              steps: RailsOnboarding.configuration.steps
            }
          end
        end
      else
        respond_to do |format|
          format.html do
            flash[:error] = "Failed to apply template"
            redirect_to templates_path
          end
          format.json { render json: { success: false }, status: :unprocessable_entity }
        end
      end
    end

    # POST /templates/:template_key/preview
    # Preview what a template would look like without applying it
    def preview
      template_key = params[:template_key] || params[:id]
      template = RailsOnboarding.configuration.template(template_key)

      unless template
        respond_to do |format|
          format.json { render json: { error: "Template not found" }, status: :not_found }
        end
        return
      end

      # Return template details without actually applying it
      render json: {
        template_key: template_key,
        name: template[:name],
        steps: template[:steps],
        total_steps: template[:steps]&.size || 0,
        description: template[:description],
        suitable_for: template[:suitable_for]
      }
    end

    # GET /templates/compare
    # Compare multiple templates side by side
    def compare
      template_keys = params[:templates]&.split(",") || []
      @templates_to_compare = {}

      template_keys.each do |key|
        template = RailsOnboarding.configuration.template(key.to_sym)
        @templates_to_compare[key.to_sym] = template if template
      end

      respond_to do |format|
        format.html
        format.json { render json: @templates_to_compare }
      end
    end

    # POST /templates/custom
    # Create a custom template based on current configuration
    def create_custom
      template_name = params[:template_name] || "Custom Template"
      template_key = params[:template_key]&.to_sym || :custom

      custom_template = {
        name: template_name,
        steps: RailsOnboarding.configuration.steps,
        description: params[:description] || "Custom onboarding flow",
        created_at: Time.current
      }

      # In a real application, you'd save this to the database
      # For now, we'll just return it as JSON

      respond_to do |format|
        format.json do
          render json: {
            success: true,
            template_key: template_key,
            template: custom_template
          }
        end
      end
    end
  end
end
