json.audit_logs @audit_logs do |audit_log|
  json.id audit_log.id
  json.auditable_id audit_log.auditable_id
  json.auditable_type audit_log.auditable_type
  # The page tells "edited themselves" from "edited someone else" by the account user's user_id
  auditable = audit_log.auditable
  json.auditable(auditable.is_a?(AccountUser) ? auditable.slice(:id, :user_id) : auditable&.slice(:id))
  json.associated_id audit_log.associated_id
  json.associated_type audit_log.associated_type
  json.action audit_log.action
  json.audited_changes audit_log.audited_changes
  json.user_id audit_log.user_id
  json.username audit_log.username
  json.remote_address audit_log.remote_address
  json.location nil
  json.created_at audit_log.created_at.to_i
end
json.current_page @current_page
json.per_page @per_page
json.total_entries @total_entries
