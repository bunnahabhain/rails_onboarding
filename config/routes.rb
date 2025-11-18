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

  # Admin interface
  namespace :admin do
    # Dashboard
    get '/', to: 'dashboard#index', as: :dashboard

    # User management
    resources :users, only: [:index, :show] do
      member do
        post :reset_onboarding
        post :complete_onboarding
      end
      collection do
        post :bulk_action
      end
    end

    # Flow editor
    resources :flows do
      member do
        post :duplicate
        post :activate
        get :preview
      end
    end

    # A/B test management
    resources :ab_tests do
      member do
        post :start
        post :stop
        post :declare_winner
        get :export
      end
    end
  end
end
