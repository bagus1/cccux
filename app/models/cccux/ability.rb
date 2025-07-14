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
      puts "Debug: apply_owned_ability called with action=#{action}, model_class=#{model_class}, user.id=#{user.id}"
      puts "Debug: role_ability.ownership_source = #{role_ability&.ownership_source.inspect}"
      puts "Debug: role_ability.ownership_conditions = #{role_ability&.ownership_conditions.inspect}"
      
      # 1. Dynamic ownership configuration
      if role_ability && role_ability.ownership_source.present?
        puts "Debug: Taking ownership_source branch"
        ownership_model = role_ability.ownership_source.constantize rescue nil
        puts "Debug: ownership_model = #{ownership_model}"
        if ownership_model && user&.persisted?
          # Parse conditions (should be a JSON string or nil)
          conditions = role_ability.ownership_conditions.present? ? JSON.parse(role_ability.ownership_conditions) : {}
          puts "Debug: ownership_conditions raw: #{role_ability.ownership_conditions.inspect}"
          puts "Debug: ownership_conditions parsed: #{conditions.inspect}"
          foreign_key = conditions["foreign_key"] || (model_class.name.foreign_key)
          user_key = conditions["user_key"] || "user_id"
          puts "Debug: foreign_key = #{foreign_key}, user_key = #{user_key}"
          # Find all records owned by user via the join model
          owned_ids = ownership_model.where(user_key => user.id).pluck(foreign_key)
          puts "Debug: Ability#can #{action} #{model_class} id: #{owned_ids} via join model"
          if owned_ids.any?
            can action, model_class, id: owned_ids
            puts "Debug: GRANTED permission for #{action} on #{model_class} with ids: #{owned_ids}"
          else
            puts "Debug: NO owned_ids found, not granting permission"
          end
        else
          puts "Debug: ownership_model or user not valid, granting empty permission"
          can action, model_class, id: []
        end
      # 2. Model custom owned_by?
      elsif model_class.respond_to?(:owned_by?)
        puts "Debug: Taking owned_by? branch"
        puts "Debug: Ability#can #{action} #{model_class} via owned_by?"
        can action, model_class do |record|
          record.owned_by?(user)
        end
      # 3. Model custom scoped_for_user
      elsif model_class.respond_to?(:scoped_for_user)
        puts "Debug: Taking scoped_for_user branch"
        scoped_records = model_class.scoped_for_user(user)
        if scoped_records.is_a?(ActiveRecord::Relation)
          ids = scoped_records.pluck(:id)
          puts "Debug: Ability#can #{action} #{model_class} id: #{ids} via scoped_for_user"
          can action, model_class, id: ids if ids.any?
        else
          can action, model_class, scoped_records
        end
      # 4. Special case for User model (self-ownership)
      elsif model_class == User
        puts "Debug: Taking User model self-ownership branch"
        puts "Debug: Ability#can #{action} #{model_class} id: #{user.id}"
        can action, model_class, id: user.id
      # 5. Standard user_id
      elsif model_class.column_names.include?('user_id')
        puts "Debug: Taking standard user_id branch"
        puts "Debug: Ability#can #{action} #{model_class} user_id: #{user.id}"
        can action, model_class, user_id: user.id
      # 6. Standard creator_id
      elsif model_class.column_names.include?('creator_id')
        puts "Debug: Taking standard creator_id branch"
        puts "Debug: Ability#can #{action} #{model_class} creator_id: #{user.id}"
        can action, model_class, creator_id: user.id
      # 7. Dynamic ownership check for individual records
      else
        puts "Debug: Taking dynamic ownership check branch"
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
      
      puts "Debug: resolve_model_class: trying to resolve '#{subject}' with candidates: #{candidates}"
      
      candidates.each do |candidate|
        begin
          klass = candidate.constantize
          puts "Debug: resolve_model_class: tried #{candidate}, got #{klass}"
          return klass
        rescue NameError => e
          puts "Debug: resolve_model_class: NameError for #{candidate}: #{e.message}"
          next
        end
      end
      puts "Debug: resolve_model_class: failed to resolve #{subject}"
      nil
    end
  end
end