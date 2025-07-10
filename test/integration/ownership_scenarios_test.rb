require "test_helper"

class Cccux::OwnershipScenariosTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  
  def setup
    # Create users
    @user1 = FactoryBot.create(:user, email: "user1@example.com")
    @user2 = FactoryBot.create(:user, email: "user2@example.com")
    
    # Create roles
    @post_creator_role = Cccux::Role.create!(name: "Post Creator", active: true)
    @post_manager_role = Cccux::Role.create!(name: "Post Manager", active: true)
    @comment_manager_role = Cccux::Role.create!(name: "Comment Manager", active: true)
    
    setup_permissions
  end

  test "scenario 1: user can create and edit own posts, others can read but not edit" do
    # Assign post creator role to both users
    @user1.assign_role(@post_creator_role)
    @user2.assign_role(@post_creator_role)
    @user1.reload
    @user2.reload
    sign_in_as(@user1)
    
    # User1 creates a post
    post "/posts", params: { post: { title: "My Post", content: "My content" } }
    assert_response :redirect
    post1 = Post.last
    assert_equal @user1.id, post1.user_id
    
    # User1 can edit their own post
    patch "/posts/#{post1.id}", params: { post: { title: "Updated Post" } }
    assert_response :redirect
    post1.reload
    assert_equal "Updated Post", post1.title
    
    # Switch to user2 (no special permissions)
    sign_out @user1
    sign_in_as(@user2)
    
    # User2 can read the post
    get "/posts/#{post1.id}"
    assert_response :success
    
    # User2 cannot edit the post
    patch "/posts/#{post1.id}", params: { post: { title: "Hacked Post" } }
    assert_response :forbidden
    post1.reload
    assert_equal "Updated Post", post1.title # Should not be changed
  end

  test "scenario 2: post manager can edit posts they manage via PostManager relationship" do
    # User1 creates two posts
    @user1.assign_role(@post_creator_role)
    @user1.reload
    sign_in_as(@user1)
    
    post "/posts", params: { post: { title: "Post 1", content: "Content 1" } }
    assert_response :redirect
    post1 = Post.last
    
    post "/posts", params: { post: { title: "Post 2", content: "Content 2" } }
    assert_response :redirect
    post2 = Post.last
    
    # Create PostManager relationship for user2 and post1
    PostManager.create!(user: @user2, post: post1)
    
    # Assign post manager role to user2
    @user2.assign_role(@post_manager_role)
    @user2.reload
    
    # Switch to user2
    sign_out @user1
    sign_in_as(@user2)
    
    # User2 can edit post1 (they manage it)
    patch "/posts/#{post1.id}", params: { post: { title: "Post 1 Updated" } }
    assert_response :redirect
    post1.reload
    assert_equal "Post 1 Updated", post1.title
    
    # User2 cannot edit post2 (they don't manage it)
    patch "/posts/#{post2.id}", params: { post: { title: "Post 2 Hacked" } }
    assert_response :forbidden
    post2.reload
    assert_equal "Post 2", post2.title # Should not be changed
  end

  test "scenario 3: post manager can edit comments within posts they manage" do
    # User1 creates two posts and comments
    @user1.assign_role(@post_creator_role)
    @user1.assign_role(@comment_manager_role)
    @user1.reload
    sign_in_as(@user1)
    
    # Create posts
    post "/posts", params: { post: { title: "Post 1", content: "Content 1" } }
    assert_response :redirect
    post1 = Post.last
    
    post "/posts", params: { post: { title: "Post 2", content: "Content 2" } }
    assert_response :redirect
    post2 = Post.last
    
    # Create comments
    post "/posts/#{post1.id}/comments", params: { comment: { content: "Comment 1" } }
    assert_response :redirect
    comment1 = Comment.last
    
    post "/posts/#{post2.id}/comments", params: { comment: { content: "Comment 2" } }
    assert_response :redirect
    comment2 = Comment.last
    
    # Create PostManager relationship for user2 and post1
    PostManager.create!(user: @user2, post: post1)
    
    # Assign post manager role to user2
    @user2.assign_role(@post_manager_role)
    @user2.reload
    
    # Switch to user2
    sign_out @user1
    sign_in_as(@user2)
    
    # User2 can edit comment1 (within post they manage)
    patch "/posts/#{post1.id}/comments/#{comment1.id}", params: { comment: { content: "Comment 1 Updated" } }
    assert_response :redirect
    comment1.reload
    assert_equal "Comment 1 Updated", comment1.content
    
    # User2 cannot edit comment2 (within post they don't manage)
    patch "/posts/#{post2.id}/comments/#{comment2.id}", params: { comment: { content: "Comment 2 Hacked" } }
    assert_response :forbidden
    comment2.reload
    assert_equal "Comment 2", comment2.content # Should not be changed
  end

  private

  def setup_permissions
    # Post Creator role permissions
    post_read_permission = Cccux::AbilityPermission.find_or_create_by!(
      action: "read",
      subject: "Post",
      active: true
    )
    post_create_permission = Cccux::AbilityPermission.find_or_create_by!(
      action: "create",
      subject: "Post",
      active: true
    )
    post_update_permission = Cccux::AbilityPermission.find_or_create_by!(
      action: "update",
      subject: "Post",
      active: true
    )
    
    # Post Creator role - can read all posts, create posts, update own posts
    @post_creator_role.role_abilities.create!(
      ability_permission: post_read_permission,
      owned: false,
      context: "global"
    )
    @post_creator_role.role_abilities.create!(
      ability_permission: post_create_permission,
      owned: false,
      context: "global"
    )
    @post_creator_role.role_abilities.create!(
      ability_permission: post_update_permission,
      owned: true,
      context: "owned"
    )
    
    # Post Manager role permissions (reuse the same permissions)
    post_manager_read_permission = post_read_permission
    post_manager_create_permission = post_create_permission
    post_manager_update_permission = post_update_permission
    
    # Post Manager role - can read all posts, create posts, update managed posts
    @post_manager_role.role_abilities.create!(
      ability_permission: post_manager_read_permission,
      owned: false,
      context: "global"
    )
    @post_manager_role.role_abilities.create!(
      ability_permission: post_manager_create_permission,
      owned: false,
      context: "global"
    )
    @post_manager_role.role_abilities.create!(
      ability_permission: post_manager_update_permission,
      owned: true,
      ownership_source: "PostManager",
      ownership_conditions: { "foreign_key" => "post_id", "user_key" => "user_id" }.to_json
    )
    
    # Add comment permissions to Post Manager role
    comment_read_permission = Cccux::AbilityPermission.find_or_create_by!(
      action: "read",
      subject: "Comment",
      active: true
    )
    comment_create_permission = Cccux::AbilityPermission.find_or_create_by!(
      action: "create",
      subject: "Comment",
      active: true
    )
    comment_update_permission = Cccux::AbilityPermission.find_or_create_by!(
      action: "update",
      subject: "Comment",
      active: true
    )
    
    # Post Manager can also manage comments within posts they manage
    @post_manager_role.role_abilities.create!(
      ability_permission: comment_read_permission,
      owned: false,
      context: "global"
    )
    @post_manager_role.role_abilities.create!(
      ability_permission: comment_create_permission,
      owned: false,
      context: "global"
    )
    @post_manager_role.role_abilities.create!(
      ability_permission: comment_update_permission,
      owned: true,
      ownership_source: "PostManager",
      ownership_conditions: { "foreign_key" => "post_id", "user_key" => "user_id" }.to_json
    )
    
    # Comment Manager role permissions
    comment_read_permission = Cccux::AbilityPermission.find_or_create_by!(
      action: "read",
      subject: "Comment",
      active: true
    )
    comment_create_permission = Cccux::AbilityPermission.find_or_create_by!(
      action: "create",
      subject: "Comment",
      active: true
    )
    comment_update_permission = Cccux::AbilityPermission.find_or_create_by!(
      action: "update",
      subject: "Comment",
      active: true
    )
    
    # Comment Manager role - can read all comments, create comments, update own comments
    @comment_manager_role.role_abilities.create!(
      ability_permission: comment_read_permission,
      owned: false,
      context: "global"
    )
    @comment_manager_role.role_abilities.create!(
      ability_permission: comment_create_permission,
      owned: false,
      context: "global"
    )
    @comment_manager_role.role_abilities.create!(
      ability_permission: comment_update_permission,
      owned: true,
      context: "owned"
    )
  end

  def sign_in_as(user)
    sign_in user
  end
end 