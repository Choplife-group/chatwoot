class SavedReportPolicy < ApplicationPolicy
  def show?
    owner? || record.shared?
  end

  # Anyone can save their own reports; changing a shared one, or sharing one, needs report_manage
  def update?
    owner? || (record.shared? && @account_user.can?('report_manage'))
  end

  def destroy?
    update?
  end

  def share?
    @account_user.can?('report_manage')
  end

  private

  def owner?
    record.user_id == @user.id
  end
end
