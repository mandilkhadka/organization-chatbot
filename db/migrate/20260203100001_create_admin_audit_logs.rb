class CreateAdminAuditLogs < ActiveRecord::Migration[7.1]
  def change
    create_table :admin_audit_logs do |t|
      t.references :user, null: false, foreign_key: true
      t.string :action, null: false
      t.string :resource_type, null: false
      t.bigint :resource_id
      t.jsonb :changes, default: {}
      t.string :ip_address
      t.string :user_agent
      t.string :request_id

      t.timestamps
    end

    add_index :admin_audit_logs, %i[resource_type resource_id]
    add_index :admin_audit_logs, :created_at
    add_index :admin_audit_logs, :action
  end
end
