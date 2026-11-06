class SupportRolePolicy < ApplicationPolicy
  def index?
    @account_user.can?('role_manage') || @account_user.can?('agent_manage')
  end

  def show?
    index?
  end

  def create?
    @account_user.can?('role_manage')
  end

  def update?
    @account_user.can?('role_manage')
  end

  def destroy?
    @account_user.can?('role_manage')
  end
end
