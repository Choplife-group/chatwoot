class SlaTargetPolicy < ApplicationPolicy
  def index?
    true
  end

  def create?
    @account_user.can?('sla_manage')
  end

  def update?
    @account_user.can?('sla_manage')
  end

  def destroy?
    @account_user.can?('sla_manage')
  end
end
