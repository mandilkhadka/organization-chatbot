class CreateDocuments < ActiveRecord::Migration[7.1]
  def change
    create_table :documents do |t|
      t.references :user, null: false, foreign_key: true
      t.string :title, null: false
      t.string :filename, null: false
      t.string :content_type
      t.integer :file_size
      t.integer :status, default: 0, null: false
      t.text :error_message

      t.timestamps
    end

    add_index :documents, :status
  end
end
