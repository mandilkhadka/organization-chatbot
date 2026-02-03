require "test_helper"

class Admin::SessionsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  def setup
    @admin = users(:admin_one)
    @employee = users(:employee_one)
  end

  # Helper to mock AdminAuditLog.log_action
  def with_audit_log_mocked
    original_method = AdminAuditLog.method(:log_action)
    AdminAuditLog.define_singleton_method(:log_action) { |**kwargs| nil }
    yield
  ensure
    AdminAuditLog.define_singleton_method(:log_action, original_method)
  end

  # Test 1: Admin login page renders correctly
  test "should get new login page" do
    get admin_login_path
    assert_response :success
    assert_select "form"
  end

  # Test 2: Admin can log in with valid credentials
  test "admin can log in with valid credentials" do
    with_audit_log_mocked do
      post admin_login_path, params: { email: @admin.email, password: "password123" }
      assert_redirected_to admin_root_path
      follow_redirect!
      assert_equal "Welcome back!", flash[:notice]
    end
  end

  # Test 3: Non-admin user gets rejected with generic error (prevents user enumeration)
  test "non-admin user is rejected" do
    post admin_login_path, params: { email: @employee.email, password: "password123" }
    assert_response :unprocessable_entity
    # Generic message prevents user enumeration - doesn't reveal user exists but isn't admin
    assert_select ".flash-alert", /Invalid credentials/
  end

  # Test 4: Invalid credentials show generic error
  test "invalid credentials show error" do
    post admin_login_path, params: { email: @admin.email, password: "wrongpassword" }
    assert_response :unprocessable_entity
    assert_select ".flash-alert", /Invalid credentials/
  end

  # Test 5: Admin logout works and clears session
  test "admin can logout" do
    sign_in @admin
    @admin.refresh_admin_session!

    with_audit_log_mocked do
      delete admin_logout_path
      assert_redirected_to admin_login_path
      follow_redirect!
      assert_equal "You have been logged out", flash[:notice]
    end
  end

  # Test 6: Session timeout redirects to login (already authenticated admin with expired session)
  test "expired admin session redirects to login on admin pages" do
    sign_in @admin
    @admin.update(admin_session_expires_at: Time.current - 1.minute)

    get admin_root_path
    assert_redirected_to admin_login_path
  end

  # Test 7: Already authenticated admin is redirected to dashboard
  test "already authenticated admin is redirected to dashboard" do
    sign_in @admin
    @admin.refresh_admin_session!

    get admin_login_path
    assert_redirected_to admin_root_path
  end

  # Additional test: Admin session is refreshed on login
  test "admin session is refreshed on login" do
    with_audit_log_mocked do
      post admin_login_path, params: { email: @admin.email, password: "password123" }
      @admin.reload
      assert_not_nil @admin.admin_session_expires_at
      assert @admin.admin_session_expires_at > Time.current
    end
  end

  # Additional test: Non-existent user shows same generic error (prevents user enumeration)
  test "non-existent user shows invalid credentials error" do
    post admin_login_path, params: { email: "nonexistent@example.com", password: "password123" }
    assert_response :unprocessable_entity
    # Same message as other failures to prevent user enumeration
    assert_select ".flash-alert", /Invalid credentials/
  end

  # Additional test: Email is case insensitive for login
  test "email is case insensitive for login" do
    with_audit_log_mocked do
      post admin_login_path, params: { email: @admin.email.upcase, password: "password123" }
      assert_redirected_to admin_root_path
    end
  end

  # Additional test: Logout clears admin session
  test "logout clears admin session" do
    sign_in @admin
    @admin.refresh_admin_session!
    assert_not_nil @admin.admin_session_expires_at

    with_audit_log_mocked do
      delete admin_logout_path
      @admin.reload
      assert_nil @admin.admin_session_expires_at
    end
  end

  # Additional test: Logout signs out current user
  test "logout signs out current user" do
    sign_in @admin
    @admin.refresh_admin_session!

    with_audit_log_mocked do
      delete admin_logout_path
      follow_redirect!

      # After logout, trying to access admin pages should redirect to login
      get admin_root_path
      assert_redirected_to new_user_session_path
    end
  end

  # Additional test: Create action skips authentication
  test "create action allows unauthenticated requests" do
    with_audit_log_mocked do
      post admin_login_path, params: { email: @admin.email, password: "password123" }
      assert_response :redirect
    end
  end

  # Additional test: Non-admin employees cannot access admin dashboard
  test "non-admin cannot access admin dashboard" do
    sign_in @employee

    get admin_root_path
    assert_redirected_to admin_login_path
  end
end
