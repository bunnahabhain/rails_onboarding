module RailsOnboarding
  class TooltipsController < ApplicationController
    before_action :authenticate_user!

    # POST /tooltips/dismiss
    def dismiss
      tooltip_id = params[:tooltip_id]

      if tooltip_id.blank?
        render json: { success: false, message: "tooltip_id is required" }, status: :bad_request
        return
      end

      # For dismiss, we mark as shown and track as dismissed
      if current_user.respond_to?(:dismiss_tooltip)
        current_user.dismiss_tooltip(tooltip_id)
        render json: { success: true }
      elsif current_user.respond_to?(:mark_tooltip_shown!)
        # Fallback: manually mark and track
        tooltips = current_user.feature_tooltips_shown || {}
        tooltips[tooltip_id.to_s] = Time.current.iso8601
        current_user.update!(feature_tooltips_shown: tooltips)

        # Track dismissal event
        if current_user.respond_to?(:track_tooltip_interaction!)
          current_user.track_tooltip_interaction!(tooltip_id, 'dismissed')
        end
        render json: { success: true }
      else
        render json: { success: false, message: "User does not support tooltips" }, status: :unprocessable_entity
      end
    end

    # POST /tooltips/show
    def show
      tooltip_id = params[:tooltip_id]

      if tooltip_id.present? && current_user.respond_to?(:mark_tooltip_shown!)
        current_user.mark_tooltip_shown!(tooltip_id)
        render json: { success: true }
      else
        render json: { success: false, message: "Invalid tooltip_id or user" }, status: :unprocessable_entity
      end
    end

    # POST /tooltips/reset
    def reset
      if current_user.respond_to?(:reset_tooltips!)
        current_user.reset_tooltips!
        render json: { success: true }
      else
        render json: { success: false, message: "User does not support tooltips" }, status: :unprocessable_entity
      end
    end

    # GET /tooltips/status
    def status
      tooltip_id = params[:tooltip_id]

      if tooltip_id.present? && current_user.respond_to?(:show_feature_tooltip?)
        shown = !current_user.show_feature_tooltip?(tooltip_id)
        render json: { shown: shown, tooltip_id: tooltip_id }
      else
        render json: { shown: false, message: "Invalid tooltip_id or user" }, status: :unprocessable_entity
      end
    end

    # Legacy action - kept for backward compatibility
    def mark_shown
      feature = params[:feature]

      if feature.present? && current_user.respond_to?(:mark_tooltip_shown!)
        current_user.mark_tooltip_shown!(feature)
        render json: { status: "success", feature: feature }
      else
        render json: { status: "error", message: "Invalid feature or user" }, status: :unprocessable_entity
      end
    end

    private

    def authenticate_user!
      # This should be overridden by the host app
      # or use the host app's authentication
      unless defined?(current_user) && current_user
        render json: { status: "error", message: "Authentication required" }, status: :unauthorized
      end
    end
  end
end
