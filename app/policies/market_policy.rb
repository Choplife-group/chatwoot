class MarketPolicy < ApplicationPolicy
  def index?
    true
  end

  def show?
    true
  end

  def create?
    @account_user.can?('market_manage')
  end

  def update?
    @account_user.can?('market_manage')
  end

  def destroy?
    @account_user.can?('market_manage')
  end
end
