class AddIndexesToMessages < ActiveRecord::Migration[7.1]
  def change
    add_index :messages, :status
    add_index :messages, [:conversation_id, :created_at]
  end
end
