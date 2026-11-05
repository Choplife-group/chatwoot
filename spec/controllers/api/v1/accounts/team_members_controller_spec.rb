require 'rails_helper'

RSpec.describe 'Team Members API', type: :request do
  let(:account) { create(:account) }
  let(:account_2) { create(:account) }
  let!(:team) { create(:team, account: account) }

  describe 'GET /api/v1/accounts/{account.id}/teams/{team_id}/team_members' do
    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        get "/api/v1/accounts/#{account.id}/teams/#{team.id}/team_members"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated user' do
      let(:agent) { create(:user, account: account, role: :agent) }

      it 'returns all the teams' do
        create(:team_member, team: team, user: agent)
        get "/api/v1/accounts/#{account.id}/teams/#{team.id}/team_members",
            headers: agent.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:success)
        expect(response.parsed_body.first['id']).to eq(agent.id)
      end
    end
  end

  describe 'POST /api/v1/accounts/{account.id}/teams/{team_id}/team_members' do
    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        post "/api/v1/accounts/#{account.id}/teams/#{team.id}/team_members"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated user' do
      let(:agent) { create(:user, account: account, role: :agent) }
      let(:administrator) { create(:user, account: account, role: :administrator) }

      it 'returns unathorized for agent' do
        params = { user_id: agent.id }

        post "/api/v1/accounts/#{account.id}/teams/#{team.id}/team_members",
             params: params,
             headers: agent.create_new_auth_token,
             as: :json

        expect(response).to have_http_status(:unauthorized)
      end

      it 'add a new team members when its administrator' do
        user_ids = (1..5).map { create(:user, account: account, role: :agent).id }
        params = { user_ids: user_ids }
        # have a team member added already
        create(:team_member, team: team, user: User.find(user_ids.first))

        post "/api/v1/accounts/#{account.id}/teams/#{team.id}/team_members",
             params: params,
             headers: administrator.create_new_auth_token,
             as: :json

        expect(response).to have_http_status(:success)
        json_response = response.parsed_body
        expect(json_response.count).to eq(user_ids.count - 1)
      end
    end
  end

  describe 'DELETE /api/v1/accounts/{account.id}/teams/{team_id}/team_members' do
    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        delete "/api/v1/accounts/#{account.id}/teams/#{team.id}/team_members"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated user' do
      let(:agent) { create(:user, account: account, role: :agent) }
      let(:administrator) { create(:user, account: account, role: :administrator) }

      it 'return unauthorized for agent' do
        params = { user_id: agent.id }
        delete "/api/v1/accounts/#{account.id}/teams/#{team.id}/team_members",
               params: params,
               headers: agent.create_new_auth_token,
               as: :json

        expect(response).to have_http_status(:unauthorized)
      end

      it 'destroys the team members when its administrator' do
        user_ids = (1..5).map { create(:user, account: account, role: :agent).id }
        user_ids.each { |id| create(:team_member, team: team, user: User.find(id)) }
        params = { user_ids: user_ids.first(3) }

        delete "/api/v1/accounts/#{account.id}/teams/#{team.id}/team_members",
               params: params,
               headers: administrator.create_new_auth_token,
               as: :json

        expect(response).to have_http_status(:success)
        expect(team.team_members.count).to eq(2)
      end
    end
  end

  describe 'PATCH /api/v1/accounts/{account.id}/teams/{team_id}/team_members' do
    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        patch "/api/v1/accounts/#{account.id}/teams/#{team.id}/team_members"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated user' do
      let(:agent) { create(:user, account: account, role: :agent) }
      let(:agent_2) { create(:user, account: account_2, role: :agent) }
      let(:administrator) { create(:user, account: account, role: :administrator) }

      it 'return unauthorized for agent' do
        params = { user_id: agent.id }
        patch "/api/v1/accounts/#{account.id}/teams/#{team.id}/team_members",
              params: params,
              headers: agent.create_new_auth_token,
              as: :json

        expect(response).to have_http_status(:unauthorized)
      end

      it 'updates the team members when its administrator' do
        user_ids = (1..5).map { create(:user, account: account, role: :agent).id }
        params = { user_ids: user_ids }

        patch "/api/v1/accounts/#{account.id}/teams/#{team.id}/team_members",
              params: params,
              headers: administrator.create_new_auth_token,
              as: :json

        expect(response).to have_http_status(:success)
        json_response = response.parsed_body
        expect(json_response.count).to eq(user_ids.count)
      end

      it 'ignores the user ids when its not a valid account user id' do
        params = { user_ids: [agent_2.id] }

        patch "/api/v1/accounts/#{account.id}/teams/#{team.id}/team_members",
              params: params,
              headers: administrator.create_new_auth_token,
              as: :json

        expect(response).to have_http_status(:unauthorized)
        json_response = response.parsed_body
        expect(json_response['error']).to eq('Invalid User IDs')
      end

      it 'sets the team leads when lead_ids is passed' do
        member = create(:user, account: account, role: :agent)
        lead = create(:user, account: account, role: :agent)
        create(:team_member, team: team, user: member, lead: true)

        patch "/api/v1/accounts/#{account.id}/teams/#{team.id}/team_members",
              params: { user_ids: [member.id, lead.id], lead_ids: [lead.id] },
              headers: administrator.create_new_auth_token,
              as: :json

        expect(response).to have_http_status(:success)
        expect(team.team_members.leads.pluck(:user_id)).to eq([lead.id])
        expect(response.parsed_body.to_h { |agent| [agent['id'], agent['lead']] }).to eq(member.id => false, lead.id => true)
      end

      it 'keeps the current leads when lead_ids is not passed' do
        lead = create(:user, account: account, role: :agent)
        create(:team_member, team: team, user: lead, lead: true)

        patch "/api/v1/accounts/#{account.id}/teams/#{team.id}/team_members",
              params: { user_ids: [lead.id] },
              headers: administrator.create_new_auth_token,
              as: :json

        expect(team.team_members.leads.pluck(:user_id)).to eq([lead.id])
      end

      it 'rejects a lead who is not a team member' do
        member = create(:user, account: account, role: :agent)
        outsider = create(:user, account: account, role: :agent)

        patch "/api/v1/accounts/#{account.id}/teams/#{team.id}/team_members",
              params: { user_ids: [member.id], lead_ids: [outsider.id] },
              headers: administrator.create_new_auth_token,
              as: :json

        expect(response).to have_http_status(:unprocessable_entity)
        expect(team.team_members.count).to eq(0)
      end

      it 'does not let an agent set team leads' do
        agent = create(:user, account: account, role: :agent)
        create(:team_member, team: team, user: agent)

        patch "/api/v1/accounts/#{account.id}/teams/#{team.id}/team_members",
              params: { user_ids: [agent.id], lead_ids: [agent.id] },
              headers: agent.create_new_auth_token,
              as: :json

        expect(response).to have_http_status(:unauthorized)
        expect(team.team_members.leads).to be_empty
      end
    end
  end
end
