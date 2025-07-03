Cccux::Engine.routes.draw do
  # Devise authentication routes - use different path to avoid conflicts
  # devise_for :users, class_name: 'Cccux::User', path: 'auth'
  
  root 'dashboard#index'
  get '/test', to: 'simple#index'
  
  # Model Discovery Routes
  get 'model-discovery', to: 'dashboard#model_discovery', as: :model_discovery
  post 'sync-permissions', to: 'dashboard#sync_permissions', as: :sync_permissions
  
  # Admin CRUD routes for user management
  resources :users, path: 'admin/users' do
      member do
        patch :toggle_active
      end
      collection do
        get :search
      end
    end
    
    resources :roles do
      member do
        patch :toggle_active
        get :permissions
        patch :update_permissions
      end
      collection do
        get :search
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
    
    resources :role_abilities, only: [:index, :create, :destroy] do
      collection do
        get :search
      end
    end
end
