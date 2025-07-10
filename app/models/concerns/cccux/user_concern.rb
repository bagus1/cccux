# frozen_string_literal: true

module Cccux
  module UserConcern
    extend ActiveSupport::Concern

    included do
      # CCCUX associations
      has_many :cccux_user_roles, class_name: 'Cccux::UserRole', dependent: :destroy
      has_many :cccux_roles, through: :cccux_user_roles, source: :role, class_name: 'Cccux::Role'
      
      # Automatically assign Basic User role to new users
      after_create :assign_default_role
    end

    # Instance methods for user authorization
    def has_role?(role_name)
      cccux_user_roles.active.joins(:role).where(cccux_roles: { name: role_name }).exists?
    end

    def has_any_role?(*role_names)
      cccux_roles.active.where(name: role_names).exists?
    end

    def has_all_roles?(*role_names)
      role_names.all? { |role_name| has_role?(role_name) }
    end

    def can?(action, subject)
      # Use CanCan's ability system
      ability = Cccux::Ability.new(self)
      ability.can?(action, subject)
    end

    def cannot?(action, subject)
      !can?(action, subject)
    end

    def assign_role(role)
      return false unless role.is_a?(Cccux::Role) || role.is_a?(String)
      
      if role.is_a?(String)
        role = Cccux::Role.find_by(name: role)
        return false unless role
      end
      
      user_role = Cccux::UserRole.find_or_create_by(user: self, role: role)
      user_role.update!(active: true)
      user_role
    end

    def remove_role(role)
      return false unless role.is_a?(Cccux::Role) || role.is_a?(String)
      
      if role.is_a?(String)
        role = Cccux::Role.find_by(name: role)
        return false unless role
      end
      
      cccux_user_roles.where(role: role).destroy_all
    end

    def role_names
      cccux_user_roles.active.joins(:role).pluck('cccux_roles.name')
    end

    def highest_priority_role
      cccux_roles.active.order(:priority).first
    end

    def admin?
      has_role?('Administrator')
    end

    def role_manager?
      has_role?('Role Manager')
    end

    private

    def assign_default_role
      # Only assign if user has no roles yet
      if cccux_roles.empty?
        basic_user_role = Cccux::Role.find_by(name: 'Basic User')
        assign_role(basic_user_role) if basic_user_role
      end
    end
  end
end 