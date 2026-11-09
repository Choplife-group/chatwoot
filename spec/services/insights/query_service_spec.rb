require 'rails_helper'

RSpec.describe Insights::QueryService do
  let(:account) { create(:account) }
  let(:market_tz) { create(:market, account: account, code: 'TZ', name: 'Tanzania') }
  let(:market_na) { create(:market, account: account, code: 'NA', name: 'Namibia') }
  let(:inbox_tz) { create(:inbox, account: account, market: market_tz) }
  let(:team_tz) { create(:team, account: account) }
  let(:team_na) { create(:team, account: account) }
  let(:not_received) do
    create(:conversation_category, account: account, name: 'Not received',
                                   parent: create(:conversation_category, account: account, name: 'Withdrawal'))
  end
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent_tz) { create(:user, account: account, role: :agent).tap { |user| create(:team_member, team: team_tz, user: user) } }
  let(:agent_na) { create(:user, account: account, role: :agent).tap { |user| create(:team_member, team: team_na, user: user) } }
  let!(:conversation_tz) do
    create(:conversation, account: account, inbox: inbox_tz, assignee: agent_tz, team: team_tz, category: not_received, priority: :high,
                          status: :resolved, created_at: 3.days.ago)
  end
  let!(:conversation_na) do
    create(:conversation, account: account, inbox: create(:inbox, account: account, market: market_na), assignee: agent_na, team: team_na,
                          created_at: 3.days.ago)
  end
  let(:period) { { since: 7.days.ago.to_i, until: Time.current.to_i } }
  let(:config) { Insights::ReportConfig.new(metrics: %w[received resolved first_response_time median_first_response_time], **period) }

  before do
    create(:reporting_event, account: account, conversation: conversation_tz, inbox: inbox_tz, user: agent_tz, name: 'conversation_resolved',
                             value: 3600, event_end_time: 2.days.ago)
    create(:reporting_event, account: account, conversation: conversation_tz, inbox: inbox_tz, user: agent_tz, name: 'first_response',
                             value: 120, event_end_time: 3.days.ago + 2.minutes)
    create(:reporting_event, account: account, conversation: conversation_na, inbox: conversation_na.inbox, user: agent_na, name: 'first_response',
                             value: 300, event_end_time: 3.days.ago + 5.minutes)
  end

  it 'works out the totals for an administrator' do
    expect(described_class.new(account: account, user: admin, config: config).perform[:totals])
      .to eq('received' => 2, 'resolved' => 1, 'first_response_time' => 210.0, 'median_first_response_time' => 210.0)
  end

  context 'when grouped by market, team and category' do
    let(:config) do
      Insights::ReportConfig.new(metrics: %w[received resolved first_response_time median_first_response_time], group_by: %w[market team category],
                                 **period)
    end

    it 'returns one row per combination, with the top-level category and names' do
      result = described_class.new(account: account, user: admin, config: config).perform
      row = result[:rows].find { |item| item[:dimensions]['market'] == market_tz.id }

      expect(row).to eq(dimensions: { 'market' => market_tz.id, 'team' => team_tz.id, 'category' => not_received.parent_id },
                        metrics: { 'received' => 1, 'resolved' => 1, 'first_response_time' => 120.0, 'median_first_response_time' => 120.0 })
      expect(result[:labels]['category']).to eq(not_received.parent_id.to_s => 'Withdrawal')
    end

    it 'keeps past figures where they were after the conversation moves to another team and category' do
      conversation_tz.update!(team: team_na, category: create(:conversation_category, account: account))

      rows = described_class.new(account: account, user: admin, config: Insights::ReportConfig.new(
        metrics: %w[resolved], group_by: %w[team subcategory], **period
      )).perform[:rows]

      expect(rows).to eq([{ dimensions: { 'team' => team_tz.id, 'subcategory' => not_received.id }, metrics: { 'resolved' => 1 } }])
    end
  end

  describe 'visibility' do
    it 'shows an agent only their own figures' do
      expect(described_class.new(account: account, user: agent_tz, config: config).perform[:totals])
        .to include('received' => 1, 'resolved' => 1, 'first_response_time' => 120.0)
    end

    it 'shows a team lead their team and their own figures' do
      lead = create(:user, account: account, role: :agent)
      create(:team_member, team: team_na, user: lead, lead: true)

      expect(described_class.new(account: account, user: lead, config: config).perform[:totals])
        .to include('received' => 1, 'resolved' => 0, 'first_response_time' => 300.0)
    end

    it 'shows a role with report_manage everything' do
      account.enable_features!('support_roles')
      manager = create(:user, account: account, role: :agent)
      manager.account_users.first.update!(custom_role_id: create(:support_role, account: account, permissions: ['report_manage']).id)

      expect(described_class.new(account: account, user: manager, config: config).perform[:totals]).to include('received' => 2)
    end
  end

  context 'when comparing with an earlier period' do
    let(:config) do
      Insights::ReportConfig.new(metrics: %w[received], group_by: %w[market], compare_since: 14.days.ago.to_i, compare_until: 7.days.ago.to_i,
                                 **period)
    end

    it 'returns both periods side by side' do
      create(:conversation, account: account, inbox: inbox_tz, created_at: 10.days.ago)

      result = described_class.new(account: account, user: admin, config: config).perform

      expect(result[:previous_totals]).to eq('received' => 1)
      expect(result[:rows].find { |row| row[:dimensions]['market'] == market_tz.id })
        .to include(metrics: { 'received' => 1 }, previous: { 'received' => 1 })
    end
  end

  describe 'open conversations' do
    let(:config) { Insights::ReportConfig.new(metrics: %w[open], **period) }

    before do
      reopened = create(:conversation, account: account, inbox: inbox_tz, created_at: 6.days.ago)
      create(:reporting_event, account: account, conversation: reopened, inbox: inbox_tz, name: 'conversation_resolved', event_end_time: 5.days.ago)
      create(:reporting_event, account: account, conversation: reopened, inbox: inbox_tz, name: 'conversation_opened', value: 86_400,
                               event_start_time: 5.days.ago, event_end_time: 4.days.ago)
      resolved = create(:conversation, account: account, inbox: inbox_tz, status: :resolved, created_at: 6.days.ago)
      create(:reporting_event, account: account, conversation: resolved, inbox: inbox_tz, name: 'conversation_resolved', event_end_time: 5.days.ago)
    end

    # The Namibia conversation, and the one reopened after its resolve. The Tanzania one is resolved.
    it 'counts what was open at the end of the period' do
      expect(described_class.new(account: account, user: admin, config: config).perform[:totals]).to eq('open' => 2)
    end

    it 'leaves out a conversation that was resolved at the end of a past period' do
      past = Insights::ReportConfig.new(metrics: %w[open], since: 7.days.ago.to_i, until: (4.days.ago - 12.hours).to_i)

      expect(described_class.new(account: account, user: admin, config: past).perform[:totals]).to eq('open' => 0)
    end
  end

  it 'counts a reopen once when the conversation is opened again after snoozing' do
    resolved_at = 2.days.ago
    2.times do |index|
      create(:reporting_event, account: account, conversation: conversation_tz, inbox: inbox_tz, name: 'conversation_opened', value: 600 + index,
                               event_start_time: resolved_at, event_end_time: 1.day.ago + index.hours)
    end

    expect(described_class.new(account: account, user: admin, config: Insights::ReportConfig.new(
      metrics: %w[reopened], **period
    )).perform[:totals]).to eq('reopened' => 1)
  end

  context 'with SLA targets' do
    let(:config) { Insights::ReportConfig.new(metrics: %w[first_response_sla], group_by: %w[market], **period) }

    it 'measures each first response against the most specific target' do
      account.sla_targets.create!(first_response_seconds: 600)
      account.sla_targets.create!(market: market_tz, priority: :high, first_response_seconds: 60)
      account.sla_targets.create!(market: market_tz, first_response_seconds: 3600)

      result = described_class.new(account: account, user: admin, config: config).perform

      expect(result[:totals]).to eq('first_response_sla' => 50.0)
      expect(result[:rows].to_h { |row| [row[:dimensions]['market'], row[:metrics]['first_response_sla']] })
        .to eq(market_tz.id => 0.0, market_na.id => 100.0)
    end
  end

  context 'when grouped by day' do
    let(:config) { Insights::ReportConfig.new(metrics: %w[received], group_by: %w[day], timezone: 'Africa/Dar_es_Salaam', **period) }

    it 'buckets by the local date' do
      late = Time.find_zone('Africa/Dar_es_Salaam').now.beginning_of_day - 2.days - 1.hour
      create(:conversation, account: account, inbox: inbox_tz, created_at: late)

      rows = described_class.new(account: account, user: admin, config: config).perform[:rows]

      expect(rows.pluck(:dimensions)).to include('day' => late.in_time_zone('Africa/Dar_es_Salaam').to_date.iso8601)
    end
  end
end
