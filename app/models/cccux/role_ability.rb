module Cccux
  class RoleAbility < ApplicationRecord
    self.table_name = 'cccux_role_abilities'
    
    belongs_to :role, class_name: 'Cccux::Role'
    belongs_to :ability_permission, class_name: 'Cccux::AbilityPermission'
    
    validates :role_id, presence: true
    validates :ability_permission_id, presence: true
    validates :owned, inclusion: { in: [true, false] }
    
    # Ensure unique combinations of role, permission, and ownership scope
    validates :ability_permission_id, uniqueness: { 
      scope: [:role_id, :owned], 
      message: "already exists for this role and ownership scope" 
    }
    
    scope :owned_only, -> { where(owned: true) }
    scope :all_records, -> { where(owned: false) }
    
    def display_name
      "#{role.name} - #{ability_permission.display_name}"
    end

    def scope_description
      owned? ? "Owned records only" : "All records"
    end
  end
end 