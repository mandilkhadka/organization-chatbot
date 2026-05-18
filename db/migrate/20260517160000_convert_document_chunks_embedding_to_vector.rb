class ConvertDocumentChunksEmbeddingToVector < ActiveRecord::Migration[7.1]
  def up
    return unless extension_enabled?("vector")

    # If the column is already a vector, do nothing (idempotent).
    return if column_already_vector?

    # Safe to drop+recreate: this migration must run before any embeddings
    # are generated. If you have embeddings stored as JSON text and need
    # to preserve them, add a one-off backfill script before running.
    if column_exists?(:document_chunks, :embedding)
      begin
        remove_index :document_chunks, :embedding
      rescue StandardError
        nil
      end
      remove_column :document_chunks, :embedding
    end

    add_column :document_chunks, :embedding, :vector, limit: 768
    add_index :document_chunks, :embedding, using: :ivfflat, opclass: :vector_cosine_ops
  end

  def down
    return unless extension_enabled?("vector")
    return unless column_already_vector?

    begin
      remove_index :document_chunks, :embedding
    rescue StandardError
      nil
    end
    remove_column :document_chunks, :embedding
    add_column :document_chunks, :embedding, :text
  end

  private

  def extension_enabled?(name)
    execute("SELECT 1 FROM pg_extension WHERE extname = '#{name}'").any?
  rescue StandardError
    false
  end

  def column_already_vector?
    result = execute(<<~SQL.squish).to_a
      SELECT udt_name
      FROM information_schema.columns
      WHERE table_name = 'document_chunks' AND column_name = 'embedding'
    SQL
    result.first && result.first["udt_name"] == "vector"
  rescue StandardError
    false
  end
end
