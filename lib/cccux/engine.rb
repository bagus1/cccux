module Cccux
  class Engine < ::Rails::Engine
    isolate_namespace Cccux
    
    # Automatically append engine migrations to host app
    initializer :append_migrations do |app|
      unless app.root.to_s.match root.to_s
        config.paths["db/migrate"].expanded.each do |expanded_path|
          app.config.paths["db/migrate"] << expanded_path
        end
      end
    end
    
    # Load rake tasks
    rake_tasks do
      load 'tasks/cccux_tasks.rake'
    end
  end
end
