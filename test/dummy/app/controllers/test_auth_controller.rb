# Test authentication controller - only for test environment
class TestAuthController < ApplicationController
  def login
    session[:user_id] = params[:user_id] if params[:user_id].present?
    head :ok
  end

  def logout
    session[:user_id] = nil
    head :ok
  end
end
