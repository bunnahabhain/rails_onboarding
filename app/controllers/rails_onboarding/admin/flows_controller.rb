# frozen_string_literal: true

module RailsOnboarding
  module Admin
    # Admin flows controller
    # Visual editor for creating and managing onboarding flows
    class FlowsController < BaseController
      before_action :set_flow, only: [:show, :edit, :update, :destroy, :duplicate, :activate]

      def index
        @flows = flows_collection
        @active_flow = current_active_flow
        @templates = available_templates
      end

      def show
        @steps = @flow[:steps] || []
        @flow_stats = calculate_flow_stats(@flow)
      end

      def new
        @flow = default_flow_structure
        @available_icons = available_icons
      end

      def create
        flow_params = sanitize_flow_params(params[:flow])

        if save_flow(flow_params)
          flash[:notice] = "Flow '#{flow_params[:name]}' created successfully"
          redirect_to admin_flows_path
        else
          flash.now[:alert] = "Failed to create flow"
          @flow = flow_params
          @available_icons = available_icons
          render :new
        end
      end

      def edit
        @available_icons = available_icons
      end

      def update
        flow_params = sanitize_flow_params(params[:flow])

        if update_flow(@flow[:id], flow_params)
          flash[:notice] = "Flow updated successfully"
          redirect_to admin_flow_path(@flow[:id])
        else
          flash.now[:alert] = "Failed to update flow"
          @available_icons = available_icons
          render :edit
        end
      end

      def destroy
        if delete_flow(@flow[:id])
          flash[:notice] = "Flow deleted successfully"
        else
          flash[:alert] = "Failed to delete flow. Cannot delete active flow."
        end
        redirect_to admin_flows_path
      end

      def duplicate
        new_flow = duplicate_flow(@flow)

        if new_flow
          flash[:notice] = "Flow duplicated successfully"
          redirect_to admin_flow_path(new_flow[:id])
        else
          flash[:alert] = "Failed to duplicate flow"
          redirect_to admin_flows_path
        end
      end

      def activate
        if activate_flow(@flow[:id])
          flash[:notice] = "Flow '#{@flow[:name]}' is now active"
        else
          flash[:alert] = "Failed to activate flow"
        end
        redirect_to admin_flows_path
      end

      def preview
        @flow = find_flow(params[:id])
        @steps = @flow[:steps] || []
        render layout: 'rails_onboarding/application'
      end

      private

      def set_flow
        @flow = find_flow(params[:id])
        unless @flow
          flash[:alert] = "Flow not found"
          redirect_to admin_flows_path
        end
      end

      def flows_collection
        # Load flows from configuration file or database
        # For now, we'll use a session-based storage
        session[:onboarding_flows] ||= []

        # If no flows exist, create a default one from current configuration
        if session[:onboarding_flows].empty?
          session[:onboarding_flows] = [default_flow_from_config]
        end

        session[:onboarding_flows]
      end

      def find_flow(id)
        flows_collection.find { |f| f[:id] == id }
      end

      def save_flow(flow_data)
        flow_data[:id] = SecureRandom.uuid
        flow_data[:created_at] = Time.current
        flow_data[:updated_at] = Time.current
        flow_data[:active] = false

        session[:onboarding_flows] ||= []
        session[:onboarding_flows] << flow_data
        true
      rescue StandardError => e
        logger.error "Error saving flow: #{e.message}"
        false
      end

      def update_flow(id, flow_data)
        flows = flows_collection
        index = flows.index { |f| f[:id] == id }
        return false unless index

        flow_data[:updated_at] = Time.current
        flows[index].merge!(flow_data)
        session[:onboarding_flows] = flows
        true
      rescue StandardError => e
        logger.error "Error updating flow: #{e.message}"
        false
      end

      def delete_flow(id)
        flows = flows_collection
        flow = flows.find { |f| f[:id] == id }
        return false if flow[:active]

        session[:onboarding_flows] = flows.reject { |f| f[:id] == id }
        true
      rescue StandardError => e
        logger.error "Error deleting flow: #{e.message}"
        false
      end

      def duplicate_flow(flow)
        new_flow = flow.deep_dup
        new_flow[:id] = SecureRandom.uuid
        new_flow[:name] = "#{flow[:name]} (Copy)"
        new_flow[:active] = false
        new_flow[:created_at] = Time.current
        new_flow[:updated_at] = Time.current

        session[:onboarding_flows] ||= []
        session[:onboarding_flows] << new_flow
        new_flow
      rescue StandardError => e
        logger.error "Error duplicating flow: #{e.message}"
        nil
      end

      def activate_flow(id)
        flows = flows_collection

        # Deactivate all flows
        flows.each { |f| f[:active] = false }

        # Activate selected flow
        flow = flows.find { |f| f[:id] == id }
        return false unless flow

        flow[:active] = true
        session[:onboarding_flows] = flows

        # Update the actual configuration (this would need to be persisted)
        apply_flow_to_configuration(flow)
        true
      rescue StandardError => e
        logger.error "Error activating flow: #{e.message}"
        false
      end

      def current_active_flow
        flows_collection.find { |f| f[:active] }
      end

      def default_flow_from_config
        {
          id: 'default',
          name: 'Current Configuration',
          description: 'Flow from current configuration',
          steps: RailsOnboarding.configuration.steps,
          active: true,
          created_at: Time.current,
          updated_at: Time.current
        }
      end

      def default_flow_structure
        {
          name: '',
          description: '',
          steps: [
            { name: 'welcome', title: 'Welcome', icon: '👋', skippable: true, order: 0 }
          ],
          active: false
        }
      end

      def sanitize_flow_params(params)
        flow_data = params.to_unsafe_h.symbolize_keys

        # Process steps
        if flow_data[:steps].is_a?(Hash)
          flow_data[:steps] = flow_data[:steps].values.map do |step|
            step.symbolize_keys.slice(:name, :title, :icon, :description, :skippable, :order)
          end.sort_by { |s| s[:order].to_i }
        end

        flow_data.slice(:name, :description, :steps, :active)
      end

      def calculate_flow_stats(flow)
        return {} unless defined?(RailsOnboarding::AnalyticsEvent)

        steps = flow[:steps] || []
        stats = {}

        steps.each do |step|
          step_name = step[:name].to_s
          stats[step_name] = {
            started: RailsOnboarding::AnalyticsEvent
              .where(event_type: 'step_started')
              .where("metadata->>'step' = ?", step_name)
              .distinct
              .count(:user_id),
            completed: RailsOnboarding::AnalyticsEvent
              .where(event_type: 'step_completed')
              .where("metadata->>'step' = ?", step_name)
              .distinct
              .count(:user_id)
          }
        end

        stats
      end

      def apply_flow_to_configuration(flow)
        # This would update the configuration
        # In a real implementation, this might write to a config file or database
        RailsOnboarding.configuration.steps = flow[:steps]
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
