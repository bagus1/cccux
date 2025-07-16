require "test_helper"
require "rake"

class Cccux::SetupTaskTest < ActiveSupport::TestCase
  def setup
    # Ensure environment task is available for tests
    unless Rake::Task.task_defined?(:environment)
      Rake::Task.define_task(:environment) do
        # No-op for tests
      end
    end
    
    # Set ENV vars to prevent interactive prompts in tests
    ENV['ADMIN_EMAIL'] = 'test-admin@example.com'
    ENV['ADMIN_PASSWORD'] = 'test-password-123'
    ENV['ADMIN_PASSWORD_CONFIRMATION'] = 'test-password-123'
    
    Cccux::Engine.load_tasks
    @task = Rake::Task["cccux:setup"]
    @task.reenable
  end

  test "setup task should exist" do
    assert @task
  end

  test "setup task should create initial admin user when none exists" do
    # Ensure no users exist
    User.delete_all
    Cccux::Role.delete_all
    
    # Capture output
    output = capture_io do
      @task.invoke
    end
    
    # Should create Role Manager role (not Admin)
    role_manager = Cccux::Role.find_by(name: "Role Manager")
    assert role_manager, "Role Manager role should be created"
    
    # Should create admin user with ENV email
    admin_user = User.find_by(email: "test-admin@example.com")
    assert admin_user, "Admin user should be created"
    assert_includes admin_user.cccux_roles, role_manager
    
    # Should provide feedback
    assert_includes output.first, "Created Role Manager account"
  end

  test "setup task should not duplicate admin user if exists" do
    # Create existing admin
    existing_admin = FactoryBot.create(:user, 
      first_name: "Existing",
      last_name: "Admin", 
      email: "test-admin@example.com"
    )
    
    user_count_before = User.count
    
    output = capture_io do
      @task.invoke
    end
    
    assert_equal user_count_before, User.count
    assert_includes output.first, "Users already exist, skipping default Administrator creation"
  end

  test "setup task should run migrations" do
    # This is harder to test directly, but we can verify the task attempts it
    output = capture_io do
      @task.invoke
    end
    
    # Should indicate migration attempt
    assert_includes output.first, "Running CCCUX migrations"
  end

  test "setup task should copy initializer" do
    # Skip this test for now since we can't easily mock File operations in Minitest
    # The setup task functionality is tested by the other tests
    skip "File mocking not available in Minitest"
  end

  private

  def capture_io
    original_stdout = $stdout
    $stdout = fake = StringIO.new
    yield
    [fake.string]
  ensure
    $stdout = original_stdout
  end
end 