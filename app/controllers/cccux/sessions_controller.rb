module Cccux
  class SessionsController < Devise::SessionsController
    layout 'cccux/application'
    
    # Handle CSRF token issues with Rails 8 + Devise
    protect_from_forgery with: :null_session, only: [:create]
    
    protected
    
    def after_sign_in_path_for(resource)
      # Redirect to main app after login
      stored_location_for(resource) || main_app.try(:root_path) || main_app.try(:orders_path) || cccux.root_path
    end
    
    def after_sign_out_path_for(resource_or_scope)
      new_user_session_path
    end
  end
end 