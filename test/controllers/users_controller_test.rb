require "test_helper"

class Cccux::UsersControllerTest < ActionDispatch::IntegrationTest
  include Engine.routes.url_helpers

  def setup
    @admin_user = Cccux::User.create!(name: "Admin User", email: "admin@example.com")
    @regular_user = Cccux::User.create!(name: "Regular User", email: "user@example.com") 
    @admin_role = Cccux::Role.create!(name: "Admin")
    
    # Give admin user permission to manage users
    @admin_role.role_abilities.create!(
      model_name: "Cccux::User",
      action_name: "read",
      access_type: "global"
    )
    @admin_role.role_abilities.create!(
      model_name: "Cccux::User", 
      action_name: "create",
      access_type: "global"
    )
    @admin_role.role_abilities.create!(
      model_name: "Cccux::User",
      action_name: "update", 
      access_type: "global"
    )
    @admin_role.role_abilities.create!(
      model_name: "Cccux::User",
      action_name: "destroy",
      access_type: "global"
    )
    
    @admin_user.roles << @admin_role
  end

  test "should get index when authorized" do
    sign_in_as(@admin_user)
    get cccux.users_path
    assert_response :success
    assert_select "h1", "Users"
  end

  test "should deny index when not authorized" do
    sign_in_as(@regular_user)
    get cccux.users_path
    assert_response :forbidden
  end

  test "should show user when authorized" do
    sign_in_as(@admin_user)
    get cccux.user_path(@regular_user)
    assert_response :success
    assert_select "h1", @regular_user.name
  end

  test "should get new when authorized" do
    sign_in_as(@admin_user)
    get cccux.new_user_path
    assert_response :success
    assert_select "h1", "New User"
  end

  test "should create user when authorized" do
    sign_in_as(@admin_user)
    
    assert_difference("Cccux::User.count") do
      post cccux.users_path, params: {
        cccux_user: {
          name: "New User",
          email: "new@example.com"
        }
      }
    end
    
    assert_redirected_to cccux.user_path(Cccux::User.last)
    assert_equal "User was successfully created.", flash[:notice]
  end

  test "should not create user with invalid params" do
    sign_in_as(@admin_user)
    
    assert_no_difference("Cccux::User.count") do
      post cccux.users_path, params: {
        cccux_user: {
          name: "",
          email: "invalid"
        }
      }
    end
    
    assert_response :unprocessable_entity
  end

  test "should get edit when authorized" do
    sign_in_as(@admin_user)
    get cccux.edit_user_path(@regular_user)
    assert_response :success
    assert_select "h1", "Edit User"
  end

  test "should update user when authorized" do
    sign_in_as(@admin_user)
    
    patch cccux.user_path(@regular_user), params: {
      cccux_user: {
        name: "Updated Name"
      }
    }
    
    assert_redirected_to cccux.user_path(@regular_user)
    assert_equal "User was successfully updated.", flash[:notice]
    assert_equal "Updated Name", @regular_user.reload.name
  end

  test "should destroy user when authorized" do
    sign_in_as(@admin_user)
    
    assert_difference("Cccux::User.count", -1) do
      delete cccux.user_path(@regular_user)
    end
    
    assert_redirected_to cccux.users_path
    assert_equal "User was successfully deleted.", flash[:notice]
  end

  test "should assign roles to user" do
    sign_in_as(@admin_user)
    new_role = Cccux::Role.create!(name: "Manager")
    
    patch cccux.user_path(@regular_user), params: {
      cccux_user: {
        role_ids: [new_role.id]
      }
    }
    
    assert_includes @regular_user.reload.roles, new_role
  end

  private

  def sign_in_as(user)
    # Mock the current_user method that would be provided by authentication
    # In a real app, this would integrate with Devise or another auth system
    controller = @controller || ApplicationController.new
    controller.define_singleton_method(:current_user) { user }
    
    # You might also need to stub this in the application controller
    session[:user_id] = user.id if user
  end
end 