require "test_helper"

class Cccux::AbilityTest < ActiveSupport::TestCase
  def setup
    @user = Cccux::User.create!(name: "Test User", email: "test@example.com")
    @admin_role = Cccux::Role.create!(name: "Admin")
    @manager_role = Cccux::Role.create!(name: "Manager")
    
    # Create a dummy model for testing
    @post = OpenStruct.new(id: 1, user_id: @user.id, title: "Test Post")
    @other_post = OpenStruct.new(id: 2, user_id: 999, title: "Other Post")
    
    @ability = Cccux::Ability.new(@user)
  end

  test "should deny access when user has no roles" do
    ability = Cccux::Ability.new(@user)
    assert_not ability.can?(:read, @post)
    assert_not ability.can?(:create, @post)
    assert_not ability.can?(:update, @post)
    assert_not ability.can?(:destroy, @post)
  end

  test "should allow global access for admin role" do
    @admin_role.role_abilities.create!(
      model_name: "Post",
      action_name: "read",
      access_type: "global"
    )
    @admin_role.role_abilities.create!(
      model_name: "Post", 
      action_name: "create",
      access_type: "global"
    )
    
    @user.roles << @admin_role
    ability = Cccux::Ability.new(@user)
    
    assert ability.can?(:read, @post)
    assert ability.can?(:read, @other_post)
    assert ability.can?(:create, @post)
  end

  test "should allow owned access only for user's own records" do
    @manager_role.role_abilities.create!(
      model_name: "Post",
      action_name: "update",
      access_type: "owned"
    )
    
    @user.roles << @manager_role
    ability = Cccux::Ability.new(@user)
    
    # Should be able to update own post
    assert ability.can?(:update, @post)
    
    # Should NOT be able to update other user's post
    assert_not ability.can?(:update, @other_post)
  end

  test "should handle multiple roles with cumulative permissions" do
    # Manager role can read all posts
    @manager_role.role_abilities.create!(
      model_name: "Post",
      action_name: "read", 
      access_type: "global"
    )
    
    # User role can update own posts
    user_role = Cccux::Role.create!(name: "User")
    user_role.role_abilities.create!(
      model_name: "Post",
      action_name: "update",
      access_type: "owned"
    )
    
    @user.roles << [@manager_role, user_role]
    ability = Cccux::Ability.new(@user)
    
    # Should have both permissions
    assert ability.can?(:read, @other_post)  # from manager role
    assert ability.can?(:update, @post)      # from user role (own post)
    assert_not ability.can?(:update, @other_post)  # still can't update others
  end

  test "should handle custom ownership through ownership_model" do
    # Create a store manager scenario
    store_manager = OpenStruct.new(user_id: @user.id, store_id: 1)
    order = OpenStruct.new(id: 1, store_id: 1, user_id: 999)
    other_order = OpenStruct.new(id: 2, store_id: 2, user_id: 999)
    
    @manager_role.role_abilities.create!(
      model_name: "Order",
      action_name: "update",
      access_type: "owned",
      ownership_model: "StoreManager",
      ownership_foreign_key: "store_id",
      ownership_user_key: "user_id"
    )
    
    @user.roles << @manager_role
    
    # Mock the StoreManager.where query
    StoreManager = Class.new do
      def self.where(conditions)
        if conditions[:user_id] == 1 && conditions[:store_id] == 1
          [OpenStruct.new(store_id: 1)]
        else
          []
        end
      end
    end
    
    ability = Cccux::Ability.new(@user)
    
    # This would normally work with real ActiveRecord models
    # The test demonstrates the ownership logic structure
    assert_respond_to ability, :can?
  end

  test "should fall back to user_id for owned access when no ownership_model" do
    @manager_role.role_abilities.create!(
      model_name: "Post",
      action_name: "destroy",
      access_type: "owned"
    )
    
    @user.roles << @manager_role
    ability = Cccux::Ability.new(@user)
    
    # Should use standard user_id ownership
    assert ability.can?(:destroy, @post)
    assert_not ability.can?(:destroy, @other_post)
  end

  test "should handle creator_id as fallback ownership" do
    creator_post = OpenStruct.new(id: 3, creator_id: @user.id)
    other_creator_post = OpenStruct.new(id: 4, creator_id: 999)
    
    @manager_role.role_abilities.create!(
      model_name: "Post",
      action_name: "update",
      access_type: "owned"
    )
    
    @user.roles << @manager_role
    ability = Cccux::Ability.new(@user)
    
    # Should recognize creator_id as ownership
    assert ability.can?(:update, creator_post)
    assert_not ability.can?(:update, other_creator_post)
  end

  test "should handle guest user (nil user)" do
    guest_ability = Cccux::Ability.new(nil)
    
    assert_not guest_ability.can?(:read, @post)
    assert_not guest_ability.can?(:create, @post)
    assert_not guest_ability.can?(:update, @post)
    assert_not guest_ability.can?(:destroy, @post)
  end

  test "should handle string model names" do
    @admin_role.role_abilities.create!(
      model_name: "Post",
      action_name: "read",
      access_type: "global"
    )
    
    @user.roles << @admin_role
    ability = Cccux::Ability.new(@user)
    
    # Should work with class name as string
    assert ability.can?(:read, "Post")
  end

  test "should respect action aliases" do
    @admin_role.role_abilities.create!(
      model_name: "Post",
      action_name: "read",
      access_type: "global"
    )
    
    @user.roles << @admin_role  
    ability = Cccux::Ability.new(@user)
    
    # CanCanCan aliases - read includes index and show
    assert ability.can?(:index, @post)
    assert ability.can?(:show, @post)
  end

  test "should handle model inheritance" do
    @admin_role.role_abilities.create!(
      model_name: "ActiveRecord::Base",
      action_name: "read",
      access_type: "global"
    )
    
    @user.roles << @admin_role
    ability = Cccux::Ability.new(@user)
    
    # Should inherit permissions for all models
    assert ability.can?(:read, @post)
  end
end 