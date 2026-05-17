module Admin
  class UsersController < Admin::BaseController
    include Auditable

    before_action :set_user, only: %i[show edit update destroy update_role]
    rescue_from ActiveRecord::RecordNotFound, with: :user_not_found

    def index
      @users = User.left_joins(:conversations)
                   .select("users.*, COUNT(conversations.id) AS conversations_count")
                   .group("users.id")
                   .order(created_at: :desc)

      if params[:search].present?
        sanitized_search = ActiveRecord::Base.sanitize_sql_like(params[:search])
        @users = @users.where("email ILIKE ?", "%#{sanitized_search}%")
      end
      @users = @users.where(role: params[:role]) if params[:role].present?
    end

    def show
      @conversations = @user.conversations.includes(:messages).order(updated_at: :desc).limit(10)
    end

    def new
      @user = User.new
    end

    def create
      # SECURITY: role is NOT mass-assignable. New users default to :employee.
      # Promotion to admin must go through update_role (audited).
      @user = User.new(user_params.merge(role: :employee))

      if @user.save
        audit_resource(@user)
        redirect_to admin_users_path, notice: "Employee account created successfully. Credentials: #{@user.email}"
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      update_params = user_params.dup
      update_params.delete(:password) if update_params[:password].blank?
      update_params.delete(:password_confirmation) if update_params[:password_confirmation].blank?

      if @user.update(update_params)
        audit_resource(@user)
        redirect_to admin_users_path, notice: "User updated successfully."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      if @user == current_user
        redirect_to admin_users_path, alert: "You cannot delete your own account."
        return
      end

      if @user.last_admin?
        redirect_to admin_users_path, alert: "Cannot delete the last admin user."
        return
      end

      @user.destroy
      audit_resource(@user)
      respond_to do |format|
        format.html { redirect_to admin_users_path, notice: "User deleted successfully." }
        format.turbo_stream
      end
    end

    # Dedicated, audited role change endpoint.
    # SECURITY: role changes go through here, never via user_params.
    def update_role
      new_role = params[:role].to_s
      redirect_to admin_users_path, alert: "Invalid role." and return unless User.roles.key?(new_role)

      if @user == current_user && new_role != "admin"
        redirect_to admin_users_path, alert: "You cannot demote yourself." and return
      end

      previous_role = @user.role
      if @user.update(role: new_role)
        AdminAuditLog.log_action(
          user: current_user,
          action: "role_change",
          resource: @user,
          change_data: { "role" => [previous_role, new_role] },
          request: request
        )
        redirect_to admin_users_path, notice: "Role updated to #{new_role.titleize}."
      else
        redirect_to admin_users_path, alert: @user.errors.full_messages.to_sentence
      end
    end

    private

    def set_user
      @user = User.find(params[:id])
    end

    # SECURITY: :role is intentionally excluded. Use update_role action.
    def user_params
      params.require(:user).permit(:email, :password, :password_confirmation)
    end

    def user_not_found
      redirect_to admin_users_path, alert: "User not found."
    end
  end
end
