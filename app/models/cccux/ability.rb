# frozen_string_literal: true
module Cccux
  class Ability
    include CanCan::Ability

    def initialize(user)
      user ||= Cccux::User.new # guest user (not logged in)
      
      # Load abilities from database through user's roles
      if user.persisted?
        # Logged in user - use their assigned roles
        user.roles.includes(:role_abilities => :ability_permission).each do |role|
          role.role_abilities.each do |role_ability|
            apply_permission_with_ownership_scope(role_ability, user)
          end
        end
      else
        # Guest user (not logged in) - use "Guest" role permissions
        guest_role = Cccux::Role.find_by(name: 'Guest')
        if guest_role
          guest_role.role_abilities.includes(:ability_permission).each do |role_ability|
            apply_permission_with_ownership_scope(role_ability, user)
          end
        end
      end
    end

    private

    def apply_permission_with_ownership_scope(role_ability, user)
      permission = role_ability.ability_permission
      action = permission.action.to_sym
      subject_class = permission.subject.constantize
      
      if role_ability.owned?
        # Owned records only - apply scoping based on action type
        case action
        when :index
          # For index, allow the action but scope the query
          can action, subject_class, user_id: user.id
        when :create
          # For create, allow the action (user can create new records)
          can action, subject_class
        when :show, :update, :destroy
          # For individual record actions, scope to owned records
          can action, subject_class, user_id: user.id
        else
          # For other actions, apply general ownership scope
          can action, subject_class, user_id: user.id
        end
      else
        # All records - no scoping
        can action, subject_class
      end
    end
  end
end