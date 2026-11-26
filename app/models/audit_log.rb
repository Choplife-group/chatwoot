# Choplife fork: Settings → Audit logs for the CE build. enterprise/ ships its own (Enterprise::AuditLog),
# which is stripped from our image. Model changes are recorded by the audited gem
# (config/initializers/chopwin_audit_logs.rb); sign-ins and sign-outs are recorded here.
class AuditLog < Audited::Audit
  # One entry per account the user belongs to, so each account's admins see it.
  def self.record_session(user, action, request)
    user.account_users.includes(:account).find_each do |account_user|
      create!(
        auditable: user, associated: account_user.account, user: user, action: action,
        remote_address: request.remote_ip, request_uuid: request.uuid
      )
    end
  end

  def self.for_account(account)
    where(associated_type: 'Account', associated_id: account.id)
      .or(where(auditable_type: 'Account', auditable_id: account.id))
  end
end
