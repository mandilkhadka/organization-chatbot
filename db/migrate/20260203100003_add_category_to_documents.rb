class AddCategoryToDocuments < ActiveRecord::Migration[7.1]
  def change
    add_reference :documents, :category, foreign_key: true
  end
end
