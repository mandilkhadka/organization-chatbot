class DocumentProcessorJob < ApplicationJob
  queue_as :default
  retry_on StandardError, wait: :polynomially_longer, attempts: 3

  def perform(document_id)
    document = Document.find(document_id)
    return if document.ready? || document.processing?

    document.processing!

    # Parse document
    parser = DocumentParserService.new
    text = parser.parse(document)

    if text.blank?
      document.update!(status: :failed, error_message: "No text content found in document")
      return
    end

    # Chunk the text
    chunker = TextChunkerService.new
    chunks = chunker.chunk(text)

    # Create chunks in the database
    chunks.each_with_index do |content, position|
      document.document_chunks.create!(
        content: content,
        position: position,
        metadata: { original_length: content.length }
      )
    end

    # Queue embedding generation for each chunk
    document.document_chunks.each do |chunk|
      EmbeddingJob.perform_later(chunk.id)
    end

    Rails.logger.info("Document #{document.id} processed: #{chunks.size} chunks created")
  rescue DocumentParserService::ParseError, DocumentParserService::UnsupportedFormatError => e
    document.update!(status: :failed, error_message: e.message)
  rescue StandardError => e
    document.update!(status: :failed, error_message: "Unexpected error: #{e.message}")
    raise
  end
end
