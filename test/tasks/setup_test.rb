require "test_helper"
require "rake"

class Cccux::SetupTaskTest < ActiveSupport::TestCase
  def setup
    Cccux::Engine.load_tasks
    @task = Rake::Task["cccux:setup"]
    @task.reenable
  end

  test "setup task should exist" do
    assert @task
  end

  test "setup task should create initial admin user when none exists" do
    # Ensure no users exist
    Cccux::User.delete_all
    Cccux::Role.delete_all
    
    # Capture output
    output = capture_io do
      @task.invoke
    end
    
    # Should create admin role
    admin_role = Cccux::Role.find_by(name: "Admin")
    assert admin_role, "Admin role should be created"
    
    # Should create admin user
    admin_user = Cccux::User.find_by(email: "admin@example.com")
    assert admin_user, "Admin user should be created"
    assert_includes admin_user.roles, admin_role
    
    # Should provide feedback
    assert_includes output.first, "Admin user created"
  end

  test "setup task should not duplicate admin user if exists" do
    # Create existing admin
    existing_admin = Cccux::User.create!(
      name: "Existing Admin",
      email: "admin@example.com"
    )
    
    user_count_before = Cccux::User.count
    
    output = capture_io do
      @task.invoke
    end
    
    assert_equal user_count_before, Cccux::User.count
    assert_includes output.first, "Admin user already exists"
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
    # Mock File operations to avoid actually creating files
    File.stub :exist?, false do
      FileUtils.stub :copy, nil do
        output = capture_io do
          @task.invoke
        end
        
        assert_includes output.first, "Copied initializer"
      end
    end
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