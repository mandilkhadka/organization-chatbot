class EmbeddingJob < ApplicationJob
  queue_as :default
  retry_on StandardError, wait: :polynomially_longer, attempts: 3

  def perform(document_chunk_id)
    chunk = DocumentChunk.find_by(id: document_chunk_id)
    return if chunk.nil?
    return if chunk.embedding.present?

    embedding_service = EmbeddingService.new
    embedding = embedding_service.generate(chunk.content)

    # Store as vector if pgvector is available, otherwise as JSON string
    if DocumentChunk.pgvector_enabled?
      chunk.update!(embedding: embedding)
    else
      chunk.update!(embedding: embedding.to_json)
    end

    # Check if all chunks are embedded and mark document as ready
    document = chunk.document
    # Use count query instead of where(embedding: nil) for better pgvector compatibility
    if document.document_chunks.where("embedding IS NULL").none?
      document.ready!
      Rails.logger.info("Document #{document.id} is ready with all embeddings generated")
    end
  rescue StandardError => e
    Rails.logger.error("Embedding generation failed for chunk #{document_chunk_id}: #{e.message}")
    raise
  end
end
