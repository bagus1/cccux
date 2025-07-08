require "test_helper"

class Cccux::RoleAbilityTest < ActiveSupport::TestCase
  def setup
    @role = Cccux::Role.create!(name: "Manager")
    @ability = @role.role_abilities.build(
      model_name: "Post",
      action_name: "read",
      access_type: "global"
    )
  end

  test "should create role ability with valid attributes" do
    assert @ability.valid?
    assert @ability.save
  end

  test "should require role" do
    ability = Cccux::RoleAbility.new(
      model_name: "Post",
      action_name: "read",
      access_type: "global"
    )
    assert_not ability.valid?
    assert_includes ability.errors[:role], "must exist"
  end

  test "should require model_name" do
    @ability.model_name = nil
    assert_not @ability.valid?
    assert_includes @ability.errors[:model_name], "can't be blank"
  end

  test "should require action_name" do
    @ability.action_name = nil
    assert_not @ability.valid?
    assert_includes @ability.errors[:action_name], "can't be blank"
  end

  test "should require access_type" do
    @ability.access_type = nil
    assert_not @ability.valid?
    assert_includes @ability.errors[:access_type], "can't be blank"
  end

  test "should validate access_type inclusion" do
    @ability.access_type = "invalid"
    assert_not @ability.valid?
    assert_includes @ability.errors[:access_type], "is not included in the list"
  end

  test "should accept valid access_types" do
    %w[global owned].each do |access_type|
      @ability.access_type = access_type
      assert @ability.valid?, "#{access_type} should be valid"
    end
  end

  test "should validate unique combination of role, model, and action" do
    @ability.save!
    
    duplicate = @role.role_abilities.build(
      model_name: "Post",
      action_name: "read",
      access_type: "owned"
    )
    
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:action_name], "has already been taken"
  end

  test "should allow same permission for different roles" do
    @ability.save!
    
    another_role = Cccux::Role.create!(name: "Admin")
    another_ability = another_role.role_abilities.build(
      model_name: "Post",
      action_name: "read",
      access_type: "global"
    )
    
    assert another_ability.valid?
  end

  test "should handle ownership configuration for owned access type" do
    owned_ability = @role.role_abilities.build(
      model_name: "Order",
      action_name: "update",
      access_type: "owned",
      ownership_model: "StoreManager",
      ownership_foreign_key: "store_id",
      ownership_user_key: "user_id"
    )
    
    assert owned_ability.valid?
    assert owned_ability.save
    
    assert_equal "StoreManager", owned_ability.ownership_model
    assert_equal "store_id", owned_ability.ownership_foreign_key
    assert_equal "user_id", owned_ability.ownership_user_key
  end

  test "should provide readable action display" do
    @ability.action_name = "create"
    assert_equal "Create", @ability.action_display
    
    @ability.action_name = "destroy"
    assert_equal "Delete", @ability.action_display
    
    @ability.action_name = "custom_action"
    assert_equal "Custom Action", @ability.action_display
  end

  test "should provide readable access type display" do
    @ability.access_type = "global"
    assert_equal "Global", @ability.access_type_display
    
    @ability.access_type = "owned"
    assert_equal "Owned", @ability.access_type_display
  end

  test "should scope by model" do
    @ability.save!
    
    comment_ability = @role.role_abilities.create!(
      model_name: "Comment",
      action_name: "read",
      access_type: "global"
    )
    
    post_abilities = Cccux::RoleAbility.for_model("Post")
    assert_includes post_abilities, @ability
    assert_not_includes post_abilities, comment_ability
  end

  test "should scope by action" do
    @ability.save!
    
    write_ability = @role.role_abilities.create!(
      model_name: "Post",
      action_name: "create",
      access_type: "global"
    )
    
    read_abilities = Cccux::RoleAbility.for_action("read")
    assert_includes read_abilities, @ability
    assert_not_includes read_abilities, write_ability
  end
end 