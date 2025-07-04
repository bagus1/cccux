module Cccux
  class AuthorizationController < ApplicationController
    # Provide CCCUX authorization without forcing a specific layout
    # This allows host app controllers to use their own layouts
    layout 'application'
    
    # CanCanCan authorization
    include CanCan::ControllerAdditions
    
    # Handle CanCan authorization errors gracefully
    rescue_from CanCan::AccessDenied do |exception|
      redirect_to main_app.root_path, alert: 'Access denied.'
    end
    
    # Handle 404 errors gracefully
    rescue_from ActiveRecord::RecordNotFound do |exception|
      redirect_to main_app.root_path, alert: 'The requested resource was not found.'
    end
    
    # Automatically load and authorize resources for all actions
    load_and_authorize_resource
    
    before_action :set_current_user
    
    protected
    
    # Override current_ability to use CCCUX Ability class
    def current_ability
      @current_ability ||= Cccux::Ability.new(current_user)
    end
    
    def set_current_user
      @current_user = current_user if defined?(current_user)
    end
  end
end 