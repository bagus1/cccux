require "test_helper"

class Cccux::AuthorizationFlowTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  
  def setup
    # Ensure all AbilityPermission records for User exist and are active
    %w[read create update destroy index].each do |action|
      Cccux::AbilityPermission.find_or_create_by!(action: action, subject: 'User') do |perm|
        perm.active = true
      end
      # If already exists, ensure active is true
      perm = Cccux::AbilityPermission.find_by(action: action, subject: 'User')
      perm.update!(active: true) if perm && !perm.active
    end

    # Create only the essential roles and users for the base setup
    @role_manager_role = Cccux::Role.find_or_create_by(name: "Role Manager") do |role|
      role.description = "Can manage roles and permissions"
      role.active = true
      role.priority = 25
    end

    # Explicitly assign all permissions for Cccux::Role to Role Manager
    %w[read create update destroy index].each do |action|
      perm = Cccux::AbilityPermission.find_or_create_by!(action: action, subject: 'Cccux::Role') { |p| p.active = true }
      @role_manager_role.role_abilities.find_or_create_by!(ability_permission: perm)
    end

    @role_manager = User.create!(email: "role_manager@example.com", password: "password123")
    @role_manager.assign_role(@role_manager_role)
    @manager = User.create!(email: "manager@example.com", password: "password123")
    @user = User.create!(email: "user@example.com", password: "password123")
    setup_basic_permissions
  end

  def setup_basic_permissions
    # Assign ALL permissions in the AbilityPermission table to Role Manager role
    # This matches the behavior in cccux.rake setup task
    Cccux::AbilityPermission.all.each do |permission|
      @role_manager_role.role_abilities.find_or_create_by(ability_permission: permission, owned: false)
    end
  end

  def create_role_as_role_manager(role_name, description = nil)
    sign_in_as(@role_manager)
    
    post cccux.roles_path, params: { 
      role: { 
        name: role_name, 
        description: description,
        active: true 
      } 
    }
    
    assert_response :redirect
    role = Cccux::Role.find_by(name: role_name)
    assert role, "Role '#{role_name}' should have been created"
    
    # Sign out after creating role
    sign_out @role_manager
    
    role
  end

  def assign_permission_to_role(role, action, subject, owned = false, ownership_source = nil, ownership_conditions = nil)
    sign_in_as(@role_manager)
    
    # Find or create the permission
    permission = Cccux::AbilityPermission.find_or_create_by(action: action, subject: subject) do |p|
      p.active = true
    end
    
    # Create role ability
    role_ability_params = {
      ability_permission_id: permission.id,
      owned: owned
    }
    
    if ownership_source
      role_ability_params[:ownership_source] = ownership_source
    end
    
    if ownership_conditions
      role_ability_params[:ownership_conditions] = ownership_conditions.to_json
    end
    
    post cccux.role_role_abilities_path(role), params: {
      cccux_role_ability: role_ability_params
    }
    
    assert_response :redirect
    role_ability = role.role_abilities.find_by(ability_permission: permission)
    assert role_ability, "Role ability should have been created for #{action} #{subject}"
    
    # Sign out after assigning permission
    sign_out @role_manager
    
    role_ability
  end

  def assign_role_to_user(user, role)
    sign_in_as(@role_manager)
    
    # Get current role IDs and add the new one
    current_role_ids = user.cccux_roles.pluck(:id)
    new_role_ids = current_role_ids + [role.id]
    
    patch cccux.user_path(user), params: {
      user: { role_ids: new_role_ids }
    }
    
    assert_response :redirect
    user.reload
    assert user.has_role?(role.name), "User should have been assigned #{role.name} role"
    
    # Sign out after assigning role
    sign_out @role_manager
  end

  # Removed test_complete_admin_workflow and all Admin role logic

  test "manager_with_limited_permissions_workflow" do
    # Create Manager role as Role Manager
    manager_role = create_role_as_role_manager("Manager", "Limited user management")
    
    # Assign limited permissions to Manager role
    assign_permission_to_role(manager_role, "read", "User")
    assign_permission_to_role(manager_role, "update", "User")
    
    # Assign Manager role to manager user
    assign_role_to_user(@manager, manager_role)
    
    # Test the manager workflow
    sign_in_as(@manager)

    # Manager can view users
    get cccux.users_path
    assert_response :success

    # Manager can update existing users
    patch cccux.user_path(@user), params: {
      user: { first_name: "Updated", last_name: "Name" }
    }
    assert_response :redirect
    assert_equal "Updated", @user.reload.first_name
    assert_equal "Name", @user.reload.last_name

    # Manager cannot create new users (no create permission)
    get cccux.new_user_path
    assert_response :forbidden
  end

  test "regular_user_with_minimal_permissions" do
    # Create Basic User role as Role Manager
    basic_user_role = create_role_as_role_manager("Basic User", "Standard user with minimal permissions")
    
    # Assign minimal permissions to Basic User role
    assign_permission_to_role(basic_user_role, "read", "User", true) # Can only read own profile
    
    # Assign Basic User role to regular user
    assign_role_to_user(@user, basic_user_role)
    
    # Test the regular user workflow
    sign_in_as(@user)

    # Regular user can view their own profile
    get cccux.user_path(@user)
    assert_response :success

    # Regular user can access the users index, but only see themselves
    get cccux.users_path
    assert_response :success
    assert_includes @response.body, @user.email
    assert_not_includes @response.body, @manager.email
  end

  test "guest user (not signed in) should be denied everything" do
    # No sign in
    
    get cccux.users_path
    assert_response :forbidden
    
    get cccux.roles_path
    assert_response :forbidden
  end

  test "cumulative permissions from multiple roles" do
    # Create roles as Role Manager
    manager_role = create_role_as_role_manager("Manager", "Post management")
    basic_user_role = create_role_as_role_manager("Basic User", "Standard user")
    
    # Assign permissions to Manager role
    assign_permission_to_role(manager_role, "read", "User")
    assign_permission_to_role(manager_role, "update", "User")
    
    # Assign permissions to Basic User role
    assign_permission_to_role(basic_user_role, "read", "User", true) # Own profile only
    
    # Assign both roles to user
    assign_role_to_user(@user, manager_role)
    assign_role_to_user(@user, basic_user_role)
    
    # Test cumulative permissions
    sign_in_as(@user)
    
    # Should have permissions from both roles
    get cccux.users_path
    assert_response :success  # From Manager role
    
    get cccux.user_path(@user)
    assert_response :success  # From Basic User role (own profile)
    
    # Cannot create users (no create permission from either role)
    get cccux.new_user_path
    assert_response :forbidden
  end

  test "ownership-based permissions work correctly" do
    # Create Basic User role with ownership-based permissions
    basic_user_role = create_role_as_role_manager("Basic User", "User with ownership-based permissions")
    
    # Assign ownership-based permissions
    assign_permission_to_role(basic_user_role, "read", "Post", true)
    assign_permission_to_role(basic_user_role, "update", "Post", true)
    
    # Assign role to user
    assign_role_to_user(@user, basic_user_role)
    
    # Test ownership-based permissions
    sign_in_as(@user)
    user_post = create_test_post(@user)
    other_post = create_test_post(@manager)
    
    # Can edit own post
    get "/posts/#{user_post.id}/edit"
    assert_response :success
    
    # Cannot edit other's post
    get "/posts/#{other_post.id}/edit"
    assert_response :forbidden
  end

  test "contextual permissions through ownership model" do
    # Create Manager role with contextual permissions
    manager_role = create_role_as_role_manager("Manager", "Post manager with contextual permissions")
    
    # Assign contextual permissions
    assign_permission_to_role(manager_role, "update", "Post", true, "PostManager", 
      { "foreign_key" => "post_id", "user_key" => "user_id" })
    
    # Assign role to user
    assign_role_to_user(@user, manager_role)
    
    # Test contextual permissions
    user_post = create_test_post(@user)
    other_post = create_test_post(@manager)
    create_post_manager(@user, other_post)
    
    puts "Debug: @user.id = #{@user.id}"
    puts "Debug: @manager.id = #{@manager.id}"
    puts "Debug: user_post.user_id = #{user_post.user_id}"
    puts "Debug: other_post.user_id = #{other_post.user_id}"
    puts "Debug: PostManager.where(user_id: #{@user.id}).pluck(:post_id) = #{PostManager.where(user_id: @user.id).pluck(:post_id)}"
    
    sign_in_as(@user)
    
    # Can manage posts they are manager for (even if they didn't create them)
    get "/posts/#{other_post.id}/edit"
    assert_response :success
    
    # Cannot manage posts they don't manage
    get "/posts/#{user_post.id}/edit" 
    assert_response :forbidden
  end

  test "role_manager_can_fully_manage_users_roles_and_permissions" do
    puts "Debug: Starting role_manager_can_fully_manage_users_roles_and_permissions test"
    puts "Debug: Role manager user roles: #{@role_manager.cccux_roles.pluck(:name)}"
    sign_in_as(@role_manager)
    puts "Debug: Signed in as role manager: #{@role_manager.email}"

    # USERS CRUD
    puts "Debug: Testing users index"

    get cccux.users_path
    puts "Debug: Users index response: #{response.status}"
    assert_response :success

    get cccux.new_user_path
    assert_response :success

    post cccux.users_path, params: { user: { email: "newuser@example.com", password: "password123" } }
    assert_response :redirect
    new_user = User.find_by(email: "newuser@example.com")
    assert new_user

    get cccux.edit_user_path(new_user)
    assert_response :success

    patch cccux.user_path(new_user), params: { user: { first_name: "Updated" } }
    assert_response :redirect
    assert_equal "Updated", new_user.reload.first_name

    delete cccux.user_path(new_user)
    assert_response :redirect
    assert_nil User.find_by(email: "newuser@example.com")

    # ROLES CRUD
    get cccux.roles_path
    assert_response :success

    get cccux.new_role_path
    assert_response :success

    puts "Debug: About to create role with name: 'TestRole'"
    post cccux.roles_path, params: { role: { name: "TestRole", active: true } }
    puts "Debug: Role creation response status: #{response.status}"
    puts "Debug: Role creation response body: #{response.body}" if response.status != 200 && response.status != 302
    puts "Debug: Response location: #{response.location}" if response.status == 302
    assert_response :redirect
    test_role = Cccux::Role.find_by(name: "TestRole")
    puts "Debug: TestRole found in DB: #{test_role.inspect}"
    puts "Debug: All roles in DB: #{Cccux::Role.all.map { |r| r.name }}"
    assert test_role

    get cccux.edit_role_path(test_role)
    assert_response :success

    patch cccux.role_path(test_role), params: { role: { description: "Updated desc" } }
    assert_response :redirect
    assert_equal "Updated desc", test_role.reload.description

    delete cccux.role_path(test_role)
    assert_response :redirect
    assert_nil Cccux::Role.find_by(name: "TestRole")

    # PERMISSIONS CRUD
    get cccux.ability_permissions_path
    assert_response :success

    get cccux.new_ability_permission_path
    assert_response :success

    puts "Debug: About to create permission with action: 'manage', subject: 'Widget'"
    post "/cccux/ability_permissions", params: { ability_permission: { action: "manage", subject: "Widget", active: true } }
    puts "Debug: Response status: #{response.status}"
    puts "Debug: Response body: #{response.body}" if response.status != 302
    puts "Debug: Response location: #{response.location}" if response.status == 302
    assert_response :redirect
    perm = Cccux::AbilityPermission.find_by(action: "manage", subject: "Widget")
    puts "Debug: Permission found: #{perm.inspect}"
    puts "Debug: All permissions after creation: #{Cccux::AbilityPermission.all.map { |p| "#{p.action} #{p.subject}" }}"
    assert perm

    get cccux.edit_ability_permission_path(perm)
    assert_response :success

    patch cccux.ability_permission_path(perm), params: { ability_permission: { subject: "Gadget" } }
    assert_response :redirect
    assert_equal "Gadget", perm.reload.subject

    delete cccux.ability_permission_path(perm)
    assert_response :redirect
    assert_nil Cccux::AbilityPermission.find_by(action: "manage", subject: "Gadget")
  end

  test "non_role_manager_cannot_access_admin" do
    # Create a user WITHOUT the Role Manager role
    user = User.create!(email: "not_manager@example.com", password: "password123")
    sign_in_as(user)

    # Try to access an admin endpoint (e.g., users index)
    get cccux.users_path
    assert_response :forbidden
    assert_includes response.body, "You do not have permission to access this page."
  end

  private

  def sign_in_as(user)
    # Use Devise's sign_in method for integration tests
    sign_in user
  end

  def create_test_post(user)
    FactoryBot.create(:post, user: user)
  end

  def create_test_comment(post)
    FactoryBot.create(:comment, post: post)
  end

  def create_post_manager(user, post)
    PostManager.create!(user: user, post: post)
  end
end 