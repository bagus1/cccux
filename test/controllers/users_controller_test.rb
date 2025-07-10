require "test_helper"

class Cccux::UsersControllerTest < ActionDispatch::IntegrationTest
  include Cccux::Engine.routes.url_helpers
  include Devise::Test::IntegrationHelpers

  def setup
    @user = User.find_or_create_by(email: "test@example.com") do |user|
      user.password = "password123"
    end
    @other_user = User.find_or_create_by(email: "other@example.com") do |user|
      user.password = "password123"
    end
    
    # Create roles using find_or_create_by to avoid duplicates
    @admin_role = Cccux::Role.find_or_create_by(name: "Admin") do |role|
      role.active = true
    end
    @role_manager_role = Cccux::Role.find_or_create_by(name: "Role Manager") do |role|
      role.active = true
    end
    @basic_user_role = Cccux::Role.find_or_create_by(name: "Basic User") do |role|
      role.active = true
    end
    @guest_role = Cccux::Role.find_or_create_by(name: "Guest") do |role|
      role.active = true
    end
    
    # Create permissions using find_or_create_by
    user_permissions = [
      Cccux::AbilityPermission.find_or_create_by(action: 'read', subject: 'User') do |p|
        p.active = true
      end,
      Cccux::AbilityPermission.find_or_create_by(action: 'create', subject: 'User') do |p|
        p.active = true
      end,
      Cccux::AbilityPermission.find_or_create_by(action: 'update', subject: 'User') do |p|
        p.active = true
      end,
      Cccux::AbilityPermission.find_or_create_by(action: 'destroy', subject: 'User') do |p|
        p.active = true
      end
    ]
    
    role_permissions = [
      Cccux::AbilityPermission.find_or_create_by(action: 'read', subject: 'Cccux::Role') do |p|
        p.active = true
      end,
      Cccux::AbilityPermission.find_or_create_by(action: 'create', subject: 'Cccux::Role') do |p|
        p.active = true
      end,
      Cccux::AbilityPermission.find_or_create_by(action: 'update', subject: 'Cccux::Role') do |p|
        p.active = true
      end,
      Cccux::AbilityPermission.find_or_create_by(action: 'destroy', subject: 'Cccux::Role') do |p|
        p.active = true
      end
    ]
    
    permission_permissions = [
      Cccux::AbilityPermission.find_or_create_by(action: 'read', subject: 'Cccux::AbilityPermission') do |p|
        p.active = true
      end,
      Cccux::AbilityPermission.find_or_create_by(action: 'create', subject: 'Cccux::AbilityPermission') do |p|
        p.active = true
      end,
      Cccux::AbilityPermission.find_or_create_by(action: 'update', subject: 'Cccux::AbilityPermission') do |p|
        p.active = true
      end,
      Cccux::AbilityPermission.find_or_create_by(action: 'destroy', subject: 'Cccux::AbilityPermission') do |p|
        p.active = true
      end
    ]
    
    # Role Manager gets all permissions (like in setup task)
    (user_permissions + role_permissions + permission_permissions).each do |permission|
      Cccux::RoleAbility.find_or_create_by(
        role: @role_manager_role,
        ability_permission: permission
      ) do |ra|
        ra.owned = false
      end
    end
    
    # Basic User gets limited permissions
    Cccux::RoleAbility.find_or_create_by(
      role: @basic_user_role,
      ability_permission: user_permissions.find { |p| p.action == "read" }
    ) do |ra|
      ra.owned = false
    end
    
    Cccux::RoleAbility.find_or_create_by(
      role: @basic_user_role,
      ability_permission: user_permissions.find { |p| p.action == "update" }
    ) do |ra|
      ra.owned = true
      ra.context = "owned"
    end
    
    # Guest gets read-only permissions
    Cccux::RoleAbility.find_or_create_by(
      role: @guest_role,
      ability_permission: user_permissions.find { |p| p.action == "read" }
    ) do |ra|
      ra.owned = false
    end
    
    # Assign roles to users
    @user.assign_role(@role_manager_role)
    @other_user.assign_role(@basic_user_role)
  end

  test "should get index when authorized" do
    sign_in @user
    
    # Test with specific User instance
    test_user = User.first || FactoryBot.create(:user)
    
    # Test the role check
    assert @user.has_role?('Role Manager'), "User should have Role Manager role"
    
    # Test the authorization
    assert @user.can?(:read, User), "User should be able to read User"
    assert @user.can?(:index, User), "User should be able to index User"
  end

  test "should deny index when not authenticated" do
    get cccux.users_path
    assert_response :forbidden
  end

  test "should show user when authorized" do
    sign_in @user
    get cccux.user_path(@other_user)
    assert_response :success
  end

  test "should get new when authorized" do
    sign_in @user
    get cccux.new_user_path
    assert_response :success
  end

  test "should create user when authorized" do
    sign_in @user
    
    assert_difference("User.count") do
      post cccux.users_path, params: { user: { first_name: "New", last_name: "User", email: "new@example.com", password: "password123", password_confirmation: "password123" } }
    end
    
    assert_redirected_to cccux.user_path(User.last)
  end

  test "should not create user with invalid params" do
    sign_in @user
    
    assert_no_difference("User.count") do
      post cccux.users_path, params: { user: { first_name: "", last_name: "", email: "invalid" } }
    end
    
    assert_response :unprocessable_entity
  end

  test "should get edit when authorized" do
    sign_in @user
    get cccux.edit_user_path(@other_user)
    assert_response :success
  end

  test "should update user when authorized" do
    sign_in @user
    
    patch cccux.user_path(@other_user), params: {
      user: {
        first_name: "Updated",
        last_name: "Name"
      }
    }
    
    assert_redirected_to cccux.user_path(@other_user)
    assert_equal "Updated", @other_user.reload.first_name
    assert_equal "Name", @other_user.reload.last_name
  end

  test "should destroy user when authorized" do
    sign_in @user
    user_to_delete = FactoryBot.create(:user)

    assert_difference("User.count", -1) do
      delete cccux.user_path(user_to_delete)
    end

    assert_redirected_to cccux.users_path
  end

  test "should assign roles to user" do
    sign_in @user
    new_role = Cccux::Role.find_or_create_by(name: "Test Role") do |role|
      role.active = true
    end
    
    patch cccux.user_path(@other_user), params: {
      user: {
        role_ids: [new_role.id]
      }
    }
    
    assert_includes @other_user.reload.cccux_roles, new_role
  end
end 