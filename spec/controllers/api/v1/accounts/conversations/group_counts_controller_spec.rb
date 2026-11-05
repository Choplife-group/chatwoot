require 'rails_helper'

RSpec.describe 'Conversation group counts API', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:uganda) { create(:market, account: account, code: 'UG') }
  let(:team) { create(:team, account: account) }
  let(:agent_inbox) { create(:inbox, account: account, market: uganda) }
  let(:other_inbox) { create(:inbox, account: account, market: uganda) }

  before do
    create(:inbox_member, user: agent, inbox: agent_inbox)
    create(:conversation, account: account, inbox: agent_inbox, team: team)
    create(:conversation, account: account, inbox: agent_inbox, team: team).update!(waiting_since: nil)
    create(:conversation, account: account, inbox: agent_inbox, status: :resolved)
    create(:conversation, account: account, inbox: other_inbox)
  end

  def group_counts(user, group_by)
    get "/api/v1/accounts/#{account.id}/conversations/group_counts?group_by=#{group_by}", headers: user.create_new_auth_token
    response.parsed_body['payload']
  end

  it 'counts open and waiting conversations per market' do
    expect(group_counts(admin, 'market')).to eq([{ 'id' => uganda.id, 'open_count' => 3, 'waiting_count' => 2 }])
    expect(response).to conform_schema(200)
  end

  it 'counts open and waiting conversations per team' do
    expect(group_counts(admin, 'team')).to eq([{ 'id' => team.id, 'open_count' => 2, 'waiting_count' => 1 }])
  end

  it 'only counts conversations the agent can see' do
    expect(group_counts(agent, 'market')).to eq([{ 'id' => uganda.id, 'open_count' => 2, 'waiting_count' => 1 }])
  end

  it 'rejects other groupings' do
    group_counts(admin, 'inbox')

    expect(response).to have_http_status(:unprocessable_entity)
  end
end
