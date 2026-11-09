require 'rails_helper'

RSpec.describe Insights::DrilldownService do
  let(:account) { create(:account) }
  let(:market) { create(:market, account: account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:inbox) { create(:inbox, account: account, market: market) }
  let!(:own) { create(:conversation, account: account, inbox: inbox, assignee: agent, created_at: 2.days.ago) }
  let!(:other) { create(:conversation, account: account, inbox: create(:inbox, account: account), created_at: 2.days.ago) }
  let(:config) { Insights::ReportConfig.new(metrics: %w[received resolved], group_by: %w[market], since: 7.days.ago.to_i, until: Time.current.to_i) }

  it 'lists the conversations behind one row' do
    result = described_class.new(account: account, user: admin, config: config,
                                 figure: { metric: 'received', dimensions: { 'market' => market.id.to_s } })
                            .perform

    expect(result[:meta]).to include(total_count: 1)
    expect(result[:payload].first).to include(conversation_id: own.id, display_id: own.display_id, status: 'open', market_id: market.id)
    expect(result[:labels]['market']).to eq(market.id.to_s => market.name)
  end

  it 'lists the row without a market' do
    result = described_class.new(account: account, user: admin, config: config,
                                 figure: { metric: 'received', dimensions: { 'market' => nil } }).perform

    expect(result[:payload].pluck(:conversation_id)).to eq([other.id])
  end

  it 'only lists what the user may see' do
    result = described_class.new(account: account, user: agent, config: config, figure: { metric: 'received', dimensions: {} }).perform

    expect(result[:payload].pluck(:conversation_id)).to eq([own.id])
  end

  it 'includes the measured time for event metrics' do
    create(:reporting_event, account: account, conversation: own, inbox: inbox, user: agent, name: 'conversation_resolved', value: 900,
                             event_end_time: 1.day.ago)

    result = described_class.new(account: account, user: admin, config: config, figure: { metric: 'resolved', dimensions: {} }).perform

    expect(result[:payload]).to contain_exactly(include(conversation_id: own.id, agent_id: agent.id, value: 900))
  end
end
