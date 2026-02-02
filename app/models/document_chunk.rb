class DocumentChunk < ApplicationRecord
  belongs_to :document
  has_many :message_sources, dependent: :destroy

  begin
    has_neighbors :embedding if connection.execute("SELECT 1 FROM pg_extension WHERE extname = 'vector'").any?
  rescue StandardError
    # Silently continue if pgvector extension is not installed
  end

  validates :content, presence: true

  scope :with_embeddings, -> { where.not(embedding: nil) }

  def self.pgvector_enabled?
    @pgvector_enabled ||= begin
      connection.execute("SELECT 1 FROM pg_extension WHERE extname = 'vector'").any?
    rescue StandardError
      false
    end
  end

  def relevance_score
    return nil unless respond_to?(:neighbor_distance)

    1.0 - (neighbor_distance || 0)
  end
end
