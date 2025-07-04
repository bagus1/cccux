module Cccux
  module Authorizable
    extend ActiveSupport::Concern
    
    class_methods do
      # Convenience scope for authorized access (shorter than accessible_by(current_ability))
      # This should be called in a controller context where current_ability is available
      def owned(ability = nil)
        # If no ability is passed, try to get it from the controller context
        ability ||= Thread.current[:current_ability]
        
        if ability
          accessible_by(ability)
        else
          # Fallback: return all records (this should be overridden in specific models if needed)
          all
        end
      end
    end
  end
end 