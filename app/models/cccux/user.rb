module Cccux
  class User < ApplicationRecord
    self.table_name = 'cccux_users'
    
    # Authorization relationships
    has_many :user_roles, dependent: :destroy, class_name: 'Cccux::UserRole'
    has_many :roles, through: :user_roles, class_name: 'Cccux::Role'
    
    validates :email, presence: true, uniqueness: true
    
    def has_role?(role_name)
      roles.exists?(name: role_name)
    end
    
    def admin?
      has_role?('Admin')
    end
    
    def role_names
      roles.pluck(:name)
    end
  end
end 