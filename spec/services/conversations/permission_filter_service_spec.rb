require 'rails_helper'

RSpec.describe Conversations::PermissionFilterService do
  let(:account) { create(:account) }
  let!(:conversation) { create(:conversation, account: account, inbox: inbox) }
  let!(:another_conversation) { create(:conversation, account: account, inbox: inbox) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let!(:inbox) { create(:inbox, account: account) }

  # This inbox_member is used to establish the agent's access to the inbox
  before { create(:inbox_member, user: agent, inbox: inbox) }

  describe '#perform' do
    context 'when user is an administrator' do
      it 'returns all conversations' do
        result = described_class.new(
          account.conversations,
          admin,
          account
        ).perform

        expect(result).to include(conversation)
        expect(result).to include(another_conversation)
        expect(result.count).to eq(2)
      end
    end

    context 'when user is an agent' do
      it 'returns all conversations with no further filtering' do
        inbox_ids = agent.inboxes.where(account_id: account.id).pluck(:id)

        # The base implementation returns all conversations
        # expecting the caller to filter by assigned inboxes
        result = described_class.new(
          account.conversations.where(inbox_id: inbox_ids),
          agent,
          account
        ).perform

        expect(result).to include(conversation)
        expect(result).to include(another_conversation)
        expect(result.count).to eq(2)
      end
    end

    context 'when plan_hint_selective_filter is enabled' do
      let!(:other_inbox) { create(:inbox, account: account) }
      let!(:inaccessible_conversation) { create(:conversation, account: account, inbox: other_inbox) }

      it 'returns the same conversations as the default scoping for an agent' do
        default_result = described_class.new(account.conversations, agent, account).perform
        hinted_result = described_class.new(account.conversations, agent, account, plan_hint_selective_filter: true).perform

        expect(hinted_result.to_a).to match_array(default_result.to_a)
        expect(hinted_result).not_to include(inaccessible_conversation)
      end

      it 'keeps the planner hint in the generated query' do
        hinted_result = described_class.new(account.conversations, agent, account, plan_hint_selective_filter: true).perform

        expect(hinted_result.to_sql).to include('conversations.inbox_id + 0')
      end

      it 'does not change administrator scoping' do
        result = described_class.new(account.conversations, admin, account, plan_hint_selective_filter: true).perform

        expect(result.to_sql).not_to include('inbox_id + 0')
        expect(result).to include(inaccessible_conversation)
      end
    end

    context 'when restricted_inbox_access is enabled' do
      let(:team) { create(:team, account: account) }
      let(:other_team) { create(:team, account: account) }
      let!(:assigned) { create(:conversation, account: account, inbox: inbox, assignee: agent) }
      let!(:team_queue) { create(:conversation, account: account, inbox: inbox, team: team) }
      let!(:other_team_queue) { create(:conversation, account: account, inbox: inbox, team: other_team) }

      def visible_to(user)
        described_class.new(account.conversations, user, account).perform
      end

      before { account.enable_features!('restricted_inbox_access') }

      it 'shows an agent only their assigned conversations, even as an inbox and team member' do
        create(:team_member, team: team, user: agent)

        expect(visible_to(agent)).to contain_exactly(assigned)
      end

      it 'shows a team lead their team and their own conversations, not other teams' do
        create(:team_member, team: team, user: agent, lead: true)

        expect(visible_to(agent)).to contain_exactly(assigned, team_queue)
        expect(visible_to(agent)).not_to include(other_team_queue)
      end

      it 'does not need inbox membership for a team lead' do
        lead = create(:user, account: account, role: :agent)
        create(:team_member, team: team, user: lead, lead: true)

        expect(visible_to(lead)).to contain_exactly(team_queue)
      end

      it 'ignores a lead flag from another account' do
        foreign_team = create(:team)
        create(:team_member, team: foreign_team, user: agent, lead: true)
        create(:conversation, account: account, inbox: inbox, team_id: foreign_team.id)

        expect(visible_to(agent)).to contain_exactly(assigned)
      end

      it 'shows an administrator everything' do
        expect(visible_to(admin)).to include(assigned, team_queue, other_team_queue, conversation)
      end

      it 'keeps the existing behaviour when the feature is off' do
        account.disable_features!('restricted_inbox_access')

        expect(visible_to(agent)).to include(conversation, team_queue, other_team_queue)
      end
    end
  end
end
