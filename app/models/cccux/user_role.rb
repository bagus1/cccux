# frozen_string_literal: true

module Cccux
  class UserRole < ApplicationRecord
    self.table_name = 'cccux_user_roles'
    
    belongs_to :user, class_name: 'User', foreign_key: 'user_id'
    belongs_to :role, class_name: 'Cccux::Role'
    
    validates :user_id, presence: true
    validates :role_id, presence: true
    validates :user_id, uniqueness: { scope: :role_id, message: 'already has this role' }
    
    scope :active, -> { joins(:role).where(cccux_roles: { active: true }) }
    scope :for_user, ->(user) { where(user: user) }
    scope :with_role, ->(role) { where(role: role) }

    def self.assign_role_to_user(user, role)
      find_or_create_by(user: user, role: role)
    end

    def self.remove_role_from_user(user, role)
      where(user: user, role: role).destroy_all
    end

    def self.user_has_role?(user, role)
      exists?(user: user, role: role)
    end

    def self.roles_for_user(user)
      joins(:role).where(user: user).pluck('cccux_roles.name')
    end

    def self.users_with_role(role)
      joins(:user).where(role: role).pluck('users.email')
    end

    def display_name
      "#{user.email} - #{role.name}"
    end
  end
end 