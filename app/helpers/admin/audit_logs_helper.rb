module Admin
  module AuditLogsHelper
    def action_badge_color(action)
      case action
      when "login", "create", "bulk_create"
        "success"
      when "update"
        "info"
      when "delete"
        "danger"
      when "logout", "session_timeout"
        "warning"
      else
        "secondary"
      end
    end
  end
end
