class TextChunkerService
  CHUNK_SIZE = 512
  CHUNK_OVERLAP = 50

  def initialize(chunk_size: CHUNK_SIZE, chunk_overlap: CHUNK_OVERLAP)
    @chunk_size = chunk_size
    @chunk_overlap = chunk_overlap
  end

  def chunk(text)
    return [] if text.blank?

    chunks = []
    sentences = split_into_sentences(text)
    current_chunk = ""

    sentences.each do |sentence|
      if (current_chunk.length + sentence.length) > @chunk_size && current_chunk.present?
        chunks << current_chunk.strip
        # Keep overlap from previous chunk for context
        overlap_text = current_chunk.last(@chunk_overlap)
        current_chunk = "#{overlap_text} #{sentence}"
      else
        current_chunk += " #{sentence}"
      end
    end

    chunks << current_chunk.strip if current_chunk.present?
    chunks.compact_blank
  end

  private

  def split_into_sentences(text)
    text.split(/(?<=[.!?])\s+/)
  end
end
