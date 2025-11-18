# frozen_string_literal: true

# Devise Integration Example
# This file demonstrates how to integrate RailsOnboarding with Devise authentication

# 1. Configure Devise Integration in your initializer
# config/initializers/rails_onboarding.rb
RailsOnboarding.configure do |config|
  # Enable Devise integration (enabled by default)
  config.devise_integration_enabled = true

  # Redirect unconfirmed users to onboarding after email confirmation
  config.redirect_unconfirmed_to_onboarding = false

  # Require onboarding for new users only
  config.onboarding_required_for = :new_users
end

# 2. The integration happens automatically via the DeviseRailtie
# It will auto-include DeviseControllerExtension in Devise controllers

# 3. Optional: Manually include in your ApplicationController
class ApplicationController < ActionController::Base
  include RailsOnboarding::DeviseIntegration

  # Configure devise integration options
  configure_devise_integration(
    skip_for_admin: true,
    admin_check: ->(user) { user.admin? || user.role == 'admin' }
  )
end

# 4. Devise controllers will automatically redirect to onboarding
# after successful sign in or sign up if user should see onboarding

# 5. Custom Devise controller override example
class Users::RegistrationsController < Devise::RegistrationsController
  include RailsOnboarding::DeviseControllerExtension

  protected

  # Override after_sign_up_path_for to always redirect to onboarding
  def after_sign_up_path_for(resource)
    if resource.should_see_onboarding?
      rails_onboarding.onboarding_path
    else
      super
    end
  end

  # Override after_inactive_sign_up_path_for for unconfirmed users
  def after_inactive_sign_up_path_for(resource)
    if RailsOnboarding.configuration.redirect_unconfirmed_to_onboarding
      session[:pending_onboarding] = true
    end
    super
  end
end

# 6. Handle pending onboarding after email confirmation
class Users::ConfirmationsController < Devise::ConfirmationsController
  protected

  def after_confirmation_path_for(resource_name, resource)
    if session[:pending_onboarding]
      session.delete(:pending_onboarding)
      rails_onboarding.onboarding_path
    else
      super
    end
  end
end

# 7. Routes configuration
# config/routes.rb
Rails.application.routes.draw do
  # Mount the onboarding engine
  mount RailsOnboarding::Engine => "/onboarding"

  # Devise routes with custom controllers
  devise_for :users, controllers: {
    registrations: 'users/registrations',
    confirmations: 'users/confirmations'
  }
end

# 8. User model setup
class User < ApplicationRecord
  # Include Devise modules
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :confirmable, :trackable

  # Include RailsOnboarding Onboardable concern
  include RailsOnboarding::Onboardable

  # Admin check method
  def admin?
    role == 'admin' || is_admin
  end
end

# 9. Testing the integration
RSpec.describe "Devise Integration" do
  let(:user) { create(:user, onboarding_completed: false) }

  it "redirects to onboarding after sign in" do
    sign_in user
    expect(response).to redirect_to(rails_onboarding.onboarding_path)
  end

  it "skips onboarding for admin users" do
    admin = create(:user, :admin, onboarding_completed: false)
    sign_in admin
    expect(response).not_to redirect_to(rails_onboarding.onboarding_path)
  end

  it "redirects to stored location after onboarding completion" do
    user.update(onboarding_completed: true)
    sign_in user
    expect(response).to redirect_to(root_path)
  end
end
