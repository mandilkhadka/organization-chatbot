require "test_helper"

module Admin
  class SessionsSecurityTest < ActionDispatch::IntegrationTest
    include Devise::Test::IntegrationHelpers

    def setup
      @admin = users(:admin_one)
      @employee = users(:employee_one)
    end

    # Helper to mock AdminAuditLog.log_action
    def with_audit_log_mocked
      original_method = AdminAuditLog.method(:log_action)
      AdminAuditLog.define_singleton_method(:log_action) { |**_kwargs| nil }
      yield
    ensure
      AdminAuditLog.define_singleton_method(:log_action, original_method)
    end

    # User enumeration prevention tests
    test "non-existent user gets same error as wrong password" do
      # Wrong password for existing user
      post admin_login_path, params: { email: @admin.email, password: "wrongpassword" }
      wrong_password_response = response.body

      # Non-existent user
      post admin_login_path, params: { email: "nonexistent@example.com", password: "password123" }
      nonexistent_response = response.body

      # Both should show "Invalid credentials"
      assert_match(/Invalid credentials/, wrong_password_response)
      assert_match(/Invalid credentials/, nonexistent_response)
    end

    test "non-admin user gets same error as invalid credentials" do
      # Valid employee credentials (but not admin)
      post admin_login_path, params: { email: @employee.email, password: "password123" }
      employee_response = response.body

      # Invalid credentials
      post admin_login_path, params: { email: @admin.email, password: "wrongpassword" }
      invalid_response = response.body

      # Both should show same generic error
      assert_match(/Invalid credentials/, employee_response)
      assert_match(/Invalid credentials/, invalid_response)
    end

    test "successful login does not reveal email in welcome message" do
      with_audit_log_mocked do
        post admin_login_path, params: { email: @admin.email, password: "password123" }
        follow_redirect!

        # Welcome message should not include email
        assert_equal "Welcome back!", flash[:notice]
        assert_no_match @admin.email, flash[:notice].to_s
      end
    end

    # Session timeout security tests
    test "expired session forces re-authentication" do
      sign_in @admin
      @admin.update(admin_session_expires_at: 1.minute.ago)

      get admin_root_path

      assert_redirected_to admin_login_path
    end

    test "nil session expiration forces re-authentication" do
      sign_in @admin
      @admin.update(admin_session_expires_at: nil)

      get admin_root_path

      assert_redirected_to admin_login_path
    end

    test "logout clears admin session expiration" do
      sign_in @admin
      @admin.refresh_admin_session!

      assert_not_nil @admin.reload.admin_session_expires_at

      with_audit_log_mocked do
        delete admin_logout_path
      end

      assert_nil @admin.reload.admin_session_expires_at
    end

    # Authentication bypass prevention
    test "employee cannot access admin routes by signing in through devise" do
      sign_in @employee

      get admin_root_path

      assert_redirected_to admin_login_path
      assert_equal "Admin access required", flash[:alert]
    end

    test "unauthenticated user is redirected to devise login" do
      get admin_root_path

      assert_redirected_to new_user_session_path
    end
  end
end
