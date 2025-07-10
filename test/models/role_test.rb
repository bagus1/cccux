require "test_helper"

class Cccux::RoleTest < ActiveSupport::TestCase
  def setup
    @role = Cccux::Role.create!(name: "Role Manager", active: true)
    @user = FactoryBot.create(:user, email: "test@example.com")
  end

  test "should create role with valid attributes" do
    role = Cccux::Role.new(name: "UniqueTestRole")
    assert role.valid?
    assert role.save
  end

  test "should require name" do
    role = Cccux::Role.new
    assert_not role.valid?
    assert_includes role.errors[:name], "can't be blank"
  end

  test "should require unique name" do
    duplicate_role = Cccux::Role.new(name: @role.name)
    assert_not duplicate_role.valid?
    assert_includes duplicate_role.errors[:name], "has already been taken"
  end

  test "should have case insensitive uniqueness" do
    duplicate_role = Cccux::Role.new(name: @role.name.upcase)
    assert_not duplicate_role.valid?
  end

  test "should have many users" do
    @user.assign_role(@role)
    assert_includes @user.cccux_roles, @role
    assert_equal 1, @role.users.count
  end

  test "should have many role_abilities" do
    # Create an ability permission first
    ability_permission = Cccux::AbilityPermission.create!(
      action: "read",
      subject: "Post",
      active: true
    )
    
    # Create the role ability through the association with required fields
    role_ability = @role.role_abilities.create!(
      ability_permission: ability_permission,
      owned: false
    )
    
    assert_equal 1, @role.role_abilities.count
    assert_equal role_ability, @role.role_abilities.first
  end

  test "should destroy dependent associations" do
    @user.assign_role(@role)
    
    # Create an ability permission first
    ability_permission = Cccux::AbilityPermission.create!(
      action: "read",
      subject: "Post",
      active: true
    )
    
    role_ability = @role.role_abilities.create!(
      ability_permission: ability_permission,
      owned: false
    )
    
    user_role_id = Cccux::UserRole.find_by(user: @user, role: @role).id
    role_ability_id = role_ability.id
    
    @role.destroy
    
    assert_nil Cccux::UserRole.find_by(id: user_role_id)
    assert_nil Cccux::RoleAbility.find_by(id: role_ability_id)
  end

  test "should normalize name case" do
    role = Cccux::Role.create!(name: "super admin", active: true)
    assert_equal "Super Admin", role.name
  end

  test "should provide slug from name" do
    role = Cccux::Role.create!(name: "Super Admin", active: true)
    assert_equal "super_admin", role.slug
  end
end 