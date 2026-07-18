class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Provide current_user for testing
  def current_user
    @current_user ||= User.find_by(id: session[:user_id]) if session[:user_id]
  end
  helper_method :current_user

  def index
    render html: "<h1>Test App Home</h1>".html_safe, layout: true
  end

  # Host-app page a :path-based onboarding step can point at
  def new_profile
  end

  # Simulates the host app's real create action completing an onboarding
  # step via advance_onboarding! (from RailsOnboarding::ControllerHelpers)
  def create_profile
    if advance_onboarding!(:profile)
      redirect_to onboarding_path
    else
      redirect_to root_path
    end
  end
end
