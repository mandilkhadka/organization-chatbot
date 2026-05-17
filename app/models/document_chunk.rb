class DocumentChunk < ApplicationRecord
  belongs_to :document
  has_many :message_sources, dependent: :destroy

  validates :content, presence: true

  scope :with_embeddings, -> { where.not(embedding: nil) }

  class << self
    def pgvector_enabled?
      return @pgvector_enabled if defined?(@pgvector_enabled)

      @pgvector_enabled = begin
        connection.execute("SELECT 1 FROM pg_extension WHERE extname = 'vector'").any?
      rescue StandardError
        false
      end
    end

    # Lazily configure has_neighbors only when pgvector is available.
    # VectorSearchService calls this before issuing a nearest-neighbors query.
    def configure_neighbors!
      return if @neighbors_configured

      @neighbors_configured = true
      has_neighbors :embedding if pgvector_enabled?
    rescue StandardError
      # Silently continue if configuration fails — the Ruby fallback will be used.
    end
  end

  def relevance_score
    return nil unless respond_to?(:neighbor_distance)

    1.0 - (neighbor_distance || 0)
  end
end
