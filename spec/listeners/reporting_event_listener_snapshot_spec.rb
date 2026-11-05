require 'rails_helper'

RSpec.describe ReportingEventListener do
  let(:account) { create(:account) }
  let(:market) { create(:market, account: account) }
  let(:category) { create(:conversation_category, account: account) }

  it 'snapshots the market and category on the resolution event' do
    conversation = create(:conversation, account: account, inbox: create(:inbox, account: account, market: market), category: category)
    event = Events::Base.new('conversation_resolved', Time.zone.now, { conversation: conversation })

    described_class.instance.conversation_resolved(event)

    expect(ReportingEvent.find_by(conversation: conversation, name: 'conversation_resolved'))
      .to have_attributes(market_id: market.id, category_id: category.id)
  end
end
