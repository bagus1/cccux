# frozen_string_literal: true

module Cccux
  class Ability
    include CanCan::Ability

    def initialize(user, context = nil)
      user ||= User.new # guest user (not logged in)
      @context = context || {}
      
      # Track which permissions have been defined to avoid conflicts
      @defined_permissions = Set.new
      
      if user.persisted?
        # Authenticated user - use their assigned roles in priority order
        user_roles = Cccux::UserRole.active.for_user(user).includes(:role).joins(:role).order('cccux_roles.priority DESC')
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
        
        # Check if this permission has already been defined by a higher priority role
        permission_key = "#{permission.action}:#{permission.subject}:#{role_ability.context}"
        next if @defined_permissions.include?(permission_key)
        
        # Mark this permission as defined
        @defined_permissions.add(permission_key)
        
        # Define the ability based on context and ownership
        apply_access_ability(role_ability, permission, model_class, user)
      end
    end
    
    def apply_access_ability(role_ability, permission, model_class, user)
      action = permission.action.to_sym
      
      # For User resource, keep owned logic for now
      if permission.subject == 'User'
        if role_ability.context == 'owned' || (role_ability.owned && user&.persisted?)
          apply_owned_ability(action, model_class, user, role_ability)
        else
          can action, model_class
        end
      else
        # For all other resources, use global/owned (contextual is now handled by owned with configuration)
        case role_ability.access_type
        when 'global'
          can action, model_class
        when 'owned'
          apply_owned_ability(action, model_class, user, role_ability)
        else
          # Default: deny access if access_type is not recognized
          Rails.logger.warn "CCCUX: Unknown access_type '#{role_ability.access_type}' for #{model_class.name}, denying access"
          # Don't grant any permissions - CanCanCan denies by default
        end
      end
    end
    
    def apply_owned_ability(action, model_class, user, role_ability = nil)
      # 1. Dynamic ownership configuration
      if role_ability && role_ability.ownership_source.present?
        ownership_model = role_ability.ownership_source.constantize rescue nil
        if ownership_model && user&.persisted?
          # Parse conditions (should be a JSON string or nil)
          conditions = role_ability.ownership_conditions.present? ? JSON.parse(role_ability.ownership_conditions) : {}
          foreign_key = conditions["foreign_key"] || (model_class.name.foreign_key)
          user_key = conditions["user_key"] || "user_id"
          # Find all records owned by user via the join model
          owned_ids = ownership_model.where(user_key => user.id).pluck(foreign_key)
          can action, model_class, id: owned_ids if owned_ids.any?
        else
          Rails.logger.warn "CCCUX: Invalid ownership_source #{role_ability.ownership_source} for #{model_class.name}"
          can action, model_class, id: []
        end
      # 2. Model custom owned_by?
      elsif model_class.respond_to?(:owned_by?)
        can action, model_class do |record|
          record.owned_by?(user)
        end
      # 3. Model custom scoped_for_user
      elsif model_class.respond_to?(:scoped_for_user)
        scoped_records = model_class.scoped_for_user(user)
        if scoped_records.is_a?(ActiveRecord::Relation)
          ids = scoped_records.pluck(:id)
          can action, model_class, id: ids if ids.any?
        else
          can action, model_class, scoped_records
        end
      # 4. Standard user_id
      elsif model_class.column_names.include?('user_id')
        can action, model_class, user_id: user.id
      # 5. Standard creator_id
      elsif model_class.column_names.include?('creator_id')
        can action, model_class, creator_id: user.id
      else
        # Default: deny access when no ownership pattern is found
        Rails.logger.warn "CCCUX: No ownership pattern found for #{model_class.name}, denying access"
        # Don't grant any permissions - CanCanCan denies by default
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