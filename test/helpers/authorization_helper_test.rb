require "test_helper"

class Cccux::AuthorizationHelperTest < ActionView::TestCase
  include Cccux::AuthorizationHelper

  def setup
    @user = Cccux::User.create!(name: "Test User", email: "test@example.com")
    @admin_role = Cccux::Role.create!(name: "Admin")
    @post = OpenStruct.new(id: 1, title: "Test Post")
    
    # Mock current_ability method
    def current_ability
      @current_ability ||= Cccux::Ability.new(@user)
    end
  end

  test "link_if_can_show should render link when authorized" do
    @admin_role.role_abilities.create!(
      model_name: "Post",
      action_name: "read",
      access_type: "global"
    )
    @user.roles << @admin_role
    
    result = link_if_can_show("View Post", @post, "/posts/1")
    assert_includes result, '<a href="/posts/1">View Post</a>'
  end

  test "link_if_can_show should not render link when unauthorized" do
    result = link_if_can_show("View Post", @post, "/posts/1")
    assert_equal "", result
  end

  test "link_if_can_show should render just text when unauthorized and show_text is true" do
    result = link_if_can_show("View Post", @post, "/posts/1", show_text: true)
    assert_equal "View Post", result
  end

  test "link_if_can_edit should render edit link when authorized" do
    @admin_role.role_abilities.create!(
      model_name: "Post",
      action_name: "update",
      access_type: "global"
    )
    @user.roles << @admin_role
    
    result = link_if_can_edit("Edit", @post, "/posts/1/edit")
    assert_includes result, '<a href="/posts/1/edit">Edit</a>'
  end

  test "link_if_can_create should render create link when authorized" do
    @admin_role.role_abilities.create!(
      model_name: "Post",
      action_name: "create",
      access_type: "global"
    )
    @user.roles << @admin_role
    
    result = link_if_can_create("New Post", "Post", "/posts/new")
    assert_includes result, '<a href="/posts/new">New Post</a>'
  end

  test "button_if_can_destroy should render delete button when authorized" do
    @admin_role.role_abilities.create!(
      model_name: "Post",
      action_name: "destroy",
      access_type: "global"
    )
    @user.roles << @admin_role
    
    result = button_if_can_destroy("Delete", @post, "/posts/1")
    assert_includes result, 'data-method="delete"'
    assert_includes result, 'data-confirm="Are you sure?"'
    assert_includes result, '>Delete<'
  end

  test "button_if_can_destroy should not render when unauthorized" do
    result = button_if_can_destroy("Delete", @post, "/posts/1")
    assert_equal "", result
  end

  test "helpers should accept custom CSS classes" do
    @admin_role.role_abilities.create!(
      model_name: "Post",
      action_name: "read",
      access_type: "global"
    )
    @user.roles << @admin_role
    
    result = link_if_can_show("View", @post, "/posts/1", class: "btn btn-primary")
    assert_includes result, 'class="btn btn-primary"'
  end

  test "helpers should handle nested resources" do
    @admin_role.role_abilities.create!(
      model_name: "Comment",
      action_name: "create",
      access_type: "global"
    )
    @user.roles << @admin_role
    
    result = link_if_can_create("Add Comment", "Comment", "/posts/1/comments/new")
    assert_includes result, '<a href="/posts/1/comments/new">Add Comment</a>'
  end

  test "helpers should work with model classes" do
    @admin_role.role_abilities.create!(
      model_name: "Post",
      action_name: "create",
      access_type: "global"
    )
    @user.roles << @admin_role
    
    # Using class instead of string
    post_class = Struct.new(:name) { def model_name; OpenStruct.new(name: "Post"); end }
    
    result = link_if_can_create("New", post_class.new, "/posts/new")
    assert_includes result, '<a href="/posts/new">New</a>'
  end

  test "helpers should handle data attributes" do
    @admin_role.role_abilities.create!(
      model_name: "Post",
      action_name: "update",
      access_type: "global"
    )
    @user.roles << @admin_role
    
    result = link_if_can_edit("Edit", @post, "/posts/1/edit", 
                             data: { remote: true, method: :patch })
    assert_includes result, 'data-remote="true"'
    assert_includes result, 'data-method="patch"'
  end

  test "should handle guest user gracefully" do
    # Simulate guest user
    def current_ability
      Cccux::Ability.new(nil)
    end
    
    result = link_if_can_show("View", @post, "/posts/1")
    assert_equal "", result
    
    result = button_if_can_destroy("Delete", @post, "/posts/1")
    assert_equal "", result
  end
end 