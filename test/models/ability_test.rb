require "test_helper"
require "ostruct"

class Cccux::AbilityTest < ActiveSupport::TestCase
  def setup
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
    @manager_role = Cccux::Role.find_or_create_by(name: "Manager") do |role|
      role.active = true
    end
    
    # Create users using find_or_create_by
    @admin = User.find_or_create_by(email: "admin@example.com") do |user|
      user.password = "password123"
    end
    @role_manager = User.find_or_create_by(email: "role_manager@example.com") do |user|
      user.password = "password123"
    end
    @basic_user = User.find_or_create_by(email: "user@example.com") do |user|
      user.password = "password123"
    end
    @guest = User.find_or_create_by(email: "guest@example.com") do |user|
      user.password = "password123"
    end
    @user = User.find_or_create_by(email: "testuser@example.com") do |user|
      user.password = "password123"
    end
    
    # Create test posts
    @post = Post.find_or_create_by(title: "Test Post", content: "Test content", user: @user) do |post|
      post.user = @user
    end
    @other_post = Post.find_or_create_by(title: "Other Post", content: "Other content", user: @admin) do |post|
      post.user = @admin
    end
    
    # Assign roles
    @admin.assign_role(@admin_role)
    @role_manager.assign_role(@role_manager_role)
    @basic_user.assign_role(@basic_user_role)
    @guest.assign_role(@guest_role)
    
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
  end

  test "should deny access when user has no roles" do
    ability = Cccux::Ability.new(@user)
    assert_not ability.can?(:read, @post)
    assert_not ability.can?(:create, @post)
    assert_not ability.can?(:update, @post)
    assert_not ability.can?(:destroy, @post)
  end

  test "should allow global access for admin role" do
    read_permission = Cccux::AbilityPermission.create!(
      action: "read",
      subject: "Post",
      active: true
    )
    create_permission = Cccux::AbilityPermission.create!(
      action: "create",
      subject: "Post",
      active: true
    )
    
    @admin_role.role_abilities.create!(
      ability_permission: read_permission,
      owned: false,
      context: "global"
    )
    @admin_role.role_abilities.create!(
      ability_permission: create_permission,
      owned: false,
      context: "global"
    )
    
    @user.assign_role(@admin_role)
    @user.reload
    
    # Debug: Check if role was assigned
    puts "Debug: After assign_role - User roles: #{@user.cccux_roles.count}"
    puts "Debug: After assign_role - User role names: #{@user.role_names}"
    
    ability = Cccux::Ability.new(@user)
    
    assert ability.can?(:read, @post)
    assert ability.can?(:read, @other_post)
    assert ability.can?(:create, @post)
  end

  test "should allow owned access only for user's own records" do
    update_permission = Cccux::AbilityPermission.create!(
      action: "update",
      subject: "Post",
      active: true
    )
    
    @manager_role.role_abilities.create!(
      ability_permission: update_permission,
      owned: true,
      context: "owned"
    )
    
    @user.assign_role(@manager_role)
    @user.reload
    ability = Cccux::Ability.new(@user)
    
    # Should be able to update own post
    assert ability.can?(:update, @post)
    
    # Should NOT be able to update other user's post
    assert_not ability.can?(:update, @other_post)
  end

  test "should handle multiple roles with cumulative permissions" do
    # Manager role can read all posts
    read_permission = Cccux::AbilityPermission.create!(
      action: "read",
      subject: "Post",
      active: true
    )
    @manager_role.role_abilities.create!(
      ability_permission: read_permission,
      owned: false,
      context: "global"
    )
    
    # User role can update own posts
    user_role = Cccux::Role.create!(name: "TestUser", active: true)
    update_permission = Cccux::AbilityPermission.create!(
      action: "update",
      subject: "Post",
      active: true
    )
    user_role.role_abilities.create!(
      ability_permission: update_permission,
      owned: true,
      context: "owned"
    )
    
    @user.assign_role(@manager_role)
    @user.assign_role(user_role)
    @user.reload
    ability = Cccux::Ability.new(@user)
    
    # Should have both permissions
    assert ability.can?(:read, @other_post)  # from manager role
    assert ability.can?(:update, @post)      # from user role (own post)
    assert_not ability.can?(:update, @other_post)  # still can't update others
  end

  test "should handle custom ownership through ownership_model" do
    # Use Post model for ownership test
    post = @post
    other_post = @other_post
    
    update_permission = Cccux::AbilityPermission.create!(
      action: "update",
      subject: "Post",
      active: true
    )
    @manager_role.role_abilities.create!(
      ability_permission: update_permission,
      owned: true,
      context: "owned"
    )
    
    @user.assign_role(@manager_role)
    @user.reload
    ability = Cccux::Ability.new(@user)
    
    # Should be able to update own post
    assert ability.can?(:update, post)
    # Should NOT be able to update other user's post
    assert_not ability.can?(:update, other_post)
  end

  test "should fall back to user_id for owned access when no ownership_model" do
    destroy_permission = Cccux::AbilityPermission.create!(
      action: "destroy",
      subject: "Post",
      active: true
    )
    @manager_role.role_abilities.create!(
      ability_permission: destroy_permission,
      owned: true,
      context: "owned"
    )
    
    @user.assign_role(@manager_role)
    @user.reload
    ability = Cccux::Ability.new(@user)
    
    # Should use standard user_id ownership
    assert ability.can?(:destroy, @post)
    assert_not ability.can?(:destroy, @other_post)
  end

  test "should handle creator_id as fallback ownership" do
    # Use Post model and add a temporary creator_id method
    post = @post
    other_post = @other_post
    user = @user
    post.define_singleton_method(:creator_id) { user.id }
    other_post.define_singleton_method(:creator_id) { 999 }

    update_permission = Cccux::AbilityPermission.create!(
      action: "update",
      subject: "Post",
      active: true
    )
    @manager_role.role_abilities.create!(
      ability_permission: update_permission,
      owned: true,
      context: "owned"
    )

    @user.assign_role(@manager_role)
    @user.reload
    ability = Cccux::Ability.new(@user)

    # Should recognize creator_id as ownership
    assert ability.can?(:update, post)
    assert_not ability.can?(:update, other_post)
  end

  test "should handle guest user (nil user)" do
    guest_ability = Cccux::Ability.new(nil)
    
    assert_not guest_ability.can?(:read, @post)
    assert_not guest_ability.can?(:create, @post)
    assert_not guest_ability.can?(:update, @post)
    assert_not guest_ability.can?(:destroy, @post)
  end

  test "should handle string model names" do
    read_permission = Cccux::AbilityPermission.create!(
      action: "read",
      subject: "Post",
      active: true
    )
    @admin_role.role_abilities.create!(
      ability_permission: read_permission,
      owned: false,
      context: "global"
    )
    
    @user.assign_role(@admin_role)
    @user.reload
    ability = Cccux::Ability.new(@user)
    
    # Should work with Post class (not string)
    assert ability.can?(:read, Post)
  end

  test "should respect action aliases" do
    read_permission = Cccux::AbilityPermission.create!(
      action: "read",
      subject: "Post",
      active: true
    )
    @admin_role.role_abilities.create!(
      ability_permission: read_permission,
      owned: false,
      context: "global"
    )
    
    @user.assign_role(@admin_role)
    @user.reload
    ability = Cccux::Ability.new(@user)
    
    # CanCanCan aliases - read includes index and show
    assert ability.can?(:index, @post)
    assert ability.can?(:show, @post)
  end

  test "should handle model inheritance" do
    read_permission = Cccux::AbilityPermission.create!(
      action: "read",
      subject: "ActiveRecord::Base",
      active: true
    )
    @admin_role.role_abilities.create!(
      ability_permission: read_permission,
      owned: false,
      context: "global"
    )
    
    @user.assign_role(@admin_role)
    @user.reload
    ability = Cccux::Ability.new(@user)
    
    # Should inherit permissions for all models
    assert ability.can?(:read, @post)
  end
end 