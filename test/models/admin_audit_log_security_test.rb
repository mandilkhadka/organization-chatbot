require "test_helper"
require "minitest/mock"

class AdminAuditLogSecurityTest < ActiveSupport::TestCase
  def setup
    @admin = users(:admin_one)
  end

  test "constantize whitelist prevents arbitrary class loading" do
    # Create an audit log with a non-whitelisted resource type
    log = AdminAuditLog.create!(
      user: @admin,
      action: "create",
      resource_type: "Kernel", # Dangerous class - not whitelisted
      resource_id: 1
    )

    # resource method should return nil for non-whitelisted types
    assert_nil log.resource
  end

  test "whitelisted resource types can be resolved" do
    AdminAuditLog::ALLOWED_RESOURCE_TYPES.each do |type|
      next if type == "System" # System has no ID

      log = AdminAuditLog.new(
        user: @admin,
        action: "create",
        resource_type: type,
        resource_id: 999 # Non-existent ID
      )

      # Should not raise, should return nil for non-existent record
      assert_nil log.resource
    end
  end

  test "resource returns nil for System type" do
    log = AdminAuditLog.create!(
      user: @admin,
      action: "login",
      resource_type: "System"
    )

    assert_nil log.resource
  end

  test "ALLOWED_RESOURCE_TYPES includes expected types" do
    expected_types = %w[Document Category User System]

    expected_types.each do |type|
      assert_includes AdminAuditLog::ALLOWED_RESOURCE_TYPES, type
    end
  end

  test "log_action truncates long user agents" do
    mock_request = Minitest::Mock.new
    mock_request.expect :remote_ip, "127.0.0.1"
    mock_request.expect :user_agent, "A" * 1000
    mock_request.expect :request_id, "test-request-id"

    log = AdminAuditLog.log_action(
      user: @admin,
      action: "login",
      request: mock_request
    )

    assert_operator log.user_agent.length, :<=, 500
    mock_request.verify
  end
end
