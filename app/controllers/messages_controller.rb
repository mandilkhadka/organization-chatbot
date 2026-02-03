class MessagesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_conversation

  def create
    # Validate content
    content = message_params[:content]&.strip
    if content.blank?
      head :unprocessable_entity
      return
    end

    # Create user message
    @user_message = @conversation.messages.create!(
      role: :user,
      content: content,
      status: :complete
    )

    # Update conversation title if it's the first message
    @conversation.update(title: content.truncate(50)) if @conversation.messages.user.one?

    # Create placeholder assistant message for streaming
    @assistant_message = @conversation.messages.create!(
      role: :assistant,
      content: "",
      status: :pending
    )

    # Queue background job for async response generation with streaming
    GenerateResponseJob.perform_later(@assistant_message.id, content)

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to conversation_path(@conversation) }
    end
  end

  def feedback
    @message = @conversation.messages.find(params[:id])
    feedback_value = params[:feedback]

    unless Message.feedbacks.keys.include?(feedback_value)
      head :bad_request
      return
    end

    @message.update!(feedback: feedback_value)
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
