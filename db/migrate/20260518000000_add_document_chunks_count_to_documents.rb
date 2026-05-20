class AddDocumentChunksCountToDocuments < ActiveRecord::Migration[7.1]
  def up
    return if column_exists?(:documents, :document_chunks_count)

    add_column :documents, :document_chunks_count, :integer, default: 0, null: false

    # Backfill from the join. Use update_all so we don't touch validations or
    # bump updated_at on every row.
    execute <<~SQL.squish
      UPDATE documents d
      SET document_chunks_count = (
        SELECT COUNT(*) FROM document_chunks dc WHERE dc.document_id = d.id
      )
    SQL
  end

  def down
    remove_column :documents, :document_chunks_count
  end
end
