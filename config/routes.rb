Cccux::Engine.routes.draw do
  # Devise authentication routes - use different path to avoid conflicts
  # devise_for :users, class_name: 'Cccux::User', path: 'auth'
  
  # Root route for the engine - goes to dashboard
  root 'dashboard#index'
  
  # Dashboard route (alias for root)
  get '/dashboard', to: 'dashboard#index', as: :dashboard
  
  # Model Discovery Routes
  get 'model-discovery', to: 'dashboard#model_discovery', as: :model_discovery
  post 'sync-permissions', to: 'dashboard#sync_permissions', as: :sync_permissions
  post 'clear-model-cache', to: 'dashboard#clear_model_cache', as: :clear_model_cache
  
  # Admin CRUD routes for user management
  resources :users do
      member do
        patch :toggle_active
        post :assign_role
        delete :remove_role
      end
      collection do
        get :search
      end
    end
    
    resources :roles do
      resources :role_abilities, only: [:index, :create, :destroy]
      member do
        patch :toggle_active
        get :permissions
        patch :update_permissions
      end
      collection do
        get :search
        patch :reorder
        get :model_columns
      end
    end
    
    resources :ability_permissions do
      member do
        patch :toggle_active
      end
      collection do
        get :search
        get :grid
        post :bulk_create
        get :actions_for_subject
      end
    end
    
    resources :user_roles, only: [:index, :create, :destroy] do
      collection do
        get :search
      end
    end
    

    
    # Catch-all route for any unmatched paths in CCCUX - redirect to home
    match '*unmatched', to: 'dashboard#not_found', via: :all
end
