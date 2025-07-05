# frozen_string_literal: true

module Cccux
  module NestedResource
    extend ActiveSupport::Concern

    included do
      class_attribute :parent_resource_name, :parent_resource_class, :resource_name, :resource_class
    end

    module ClassMethods
      # Configure nested resource settings
      # Example: nested_under :store, Store, resource: :product, resource_class: Product
      def nested_under(parent_name, parent_class, resource:, resource_class:)
        self.parent_resource_name = parent_name
        self.parent_resource_class = parent_class
        self.resource_name = resource
        self.resource_class = resource_class

        # Add before_actions for common nested resource patterns
        before_action :set_parent_resource, only: [:index, :show, :new, :create, :edit, :update, :destroy]
        before_action :set_nested_resource, only: [:show, :edit, :update, :destroy]
      end

      # Convenience method to set up a fully configured nested resource controller
      # Example: nested_resource :product, parent: :store
      def nested_resource(resource_name, parent:, resource_class: nil, parent_class: nil)
        resource_class ||= resource_name.to_s.classify.constantize
        parent_class ||= parent.to_s.classify.constantize
        
        nested_under parent, parent_class, resource: resource_name, resource_class: resource_class
        
        # Add authorization if the class responds to it (for NestedAuthorizationController)
        if respond_to?(:load_and_authorize_resource)
          load_and_authorize_resource resource_class.name.underscore.to_sym
        end
      end
    end

    private

    # Set the parent resource (e.g., @store)
    def set_parent_resource
      return unless parent_resource_configured?
      
      parent_id_param = "#{parent_resource_name}_id"
      return unless params[parent_id_param].present?

      parent = parent_resource_class.find_by(id: params[parent_id_param])
      unless parent
        redirect_to_parent_index("#{parent_resource_name.to_s.humanize} not found.")
        return
      end

      instance_variable_set("@#{parent_resource_name}", parent)
    end

    # Set the nested resource (e.g., @product)
    def set_nested_resource
      return unless parent_resource_configured?
      
      parent = instance_variable_get("@#{parent_resource_name}")
      
      if parent
        # Find resource within parent scope
        resource = parent.send(resource_name.to_s.pluralize).find_by(id: params[:id])
        unless resource
          redirect_to_nested_index("#{resource_name.to_s.humanize} not found in this #{parent_resource_name}.")
          return
        end
      else
        # Find resource globally
        resource = resource_class.find_by(id: params[:id])
        unless resource
          redirect_to_global_index("#{resource_name.to_s.humanize} not found.")
          return
        end
      end

      instance_variable_set("@#{resource_name}", resource)
    end

    # Check if the resource belongs to the current parent
    def validate_resource_context
      return unless parent_resource_configured?
      
      parent = instance_variable_get("@#{parent_resource_name}")
      resource = instance_variable_get("@#{resource_name}")
      
      return unless parent && resource

      parent_association = "#{parent_resource_name}_id"
      if resource.respond_to?(parent_association) && resource.send(parent_association) != parent.id
        redirect_to_nested_index("#{resource_name.to_s.humanize} not found in this #{parent_resource_name}.")
      end
    end

    # Build resource with proper associations
    def build_nested_resource(attributes = {})
      return unless parent_resource_configured?
      
      parent = instance_variable_get("@#{parent_resource_name}")
      
      if parent
        parent.send(resource_name.to_s.pluralize).build(attributes)
      else
        resource_class.new(attributes)
      end
    end

    # Get the collection for index action
    def get_nested_collection(ability = nil)
      return unless parent_resource_configured?
      
      parent = instance_variable_get("@#{parent_resource_name}")
      
      if parent
        collection = parent.send(resource_name.to_s.pluralize)
        ability ? collection.owned(ability) : collection
      else
        collection = resource_class.all
        ability ? collection.owned(ability) : collection
      end
    end

    # Redirect helpers
    def redirect_to_parent_index(message)
      redirect_to send("#{parent_resource_name.to_s.pluralize}_path"), alert: message
    end

    def redirect_to_nested_index(message)
      parent = instance_variable_get("@#{parent_resource_name}")
      if parent
        redirect_to send("#{parent_resource_name}_#{resource_name.to_s.pluralize}_path", parent), alert: message
      else
        redirect_to send("#{resource_name.to_s.pluralize}_path"), alert: message
      end
    end

    def redirect_to_global_index(message)
      redirect_to send("#{resource_name.to_s.pluralize}_path"), alert: message
    end

    # Generate success redirect path
    def success_redirect_path(resource, action = 'show')
      parent = instance_variable_get("@#{parent_resource_name}")
      
      if parent
        case action
        when 'show'
          send("#{parent_resource_name}_#{resource_name}_path", parent, resource)
        when 'index'
          send("#{parent_resource_name}_#{resource_name.to_s.pluralize}_path", parent)
        end
      else
        case action
        when 'show'
          send("#{resource_name}_path", resource)
        when 'index'
          send("#{resource_name.to_s.pluralize}_path")
        end
      end
    end

    def parent_resource_configured?
      parent_resource_name && parent_resource_class && resource_name && resource_class
    end
  end
end 