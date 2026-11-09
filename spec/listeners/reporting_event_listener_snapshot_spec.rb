require 'rails_helper'

RSpec.describe ReportingEventListener do
  let(:account) { create(:account) }
  let(:market) { create(:market, account: account) }
  let(:category) { create(:conversation_category, account: account) }
  let(:team) { create(:team, account: account) }
  let(:conversation) do
    create(:conversation, account: account, inbox: create(:inbox, account: account, market: market), category: category, team: team)
  end

  it 'snapshots the market, team and category on the resolution event' do
    described_class.instance.conversation_resolved(Events::Base.new('conversation_resolved', Time.zone.now, { conversation: conversation }))

    expect(ReportingEvent.find_by(conversation: conversation, name: 'conversation_resolved'))
      .to have_attributes(market_id: market.id, team_id: team.id, category_id: category.id)
  end

  it 'snapshots them on reopen events too' do
    described_class.instance.conversation_opened(Events::Base.new('conversation_opened', Time.zone.now, { conversation: conversation }))

    expect(ReportingEvent.find_by(conversation: conversation, name: 'conversation_opened'))
      .to have_attributes(market_id: market.id, team_id: team.id, category_id: category.id)
  end

  it 'keeps the values from when the event happened after the conversation moves' do
    described_class.instance.conversation_resolved(Events::Base.new('conversation_resolved', Time.zone.now, { conversation: conversation }))
    conversation.update!(team: create(:team, account: account), category: create(:conversation_category, account: account))

    expect(ReportingEvent.find_by(conversation: conversation, name: 'conversation_resolved'))
      .to have_attributes(team_id: team.id, category_id: category.id)
  end
end
