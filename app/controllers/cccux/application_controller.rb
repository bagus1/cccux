module Cccux
  class ApplicationController < ActionController::Base
    # CanCanCan authorization - shared across all CCCUX controllers
    include CanCan::ControllerAdditions
    
    # Handle CanCan authorization errors gracefully
    rescue_from CanCan::AccessDenied do |exception|
      redirect_to main_app.root_path, alert: 'Access denied.'
    end
    
    # Handle 404 errors gracefully
    rescue_from ActiveRecord::RecordNotFound do |exception|
      redirect_to main_app.root_path, alert: 'The requested resource was not found.'
    end
    
    before_action :configure_permitted_parameters, if: :devise_controller?
    before_action :set_current_user
    
    protected
    
    # Override current_ability to use CCCUX Ability class
    def current_ability
      @current_ability ||= Cccux::Ability.new(current_user)
    end
    
    def set_current_user
      @current_user = current_user if defined?(current_user)
    end
    
    private
    
    def configure_permitted_parameters
      devise_parameter_sanitizer.permit(:sign_up, keys: [:first_name, :last_name])
      devise_parameter_sanitizer.permit(:account_update, keys: [:first_name, :last_name])
    end
  end
end
