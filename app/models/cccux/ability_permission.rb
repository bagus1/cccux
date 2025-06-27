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
    
    def display_name
      "#{action.humanize} #{subject}"
    end
    
    def role_count
      roles.count
    end
  end
end