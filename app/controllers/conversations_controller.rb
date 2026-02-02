class ConversationsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_conversation, only: %i[show destroy]

  def index
    @conversations = current_user.conversations.order(updated_at: :desc)
    @conversation = @conversations.first || current_user.conversations.create!(title: "New Conversation")
  end

  def show
    @messages = @conversation.messages.ordered.includes(message_sources: { document_chunk: :document })
  end

  def create
    @conversation = current_user.conversations.create!(title: "New Conversation")

    respond_to do |format|
      format.html { redirect_to conversation_path(@conversation) }
      format.turbo_stream
    end
  end

  def destroy
    @conversation.destroy

    respond_to do |format|
      format.html { redirect_to conversations_path, notice: "Conversation deleted." }
      format.turbo_stream
    end
  end

  private

  def set_conversation
    @conversation = current_user.conversations.find(params[:id])
  end
end
