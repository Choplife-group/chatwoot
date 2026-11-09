require 'rails_helper'

# Every metric by every dimension, on data that includes conversations with no team, category or agent.
# Each figure must match the conversations its drill-down lists, and counts must add up to their total.
RSpec.describe Insights::QueryService do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:market_tz) { create(:market, account: account, code: 'TZ') }
  let(:market_na) { create(:market, account: account, code: 'NA') }
  let(:team_tz) { create(:team, account: account) }
  let(:agent_tz) { create(:user, account: account, role: :agent).tap { |user| create(:team_member, team: team_tz, user: user) } }
  let(:category) do
    create(:conversation_category, account: account, name: 'Not received',
                                   parent: create(:conversation_category, account: account, name: 'Withdrawal'))
  end
  let(:inbox_tz) { create(:inbox, account: account, market: market_tz) }
  let(:inbox_na) { create(:inbox, account: account, market: market_na) }
  let(:reopened) do
    create(:conversation, account: account, inbox: inbox_tz, assignee: agent_tz, team: team_tz, category: category, priority: :high,
                          created_at: 3.days.ago)
  end
  let(:waiting) { create(:conversation, account: account, inbox: inbox_na, assignee: admin, created_at: 3.days.ago) }
  let(:untouched) { create(:conversation, account: account, inbox: inbox_tz, created_at: 2.days.ago) }
  let(:expected_values) do
    {
      'market' => [market_tz.id, market_na.id], 'team' => [team_tz.id, nil], 'category' => [category.parent_id, nil],
      'subcategory' => [category.id, nil], 'agent' => [agent_tz.id, admin.id, nil], 'inbox' => [inbox_tz.id, inbox_na.id]
    }
  end

  before do
    untouched
    account.sla_targets.create!(first_response_seconds: 200, resolution_seconds: 7200)
    create(:reporting_event, account: account, conversation: reopened, inbox: inbox_tz, user: agent_tz, name: 'first_response', value: 120,
                             value_in_business_hours: 120, event_end_time: 3.days.ago + 2.minutes)
    create(:reporting_event, account: account, conversation: reopened, inbox: inbox_tz, user: agent_tz, name: 'conversation_resolved', value: 3600,
                             value_in_business_hours: 3600, event_end_time: 2.days.ago)
    create(:reporting_event, account: account, conversation: reopened, inbox: inbox_tz, user: agent_tz, name: 'conversation_opened', value: 86_400,
                             event_start_time: 2.days.ago, event_end_time: 1.day.ago)
    create(:reporting_event, account: account, conversation: waiting, inbox: inbox_na, user: admin, name: 'first_response', value: 300,
                             value_in_business_hours: 300, event_end_time: 3.days.ago + 5.minutes)
  end

  Insights::ReportConfig::METRICS.each do |metric|
    it "breaks #{metric} down by every dimension, matching each figure to its conversations" do
      dimensions = Insights::ReportConfig::DIMENSIONS + (metric == 'open' ? [] : Insights::ReportConfig::TIME_DIMENSIONS)
      count_metric = Insights::QueryService::COUNT_METRICS.include?(metric)

      dimensions.each do |dimension|
        config = Insights::ReportConfig.new(metrics: [metric], group_by: [dimension], period: 'last_7_days', timezone: 'Africa/Dar_es_Salaam')
        expect(config).to be_valid
        result = described_class.new(account: account, user: admin, config: config).perform
        values = result[:rows].map { |row| row[:dimensions][dimension] }

        aggregate_failures("#{metric} by #{dimension}") do
          expect(values - expected_values.fetch(dimension, values)).to be_empty
          expect(result[:rows].sum { |row| row[:metrics][metric] }).to eq(result[:totals][metric]) if count_metric

          result[:rows].each do |row|
            listed = Insights::DrilldownService.new(account: account, user: admin, config: config,
                                                    figure: { metric: metric, dimensions: row[:dimensions].transform_values { |value| value&.to_s } })
                                               .perform[:meta][:total_count]
            count_metric ? expect(listed).to(eq(row[:metrics][metric])) : expect(listed).to(be_positive)
          end
        end
      end
    end
  end

  it 'works out each metric for this data' do
    config = Insights::ReportConfig.new(metrics: Insights::ReportConfig::METRICS, period: 'last_7_days')

    expect(described_class.new(account: account, user: admin, config: config).perform[:totals]).to eq(
      'received' => 3, 'resolved' => 1, 'open' => 3, 'reopened' => 1,
      'first_response_time' => 210.0, 'median_first_response_time' => 210.0, 'resolution_time' => 3600.0, 'median_resolution_time' => 3600.0,
      'first_response_sla' => 50.0, 'resolution_sla' => 100.0
    )
  end
end
