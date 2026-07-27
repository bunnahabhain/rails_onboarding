RailsOnboarding::Engine.routes.draw do
  # Test-only route for setting session in integration tests (no URL helpers needed)
  post "test_session", to: "test_sessions#create", as: nil if Rails.env.test?

  # Regular web routes. path: "" anchors the onboarding flow at the engine's
  # mount point, so the host app's mount path alone controls the URL -
  # `mount ... => "/onboarding"` yields /onboarding, not /onboarding/onboarding.
  resource :onboarding, only: [ :show ], controller: "onboarding", path: "" do
    post :next
    post :complete
    post :skip
    post :back
    post :restart
  end

  # Tooltip routes
  post "tooltips/dismiss", to: "tooltips#dismiss", as: :dismiss_tooltip
  post "tooltips/show", to: "tooltips#show", as: :show_tooltip
  post "tooltips/reset", to: "tooltips#reset", as: :reset_tooltips
  get "tooltips/status", to: "tooltips#status", as: :tooltip_status

  resources :tooltips, only: [] do
    member do
      post :mark_shown
    end
  end

  resources :milestones, only: [ :index, :show ] do
    collection do
      get :recent
      post :achieve
      get :progress
      post :trigger
      get :available
    end
    member do
      get :check
    end
  end

  # Admin interface
  namespace :admin do
    # Dashboard
    get "/", to: "dashboard#index", as: :dashboard

    # User management
    resources :users, only: [ :index, :show ] do
      member do
        post :reset_onboarding
        post :complete_onboarding
        post :restart_onboarding
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

    # A/B test management - tests are defined in the host app's initializer
    # (RailsOnboarding.configuration.ab_tests), so only viewing and toggling
    # them on/off is supported here, not creating or deleting them.
    resources :ab_tests, only: [ :index, :show ] do
      member do
        post :start
        post :stop
        get :export
      end
    end
  end
end
