class UserPolicy < ApplicationPolicy
  def index?
    true
  end

  def create?
    @account_user.can?('agent_manage')
  end

  def update?
    @account_user.can?('agent_manage')
  end

  def destroy?
    @account_user.can?('agent_manage')
  end

  def bulk_create?
    @account_user.can?('agent_manage')
  end
end
