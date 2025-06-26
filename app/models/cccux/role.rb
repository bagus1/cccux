module Cccux
  class Role < ApplicationRecord
    self.table_name = 'cccux_roles'
    
    has_many :user_roles, dependent: :destroy, class_name: 'Cccux::UserRole'
    has_many :users, through: :user_roles, class_name: 'Cccux::User'
    has_many :role_abilities, dependent: :destroy, class_name: 'Cccux::RoleAbility'
    has_many :ability_permissions, through: :role_abilities, class_name: 'Cccux::AbilityPermission'
    
    validates :name, presence: true, uniqueness: true
    
    def permission_count
      ability_permissions.count
    end
    
    def user_count
      users.count
    end
  end
end 