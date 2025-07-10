Rails.application.routes.draw do
  get "home/index"
  devise_for :users
  root 'home#index'
  
  # Add posts routes for testing
  resources :posts do
    resources :comments
  end
  
  # Add a root route for the dummy app
  
  mount Cccux::Engine => "/cccux"
end
