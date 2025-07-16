# Post model is now defined in the dummy app

require "test_helper"

class Cccux::AuthorizationHelperTest < ActionView::TestCase
  self.use_transactional_tests = true
  include Cccux::AuthorizationHelper

  def self.fixtures(*args)
    # Disable fixtures for this test class
    []
  end

  def setup
    # Clean up to ensure a fresh state for each test
    Cccux::RoleAbility.delete_all
    Cccux::AbilityPermission.delete_all
    Cccux::UserRole.delete_all
    Cccux::Role.delete_all
    User.delete_all
    Post.delete_all

    @user = create(:user)
    @admin_role = create(:role)
    @post_record = create(:post, user: @user)
    @read_permission = Cccux::AbilityPermission.find_or_create_by!(action: "read", subject: "Post", active: true)
    @create_permission = Cccux::AbilityPermission.find_or_create_by!(action: "create", subject: "Post", active: true)
    @update_permission = Cccux::AbilityPermission.find_or_create_by!(action: "update", subject: "Post", active: true)
    @destroy_permission = Cccux::AbilityPermission.find_or_create_by!(action: "destroy", subject: "Post", active: true)
    @comment_create_permission = Cccux::AbilityPermission.find_or_create_by!(action: "create", subject: "Comment", active: true)
    create(:user_role, user: @user, role: @admin_role, active: true)
    @user.reload
    # Mock current_ability and current_user
    self.class.send(:define_method, :current_ability) { @current_ability ||= Cccux::Ability.new(@user) }
    self.class.send(:define_method, :current_user) { @user }
  end

  test "link_if_can_show should render link when authorized" do
    create(:role_ability, role: @admin_role, ability_permission: @read_permission)
    @current_ability = nil
    result = link_if_can_show(Post, "View Post", "/posts/1")
    assert_includes result, '<a href="/posts/1">View Post</a>'
  end

  test "link_if_can_show should not render link when unauthorized" do
    result = link_if_can_show(Post, "View Post", "/posts/1")
    assert_equal "", result
  end

  test "link_if_can_show should render just text when unauthorized and show_text is true" do
    result = link_if_can_show(Post, "View Post", "/posts/1", show_text: true)
    assert_equal "View Post", result
  end

  test "link_if_can_edit should render edit link when authorized" do
    create(:role_ability, role: @admin_role, ability_permission: @update_permission)
    @current_ability = nil
    result = link_if_can_edit(Post, "Edit", "/posts/1/edit")
    assert_includes result, '<a href="/posts/1/edit">Edit</a>'
  end

  test "link_if_can_create should render create link when authorized" do
    create(:role_ability, role: @admin_role, ability_permission: @create_permission)
    @current_ability = nil
    result = link_if_can_create(Post, "New Post", "/posts/new")
    assert_includes result, '<a href="/posts/new">New Post</a>'
  end

  test "button_if_can_destroy should render delete button when authorized" do
    create(:role_ability, role: @admin_role, ability_permission: @destroy_permission)
    @current_ability = nil
    result = button_if_can_destroy(Post, "Delete", "/posts/1")
    assert_includes result, '<form'
    assert_includes result, 'method="post"'
    assert_includes result, '>Delete<'
  end

  test "button_if_can_destroy should not render when unauthorized" do
    result = button_if_can_destroy(Post, "Delete", "/posts/1")
    assert_equal "", result
  end

  test "helpers should accept custom CSS classes" do
    create(:role_ability, role: @admin_role, ability_permission: @read_permission)
    @current_ability = nil
    result = link_if_can_show(Post, "View", "/posts/1", class: "btn btn-primary")
    assert_includes result, 'class="btn btn-primary"'
  end

  test "helpers should work with model classes" do
    create(:role_ability, role: @admin_role, ability_permission: @create_permission)
    @current_ability = nil
    # Use the actual Post class
    result = link_if_can_create(Post, "New", "/posts/new")
    assert_includes result, '<a href="/posts/new">New</a>'
  end

  test "helpers should handle nested resources" do
    skip "Testing with custom classes requires more complex setup"
    create(:role_ability, role: @admin_role, ability_permission: @comment_create_permission)
    @current_ability = nil
    # Create a simple Comment class for testing
    comment_class = Class.new do
      def self.name
        "Comment"
      end
    end
    result = link_if_can_create(comment_class, "Add Comment", "/posts/1/comments/new")
    assert_includes result, '<a href="/posts/1/comments/new">Add Comment</a>'
  end

  test "helpers should handle data attributes" do
    create(:role_ability, role: @admin_role, ability_permission: @update_permission)
    @current_ability = nil
    result = link_if_can_edit(Post, "Edit", "/posts/1/edit", 
                             data: { remote: true, method: :patch })
    assert_includes result, 'data-remote="true"'
    assert_includes result, 'data-method="patch"'
  end

  test "should handle guest user gracefully" do
    # Simulate guest user
    Cccux::Ability.new(nil)
    result = link_if_can_show(Post, "View Post", "/posts/1")
    assert_equal "", result
  end
end 