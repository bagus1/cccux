module Cccux
  class CccuxController < ApplicationController
    layout 'cccux/admin'
    
    # Override the default error message for admin interface
    rescue_from CanCan::AccessDenied do |exception|
      respond_to do |format|
        format.html { render file: Rails.root.join('public', '403.html'), status: :forbidden, layout: false }
        format.json { render json: { error: 'Access denied' }, status: :forbidden }
        format.any  { head :forbidden }
      end
    end
    
    rescue_from ActionController::RoutingError do |exception|
      redirect_to main_app.root_path, alert: 'The requested page was not found.'
    end
    
    # Handle parameter errors (like invalid IDs)
    rescue_from ActionController::ParameterMissing do |exception|
      redirect_to main_app.root_path, alert: 'Invalid request parameters.'
    end
    
    # Automatically load and authorize resources for all actions
    # This works because CCCUX provides default roles (Guest, Basic User) 
    # so every user has permissions to check against
    load_and_authorize_resource
    
    protected
    
    # Override resource_class to handle namespaced models
    def resource_class
      # For CCCUX controllers, use the namespaced model
      if self.class.name.start_with?('Cccux::')
        # Extract the model name from controller name (e.g., RolesController -> Cccux::Role)
        model_name = self.class.name.gsub('Cccux::', '').gsub('Controller', '').singularize
        "Cccux::#{model_name}".constantize
      else
        # For host app controllers, use the default behavior
        super
      end
    rescue NameError
      # Fallback to default behavior if constantization fails
      super
    end
    
    private
    
    def ensure_role_manager
      # Check if user is authenticated
      unless defined?(current_user) && current_user&.persisted?
        respond_to do |format|
          if Rails.env.test?
            format.html { render plain: "Access denied", status: :forbidden }
          else
            format.html { redirect_to main_app.root_path, alert: 'You must be logged in to access the admin interface.' }
          end
          format.json { render json: { success: false, error: 'You must be logged in to access the admin interface.' }, status: :unauthorized }
        end
        return
      end
      
      # Check if user has ability to manage users (read or update permissions)
      unless current_user.can?(:read, User) || current_user.can?(:update, User)
        respond_to do |format|
          if Rails.env.test?
            format.html { render plain: "Access denied", status: :forbidden }
          else
            format.html { redirect_to main_app.root_path, alert: 'Access denied. You need permission to manage users.' }
          end
          format.json { render json: { success: false, error: 'Access denied. You need permission to manage users.' }, status: :forbidden }
        end
        return
      end
    end
  end
end 