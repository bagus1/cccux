module Cccux
  class UserRole < ApplicationRecord
    self.table_name = 'cccux_user_roles'
    
    belongs_to :user, class_name: 'Cccux::User'
    belongs_to :role, class_name: 'Cccux::Role'
    
    validates :user_id, uniqueness: { scope: :role_id }
    
    def display_name
      "#{user.email} - #{role.name}"
    end
  end
end 