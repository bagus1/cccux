# frozen_string_literal: true

module Cccux
  module ContextAware
    extend ActiveSupport::Concern

    included do
      class_attribute :context_mappings
      self.context_mappings = {}

      # Override current_ability to pass context for scoped permissions
      def current_ability
        context = build_context
        @current_ability ||= Cccux::Ability.new(current_user, context)
      end
    end

    class_methods do
      # Configure context mappings for this controller
      # Example: context_mapping :show, id: :store_id
      def context_mapping(action, mappings = {})
        self.context_mappings ||= {}
        self.context_mappings[action.to_sym] = mappings
      end

      # Set up standard nested resource context
      # Example: nested_context :store
      def nested_context(parent_resource)
        context_mapping :show, id: "#{parent_resource}_id".to_sym if controller_name == parent_resource.to_s.pluralize
      end
    end

    private

    # Build context hash from request parameters
    # Override this method in controllers for custom context logic
    def build_context
      context = {}
      
      # Apply standard parameter mappings
      standard_context_params.each do |param_key|
        context[param_key] = params[param_key] if params[param_key]
      end
      
      # Apply controller-specific context mappings
      if context_mappings && context_mappings[action_name.to_sym]
        context_mappings[action_name.to_sym].each do |param_key, context_key|
          context[context_key] = params[param_key] if params[param_key]
        end
      end
      
      context
    end

    # Standard context parameters to check
    def standard_context_params
      # Look for any parameter ending in _id
      params.keys.select { |key| key.to_s.end_with?('_id') }.map(&:to_sym)
    end

    # Check if user has permission for current context
    def can_access_current_context?(action, subject)
      current_ability.can?(action, subject)
    end

    # Determine the current context type based on parameters
    def determine_context
      context = build_context
      
      if context.any?
        'scoped'
      else
        'global'
      end
    end

    # Redirect with appropriate error message based on context
    def redirect_with_context_error(message = nil)
      context = build_context
      
      if context.any?
        # Try to determine the parent resource for redirect
        parent_key = context.keys.first
        parent_name = parent_key.to_s.sub(/_id$/, '')
        
        begin
          redirect_to send("#{parent_name.pluralize}_path"), 
                     alert: message || "You don't have permission to access this #{parent_name}'s resources."
        rescue NoMethodError
          # Fallback to root if we can't determine the parent path
          redirect_to root_path, 
                     alert: message || "You don't have permission to access this resource."
        end
      else
        redirect_to root_path, 
                   alert: message || "You don't have permission to access this resource."
      end
    end
  end
end 