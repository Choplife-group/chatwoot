require 'rails_helper'

RSpec.describe MarketHandler do
  let(:account) { create(:account) }
  let(:uganda) { create(:market, account: account, name: 'Uganda', code: 'UG') }
  let(:sierra_leone) { create(:market, account: account, name: 'Sierra Leone', code: 'SL') }
  let(:website_inbox) { create(:inbox, account: account, market: uganda) }
  let(:shared_inbox) { create(:inbox, account: account) }
  let(:contact) { create(:contact, account: account) }

  it 'takes the market of the inbox and remembers it on the contact' do
    conversation = create(:conversation, account: account, inbox: website_inbox, contact: contact)

    expect(conversation.market).to eq(uganda)
    expect(contact.reload.market).to eq(uganda)
  end

  it 'falls back to the contact market in a shared inbox' do
    contact.update!(market: sierra_leone)

    expect(create(:conversation, account: account, inbox: shared_inbox, contact: contact).market).to eq(sierra_leone)
  end

  it 'leaves the market empty when neither the inbox nor the contact has one' do
    expect(create(:conversation, account: account, inbox: shared_inbox, contact: contact).market).to be_nil
  end

  it 'does not overwrite the market already on the contact' do
    contact.update!(market: sierra_leone)
    conversation = create(:conversation, account: account, inbox: website_inbox, contact: contact)

    expect(conversation.market).to eq(uganda)
    expect(contact.reload.market).to eq(sierra_leone)
  end

  it 'keeps the market when contacts are merged' do
    mergee = create(:contact, account: account, market: uganda)

    ContactMergeAction.new(account: account, base_contact: contact, mergee_contact: mergee).perform

    expect(contact.reload.market).to eq(uganda)
  end

  it 'adds an activity message when a person changes the market' do
    conversation = create(:conversation, account: account, inbox: website_inbox, contact: contact)
    Current.user = create(:user, account: account, name: 'Jane')

    expect { conversation.update!(market: sierra_leone) }
      .to have_enqueued_job(Conversations::ActivityMessageJob)
      .with(conversation, hash_including(content: 'Jane changed the market from Uganda to Sierra Leone'))
  ensure
    Current.reset
  end
end
