# frozen_string_literal: true

module RailsOnboarding
  module Api
    module V1
      class MilestonesController < ApplicationController
        include RailsOnboarding::ApiMode
        include RailsOnboarding::RateLimitable

        before_action :authenticate_api_request!

        # GET /api/v1/milestones
        def index
          milestones = RailsOnboarding.configuration.milestones

          render_api_success({
            milestones: milestones.map do |milestone|
              {
                key: milestone[:key],
                title: milestone[:title],
                description: milestone[:description],
                icon: milestone[:icon],
                points: milestone[:points],
                trigger: milestone[:trigger],
                achieved: current_user.milestone_achieved?(milestone[:key])
              }
            end,
            total_points: current_user.total_milestone_points
          })
        end

        # GET /api/v1/milestones/:id
        def show
          milestone_key = params[:id]
          milestone = RailsOnboarding.configuration.milestone_by_key(milestone_key)

          if milestone
            render_api_success({
              milestone: {
                key: milestone[:key],
                title: milestone[:title],
                description: milestone[:description],
                icon: milestone[:icon],
                points: milestone[:points],
                trigger: milestone[:trigger],
                achieved: current_user.milestone_achieved?(milestone[:key]),
                achieved_at: current_user.milestone_achieved_at(milestone[:key])
              }
            })
          else
            render_api_error("Milestone not found", status: :not_found)
          end
        end

        # GET /api/v1/milestones/user/:user_id
        def user_milestones
          user = find_user(params[:user_id])

          if user
            achieved_milestones = user.achieved_milestones
            render_api_success({
              user_id: user.id,
              achieved_milestones: achieved_milestones,
              total_points: user.total_milestone_points,
              achievement_count: achieved_milestones.size
            })
          else
            render_api_error("User not found", status: :not_found)
          end
        end

        private

        def find_user(user_id)
          user_class = RailsOnboarding.configuration.user_class_name.constantize
          user_class.find_by(id: user_id)
        end
      end
    end
  end
end
