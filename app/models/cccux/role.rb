# frozen_string_literal: true

module Cccux
  class Role < ApplicationRecord
    self.table_name = 'cccux_roles'
    
    has_many :user_roles, dependent: :destroy, class_name: 'Cccux::UserRole'
    has_many :users, through: :user_roles, class_name: 'User'
    has_many :role_abilities, dependent: :destroy, class_name: 'Cccux::RoleAbility'
    has_many :ability_permissions, through: :role_abilities, class_name: 'Cccux::AbilityPermission'
    
    validates :name, presence: true, uniqueness: true
    validates :priority, presence: true, numericality: { only_integer: true, greater_than: 0 }
    
    scope :active, -> { where(active: true) }
    scope :ordered, -> { order(:priority, :name) }
    
    def self.default_roles
      [
        { name: 'Guest', description: 'Unauthenticated users', priority: 100 },
        { name: 'Basic User', description: 'Standard authenticated users', priority: 50 },
        { name: 'Role Manager', description: 'Can manage roles and permissions', priority: 25 },
        { name: 'Administrator', description: 'Full system access', priority: 1 }
      ]
    end
    
    def assign_permission(permission)
      return false unless permission.is_a?(Cccux::AbilityPermission)
      
      Cccux::RoleAbility.find_or_create_by(role: self, ability_permission: permission)
    end
    
    def remove_permission(permission)
      return false unless permission.is_a?(Cccux::AbilityPermission)
      
      role_abilities.where(ability_permission: permission).destroy_all
    end
    
    def has_permission?(permission)
      return false unless permission.is_a?(Cccux::AbilityPermission)
      
      role_abilities.exists?(ability_permission: permission)
    end
    
    def permission_names
      ability_permissions.pluck(:action, :subject).map { |action, subject| "#{action} #{subject}" }
    end
    
    def user_count
      users.count
    end
    
    def display_name
      "#{name} (#{user_count} users)"
    end
    
    # Check if role has access to all records for a given subject
    def has_all_records_access?(subject)
      role_abilities.joins(:ability_permission)
                   .where(cccux_ability_permissions: { subject: subject }, owned: false)
                   .exists?
    end
    
    # Check if role has access to only owned records for a given subject  
    def has_owned_records_access?(subject)
      role_abilities.joins(:ability_permission)
                   .where(cccux_ability_permissions: { subject: subject }, owned: true)
                   .exists?
    end
    
    # Get ownership scope for a subject ('all', 'owned', or nil if no permissions)
    def ownership_scope_for(subject)
      if has_all_records_access?(subject)
        'all'
      elsif has_owned_records_access?(subject)
        'owned'
      else
        nil
      end
    end
  end
end 