begin
  require 'bundler/setup'
rescue LoadError
  puts 'You must `gem install bundler` and `bundle install` to run rake tasks'
end

require 'rdoc/task'

RDoc::Task.new(:rdoc) do |rdoc|
  rdoc.rdoc_dir = 'rdoc'
  rdoc.title    = 'Cccux'
  rdoc.options << '--line-numbers'
  rdoc.rdoc_files.include('README.md')
  rdoc.rdoc_files.include('lib/**/*.rb')
end

# Load the engine's tasks
APP_RAKEFILE = File.expand_path("test/dummy/Rakefile", __dir__)
load 'rails/tasks/engine.rake'

load 'rails/tasks/statistics.rake'

require 'bundler/gem_tasks'

# Custom test preparation task
namespace :test do
  desc "Prepare test database"
  task :prepare do
    puts "🧪 Preparing test database..."
    
    # Change to dummy app directory and setup database
    Dir.chdir(File.expand_path("test/dummy", __dir__)) do
      system("RAILS_ENV=test bundle exec rails db:environment:set RAILS_ENV=test")
      system("RAILS_ENV=test bundle exec rails db:schema:load")
    end
    
    puts "✅ Test database prepared"
  end
end

# Override the default test task to include preparation
task :test => 'test:prepare'

# Dummy environment task for engine compatibility
# This prevents "Don't know how to build task 'environment'" errors
# when engine Rake tasks depend on :environment but it's not defined
task :environment do
  # No-op: Engine doesn't need full Rails environment loading
  # Host applications will have their own real environment task
end

# Dummy db:migrate task for engine compatibility
# This prevents "Don't know how to build task 'db:migrate'" errors
# when engine Rake tasks depend on :db:migrate but it's not defined
namespace :db do
  task :migrate do
    # No-op: Engine doesn't need to run migrations in test context
    # Host applications will have their own real db:migrate task
    puts "Dummy db:migrate task called (no-op in engine context)"
  end
end
