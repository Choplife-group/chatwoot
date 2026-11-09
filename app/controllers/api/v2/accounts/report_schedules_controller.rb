class Api::V2::Accounts::ReportSchedulesController < Api::V1::Accounts::BaseController
  include InsightsFeatureCheck

  FIELDS = %i[id saved_report_id user_id frequency hour weekday day_of_month timezone recipient_ids file_types active next_run_at last_sent_at].freeze

  before_action :fetch_saved_report, only: [:index, :create]
  before_action :fetch_schedule, only: [:update, :destroy, :deliver]

  # One saved report's schedules: your own, or all of them if you can manage reports
  def index
    schedules = @saved_report.report_schedules.order(:created_at)
    schedules = schedules.where(user: Current.user) unless manager?
    render json: schedules.as_json(only: FIELDS)
  end

  def create
    save_schedule(@saved_report.report_schedules.new(account: Current.account, user: Current.user))
  end

  def update
    save_schedule(@schedule)
  end

  def destroy
    @schedule.destroy!
    head :ok
  end

  # Sends the schedule now, so people can see what the email looks like
  def deliver
    Insights::DeliverReportScheduleJob.perform_later(@schedule.id)
    head :accepted
  end

  private

  def fetch_saved_report
    @saved_report = Current.account.saved_reports.visible_to(Current.user).find(params[:saved_report_id])
  end

  def fetch_schedule
    @schedule = Current.account.report_schedules.find(params[:id])
    render_unauthorized(I18n.t('errors.insights.not_your_schedule')) unless @schedule.user_id == Current.user.id || manager?
  end

  def save_schedule(schedule)
    schedule.assign_attributes(params.require(:report_schedule).permit(:frequency, :hour, :weekday, :day_of_month, :timezone, :active,
                                                                       recipient_ids: [], file_types: []))
    return render_unauthorized(I18n.t('errors.insights.schedule_for_others')) unless manager? || schedule.recipient_ids == [Current.user.id]
    return render_could_not_create_error(I18n.t('errors.insights.share_before_scheduling')) unless recipients_can_open?(schedule)

    schedule.save!
    render json: schedule.as_json(only: FIELDS)
  end

  # The email links to the report, so anyone besides its owner needs it shared to open it
  def recipients_can_open?(schedule)
    schedule.saved_report.shared? || (schedule.recipient_ids - [schedule.saved_report.user_id]).empty?
  end

  def manager?
    Current.account_user.can?('report_manage')
  end
end
