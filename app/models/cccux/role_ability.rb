module Cccux
  class RoleAbility < ApplicationRecord
    self.table_name = 'cccux_role_abilities'
    
    belongs_to :role, class_name: 'Cccux::Role'
    belongs_to :ability_permission, class_name: 'Cccux::AbilityPermission'
    
    # New: access field (enum: global, contextual)
    ACCESS_TYPES = %w[global contextual].freeze
    
    # For now, keep validations for owned/context for backward compatibility
    validates :role_id, presence: true
    validates :ability_permission_id, presence: true
    validates :context, inclusion: { in: %w[global owned scoped], allow_nil: true }
    validates :owned, inclusion: { in: [true, false] }
    
    # Ensure unique combinations of role, permission, ownership scope, and context
    validates :ability_permission_id, uniqueness: { 
      scope: [:role_id, :owned, :context], 
      message: "already exists for this role, ownership scope, and context" 
    }
    
    scope :global_access, -> { where(context: 'global') }
    scope :contextual_access, -> { where(context: 'scoped') }
    
    # Access types: global, contextual, owned
    def access_type
      if owned
        'owned'
      elsif context == 'global'
        'global'
      elsif context == 'scoped'
        'contextual'
      else
        'global' # fallback
      end
    end
    
    def display_name
      "#{role.name} - #{ability_permission.display_name}"
    end

    def access_description
      case access_type
      when 'global'
        "Global access"
      when 'contextual'
        "Contextual (store/project/etc) access"
      else
        "Unknown access"
      end
    end
  end
end 