require 'rails_helper'

RSpec.describe Conversations::ResolveGuard do
  let(:account) { create(:account) }
  let(:conversation) { create(:conversation, account: account) }

  it 'blocks a person resolving an uncategorised conversation' do
    expect(described_class.blocked?(conversation, create(:user, account: account))).to be true
  end

  it 'does not block bots' do
    expect(described_class.blocked?(conversation, create(:agent_bot, account: account))).to be false
  end

  it 'does not block categorised conversations' do
    conversation.update!(category: create(:conversation_category, account: account))

    expect(described_class.blocked?(conversation, create(:user, account: account))).to be false
  end

  it 'lets the system auto-resolve uncategorised conversations' do
    account.update!(auto_resolve_after: 10)
    conversation.update!(last_activity_at: 1.day.ago)

    Conversations::ResolutionJob.perform_now(account: account)

    expect(conversation.reload).to be_resolved
  end
end
