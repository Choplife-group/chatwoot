require 'rails_helper'

RSpec.describe ReportSchedule do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account) }
  let(:report) { account.saved_reports.create!(user: user, name: 'Weekly', config: { metrics: %w[received], period: 'last_week' }) }
  let(:schedule) do
    account.report_schedules.new(saved_report: report, user: user, recipient_ids: [user.id], file_types: %w[pdf], timezone: 'Africa/Dar_es_Salaam',
                                 hour: 8)
  end
  # A Monday, 10:00 in Dar es Salaam
  let(:now) { Time.find_zone('Africa/Dar_es_Salaam').parse('2026-11-09 10:00') }

  it 'goes out tomorrow at the hour when today\'s has passed' do
    schedule.frequency = :daily

    expect(schedule.next_run_after(now)).to eq(Time.find_zone('Africa/Dar_es_Salaam').parse('2026-11-10 08:00'))
  end

  it 'goes out on the chosen weekday' do
    schedule.assign_attributes(frequency: :weekly, weekday: 1)

    expect(schedule.next_run_after(now)).to eq(Time.find_zone('Africa/Dar_es_Salaam').parse('2026-11-16 08:00'))
  end

  it 'goes out on the chosen day of the month' do
    schedule.assign_attributes(frequency: :monthly, day_of_month: 1)

    expect(schedule.next_run_after(now)).to eq(Time.find_zone('Africa/Dar_es_Salaam').parse('2026-12-01 08:00'))
  end

  it 'sets the next run when saved and rejects people outside the account, unknown file types and unknown frequencies' do
    schedule.frequency = :daily
    schedule.save!
    expect(schedule.next_run_at).to be > Time.current

    expect(schedule.dup.tap { |copy| copy.recipient_ids = [create(:user).id] }).not_to be_valid
    expect(schedule.dup.tap { |copy| copy.file_types = %w[docx] }).not_to be_valid
    expect(schedule.dup.tap { |copy| copy.frequency = 'hourly' }).not_to be_valid
  end
end
