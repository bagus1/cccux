module Cccux
  class Engine < ::Rails::Engine
    # Only isolate namespace if explicitly mounted - check this later
    isolate_namespace Cccux
    
    # Prevent automatic route registration - only register when explicitly mounted
    config.autoload_paths += %W(#{config.root}/lib)
    
    # Automatically append engine migrations to host app
    initializer :append_migrations do |app|
      unless app.root.to_s.match root.to_s
        config.paths["db/migrate"].expanded.each do |expanded_path|
          app.config.paths["db/migrate"] << expanded_path
        end
      end
    end
    
    # Ensure concerns are autoloaded
    config.autoload_paths << root.join('app', 'models', 'concerns')
    config.eager_load_paths << root.join('app', 'models', 'concerns')
    
    # Load rake tasks
    rake_tasks do
      load 'tasks/cccux.rake'
    end
    
    # Configure assets for both Sprockets and Propshaft
    initializer "cccux.assets" do |app|
      # Add engine assets to the load path
      app.config.assets.paths << root.join('app', 'assets', 'stylesheets')
      app.config.assets.paths << root.join('app', 'assets', 'javascripts')
      
      # For Propshaft, ensure engine assets are available
      if defined?(Propshaft)
        app.config.assets.paths << root.join('app', 'assets')
      end
    end
    
    # Include helpers in host application only when mounted
    config.to_prepare do
      # Only include helpers if the engine is actually mounted
      if Rails.application.routes.respond_to?(:include?) && 
         Rails.application.routes.include?(Cccux::Engine)
        # Temporarily disabled to avoid conflicts with Devise
        # ActionView::Base.include Cccux::AuthorizationHelper
      end
    end

  end
end
