module Cccux
  class RoleAbility < ApplicationRecord
    self.table_name = 'cccux_role_abilities'
    
    belongs_to :role, class_name: 'Cccux::Role'
    belongs_to :ability_permission, class_name: 'Cccux::AbilityPermission'
    
    validates :role_id, uniqueness: { scope: :ability_permission_id }
    
    def display_name
      "#{role.name} - #{ability_permission.display_name}"
    end
  end
end 