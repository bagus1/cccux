module Cccux
  class CccuxController < ApplicationController
    layout 'cccux/admin'
    
    # CanCanCan authorization
    include CanCan::ControllerAdditions
    
    # Automatically load and authorize resources for all actions
    # This works because CCCUX provides default roles (Guest, Basic User) 
    # so every user has permissions to check against
    load_and_authorize_resource
    
    before_action :set_current_user
    
    protected
    
    # Override current_ability to use CCCUX Ability class
    def current_ability
      @current_ability ||= Cccux::Ability.new(current_user)
    end
    
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
    
    def set_current_user
      @current_user = current_user if defined?(current_user)
    end
  end
end 