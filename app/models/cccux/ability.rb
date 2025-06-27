# frozen_string_literal: true
module Cccux
  class Ability
    include CanCan::Ability

    def initialize(user)
      user ||= Cccux::User.new # guest user (not logged in)
      
      # Load abilities from database through user's roles
      if user.persisted?
        # Logged in user - use their assigned roles
        user.roles.includes(:ability_permissions).each do |role|
          role.ability_permissions.each do |permission|
            apply_permission_with_scoping(permission, user, role.name)
          end
        end
      else
        # Guest user (not logged in) - use "Guest" role permissions
        guest_role = Cccux::Role.find_by(name: 'Guest')
        if guest_role
          guest_role.ability_permissions.each do |permission|
            apply_permission_with_scoping(permission, user, 'Guest')
          end
        end
      end
    end

    private

    def apply_permission_with_scoping(permission, user, role_name)
      action = permission.action.to_sym
      subject_class = permission.subject.constantize
      
      # Check if this permission has custom scoping conditions
      if permission.scoping_conditions.present?
        scoping_hash = parse_scoping_conditions(permission.scoping_conditions, user)
        Rails.logger.debug "Applying scoped permission: #{action} #{subject_class} with #{scoping_hash.inspect}"
        can action, subject_class, scoping_hash
      else
        Rails.logger.debug "Applying unscoped permission: #{action} #{subject_class}"
        # Default: no scoping - full access to the model
        can action, subject_class
      end
    end

    def parse_scoping_conditions(conditions_string, user)
      # Parse JSON scoping conditions and substitute user-specific values
      begin
        conditions = JSON.parse(conditions_string)
        
        # Substitute placeholders with actual user values
        conditions.transform_values do |value|
          case value
          when '{{current_user.id}}'
            user&.id
          when '{{current_user.email}}'
            user&.email
          else
            value
          end
        end
      rescue JSON::ParserError
        # If JSON parsing fails, return empty hash (no scoping)
        {}
      end
    end
  end
end