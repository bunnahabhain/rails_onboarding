# frozen_string_literal: true

module RailsOnboarding
  module Admin
    # Admin flows controller
    # Visual editor for creating and managing onboarding flows
    class FlowsController < BaseController
      before_action :set_flow, only: [:show, :edit, :update, :destroy, :duplicate, :activate, :preview]

      def index
        @flows = flows_collection
        @active_flow = RailsOnboarding::Flow.active.first
        @templates = available_templates
      end

      def show
        @steps = @flow.steps || []
        @flow_stats = calculate_flow_stats(@flow)
      end

      def new
        @flow = RailsOnboarding::Flow.new(default_flow_structure)
        @available_icons = available_icons
      end

      def create
        @flow = RailsOnboarding::Flow.new(flow_params)

        if @flow.save
          flash[:notice] = "Flow '#{@flow.name}' created successfully"
          redirect_to admin_flows_path
        else
          flash.now[:alert] = "Failed to create flow: #{@flow.errors.full_messages.join(', ')}"
          @available_icons = available_icons
          render :new
        end
      end

      def edit
        @available_icons = available_icons
      end

      def update
        if @flow.update(flow_params)
          flash[:notice] = "Flow updated successfully"
          redirect_to admin_flow_path(@flow)
        else
          flash.now[:alert] = "Failed to update flow: #{@flow.errors.full_messages.join(', ')}"
          @available_icons = available_icons
          render :edit
        end
      end

      def destroy
        if @flow.active?
          flash[:alert] = "Failed to delete flow. Cannot delete active flow."
        elsif @flow.destroy
          flash[:notice] = "Flow deleted successfully"
        else
          flash[:alert] = "Failed to delete flow."
        end
        redirect_to admin_flows_path
      end

      def duplicate
        new_flow = @flow.dup
        new_flow.name = "#{@flow.name} (Copy)"
        new_flow.active = false

        if new_flow.save
          flash[:notice] = "Flow duplicated successfully"
          redirect_to admin_flow_path(new_flow)
        else
          flash[:alert] = "Failed to duplicate flow"
          redirect_to admin_flows_path
        end
      end

      def activate
        RailsOnboarding::Flow.activate!(@flow)
        RailsOnboarding.configuration.clear_cache!
        flash[:notice] = "Flow '#{@flow.name}' is now active"
        redirect_to admin_flows_path
      rescue StandardError => e
        logger.error "Error activating flow: #{e.message}"
        flash[:alert] = "Failed to activate flow"
        redirect_to admin_flows_path
      end

      def preview
        @steps = @flow.steps || []
        render layout: 'rails_onboarding/application'
      end

      private

      def set_flow
        @flow = RailsOnboarding::Flow.find_by(id: params[:id])
        unless @flow
          flash[:alert] = "Flow not found"
          redirect_to admin_flows_path
        end
      end

      def flows_collection
        RailsOnboarding::Flow.seed_default! if RailsOnboarding::Flow.none?
        RailsOnboarding::Flow.order(created_at: :asc)
      end

      def default_flow_structure
        {
          name: '',
          description: '',
          steps: [
            { name: 'welcome', title: 'Welcome', icon: '👋', skippable: true, order: 0 }
          ]
        }
      end

      def flow_params
        permitted = params.require(:flow).permit(
          :name, :description,
          steps: [:name, :title, :icon, :description, :skippable, :order]
        )

        if permitted[:steps]
          permitted[:steps] = permitted[:steps].map { |step| step.to_h.symbolize_keys }
                                                .sort_by { |step| step[:order].to_i }
        end

        permitted
      end

      def calculate_flow_stats(flow)
        return {} unless defined?(RailsOnboarding::AnalyticsEvent)

        steps = flow.steps || []
        stats = {}

        steps.each do |step|
          step_name = step[:name].to_s
          stats[step_name] = {
            started: RailsOnboarding::AnalyticsEvent.where(event_type: RailsOnboarding::AnalyticsEvent::ONBOARDING_STEP_STARTED)
                       .select { |e| e.properties.to_h['step_name'].to_s == step_name }.count,
            completed: RailsOnboarding::AnalyticsEvent.where(event_type: RailsOnboarding::AnalyticsEvent::ONBOARDING_STEP_COMPLETED)
                       .select { |e| e.properties.to_h['step_name'].to_s == step_name }.count
          }
        end

        stats
      rescue StandardError => e
        logger.error "Error calculating flow stats: #{e.message}"
        {}
      end

      def available_templates
        return [] unless defined?(RailsOnboarding::Templates)

        [
          { id: 'saas', name: 'SaaS Application', description: 'Standard SaaS onboarding flow' },
          { id: 'ecommerce', name: 'E-commerce', description: 'Onboarding for online stores' },
          { id: 'marketplace', name: 'Marketplace', description: 'Two-sided marketplace flow' },
          { id: 'community', name: 'Community', description: 'Social/community platform' },
          { id: 'education', name: 'Education', description: 'Learning platform flow' }
        ]
      end

      def available_icons
        ['👋', '🎉', '👤', '📝', '🚀', '🔍', '⚙️', '💡', '📊', '🎯', '✨', '🏆', '📱', '💬', '🔔', '📧', '🎨', '🔒']
      end
    end
  end
end
