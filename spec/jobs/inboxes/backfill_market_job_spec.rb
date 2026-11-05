require 'rails_helper'

RSpec.describe Inboxes::BackfillMarketJob do
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:uganda) { create(:market, account: account) }
  let(:sierra_leone) { create(:market, account: account) }

  it 'is enqueued when an inbox is mapped to a market' do
    expect { inbox.update!(market: uganda) }.to have_enqueued_job(described_class).with(inbox)
  end

  it 'fills the market on conversations and contacts that have none' do
    contact = create(:contact, account: account)
    conversation = create(:conversation, account: account, inbox: inbox, contact: contact)
    kept = create(:conversation, account: account, inbox: inbox, market: sierra_leone)
    inbox.update!(market: uganda)

    described_class.perform_now(inbox)

    expect(conversation.reload.market).to eq(uganda)
    expect(contact.reload.market).to eq(uganda)
    expect(kept.reload.market).to eq(sierra_leone)
  end
end
