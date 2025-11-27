Rails.application.routes.draw do
  root to: "application#index"
  mount RailsOnboarding::Engine => "/rails_onboarding"

  # Test authentication routes (only in test environment)
  if Rails.env.test?
    get  "/test_auth/login", to: "test_auth#login"
    get  "/test_auth/logout", to: "test_auth#logout"
  end
end
