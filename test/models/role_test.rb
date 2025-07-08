require "test_helper"

class Cccux::RoleTest < ActiveSupport::TestCase
  def setup
    @role = Cccux::Role.create!(name: "Manager")
    @user = Cccux::User.create!(name: "Test User", email: "test@example.com")
  end

  test "should create role with valid attributes" do
    role = Cccux::Role.new(name: "Admin")
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
    @role.users << @user
    assert_includes @role.users, @user
    assert_equal 1, @role.users.count
  end

  test "should have many role_abilities" do
    ability = @role.role_abilities.build(
      model_name: "Post",
      action_name: "read",
      access_type: "global"
    )
    ability.save!
    
    assert_equal 1, @role.role_abilities.count
    assert_equal ability, @role.role_abilities.first
  end

  test "should destroy dependent associations" do
    @role.users << @user
    ability = @role.role_abilities.create!(
      model_name: "Post",
      action_name: "read",
      access_type: "global"
    )
    
    user_role_id = Cccux::UserRole.find_by(user: @user, role: @role).id
    ability_id = ability.id
    
    @role.destroy
    
    assert_nil Cccux::UserRole.find_by(id: user_role_id)
    assert_nil Cccux::RoleAbility.find_by(id: ability_id)
  end

  test "should normalize name case" do
    role = Cccux::Role.create!(name: "super admin")
    assert_equal "Super Admin", role.name
  end

  test "should provide slug from name" do
    role = Cccux::Role.create!(name: "Super Admin")
    assert_equal "super_admin", role.slug
  end
end 