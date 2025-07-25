RailsOnboarding::Engine.routes.draw do
  resource :onboarding, only: [:show], controller: 'onboarding' do
    post :next
    post :complete
    post :skip
  end

  resources :tooltips, only: [] do
    member do
      post :mark_shown
    end
  end
end
