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
    
    def display_name
      "#{name} (#{users.count} users)"
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