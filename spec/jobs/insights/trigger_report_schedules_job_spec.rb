require 'rails_helper'

RSpec.describe Insights::TriggerReportSchedulesJob do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account) }
  let(:report) { account.saved_reports.create!(user: user, name: 'Daily', config: { metrics: %w[received], period: 'yesterday' }) }
  let!(:schedule) do
    account.report_schedules.create!(saved_report: report, user: user, recipient_ids: [user.id], file_types: %w[pdf], frequency: :daily)
  end

  it 'sends each due schedule once and moves it to its next run' do
    schedule.update_columns(next_run_at: 1.minute.ago) # rubocop:disable Rails/SkipsModelValidations

    expect { 2.times { described_class.perform_now } }.to have_enqueued_job(Insights::DeliverReportScheduleJob).with(schedule.id).exactly(:once)
    expect(schedule.reload.next_run_at).to be > Time.current
  end

  it 'leaves schedules that are not due or are paused' do
    schedule.update!(active: false)

    expect { described_class.perform_now }.not_to have_enqueued_job(Insights::DeliverReportScheduleJob)
  end
end
