require 'rails_helper'

RSpec.describe Insights::DeliverReportScheduleJob do
  let(:account) { create(:account) }
  let(:manager) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:report) do
    account.saved_reports.create!(user: manager, name: 'Daily figures', shared: true,
                                  config: { metrics: %w[received], period: 'last_7_days', compare: 'previous_period' })
  end
  let(:schedule) do
    account.report_schedules.create!(saved_report: report, user: manager, recipient_ids: [manager.id, agent.id], file_types: %w[csv pdf],
                                     frequency: :daily, hour: 8)
  end

  # config/initializers/mailer.rb switches to sendmail without SMTP_ADDRESS, even in tests; collect the emails instead
  around do |example|
    original = ActionMailer::Base.delivery_method
    ActionMailer::Base.delivery_method = :test
    example.run
  ensure
    ActionMailer::Base.delivery_method = original
  end

  before do
    account.enable_features!('insights')
    create(:conversation, account: account, assignee: agent, created_at: 1.day.ago)
    create(:conversation, account: account, created_at: 1.day.ago)
    allow(Insights::ReportMailer).to receive(:new).and_wrap_original do |original, *args|
      original.call(*args).tap { |mailer| allow(mailer).to receive(:smtp_config_set_or_development?).and_return(true) }
    end
  end

  it 'emails every recipient their own figures with the files attached' do
    expect { described_class.perform_now(schedule.id) }.to change(ActionMailer::Base.deliveries, :count).by(2)

    emails = ActionMailer::Base.deliveries.last(2).index_by { |mail| mail.to.first }
    agent_email = emails[agent.email]
    expect(agent_email.subject).to start_with('Daily figures · ')
    expect(agent_email.attachments.map(&:filename)).to all(start_with('daily-figures-'))
    expect(agent_email.attachments.map(&:mime_type)).to eq(%w[text/csv application/pdf])
    expect(CSV.parse(agent_email.attachments.first.decoded).last).to eq(['Total', '1', '0', nil])
    expect(CSV.parse(emails[manager.email].attachments.first.decoded).last).to eq(['Total', '2', '0', nil])
    expect(schedule.reload.last_sent_at).to be_present
  end

  it 'sends nothing when insights is off' do
    account.disable_features!('insights')

    expect { described_class.perform_now(schedule.id) }.not_to change(ActionMailer::Base.deliveries, :count)
  end
end
