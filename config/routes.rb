RailsOnboarding::Engine.routes.draw do
  resource :onboarding, only: [ :show ], controller: "onboarding" do
    post :next
    post :complete
    post :skip
    post :back
    post :restart
  end

  resources :tooltips, only: [] do
    member do
      post :mark_shown
    end
  end

  resources :milestones, only: [ :index, :show ] do
    collection do
      get :recent
      post :achieve
    end
  end
end
