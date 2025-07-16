# Configure Rails Environment
ENV["RAILS_ENV"] = "test"
require "byebug"
require_relative "../test/dummy/config/environment"
ActiveRecord::Migrator.migrations_paths = [File.expand_path("../test/dummy/db/migrate", __dir__)]
ActiveRecord::Migrator.migrations_paths << File.expand_path("../db/migrate", __dir__)
require "rails/test_help"
require 'factory_bot_rails'
FactoryBot.definition_file_paths = [File.expand_path('factories', __dir__)]
FactoryBot.find_definitions
require "minitest/reporters"
Minitest::Reporters.use! Minitest::Reporters::SpecReporter.new

# Ensure the test database is prepared
begin
  # Check if tables exist, if not, load schema
  unless ActiveRecord::Base.connection.table_exists?('cccux_users')
    ActiveRecord::Tasks::DatabaseTasks.load_schema(ActiveRecord::Base.configurations.configs_for(env_name: "test").first)
  end
rescue ActiveRecord::NoDatabaseError
  # Create database if it doesn't exist
  ActiveRecord::Tasks::DatabaseTasks.create(ActiveRecord::Base.configurations.configs_for(env_name: "test").first.configuration_hash)
  ActiveRecord::Tasks::DatabaseTasks.load_schema(ActiveRecord::Base.configurations.configs_for(env_name: "test").first)
end

# Load fixtures from both engine and dummy app
if ActiveSupport::TestCase.respond_to?(:fixture_paths=)
  ActiveSupport::TestCase.fixture_paths = [
    File.expand_path("fixtures", __dir__),
    File.expand_path("dummy/test/fixtures", __dir__)
  ]
  ActionDispatch::IntegrationTest.fixture_paths = ActiveSupport::TestCase.fixture_paths
  ActiveSupport::TestCase.file_fixture_path = File.expand_path("fixtures", __dir__) + "/files"
  # ActiveSupport::TestCase.fixtures :all
end

# Add missing methods for testing
module TestHelperExtensions
  def can?(action, subject, resource = nil)
    # Use the current ability to check permissions
    current_ability.can?(action, subject, resource)
  end
  
  def current_user
    @current_user ||= User.first
  end
  
  def current_ability
    @current_ability ||= Cccux::Ability.new(current_user)
  end
  
  def devise_controller?
    false
  end
end

# Include the helper methods in test classes
ActiveSupport::TestCase.include TestHelperExtensions
ActionView::TestCase.include TestHelperExtensions
ActionDispatch::IntegrationTest.include TestHelperExtensions

class ActiveSupport::TestCase
  include FactoryBot::Syntax::Methods
end
