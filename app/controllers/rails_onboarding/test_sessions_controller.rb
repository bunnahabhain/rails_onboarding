# Test-only controller for setting session in integration tests
module RailsOnboarding
  class TestSessionsController < ApplicationController
    skip_before_action :verify_authenticity_token, only: :create

    def create
      # Only allow in test environment
      if Rails.env.test?
        session[:user_id] = params[:user_id]
        head :ok
      else
        head :forbidden
      end
    end
  end
end
