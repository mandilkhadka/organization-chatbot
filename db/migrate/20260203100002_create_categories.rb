class CreateCategories < ActiveRecord::Migration[7.1]
  def change
    create_table :categories do |t|
      t.string :name, null: false
      t.text :description
      t.integer :documents_count, default: 0

      t.timestamps
    end

    add_index :categories, :name, unique: true
  end
end
