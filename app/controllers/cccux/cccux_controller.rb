module Cccux
  class CccuxController < ApplicationController
    layout 'cccux/admin'
    
    # Override the default error message for admin interface
    rescue_from CanCan::AccessDenied do |exception|
      redirect_to main_app.root_path, alert: 'Access denied. Only Role Managers can access the admin interface.'
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
          format.html { redirect_to main_app.root_path, alert: 'You must be logged in to access the admin interface.' }
          format.json { render json: { success: false, error: 'You must be logged in to access the admin interface.' }, status: :unauthorized }
        end
        return
      end
      
      # Check if user has Role Manager role
      unless current_user.has_role?('Role Manager')
        respond_to do |format|
          format.html { redirect_to main_app.root_path, alert: 'Access denied. Only Role Managers can access the admin interface.' }
          format.json { render json: { success: false, error: 'Access denied. Only Role Managers can access the admin interface.' }, status: :forbidden }
        end
        return
      end
    end
  end
end 