# frozen_string_literal: true

module Cccux
  class NestedAuthorizationController < Cccux::AuthorizationController
    include ContextAware
    include NestedResource



    protected

    # Simplified CRUD actions that work with nested resources
    def nested_index
      collection = get_nested_collection(current_ability)
      instance_variable_set("@#{resource_name.to_s.pluralize}", collection)
    end

    def nested_show
      # Resource is already set by before_action
      validate_resource_context
    end

    def nested_new
      resource = build_nested_resource
      instance_variable_set("@#{resource_name}", resource)
    end

    def nested_create(permitted_params)
      resource = build_nested_resource(permitted_params)
      resource.user = current_user if resource.respond_to?(:user=)
      
      # Set parent association if needed
      parent = instance_variable_get("@#{parent_resource_name}")
      if parent && resource.respond_to?("#{parent_resource_name}=")
        resource.send("#{parent_resource_name}=", parent)
      end

      if resource.save
        redirect_to success_redirect_path(resource), notice: "#{resource_name.to_s.humanize} was successfully created."
      else
        render :new, status: :unprocessable_entity
      end
      
      instance_variable_set("@#{resource_name}", resource)
    end

    def nested_edit
      # Resource is already set by before_action
      validate_resource_context
    end

    def nested_update(permitted_params)
      resource = instance_variable_get("@#{resource_name}")
      
      if resource.update(permitted_params)
        redirect_to success_redirect_path(resource), notice: "#{resource_name.to_s.humanize} was successfully updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def nested_destroy
      resource = instance_variable_get("@#{resource_name}")
      resource.destroy!
      
      redirect_to success_redirect_path(resource, 'index'), notice: "#{resource_name.to_s.humanize} was successfully deleted."
    end
  end
end 