Rails.application.routes.draw do
  root to: "application#index"
  mount RailsOnboarding::Engine => "/rails_onboarding"

  # Host-app pages used to test :path-based onboarding steps
  get  "/profile/new", to: "application#new_profile", as: :new_profile
  post "/profile",     to: "application#create_profile", as: :create_profile

  # Test authentication routes (only in test environment)
  if Rails.env.test?
    get  "/test_auth/login", to: "test_auth#login"
    get  "/test_auth/logout", to: "test_auth#logout"
  end
end
