class CreateMessages < ActiveRecord::Migration[7.1]
  def change
    create_table :messages do |t|
      t.references :conversation, null: false, foreign_key: true
      t.integer :role, null: false
      t.text :content, null: false
      t.integer :feedback, default: 0, null: false

      t.timestamps
    end
  end
end
