module Cccux
  module Admin
    class BaseController < ApplicationController
      layout 'cccux/admin'
      
      before_action :authenticate_admin!
      before_action :set_current_user
      
      protected
      
      def authenticate_admin!
        # This should be overridden by the host application
        # or we can provide a default implementation
        redirect_to main_app.root_path, alert: 'Access denied.' unless current_user_is_admin?
      end
      
      def current_user_is_admin?
        # This should be implemented by the host application
        # Default to checking if user responds to admin? method
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
end