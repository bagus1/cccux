module Cccux
  class DashboardController < BaseController
      def index
        @stats = {
          users_count: Cccux::User.count,
          active_users_count: Cccux::User.where(active: true).count,
          roles_count: Cccux::Role.count,
          active_roles_count: Cccux::Role.where(active: true).count,
          permissions_count: Cccux::AbilityPermission.count,
          active_permissions_count: Cccux::AbilityPermission.where(active: true).count
        }
        
        @recent_users = Cccux::User.order(created_at: :desc).limit(5)
        @recent_roles = Cccux::Role.order(created_at: :desc).limit(5)
      end
    end
end