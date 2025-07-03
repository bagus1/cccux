# frozen_string_literal: true

module Cccux
  class Ability
    include CanCan::Ability

    def initialize(user)
      user ||= User.new # guest user (not logged in)
      
      if user.persisted?
        # Authenticated user - use their assigned roles
        user_roles = Cccux::UserRole.active.for_user(user).includes(:role)
        user_roles.each do |user_role|
          role = user_role.role
          apply_role_abilities(role, user)
        end
      else
        # Guest user (not logged in) - use "Guest" role permissions
        guest_role = Cccux::Role.find_by(name: 'Guest')
        if guest_role
          apply_role_abilities(guest_role, user)
        end
      end
    end

    private

    def apply_role_abilities(role, user)
      return unless role

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
        if role_ability.owned && user&.persisted?
          # User can only access their own records (only applies to authenticated users)
          can permission.action.to_sym, model_class, user_id: user.id
        else
          # User can access all records (includes Guest users with read-only access)
          can permission.action.to_sym, model_class
        end
      end
    end

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