class AddStatusToMessages < ActiveRecord::Migration[7.1]
  def change
    add_column :messages, :status, :integer, default: 2, null: false  # default: complete
  end
end
