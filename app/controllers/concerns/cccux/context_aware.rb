# frozen_string_literal: true

module Cccux
  module ContextAware
    extend ActiveSupport::Concern
    
    included do
      before_action :set_current_context
    end
    
    private
    
    def set_current_context
      # Clear any previous context
      Thread.current[:current_context] = nil
      Thread.current[:current_store_id] = nil
      Thread.current[:current_user_id] = nil
      
      # Determine context based on route parameters
      if params[:store_id].present?
        Thread.current[:current_context] = 'store_scoped'
        Thread.current[:current_store_id] = params[:store_id]
      elsif params[:user_id].present?
        Thread.current[:current_context] = 'user_scoped'
        Thread.current[:current_user_id] = params[:user_id]
      else
        Thread.current[:current_context] = 'global'
      end
    end
    
    def current_context
      Thread.current[:current_context] || 'global'
    end
    
    def current_store_id
      Thread.current[:current_store_id]
    end
    
    def current_user_id
      Thread.current[:current_user_id]
    end
  end
end 