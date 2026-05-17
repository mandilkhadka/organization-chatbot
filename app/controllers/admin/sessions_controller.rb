module Admin
  class SessionsController < ApplicationController
    layout "admin_login"

    skip_before_action :authenticate_user!, only: %i[new create]
    before_action :redirect_if_authenticated, only: %i[new create]

    def new
      # Render login form
    end

    def create
      user = User.find_by(email: params[:email]&.downcase)
      password = params[:password]

      # Constant-time authentication to prevent timing attacks
      # Always perform password check even if user is nil
      if user.present?
        valid_password = user.valid_password?(password)
        is_admin = user.admin?
        is_locked = user.access_locked?
      else
        # Perform dummy bcrypt comparison to maintain constant time
        BCrypt::Password.create("dummy").is_password?(password || "")
        valid_password = false
        is_admin = false
        is_locked = false
      end

      if is_locked
        flash.now[:alert] = "Account is locked. Please try again later."
        render :new, status: :unprocessable_entity
      elsif valid_password && is_admin
        sign_in(user)
        user.refresh_admin_session!
        AdminAuditLog.log_action(user: user, action: "login", request: request)
        redirect_to admin_root_path, notice: "Welcome back!"
      else
        # Generic error message prevents user enumeration attacks
        # Don't reveal whether email exists, password was wrong, or user isn't admin
        flash.now[:alert] = "Invalid credentials"
        render :new, status: :unprocessable_entity
      end
    end

    def destroy
      if current_user
        current_user.clear_admin_session!
        AdminAuditLog.log_action(user: current_user, action: "logout", request: request)
      end
      sign_out(current_user)
      redirect_to admin_login_path, notice: "You have been logged out"
    end

    private

    def redirect_if_authenticated
      redirect_to admin_root_path if user_signed_in? && current_user.admin? && !current_user.admin_session_expired?
    end
  end
end
