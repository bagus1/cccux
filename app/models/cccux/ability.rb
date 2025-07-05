# frozen_string_literal: true

module Cccux
  class Ability
    include CanCan::Ability

    def initialize(user)
      user ||= User.new # guest user (not logged in)
      
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
        apply_contextual_ability(role_ability, permission, model_class, user)
      end
    end
    
    def apply_contextual_ability(role_ability, permission, model_class, user)
      action = permission.action.to_sym
      
      case role_ability.context
      when 'global'
        # Global access - can access the resource from any context
        if role_ability.owned && user&.persisted?
          apply_owned_ability(action, model_class, user)
        else
          can action, model_class
        end
        
      when 'owned'
        # Owned context only - can only access through owned relationships
        if role_ability.owned && user&.persisted?
          apply_owned_ability(action, model_class, user)
        else
          # For non-owned permissions in owned context, still restrict to owned relationships
          apply_owned_ability(action, model_class, user)
        end
        
      when 'scoped'
        # Scoped context only - can only access through specific scoped routes
        if role_ability.owned && user&.persisted?
          apply_scoped_owned_ability(action, model_class, user)
        else
          apply_scoped_ability(action, model_class, user)
        end
        
      else
        # Default to global behavior for backward compatibility
        if role_ability.owned && user&.persisted?
          apply_owned_ability(action, model_class, user)
        else
          can action, model_class
        end
      end
    end
    
    def apply_scoped_ability(action, model_class, user)
      # For scoped context, we need to check the current request context
      # This will be handled by the controller using can? checks
      can action, model_class do |record|
        # Check if we're in a scoped route context
        current_context = determine_current_context
        
        case current_context
        when 'store_scoped'
          # Check if the record belongs to the current store context
          store_id = Thread.current[:current_store_id]
          return false unless store_id
          
          # Assuming Order belongs_to :store
          if record.respond_to?(:store_id)
            record.store_id == store_id
          else
            false
          end
          
        when 'user_scoped'
          # Check if the record belongs to the current user context
          user_id = Thread.current[:current_user_id]
          return false unless user_id
          
          # Assuming Order belongs_to :user
          if record.respond_to?(:user_id)
            record.user_id == user_id
          else
            false
          end
          
        else
          # Not in a scoped context - deny access
          false
        end
      end
    end
    
    def apply_scoped_owned_ability(action, model_class, user)
      # For scoped owned context, combine scoping with ownership
      can action, model_class do |record|
        # First check ownership
        unless record_owned_by_user?(record, user)
          return false
        end
        
        # Then check scoped context
        current_context = determine_current_context
        
        case current_context
        when 'store_scoped'
          # Check if the record belongs to the current store context
          store_id = Thread.current[:current_store_id]
          return false unless store_id
          
          # Assuming Order belongs_to :store
          if record.respond_to?(:store_id)
            record.store_id == store_id
          else
            false
          end
          
        when 'user_scoped'
          # Check if the record belongs to the current user context
          user_id = Thread.current[:current_user_id]
          return false unless user_id
          
          # Assuming Order belongs_to :user
          if record.respond_to?(:user_id)
            record.user_id == user_id
          else
            false
          end
          
        else
          # Not in a scoped context - deny access
          false
        end
      end
    end
    
    private
    
    def determine_current_context
      # This should be set by the controller based on the current route
      Thread.current[:current_context] || 'global'
    end
    
    def record_owned_by_user?(record, user)
      if record.respond_to?(:owned_by?)
        record.owned_by?(user)
      elsif record.respond_to?(:user_id)
        record.user_id == user.id
      elsif record.respond_to?(:creator_id)
        record.creator_id == user.id
      else
        false
      end
    end

    def apply_owned_ability(action, model_class, user)
      # Try to detect ownership pattern automatically
      if model_class.respond_to?(:owned_by?)
        # Model has custom ownership method - always use block-based rule
        can action, model_class do |record|
          record.owned_by?(user)
        end
      elsif model_class.respond_to?(:scoped_for_user)
        # Model provides scoping method - use ID-based rule
        scoped_records = model_class.scoped_for_user(user)
        if scoped_records.is_a?(ActiveRecord::Relation)
          ids = scoped_records.pluck(:id)
          can action, model_class, id: ids if ids.any?
        else
          can action, model_class, scoped_records
        end
      elsif model_class.column_names.include?('user_id')
        # Standard user_id ownership pattern
        can action, model_class, user_id: user.id
      elsif model_class.column_names.include?('creator_id')
        # Creator ownership pattern
        can action, model_class, creator_id: user.id
      else
        # Fallback: no ownership pattern found - grant access to all records
        Rails.logger.warn "CCCUX: No ownership pattern found for #{model_class.name}, granting access to all records"
        can action, model_class
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