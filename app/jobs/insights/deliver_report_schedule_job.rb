# Emails one run of a report schedule: the report is worked out separately for each recipient, as that recipient,
# so nobody gets figures beyond what they're allowed to see
class Insights::DeliverReportScheduleJob < ApplicationJob
  queue_as :low

  def perform(schedule_id)
    schedule = ReportSchedule.find_by(id: schedule_id)
    return if schedule.nil? || !schedule.account.feature_enabled?('insights')

    report = schedule.saved_report
    config = report.report_config
    schedule.recipients.each { |recipient| deliver(schedule, report, config, recipient) }
    schedule.update!(last_sent_at: Time.current)
  end

  private

  def deliver(schedule, report, config, recipient)
    result = Insights::QueryService.new(account: schedule.account, user: recipient, config: config).perform
    Insights::ReportMailer.with(account: schedule.account).scheduled_report(
      recipient: recipient, title: report.name, file_types: schedule.file_types,
      export: Insights::ExportService.new(title: report.name, config: config, result: result),
      report_url: "#{ENV.fetch('FRONTEND_URL', nil)}/app/accounts/#{schedule.account_id}/reports/insights/reports/#{report.id}"
    ).deliver_now
  end
end
