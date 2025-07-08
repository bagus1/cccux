require "test_helper"

class Cccux::UserTest < ActiveSupport::TestCase
  def setup
    @user = Cccux::User.create!(
      name: "Test User",
      email: "test@example.com"
    )
    @admin_role = Cccux::Role.create!(name: "Admin")
    @user_role = Cccux::Role.create!(name: "User")
  end

  test "should create user with valid attributes" do
    user = Cccux::User.new(name: "John Doe", email: "john@example.com")
    assert user.valid?
    assert user.save
  end

  test "should require name" do
    user = Cccux::User.new(email: "test@example.com")
    assert_not user.valid?
    assert_includes user.errors[:name], "can't be blank"
  end

  test "should require email" do
    user = Cccux::User.new(name: "Test User")
    assert_not user.valid?
    assert_includes user.errors[:email], "can't be blank"
  end

  test "should require unique email" do
    duplicate_user = Cccux::User.new(name: "Another User", email: @user.email)
    assert_not duplicate_user.valid?
    assert_includes duplicate_user.errors[:email], "has already been taken"
  end

  test "should assign roles to user" do
    @user.roles << @admin_role
    assert_includes @user.roles, @admin_role
    assert @user.has_role?(:admin)
  end

  test "should check multiple roles" do
    @user.roles << [@admin_role, @user_role]
    assert @user.has_role?(:admin)
    assert @user.has_role?(:user)
    assert_not @user.has_role?(:moderator)
  end

  test "should handle role assignment with strings" do
    @user.roles << @admin_role
    assert @user.has_role?("admin")
    assert @user.has_role?("Admin")
  end

  test "should list all role names" do
    @user.roles << [@admin_role, @user_role]
    role_names = @user.role_names
    assert_includes role_names, "Admin"
    assert_includes role_names, "User"
    assert_equal 2, role_names.length
  end
end 