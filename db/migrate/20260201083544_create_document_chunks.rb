class CreateDocumentChunks < ActiveRecord::Migration[7.1]
  def change
    create_table :document_chunks do |t|
      t.references :document, null: false, foreign_key: true
      t.text :content, null: false
      t.integer :position
      t.jsonb :metadata, default: {}

      t.timestamps
    end

    # Add vector column if pgvector extension is available
    if extension_enabled?("vector")
      add_column :document_chunks, :embedding, :vector, limit: 768
      add_index :document_chunks, :embedding, using: :ivfflat, opclass: :vector_cosine_ops
    else
      # Fallback: store embeddings as text (JSON array) for local development
      add_column :document_chunks, :embedding, :text
      puts "NOTE: Using text column for embeddings (pgvector not available)"
    end
  end

  private

  def extension_enabled?(name)
    result = execute("SELECT 1 FROM pg_extension WHERE extname = '#{name}'")
    result.any?
  rescue
    false
  end
end
