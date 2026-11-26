# Choplife fork: only administrators can read the audit log.
class AuditLogPolicy < ApplicationPolicy
  def show?
    @account_user.administrator?
  end
end
