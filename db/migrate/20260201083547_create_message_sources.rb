class CreateMessageSources < ActiveRecord::Migration[7.1]
  def change
    create_table :message_sources do |t|
      t.references :message, null: false, foreign_key: true
      t.references :document_chunk, null: false, foreign_key: true
      t.float :relevance_score

      t.timestamps
    end
  end
end
