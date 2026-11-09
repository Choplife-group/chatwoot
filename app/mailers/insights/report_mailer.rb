class Insights::ReportMailer < ApplicationMailer
  # export: an Insights::ExportService worked out for this recipient
  def scheduled_report(recipient:, title:, export:, file_types:, report_url:)
    return unless smtp_config_set_or_development?

    file_types.each do |file_type|
      attachments[export.filename(file_type)] = { mime_type: Insights::ExportService::CONTENT_TYPES[file_type], content: export.render(file_type) }
    end
    @action_url = report_url
    @meta = { 'name' => recipient.name, 'title' => title, 'period_lines' => export.period_lines, 'summary' => export.summary }
    send_mail_with_liquid(to: recipient.email, subject: "#{title} · #{export.period_lines.first}")
  end

  private

  def liquid_locals
    super.merge(meta: @meta)
  end
end
