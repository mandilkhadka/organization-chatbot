module Admin
  class UsersController < Admin::BaseController
    before_action :set_user, only: %i[show edit update destroy toggle_status]
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
      @user = User.new(user_params)

      if @user.save
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
      respond_to do |format|
        format.html { redirect_to admin_users_path, notice: "User deleted successfully." }
        format.turbo_stream
      end
    end

    def toggle_status
      # We'll add an active field later, for now this is a placeholder
      redirect_to admin_users_path, notice: "User status updated."
    end

    private

    def set_user
      @user = User.find(params[:id])
    end

    def user_params
      params.require(:user).permit(:email, :password, :password_confirmation, :role)
    end

    def user_not_found
      redirect_to admin_users_path, alert: "User not found."
    end
  end
end
