class MessagesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_conversation

  def create
    # Create user message
    @user_message = @conversation.messages.create!(
      role: :user,
      content: message_params[:content]
    )

    # Update conversation title if it's the first message
    @conversation.update(title: message_params[:content].truncate(50)) if @conversation.messages.one?

    # Generate AI response synchronously for simplicity
    # In production, this could be moved to a background job with streaming
    rag_service = RAGService.new
    result = rag_service.query(message_params[:content])

    @assistant_message = @conversation.messages.create!(
      role: :assistant,
      content: result[:response]
    )

    # Save message sources (citations)
    result[:sources].each do |chunk|
      @assistant_message.message_sources.create!(document_chunk: chunk, relevance_score: chunk.relevance_score)
    end

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to conversation_path(@conversation) }
    end
  end

  def feedback
    @message = @conversation.messages.find(params[:id])
    @message.update!(feedback: params[:feedback])

    head :ok
  end

  private

  def set_conversation
    @conversation = current_user.conversations.find(params[:conversation_id])
  end

  def message_params
    params.require(:message).permit(:content)
  end
end
