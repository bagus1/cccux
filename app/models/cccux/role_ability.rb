module Cccux
  class RoleAbility < ApplicationRecord
    self.table_name = 'cccux_role_abilities'
    
    belongs_to :role, class_name: 'Cccux::Role'
    belongs_to :ability_permission, class_name: 'Cccux::AbilityPermission'
    
    validates :role_id, presence: true
    validates :ability_permission_id, presence: true
    validates :owned, inclusion: { in: [true, false] }
    validates :context, inclusion: { in: %w[global owned scoped], allow_nil: true }
    
    # Ensure unique combinations of role, permission, ownership scope, and context
    validates :ability_permission_id, uniqueness: { 
      scope: [:role_id, :owned, :context], 
      message: "already exists for this role, ownership scope, and context" 
    }
    
    scope :owned_only, -> { where(owned: true) }
    scope :all_records, -> { where(owned: false) }
    scope :global_context, -> { where(context: 'global') }
    scope :owned_context, -> { where(context: 'owned') }
    scope :scoped_context, -> { where(context: 'scoped') }
    
    def display_name
      "#{role.name} - #{ability_permission.display_name}"
    end

    def scope_description
      owned? ? "Owned records only" : "All records"
    end
    
    def context_description
      case context
      when 'global'
        "Global access"
      when 'owned'
        "Owned context only"
      when 'scoped'
        "Scoped context only"
      else
        "Unknown context"
      end
    end
  end
end 