require 'rails_helper'

RSpec.describe Macros::ExecutionService do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent, name: 'Jane') }
  let(:conversation) { create(:conversation, account: account) }

  before { create(:inbox_member, user: agent, inbox: conversation.inbox) }

  %w[resolve_conversation change_status].each do |action_name|
    it "skips #{action_name} on an uncategorised conversation and leaves a note" do
      action_params = action_name == 'change_status' ? ['resolved'] : []
      macro = create(:macro, account: account, created_by: agent, updated_by: agent,
                             actions: [{ action_name: action_name, action_params: action_params }])

      expect { described_class.new(macro, conversation, agent).perform }
        .to have_enqueued_job(Conversations::ActivityMessageJob)
        .with(conversation, hash_including(content: 'Not resolved by Jane: choose a category and subcategory first'))
      expect(conversation.reload).to be_open
    end
  end
end
