# Choplife fork: audit logs now have our own CE backend (AuditLog, Api::V1::Accounts::ActivityLogsController).
# We record IP addresses rather than locations, so audit_log_ip_address labels the column accordingly.
class ChopwinEnableAuditLogs < ActiveRecord::Migration[7.2]
  def up
    Account.find_each { |account| account.enable_features!('audit_logs', 'audit_log_ip_address') }
  end

  def down
    # Feature flags are data; nothing to revert.
  end
end
