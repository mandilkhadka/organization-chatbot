class GenerateResponseJob < ApplicationJob
  queue_as :default

  # Retry with exponential backoff for transient failures
  retry_on StandardError, wait: :polynomially_longer, attempts: 3

  def perform(message_id, question)
    message = Message.lock.find_by(id: message_id)
    return if message.nil?
    return if message.status_complete? || message.status_failed?

    conversation = message.conversation

    # Mark as streaming
    message.update!(status: :streaming)
    broadcast_message(conversation, message, streaming: true)

    rag_service = RagService.new
    full_response = ""
    last_broadcast = Time.current

    result = rag_service.query(question) do |chunk|
      full_response << chunk

      # Throttle broadcasts to every 100ms to avoid overwhelming the client
      if Time.current - last_broadcast > 0.1
        broadcast_message(conversation, message, streaming: true, content: full_response)
        last_broadcast = Time.current
      end
    end

    # Save the final response and sources atomically
    ActiveRecord::Base.transaction do
      message.update!(content: result[:response], status: :complete)

      # Save message sources (citations)
      result[:sources].each do |chunk|
        message.message_sources.create!(
          document_chunk: chunk,
          relevance_score: chunk.relevance_score || 0.0
        )
      end
    end

    # Final broadcast with complete message and sources
    broadcast_message(conversation, message.reload, streaming: false)
  rescue StandardError => e
    Rails.logger.error("Response generation failed: #{e.message}\n#{e.backtrace.first(5).join("\n")}")

    message.update!(
      content: "I'm sorry, I encountered an error while processing your question. Please try again.",
      status: :failed
    )

    broadcast_message(conversation, message.reload, streaming: false)

    # Re-raise to trigger retry logic
    raise if executions < 3
  end

  private

  def broadcast_message(conversation, message, streaming: false, content: nil)
    Turbo::StreamsChannel.broadcast_replace_to(
      "conversation_#{conversation.id}",
      target: "message_#{message.id}",
      partial: "messages/message",
      locals: {
        message: message,
        streaming_content: streaming ? (content || message.content) : nil,
        is_streaming: streaming
      }
    )
  end
end
