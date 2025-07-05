module Cccux
  module Authorizable
    extend ActiveSupport::Concern
    
    class_methods do
      # Convenience scope for authorized access (shorter than accessible_by(current_ability))
      # Requires an explicit ability parameter for reliability
      # 
      # Usage:
      #   User.owned(current_ability)  # In controllers
      #   User.owned(ability)          # When you have an ability object
      #
      # This ensures proper authorization regardless of thread context
      def owned(ability)
        if ability
          accessible_by(ability)
        else
          # Fallback: return all records (this should be overridden in specific models if needed)
          Rails.logger.warn "CCCUX: No ability provided for #{self.name}.owned scope, returning all records"
          all
        end
      end
    end
  end
end 