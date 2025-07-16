# frozen_string_literal: true

module Cccux
  module ApplicationControllerConcern
    extend ActiveSupport::Concern

    included do
      # CanCanCan integration for authorization
      include CanCan::ControllerAdditions
      
      # Include CCCUX helpers for views
      helper Cccux::AuthorizationHelper
      
      # Handle CanCanCan authorization errors gracefully
      rescue_from CanCan::AccessDenied do |exception|
        if Rails.env.test?
          render plain: "Access denied", status: :forbidden
        else
          redirect_to cccux.root_path, alert: 'Access denied.'
        end
      end
      
      # Handle 404 errors gracefully
      rescue_from ActiveRecord::RecordNotFound do |exception|
        redirect_to cccux.root_path, alert: 'The requested resource was not found.'
      end
    end

    protected
    
    # Override current_ability to use CCCUX Ability class
    def current_ability
      @current_ability ||= Cccux::Ability.new(current_user)
    end
  end
end 