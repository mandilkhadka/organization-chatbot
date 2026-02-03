class RenameChangesToChangeDataInAdminAuditLogs < ActiveRecord::Migration[7.1]
  def change
    rename_column :admin_audit_logs, :changes, :change_data
  end
end
