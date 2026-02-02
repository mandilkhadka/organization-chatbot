class GenerateResponseJob < ApplicationJob
  queue_as :default

  def perform(message_id, question)
    message = Message.find(message_id)
    conversation = message.conversation

    rag_service = RAGService.new
    full_response = ""

    result = rag_service.query(question) do |chunk|
      full_response << chunk

      # Broadcast the chunk via Turbo Streams
      Turbo::StreamsChannel.broadcast_replace_to(
        "conversation_#{conversation.id}",
        target: "message_#{message.id}",
        partial: "messages/message",
        locals: { message: message, streaming_content: full_response }
      )
    end

    # Save the final response
    message.update!(content: result[:response])

    # Save message sources (citations)
    result[:sources].each do |chunk|
      message.message_sources.create!(document_chunk: chunk, relevance_score: chunk.relevance_score)
    end

    # Final broadcast with sources
    Turbo::StreamsChannel.broadcast_replace_to(
      "conversation_#{conversation.id}",
      target: "message_#{message.id}",
      partial: "messages/message",
      locals: { message: message.reload }
    )
  rescue StandardError => e
    Rails.logger.error("Response generation failed: #{e.message}")
    message.update!(content: "I'm sorry, I encountered an error. Please try again.")

    Turbo::StreamsChannel.broadcast_replace_to(
      "conversation_#{conversation.id}",
      target: "message_#{message.id}",
      partial: "messages/message",
      locals: { message: message.reload }
    )
  end
end
