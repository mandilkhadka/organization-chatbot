require "test_helper"

class UserTest < ActiveSupport::TestCase
  # Test role enum
  test "should have employee role by default" do
    user = User.new(email: "test@example.com", password: "password123")
    assert user.employee?
    assert_not user.admin?
  end

  test "should be able to set admin role" do
    user = users(:employee_one)
    user.update(role: :admin)
    assert user.admin?
    assert_not user.employee?
  end

  test "role enum should have correct values" do
    assert_equal 0, User.roles[:employee]
    assert_equal 1, User.roles[:admin]
  end

  # Test admin? method
  test "admin? should return true for admin users" do
    admin = users(:admin_one)
    assert admin.admin?
  end

  test "admin? should return false for employee users" do
    employee = users(:employee_one)
    assert_not employee.admin?
  end

  # Test last_admin? method
  test "last_admin? should return true when only one admin exists" do
    admin = users(:last_admin)
    # Demote other admins instead of destroying them
    User.where(role: :admin).where.not(id: admin.id).update_all(role: :employee)

    assert admin.last_admin?
  end

  test "last_admin? should return false when multiple admins exist" do
    admin = users(:admin_one)
    # Ensure at least two admins exist
    assert User.admin.count >= 2

    assert_not admin.last_admin?
  end

  test "last_admin? should return false for non-admin users" do
    employee = users(:employee_one)
    assert_not employee.last_admin?
  end

  # Test last admin protection on deletion
  test "should not delete last admin user" do
    admin = users(:last_admin)
    # Demote other admins instead of destroying them
    User.where(role: :admin).where.not(id: admin.id).update_all(role: :employee)

    assert_no_difference "User.count" do
      admin.destroy
    end

    assert_includes admin.errors[:base], "Cannot delete the last admin user"
  end

  test "should delete admin when other admins exist" do
    # Create a fresh admin for this test to avoid cascade issues
    new_admin = User.create!(email: "deletable@example.com", password: "password123", role: :admin)

    # Ensure at least two admins exist
    assert User.admin.count >= 2

    assert_difference "User.count", -1 do
      new_admin.destroy
    end
  end

  test "should delete employee users" do
    # Create a fresh employee for this test to avoid cascade issues
    new_employee = User.create!(email: "deletable_employee@example.com", password: "password123", role: :employee)

    assert_difference "User.count", -1 do
      new_employee.destroy
    end
  end

  # Test last admin protection on role change
  test "should not change role of last admin to employee" do
    admin = users(:last_admin)
    # Demote other admins instead of destroying them
    User.where(role: :admin).where.not(id: admin.id).update_all(role: :employee)

    admin.role = :employee
    assert_not admin.save
    assert_includes admin.errors[:role], "cannot be changed. You are the last admin."
  end

  test "should change admin role to employee when other admins exist" do
    admin = users(:admin_one)
    # Ensure at least two admins exist
    assert User.admin.count >= 2

    admin.role = :employee
    assert admin.save
    assert admin.employee?
  end

  test "should change employee role to admin" do
    employee = users(:employee_one)

    employee.role = :admin
    assert employee.save
    assert employee.admin?
  end

  # Test associations
  test "should have many documents" do
    user = users(:admin_one)
    assert_respond_to user, :documents
  end

  test "should have many conversations" do
    user = users(:employee_one)
    assert_respond_to user, :conversations
  end
end
