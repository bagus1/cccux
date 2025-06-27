module Cccux
  class RegistrationsController < Devise::RegistrationsController
    layout 'cccux/application'
    
    # Handle CSRF token issues with Rails 8 + Devise
    protect_from_forgery with: :null_session, only: [:create]
    
    protected
    
    def after_sign_up_path_for(resource)
      # Assign Basic User role to new users
      basic_user_role = Cccux::Role.find_by(name: 'Basic User')
      if basic_user_role
        Cccux::UserRole.create(user: resource, role: basic_user_role)
      end
      
      # Redirect to main app after registration
      main_app.try(:root_path) || main_app.try(:orders_path) || cccux.root_path
    end
    
    def sign_up_params
      params.require(:user).permit(:first_name, :last_name, :email, :password, :password_confirmation)
    end
    
    def configure_account_update_params
      devise_parameter_sanitizer.permit(:account_update, keys: [:first_name, :last_name])
    end
  end
end 