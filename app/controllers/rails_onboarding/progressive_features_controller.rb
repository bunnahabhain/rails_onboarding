# frozen_string_literal: true

module RailsOnboarding
  # Controller for managing progressive feature disclosure
  # Handles revealing and tracking progressive features
  class ProgressiveFeaturesController < ApplicationController
    before_action :authenticate_user!
    before_action :set_feature, only: [:reveal, :dismiss]

    # GET /progressive_features
    # List all progressive features and their status
    def index
      @all_features = RailsOnboarding.configuration.progressive_features || []
      @revealed_features = current_user.all_revealed_features
      @ready_features = current_user.features_ready_to_reveal

      respond_to do |format|
        format.html
        format.json do
          render json: {
            all_features: @all_features,
            revealed: @revealed_features,
            ready_to_reveal: @ready_features.map { |f| f[:key] }
          }
        end
      end
    end

    # GET /progressive_features/ready
    # Get features that are ready to be revealed
    def ready
      @ready_features = current_user.features_ready_to_reveal

      respond_to do |format|
        format.json { render json: @ready_features }
      end
    end

    # POST /progressive_features/:feature_key/reveal
    # Manually reveal a feature
    def reveal
      if current_user.reveal_feature(@feature[:key], source: :manual, revealed_by: current_user.id)
        respond_to do |format|
          format.html do
            flash[:success] = "Feature '#{@feature[:title]}' has been revealed!"
            redirect_back(fallback_location: root_path)
          end
          format.json { render json: { success: true, feature: @feature } }
        end
      else
        respond_to do |format|
          format.html do
            flash[:error] = "Failed to reveal feature"
            redirect_back(fallback_location: root_path)
          end
          format.json { render json: { success: false }, status: :unprocessable_entity }
        end
      end
    end

    # POST /progressive_features/:feature_key/dismiss
    # Dismiss a feature notification without revealing it
    def dismiss
      # Track dismissal in analytics
      if current_user.respond_to?(:track_analytics_event)
        current_user.track_analytics_event(
          'feature_dismissed',
          feature_key: @feature[:key].to_s
        )
      end

      respond_to do |format|
        format.json { render json: { success: true } }
      end
    end

    # POST /progressive_features/reveal_all_ready
    # Reveal all features that are currently ready
    def reveal_all_ready
      newly_revealed = current_user.reveal_ready_features!

      respond_to do |format|
        format.html do
          flash[:success] = "Revealed #{newly_revealed.size} new features!"
          redirect_back(fallback_location: root_path)
        end
        format.json { render json: { success: true, revealed: newly_revealed } }
      end
    end

    # GET /progressive_features/status
    # Get the current status of progressive disclosure for the user
    def status
      render json: {
        enabled: RailsOnboarding.configuration.progressive_disclosure_enabled,
        total_features: RailsOnboarding.configuration.progressive_features&.size || 0,
        revealed_count: current_user.revealed_features_count,
        pending_count: current_user.pending_features_count,
        ready_to_reveal: current_user.features_ready_to_reveal.map { |f| f[:key] }
      }
    end

    private

    def set_feature
      feature_key = params[:feature_key] || params[:id]
      @feature = (RailsOnboarding.configuration.progressive_features || [])
                 .find { |f| f[:key].to_s == feature_key.to_s }

      unless @feature
        respond_to do |format|
          format.html do
            flash[:error] = "Feature not found"
            redirect_to root_path
          end
          format.json { render json: { error: 'Feature not found' }, status: :not_found }
        end
      end
    end

    def authenticate_user!
      # This should be implemented by the host application
      # or overridden in the host's ApplicationController
      return if defined?(current_user) && current_user

      respond_to do |format|
        format.html { redirect_to main_app.root_path, alert: 'Please sign in' }
        format.json { render json: { error: 'Unauthorized' }, status: :unauthorized }
      end
    end
  end
end
