module Admin
  class DashboardController < Admin::BaseController
    def index
      @total_users = User.count
      @total_employees = User.employee.count
      @total_admins = User.admin.count
      @total_documents = Document.count
      @documents_ready = Document.ready.count
      @documents_processing = Document.where(status: %i[pending processing]).count
      @total_conversations = Conversation.count
      @total_messages = Message.count

      @recent_users = User.order(created_at: :desc).limit(5)
      @recent_documents = Document.includes(:user).order(created_at: :desc).limit(5)
      @recent_conversations = Conversation.includes(:user, :messages).order(updated_at: :desc).limit(5)
    end
  end
end
