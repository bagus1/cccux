require "test_helper"

class Cccux::AuthorizationFlowTest < ActionDispatch::IntegrationTest
  def setup
    @admin = Cccux::User.create!(name: "Admin", email: "admin@example.com")
    @manager = Cccux::User.create!(name: "Manager", email: "manager@example.com") 
    @user = Cccux::User.create!(name: "User", email: "user@example.com")
    
    @admin_role = Cccux::Role.create!(name: "Admin")
    @manager_role = Cccux::Role.create!(name: "Manager")
    @user_role = Cccux::Role.create!(name: "User")
    
    setup_permissions
  end

  test "complete admin workflow" do
    @admin.roles << @admin_role
    
    # Admin should be able to access CCCUX admin interface
    sign_in_as(@admin)
    
    # Can view all users
    get "/cccux/users"
    assert_response :success
    
    # Can create new user
    post "/cccux/users", params: {
      cccux_user: { name: "New User", email: "new@example.com" }
    }
    new_user = Cccux::User.find_by(email: "new@example.com")
    assert new_user
    assert_redirected_to "/cccux/users/#{new_user.id}"
    
    # Can create new role
    post "/cccux/roles", params: {
      cccux_role: { name: "Editor" }
    }
    editor_role = Cccux::Role.find_by(name: "Editor")
    assert editor_role
    
    # Can assign permissions to role
    post "/cccux/roles/#{editor_role.id}/role_abilities", params: {
      cccux_role_ability: {
        model_name: "Article",
        action_name: "update",
        access_type: "owned"
      }
    }
    
    ability = editor_role.role_abilities.find_by(model_name: "Article")
    assert ability
    assert_equal "update", ability.action_name
    assert_equal "owned", ability.access_type
  end

  test "manager with limited permissions workflow" do
    @manager.roles << @manager_role
    sign_in_as(@manager)
    
    # Manager can view users but not create them
    get "/cccux/users"
    assert_response :success
    
    get "/cccux/users/new"
    assert_response :forbidden
    
    # Manager can update existing users
    patch "/cccux/users/#{@user.id}", params: {
      cccux_user: { name: "Updated Name" }
    }
    assert_response :success
    assert_equal "Updated Name", @user.reload.name
  end

  test "regular user with minimal permissions" do
    @user.roles << @user_role
    sign_in_as(@user)
    
    # User cannot access admin interface at all
    get "/cccux/users"
    assert_response :forbidden
    
    get "/cccux/roles"
    assert_response :forbidden
    
    # User can only view their own profile
    get "/cccux/users/#{@user.id}"
    assert_response :success
    
    # Cannot view other users
    get "/cccux/users/#{@admin.id}"
    assert_response :forbidden
  end

  test "guest user (not signed in) should be denied everything" do
    # No sign in
    
    get "/cccux/users"
    assert_response :redirect # Should redirect to sign in
    
    get "/cccux/roles"
    assert_response :redirect
  end

  test "cumulative permissions from multiple roles" do
    # User has both manager and user roles
    @user.roles << [@manager_role, @user_role]
    sign_in_as(@user)
    
    # Should have permissions from both roles
    get "/cccux/users"
    assert_response :success  # From manager role
    
    get "/cccux/users/#{@user.id}"  
    assert_response :success  # From user role (own profile)
    
    # But still can't create users (admin only)
    get "/cccux/users/new"
    assert_response :forbidden
  end

  test "ownership-based permissions work correctly" do
    # Create a post owned by the user
    user_post = create_test_post(@user)
    other_post = create_test_post(@admin)
    
    @user.roles << @user_role
    sign_in_as(@user)
    
    # Can edit own post
    get "/posts/#{user_post.id}/edit"
    assert_response :success
    
    # Cannot edit other's post
    get "/posts/#{other_post.id}/edit"
    assert_response :forbidden
  end

  test "contextual permissions through ownership model" do
    # Simulate store manager scenario
    store = create_test_store
    order_in_managed_store = create_test_order(store)
    order_in_other_store = create_test_order(create_test_store)
    
    # Make user a manager of the first store
    create_store_manager(@user, store)
    
    @user.roles << @manager_role
    sign_in_as(@user)
    
    # Can manage orders in their store
    get "/orders/#{order_in_managed_store.id}/edit"
    assert_response :success
    
    # Cannot manage orders in other stores
    get "/orders/#{order_in_other_store.id}/edit" 
    assert_response :forbidden
  end

  private

  def setup_permissions
    # Admin permissions - can do everything
    %w[Cccux::User Cccux::Role Cccux::RoleAbility].each do |model|
      %w[read create update destroy].each do |action|
        @admin_role.role_abilities.create!(
          model_name: model,
          action_name: action,
          access_type: "global"
        )
      end
    end
    
    # Manager permissions - can manage users, view roles
    @manager_role.role_abilities.create!(
      model_name: "Cccux::User", 
      action_name: "read", 
      access_type: "global"
    )
    @manager_role.role_abilities.create!(
      model_name: "Cccux::User",
      action_name: "update",
      access_type: "global"
    )
    @manager_role.role_abilities.create!(
      model_name: "Order",
      action_name: "update",
      access_type: "owned",
      ownership_model: "StoreManager",
      ownership_foreign_key: "store_id",
      ownership_user_key: "user_id"
    )
    
    # User permissions - can only view own profile
    @user_role.role_abilities.create!(
      model_name: "Cccux::User",
      action_name: "read", 
      access_type: "owned"
    )
    @user_role.role_abilities.create!(
      model_name: "Post",
      action_name: "update",
      access_type: "owned"
    )
  end

  def sign_in_as(user)
    # Mock authentication - in real app this would be handled by Devise/etc
    session[:user_id] = user&.id
  end

  def create_test_post(user)
    OpenStruct.new(id: rand(1000), user_id: user.id, title: "Test Post")
  end

  def create_test_store
    OpenStruct.new(id: rand(1000), name: "Test Store")
  end

  def create_test_order(store) 
    OpenStruct.new(id: rand(1000), store_id: store.id, total: 100)
  end

  def create_store_manager(user, store)
    # In real app this would create a StoreManager record
    OpenStruct.new(user_id: user.id, store_id: store.id)
  end
end 