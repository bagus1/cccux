module Cccux
  class BaseController < ApplicationController
      layout 'cccux/admin'
      
      # Automatically load and authorize resources for all CCCUX controllers
      # This works because CCCUX provides default roles (Guest, Basic User) 
      # so every user has permissions to check against
      load_and_authorize_resource
      
      before_action :authenticate_admin!
      before_action :set_current_user
      
      protected
      
      def authenticate_admin!
        # This should be overridden by the host application
        # or we can provide a default implementation
        unless current_user_is_admin?
          if defined?(main_app) && main_app.respond_to?(:root_path)
            redirect_to main_app.root_path, alert: 'Access denied.'
          else
            render plain: 'Access denied.', status: :forbidden
          end
        end
      end
      
      def current_user_is_admin?
        # This should be implemented by the host application
        # Default to checking if user responds to admin? method
        # For development/testing, we'll return true
        return true if Rails.env.development?
        defined?(current_user) && current_user.respond_to?(:admin?) && current_user.admin?
      end
      
      def set_current_user
        @current_user = current_user if defined?(current_user)
      end
      
      def authorize_action!
        # Add authorization logic here if needed
        # For now, we just require admin access
        authenticate_admin!
      end
    end
end