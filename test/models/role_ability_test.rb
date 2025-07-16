require "test_helper"

class Cccux::RoleAbilityTest < ActiveSupport::TestCase
  def setup
    @role = Cccux::Role.create!(name: "Role Manager", active: true)
    @ability_permission = Cccux::AbilityPermission.create!(
      action: "read",
      subject: "Post",
      active: true
    )
    @role_ability = @role.role_abilities.build(
      ability_permission: @ability_permission
    )
  end

  test "should create role ability with valid attributes" do
    assert @role_ability.valid?
    assert @role_ability.save
  end

  test "should require role" do
    role_ability = Cccux::RoleAbility.new(
      ability_permission: @ability_permission
    )
    assert_not role_ability.valid?
    assert_includes role_ability.errors[:role], "must exist"
  end

  test "should require ability_permission" do
    @role_ability.ability_permission = nil
    assert_not @role_ability.valid?
    assert_includes @role_ability.errors[:ability_permission], "must exist"
  end

  test "should belong to role" do
    assert_respond_to @role_ability, :role
    assert_equal @role, @role_ability.role
  end

  test "should belong to ability_permission" do
    assert_respond_to @role_ability, :ability_permission
    assert_equal @ability_permission, @role_ability.ability_permission
  end

  test "should validate unique combination of role and ability_permission" do
    @role_ability.save!
    
    duplicate = @role.role_abilities.build(
      ability_permission: @ability_permission,
      owned: @role_ability.owned,
      context: @role_ability.context
    )
    
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:ability_permission_id], "already exists for this role, ownership scope, and context"
  end

  test "should allow same permission for different roles" do
    @role_ability.save!
    
    another_role = Cccux::Role.create!(name: "TestAdmin", active: true)
    another_role_ability = another_role.role_abilities.build(
      ability_permission: @ability_permission,
      owned: @role_ability.owned,
      context: @role_ability.context
    )
    
    assert another_role_ability.valid?
  end

  test "should delegate action to ability_permission" do
    assert_equal "read", @role_ability.action
  end

  test "should delegate subject to ability_permission" do
    assert_equal "Post", @role_ability.subject
  end

  test "should delegate active to ability_permission" do
    assert @role_ability.active?
  end
end 