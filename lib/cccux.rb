require "cccux/version"
require "cccux/engine"
require "cancancan"

module Cccux
  # Your code goes here...
  
  # Clear model discovery cache to force refresh after new models are created
  def self.model_discovery_cache_clear
    # Clear any cached model lists
    @detected_models_cache = nil
    @module_table_patterns_cache = nil
    
    # Force Rails to reload constants
    Rails.application.eager_load! if Rails.application.config.eager_load
    
    Rails.logger.info "🔄 CCCUX model discovery cache cleared"
  end
end
