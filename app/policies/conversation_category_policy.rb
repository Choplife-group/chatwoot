class ConversationCategoryPolicy < ApplicationPolicy
  def index?
    true
  end

  def show?
    true
  end

  def create?
    @account_user.can?('category_manage')
  end

  def update?
    @account_user.can?('category_manage')
  end

  def destroy?
    @account_user.can?('category_manage')
  end

  def reorder?
    @account_user.can?('category_manage')
  end
end
