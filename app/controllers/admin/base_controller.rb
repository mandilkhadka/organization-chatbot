module Admin
  class BaseController < ApplicationController
    before_action :authenticate_user!
    before_action :require_admin
    before_action :check_admin_session_timeout

    private

    def require_admin
      return if current_user&.admin?

      flash[:alert] = "Admin access required"
      redirect_to admin_login_path and return
    end

    def check_admin_session_timeout
      return unless current_user&.admin?

      if current_user.admin_session_expired?
        AdminAuditLog.log_action(
          user: current_user,
          action: "session_timeout",
          request: request
        )
        current_user.clear_admin_session!
        sign_out(current_user)
        flash[:alert] = "Your admin session has expired. Please log in again."
        redirect_to admin_login_path and return
      else
        # Only refresh session if within 5 minutes of expiration (throttled sliding expiration)
        # This prevents database writes on every single request
        current_user.refresh_admin_session_if_needed!
      end
    end
  end
end
