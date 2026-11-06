class ReportPolicy < ApplicationPolicy
  def view?
    @account_user.can?('report_manage')
  end
end

ReportPolicy.prepend_mod_with('ReportPolicy')
