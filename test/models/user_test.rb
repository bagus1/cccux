require "test_helper"

class Cccux::UserTest < ActiveSupport::TestCase
  def setup
    @user = FactoryBot.create(:user, email: "test@example.com")
    @admin_role = Cccux::Role.create!(name: "TestAdmin", active: true)
    @user_role = Cccux::Role.create!(name: "TestUser", active: true)
  end

  test "should create user with valid attributes" do
    user = User.new(
      first_name: "John",
      last_name: "Doe", 
      email: "john@example.com",
      password: "password123",
      password_confirmation: "password123",
      active: true
    )
    assert user.valid?
    assert user.save
  end



  test "should require email" do
    user = User.new(
      first_name: "Test",
      last_name: "User",
      password: "password123",
      password_confirmation: "password123",
      active: true
    )
    assert_not user.valid?
    assert_includes user.errors[:email], "can't be blank"
  end

  test "should require unique email" do
    duplicate_user = User.new(
      first_name: "Another",
      last_name: "User",
      email: @user.email,
      password: "password123",
      password_confirmation: "password123",
      active: true
    )
    assert_not duplicate_user.valid?
    assert_includes duplicate_user.errors[:email], "has already been taken"
  end

  test "should assign roles to user" do
    @user.assign_role(@admin_role)
    assert_includes @user.cccux_roles, @admin_role
    assert @user.has_role?('Test Admin')
  end

  test "should check multiple roles" do
    @user.assign_role(@admin_role)
    @user.assign_role(@user_role)
    assert @user.has_role?('Test Admin')
    assert @user.has_role?('Test User')
    assert_not @user.has_role?(:moderator)
  end

  test "should handle role assignment with strings" do
    @user.assign_role(@admin_role)
    assert @user.has_role?('Test Admin')
    assert @user.has_role?('Test Admin')
  end

  test "should list all role names" do
    @user.assign_role(@admin_role)
    @user.assign_role(@user_role)
    role_names = @user.role_names
    assert_includes role_names, "Test Admin"
    assert_includes role_names, "Test User"
    assert_equal 2, role_names.length
  end
end 