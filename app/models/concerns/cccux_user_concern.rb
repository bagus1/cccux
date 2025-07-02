# frozen_string_literal: true

module CccuxUserConcern
  extend ActiveSupport::Concern

  included do
    # CCCUX associations
    has_many :cccux_user_roles, class_name: 'Cccux::UserRole', dependent: :destroy
    has_many :cccux_roles, through: :cccux_user_roles, class_name: 'Cccux::Role'
  end

  # Instance methods
  def has_role?(role_name)
    cccux_roles.active.exists?(name: role_name)
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
    
    Cccux::UserRole.find_or_create_by(user: self, role: role)
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
    cccux_roles.active.pluck(:name)
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
end 