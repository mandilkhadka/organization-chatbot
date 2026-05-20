class AddAdminSessionExpiresAtToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :admin_session_expires_at, :datetime
    add_index :users, :admin_session_expires_at
  end
end
