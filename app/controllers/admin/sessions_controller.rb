module Admin
  class SessionsController < ApplicationController
    layout "admin_login"

    skip_before_action :authenticate_user!, only: [:new, :create]
    before_action :redirect_if_authenticated, only: [:new, :create]

    def new
      # Render login form
    end

    def create
      user = User.find_by(email: params[:email]&.downcase)

      # Use constant-time comparison and generic error messages to prevent user enumeration
      if user&.valid_password?(params[:password]) && user.admin?
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
