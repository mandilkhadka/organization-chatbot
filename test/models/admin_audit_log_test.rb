require "test_helper"

class AdminAuditLogTest < ActiveSupport::TestCase
  def setup
    @admin = users(:admin_one)
  end

  test "valid audit log" do
    log = AdminAuditLog.new(
      user: @admin,
      action: "login",
      resource_type: "System"
    )
    assert log.valid?
  end

  test "requires user" do
    log = AdminAuditLog.new(action: "login", resource_type: "System")
    assert_not log.valid?
    assert_includes log.errors[:user], "must exist"
  end

  test "requires action" do
    log = AdminAuditLog.new(user: @admin, resource_type: "System")
    assert_not log.valid?
    assert_includes log.errors[:action], "can't be blank"
  end

  test "requires resource_type" do
    log = AdminAuditLog.new(user: @admin, action: "login")
    assert_not log.valid?
    assert_includes log.errors[:resource_type], "can't be blank"
  end

  test "action must be valid" do
    log = AdminAuditLog.new(user: @admin, action: "invalid", resource_type: "System")
    assert_not log.valid?
    assert_includes log.errors[:action], "is not included in the list"
  end

  test "log_action class method creates log" do
    assert_difference("AdminAuditLog.count", 1) do
      AdminAuditLog.log_action(
        user: @admin,
        action: "login",
        request: nil
      )
    end
  end

  test "log_action raises errors in test environment" do
    # In test/development, errors are raised to catch issues early
    assert_raises(ActiveRecord::RecordInvalid) do
      AdminAuditLog.log_action(
        user: nil,
        action: "login",
        request: nil
      )
    end
  end

  test "scopes work correctly" do
    # Clear any existing fixture logs
    AdminAuditLog.delete_all

    AdminAuditLog.create!(user: @admin, action: "login", resource_type: "System")
    AdminAuditLog.create!(user: @admin, action: "create", resource_type: "Document")

    assert_equal 1, AdminAuditLog.by_action("login").count
    assert_equal 1, AdminAuditLog.by_resource_type("Document").count
  end
end
