module Admin
  class AuditLogsController < BaseController
    PER_PAGE = 50

    def index
      @audit_logs = AdminAuditLog.recent
                                 .by_action(params[:action_filter])
                                 .by_resource_type(params[:resource_type])
                                 .by_user(params[:user_id])
                                 .includes(:user)
                                 .limit(PER_PAGE)
                                 .offset(page_offset)

      @total_count = AdminAuditLog.count
      @current_page = current_page
      @total_pages = (@total_count.to_f / PER_PAGE).ceil
    end

    def show
      @audit_log = AdminAuditLog.find(params[:id])
    end

    private

    def current_page
      [params[:page].to_i, 1].max
    end

    def page_offset
      (current_page - 1) * PER_PAGE
    end
  end
end
