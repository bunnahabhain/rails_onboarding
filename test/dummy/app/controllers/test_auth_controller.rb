# Test authentication controller - only for test environment
class TestAuthController < ApplicationController
  def login
    session[:user_id] = params[:user_id] if params[:user_id].present?
    head :ok
  end

  # A message on the way to onboarding, as a host's redirect would carry one.
  def flash_to_onboarding
    flash[params[:type]] = params[:message]
    redirect_to "/rails_onboarding"
  end

  def logout
    session[:user_id] = nil
    head :ok
  end
end
