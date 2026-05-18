require "test_helper"

module Admin
  class CategoriesControllerTest < ActionDispatch::IntegrationTest
    include Devise::Test::IntegrationHelpers

    def setup
      @admin = users(:admin_one)
      @admin.refresh_admin_session!
      sign_in @admin
      @category = categories(:general)
    end

    test "admin can access categories index" do
      get admin_categories_path

      assert_response :success
      assert_select "h1", /Document Categories/
    end

    test "admin can create new category" do
      assert_difference("Category.count", 1) do
        post admin_categories_path, params: { category: { name: "New Category", description: "Test" } }
      end
      assert_redirected_to admin_categories_path
    end

    test "admin can update category" do
      patch admin_category_path(@category), params: { category: { name: "Updated Name" } }

      assert_redirected_to admin_categories_path
      @category.reload

      assert_equal "Updated Name", @category.name
    end

    test "admin can delete category" do
      assert_difference("Category.count", -1) do
        delete admin_category_path(@category)
      end
      assert_redirected_to admin_categories_path
    end

    test "non-admin is redirected to admin login" do
      sign_out @admin
      employee = users(:employee_one)
      sign_in employee

      get admin_categories_path

      assert_redirected_to admin_login_path
    end

    test "category name is required" do
      post admin_categories_path, params: { category: { name: "", description: "Test" } }

      assert_response :unprocessable_entity
    end

    test "category name must be unique" do
      post admin_categories_path, params: { category: { name: @category.name } }

      assert_response :unprocessable_entity
    end

    test "audit log is created for create operation" do
      assert_difference("AdminAuditLog.count", 1) do
        post admin_categories_path, params: { category: { name: "Audited Category", description: "Test" } }
      end

      audit_log = AdminAuditLog.last

      assert_equal "Category", audit_log.resource_type
      assert_equal "create", audit_log.action
      assert_equal @admin.id, audit_log.user_id
    end

    test "audit log is created for update operation" do
      assert_difference("AdminAuditLog.count", 1) do
        patch admin_category_path(@category), params: { category: { name: "Audited Update" } }
      end

      audit_log = AdminAuditLog.last

      assert_equal "Category", audit_log.resource_type
      assert_equal "update", audit_log.action
      assert_equal @admin.id, audit_log.user_id
    end

    test "audit log is created for delete operation" do
      assert_difference("AdminAuditLog.count", 1) do
        delete admin_category_path(@category)
      end

      audit_log = AdminAuditLog.last

      assert_equal "Category", audit_log.resource_type
      assert_equal "delete", audit_log.action
      assert_equal @admin.id, audit_log.user_id
    end
  end
end
