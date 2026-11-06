# Stops someone with agent_manage or role_manage from handing out, or gaining, access an administrator didn't give them.
class Agents::EscalationGuard
  pattr_initialize [:account_user!]

  # Giving someone a base role and support role. Only an administrator can make an administrator.
  def can_give?(role, custom_role_id)
    return true if administrator?

    (role.nil? || role.to_s == 'agent') && holds?(account_user.account.support_roles.find_by(id: custom_role_id)&.permissions)
  end

  def can_manage_agent?(target)
    return true if administrator?

    !target.administrator? && target.user_id != account_user.user_id && holds?(target.permissions)
  end

  def can_set_permissions?(permissions)
    administrator? || holds?(permissions)
  end

  def can_manage_role?(role)
    return true if administrator?

    role.id != account_user.custom_role_id && holds?(role.permissions)
  end

  private

  def administrator?
    account_user.administrator?
  end

  def holds?(permissions)
    (Array(permissions) - account_user.permissions).empty?
  end
end
