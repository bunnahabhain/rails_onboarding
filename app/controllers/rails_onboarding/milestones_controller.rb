module RailsOnboarding
  class MilestonesController < ApplicationController
    include RailsOnboarding::RateLimitable

    before_action :authenticate_user!
    before_action :check_milestones_enabled

    def index
      achieved_milestones = current_user.achieved_milestones.map do |key|
        RailsOnboarding.configuration.milestone_by_key(key)
      end.compact

      available_milestones = current_user.milestones_available
      total_points = current_user.total_milestone_points

      respond_to do |format|
        format.html do
          @achieved_milestones = achieved_milestones
          @available_milestones = available_milestones
          @total_points = total_points
        end
        format.json do
          render json: (achieved_milestones + available_milestones)
        end
      end
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
      milestone = MilestoneService.claim_if_eligible(current_user, params[:milestone_key])

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
        }, status: :forbidden
      end
    end

    def recent
      @recent_milestones = current_user.recent_milestones(limit: params[:limit]&.to_i || 5)
      render json: @recent_milestones
    end

    def progress
      render json: {
        points: current_user.milestone_points || 0,
        achieved: current_user.milestones_achieved.map { |m| m["key"] || m[:key] }.compact
      }
    end

    def check
      milestone_id = params[:id]
      achieved = current_user.milestone_achieved?(milestone_id)

      render json: { achieved: achieved }
    end

    def trigger
      milestone_id = params[:milestone_id]

      # Check if milestone is already achieved
      if current_user.milestone_achieved?(milestone_id)
        render json: {
          success: false,
          message: "Milestone already achieved"
        }
        return
      end

      # Award the milestone only if the user actually qualifies for it
      milestone = MilestoneService.claim_if_eligible(current_user, milestone_id)

      if milestone
        render json: {
          success: true,
          celebration: true,
          points_awarded: milestone[:points] || 0,
          total_points: current_user.milestone_points || 0
        }
      else
        render json: {
          success: false,
          error: "You are not eligible for this milestone yet"
        }, status: :forbidden
      end
    end

    def available
      available_milestones = current_user.milestones_available || []
      render json: available_milestones
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
