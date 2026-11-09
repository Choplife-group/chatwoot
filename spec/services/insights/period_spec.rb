require 'rails_helper'

RSpec.describe Insights::Period do
  let(:now) { Time.find_zone('UTC').parse('2026-11-09 10:00 UTC') }
  let(:zone) { 'Africa/Dar_es_Salaam' }

  def format(range) = range.map { |time| time.strftime('%F %T') }

  it 'finds last month and the month before it in the time zone' do
    period = described_class.new('last_month', zone, now: now)

    expect(format(period.range)).to eq(['2026-10-01 00:00:00', '2026-10-31 23:59:59'])
    expect(format(period.compare_range('previous_period'))).to eq(['2026-09-01 00:00:00', '2026-09-30 23:59:59'])
    expect(format(period.compare_range('previous_year'))).to eq(['2025-10-01 00:00:00', '2025-10-31 23:59:59'])
  end

  it 'compares a run of days with the same days just before' do
    period = described_class.new('last_7_days', zone, now: now)

    expect(format(period.range)).to eq(['2026-11-03 00:00:00', '2026-11-09 13:00:00'])
    expect(format(period.compare_range('previous_period'))).to eq(['2026-10-27 00:00:00', '2026-11-02 13:00:00'])
  end

  it 'compares a month so far with the same days of the month before' do
    expect(format(described_class.new('this_month', zone, now: now).compare_range('previous_period')))
      .to eq(['2026-10-01 00:00:00', '2026-10-09 13:00:00'])
  end

  it 'compares a custom period with the same length just before it' do
    custom = [Time.find_zone('UTC').parse('2026-10-10 00:00'), Time.find_zone('UTC').parse('2026-10-19 23:59:59')]

    expect(format(described_class.new('custom', 'UTC', custom: custom).compare_range('previous_period')))
      .to eq(['2026-09-30 00:00:00', '2026-10-09 23:59:59'])
  end
end
