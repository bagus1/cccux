module Cccux
  class RoleAbility < ApplicationRecord
    self.table_name = 'cccux_role_abilities'
    
    belongs_to :role, class_name: 'Cccux::Role'
    belongs_to :ability_permission, class_name: 'Cccux::AbilityPermission'
    
    # Delegate methods to ability_permission
    delegate :action, :subject, :active?, to: :ability_permission, allow_nil: true
    
    # Simplified access types: global, owned
    ACCESS_TYPES = %w[global owned].freeze
    
    validates :role_id, presence: true
    validates :ability_permission_id, presence: true
    validates :context, inclusion: { in: %w[global owned], allow_nil: true }
    validates :owned, inclusion: { in: [true, false] }
    
    # Ensure unique combinations of role, permission, ownership scope, and context
    validates :ability_permission_id, uniqueness: { 
      scope: [:role_id, :owned, :context], 
      message: "already exists for this role, ownership scope, and context" 
    }
    
    scope :global_access, -> { where(context: 'global') }
    scope :owned_access, -> { where(owned: true) }
    
    # Simplified access types: global, owned
    def access_type
      if owned
        'owned'
      else
        'global'
      end
    end
    
    def display_name
      "#{role.name} - #{ability_permission.display_name}"
    end

    def access_description
      case access_type
      when 'global'
        "Global access to all records"
      when 'owned'
        "Access to owned records or records via configured ownership relationship"
      else
        "Unknown access"
      end
    end
  end
end 