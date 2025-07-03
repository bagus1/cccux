# frozen_string_literal: true

module Cccux
  class Ability
    include CanCan::Ability

    def initialize(user)
      return unless user

      # Get all active roles for the user
      user_roles = Cccux::UserRole.active.for_user(user).includes(:role)
      byebug
      user_roles.each do |user_role|
        role = user_role.role
        
        # Get all abilities for this role
        role_abilities = Cccux::RoleAbility.includes(:ability_permission)
                                          .where(role: role)
                                          .joins(:ability_permission)
                                          .where(cccux_ability_permissions: { active: true })
        
        role_abilities.each do |role_ability|
          permission = role_ability.ability_permission
          
          # Determine the model class
          model_class = resolve_model_class(permission.subject)
          next unless model_class
          
          # Define the ability
          if role_ability.owned
            # User can only access their own records
            can permission.action.to_sym, model_class, user_id: user.id
          else
            # User can access all records
            can permission.action.to_sym, model_class
          end
        end
      end
    end

    private

    def resolve_model_class(subject)
      # Handle namespaced models
      if subject.include?('::')
        subject.constantize
      else
        # Try to find the model in the host app
        Object.const_get(subject)
      end
    rescue NameError
      # If the model doesn't exist, we can't define permissions for it
      Rails.logger.warn "CCCUX: Model '#{subject}' not found, skipping permission"
      nil
    end
  end
end