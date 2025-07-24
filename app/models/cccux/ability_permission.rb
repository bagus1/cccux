module Cccux
  class AbilityPermission < ApplicationRecord
    self.table_name = 'cccux_ability_permissions'
    
    has_many :role_abilities, dependent: :destroy, class_name: 'Cccux::RoleAbility'
    has_many :roles, through: :role_abilities, class_name: 'Cccux::Role'
    
    validates :action, presence: true
    validates :subject, presence: true
    validates :action, uniqueness: { scope: :subject }
    
    scope :for_subject, ->(subject) { where(subject: subject) }
    scope :for_action, ->(action) { where(action: action) }
    
    # Ensure all permissions are created as active by default
    before_create :ensure_active
    
    def display_name
      "#{action.humanize} #{subject}"
    end
    
    def role_count
      roles.count
    end
    
    # Determine if this permission supports ownership controls
    def supports_ownership?
      # CCCUX system models don't support ownership
      return false if subject.start_with?('Cccux::')
      
      # You could add more sophisticated logic here:
      # - Check if the model has ownership methods (owned_by?, scoped_for_user)
      # - Check against a configuration list
      # - Check if the model is in a specific namespace
      
      true
    end
    
    # Get the model class for this permission
    def model_class
      return nil unless subject.present?
      
      if subject.include?('::')
        subject.constantize
      else
        Object.const_get(subject)
      end
    rescue NameError
      nil
    end
    
    # Check if the model has ownership capabilities
    def model_supports_ownership?
      klass = model_class
      return false unless klass
      
      # Check if model has ownership methods
      klass.respond_to?(:owned_by?) || 
      klass.respond_to?(:scoped_for_user) ||
      klass.column_names.include?('user_id') ||
      klass.column_names.include?('creator_id')
    end
    
    private
    
    def ensure_active
      self.active = true if active.nil?
    end
  end
end