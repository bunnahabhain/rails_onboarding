Rails.application.routes.draw do
  root to: "application#index"
  mount RailsOnboarding::Engine => "/rails_onboarding"
end
