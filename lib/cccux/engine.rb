module Cccux
  class Engine < ::Rails::Engine
    isolate_namespace Cccux
    
    # Load rake tasks
    rake_tasks do
      load 'tasks/cccux_tasks.rake'
    end
  end
end
