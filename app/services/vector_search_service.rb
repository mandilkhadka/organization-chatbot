class VectorSearchService
  DEFAULT_LIMIT = 5
  DEFAULT_THRESHOLD = 0.5

  def initialize(embedding_service: EmbeddingService.new)
    @embedding_service = embedding_service
  end

  def search(query, limit: DEFAULT_LIMIT, threshold: DEFAULT_THRESHOLD)
    query_embedding = @embedding_service.generate(query)

    if DocumentChunk.pgvector_enabled?
      search_with_pgvector(query_embedding, limit, threshold)
    else
      search_with_ruby(query_embedding, limit, threshold)
    end
  rescue StandardError => e
    Rails.logger.error("Vector search failed: #{e.message}")
    []
  end

  private

  def search_with_pgvector(query_embedding, limit, threshold)
    max_distance = 1 - threshold

    # Configure neighbors before searching
    DocumentChunk.configure_neighbors!

    # Fetch more results than needed to account for threshold filtering
    # neighbor_distance is computed dynamically, so we filter in Ruby after fetching
    results = DocumentChunk
      .with_embeddings
      .includes(:document)
      .nearest_neighbors(:embedding, query_embedding, distance: "cosine")
      .limit(limit * 3)
      .to_a

    # Apply threshold filter and take the requested limit
    results
      .select { |chunk| chunk.neighbor_distance <= max_distance }
      .take(limit)
  end

  def search_with_ruby(query_embedding, limit, threshold)
    # Fallback: compute cosine similarity in Ruby (slower but works without pgvector)
    chunks = DocumentChunk.with_embeddings.includes(:document).to_a

    scored_chunks = chunks.filter_map do |chunk|
      stored_embedding = parse_embedding(chunk.embedding)
      next unless stored_embedding

      similarity = cosine_similarity(query_embedding, stored_embedding)
      next if similarity < threshold

      chunk.define_singleton_method(:neighbor_distance) { 1 - similarity }
      [chunk, similarity]
    end

    scored_chunks
      .sort_by { |_, similarity| -similarity }
      .take(limit)
      .map(&:first)
  end

  def parse_embedding(embedding)
    return nil if embedding.blank?
    return embedding if embedding.is_a?(Array)

    JSON.parse(embedding)
  rescue JSON::ParserError
    nil
  end

  def cosine_similarity(vec_a, vec_b)
    return 0 if vec_a.nil? || vec_b.nil? || vec_a.empty? || vec_b.empty?

    dot = vec_a.zip(vec_b).sum { |a, b| a * b }
    mag_a = Math.sqrt(vec_a.sum { |x| x**2 })
    mag_b = Math.sqrt(vec_b.sum { |x| x**2 })

    return 0 if mag_a.zero? || mag_b.zero?

    dot / (mag_a * mag_b)
  end
end
