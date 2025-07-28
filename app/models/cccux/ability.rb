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
      
      # Handle action aliases (read includes show and index)
      actions_to_grant = case action
      when :read
        [:read, :show, :index]
      when :update
        [:update, :edit]
      when :create
        [:create, :new]
      when :destroy
        [:destroy, :delete]
      else
        [action]
      end
      
      # For User resource, keep owned logic for now
      if permission.subject == 'User'
        if role_ability.context == 'owned' || role_ability.owned
          actions_to_grant.each { |act| apply_owned_ability(act, model_class, user, role_ability) }
        else
          actions_to_grant.each { |act| can act, model_class }
        end
      else
        # For all other resources, use global/owned logic based on context field
        if role_ability.context == 'owned' || role_ability.owned
          actions_to_grant.each { |act| apply_owned_ability(act, model_class, user, role_ability) }
        else
          actions_to_grant.each { |act| can act, model_class }
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
          foreign_key = conditions["foreign_key"]
          user_key = conditions["user_key"] || "user_id"
          
          # Require foreign_key to be explicitly specified when using ownership model
          if foreign_key.present?
            # Find all records owned by user via the join model
            owned_ids = ownership_model.where(user_key => user.id).pluck(foreign_key)
            if owned_ids.any?
              # Check if the target model has the foreign key column
              if model_class.column_names.include?(foreign_key)
                # Direct ownership: model has the foreign key (e.g., Comment has post_id)
                can action, model_class, foreign_key.to_sym => owned_ids
              else
                # Indirect ownership: model doesn't have the foreign key, use primary key
                # This means the foreign key in the join table refers to the target model's primary key
                can action, model_class, id: owned_ids
              end
            else
              can action, model_class, id: []
            end
          else
            # Fall back to no access if foreign_key is not specified
            can action, model_class, id: []
          end
        else
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
      # 4. Special case for User model (self-ownership)
      elsif model_class == User
        can action, model_class, id: user.id
      # 5. Standard user_id
      elsif model_class.column_names.include?('user_id')
        can action, model_class, user_id: user.id
      # 6. Standard creator_id
      elsif model_class.column_names.include?('creator_id')
        can action, model_class, creator_id: user.id
      # 7. Dynamic ownership check for individual records
      else
        # For cases where we need to check individual record attributes
        can action, model_class do |record|
          if record.respond_to?(:creator_id)
            record.creator_id == user.id
          elsif record.respond_to?(:user_id)
            record.user_id == user.id
          else
            false
          end
        end
      end
    end

    def resolve_model_class(subject)
      # Try to resolve the model class in a robust way
      candidates = []
      if subject.include?("::")
        candidates << subject
        candidates << subject.split("::").last
      else
        candidates << subject
        candidates << "Cccux::#{subject}"
      
      end
      
      # Add more candidates for common patterns
      candidates << subject.split("::").last if subject.include?("::")
      candidates << subject.gsub("Cccux::", "") if subject.start_with?("Cccux::")
      
      candidates.each do |candidate|
        begin
          klass = candidate.constantize
          return klass
        rescue NameError => e
          next
        end
      end
      nil
    end
  end
end