class CsatSurveyResponsePolicy < ApplicationPolicy
  def index?
    @account_user.can?('report_manage')
  end

  def metrics?
    @account_user.can?('report_manage')
  end

  def download?
    @account_user.can?('report_manage')
  end
end

CsatSurveyResponsePolicy.prepend_mod_with('CsatSurveyResponsePolicy')
