# Choplife fork: serves /audit_logs for the existing Settings → Audit logs page on the CE build.
# Named apart from enterprise/'s AuditLogsController, which our image doesn't ship.
class Api::V1::Accounts::ActivityLogsController < Api::V1::Accounts::BaseController
  PER_PAGE = 25

  before_action -> { check_authorization(AuditLog) }

  def show
    logs = filtered_logs
    @total_entries = logs.count
    @current_page = [params[:page].to_i, 1].max
    @per_page = PER_PAGE
    @audit_logs = logs.includes(:auditable)
                      .reorder(created_at: params[:sort] == 'asc' ? :asc : :desc, id: :desc)
                      .offset((@current_page - 1) * PER_PAGE).limit(PER_PAGE)
  end

  private

  def filtered_logs
    logs = AuditLog.for_account(Current.account)
    logs = logs.where(auditable_type: Array(params[:types])) if params[:types].present?
    logs = logs.where(created_at: date_range) if date_range
    params[:q].present? ? search(logs, params[:q]) : logs
  end

  def date_range
    return if params[:since].blank? || params[:until].blank?

    Time.zone.at(params[:since].to_i)..Time.zone.at(params[:until].to_i)
  end

  # Search by the name or email of whoever made the change
  def search(logs, query)
    term = "%#{ActiveRecord::Base.sanitize_sql_like(query)}%"
    user_ids = User.where('users.name ILIKE :term OR users.email ILIKE :term', term: term).select(:id)
    logs.where(user_type: 'User', user_id: user_ids)
  end
end
