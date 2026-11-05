require 'rails_helper'

RSpec.describe CategoryHandler do
  let(:account) { create(:account) }
  let(:conversation) { create(:conversation, account: account) }
  let(:withdrawal) { create(:conversation_category, account: account, name: 'Withdrawal') }
  let(:pending_approval) { create(:conversation_category, account: account, name: 'Pending approval', parent: withdrawal) }

  it 'accepts a category at the last level of its branch' do
    conversation.update!(category: pending_approval)

    expect(conversation).to be_categorised
  end

  it 'rejects a category that has subcategories' do
    pending_approval

    expect(conversation.update(category: withdrawal)).to be false
    expect(conversation.errors[:category]).to be_present
  end

  it 'rejects archived categories and categories of another account' do
    expect(conversation.update(category: create(:conversation_category, account: account, archived_at: Time.current))).to be false
    expect(conversation.update(category: create(:conversation_category))).to be false
  end

  it 'adds an activity message when a person sets the category' do
    Current.user = create(:user, account: account, name: 'Jane')

    expect { conversation.update!(category: pending_approval) }
      .to have_enqueued_job(Conversations::ActivityMessageJob)
      .with(conversation, hash_including(content: 'Jane set the category to Withdrawal › Pending approval'))
  ensure
    Current.reset
  end
end
