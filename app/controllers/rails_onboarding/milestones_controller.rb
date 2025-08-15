module RailsOnboarding
  class MilestonesController < ApplicationController
    before_action :authenticate_user!
    before_action :check_milestones_enabled

    def index
      @achieved_milestones = current_user.achieved_milestones.map do |key|
        RailsOnboarding.configuration.milestone_by_key(key)
      end.compact

      @available_milestones = current_user.milestones_available
      @total_points = current_user.total_milestone_points
    end

    def show
      milestone_key = params[:id]
      @milestone = RailsOnboarding.configuration.milestone_by_key(milestone_key)

      unless @milestone
        redirect_to milestones_path, alert: "Milestone not found"
        return
      end

      @achieved = current_user.milestone_achieved?(milestone_key)
    end

    def achieve
      milestone_key = params[:milestone_key]
      milestone = current_user.achieve_milestone!(milestone_key)

      if milestone
        render json: {
          success: true,
          milestone: milestone,
          total_points: current_user.total_milestone_points,
          celebration: true
        }
      else
        render json: {
          success: false,
          error: "Milestone could not be achieved"
        }
      end
    end

    def recent
      @recent_milestones = current_user.recent_milestones(limit: params[:limit]&.to_i || 5)
      render json: @recent_milestones
    end

    private

    def authenticate_user!
      unless respond_to?(:current_user) && current_user
        redirect_to main_app.root_path, alert: "Please log in to view milestones"
      end
    end

    def check_milestones_enabled
      unless RailsOnboarding.configuration.enable_milestones
        redirect_to main_app.root_path, alert: "Milestones are not enabled"
      end
    end
  end
end
