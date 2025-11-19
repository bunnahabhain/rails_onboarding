RailsOnboarding::Engine.routes.draw do
  # Regular web routes
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
  # API routes (v1)
  namespace :api do
    namespace :v1 do
      # Onboarding API endpoints
      get 'onboarding/status', to: 'onboarding#status'
      post 'onboarding/complete', to: 'onboarding#complete'
      post 'onboarding/restart', to: 'onboarding#restart'
      post 'onboarding/steps/:step_name/complete', to: 'onboarding#complete_step'
      post 'onboarding/steps/:step_name/skip', to: 'onboarding#skip_step'

      # Tooltips API endpoints
      get 'tooltips', to: 'tooltips#index'
      post 'tooltips/:tooltip_id/dismiss', to: 'tooltips#dismiss'

      # Milestones API endpoints
      get 'milestones', to: 'milestones#index'
      get 'milestones/:id', to: 'milestones#show'
      get 'milestones/user/:user_id', to: 'milestones#user_milestones'
    end
  end
end
