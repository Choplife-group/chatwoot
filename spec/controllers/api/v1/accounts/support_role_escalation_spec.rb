require 'rails_helper'

# Attempts to gain or hand out access, sent straight to the API as a dashboard user could
RSpec.describe 'Support role escalation', type: :request do
  let(:account) { create(:account) }
  let(:base) { "/api/v1/accounts/#{account.id}" }
  let(:own_role) { create(:support_role, account: account, name: 'Head', permissions: %w[agent_manage role_manage team_manage report_manage]) }
  let(:smaller_role) { create(:support_role, account: account, permissions: ['report_manage']) }
  let(:bigger_role) { create(:support_role, account: account, permissions: %w[report_manage vip_manage]) }
  let(:head) { create(:user, account: account, role: :agent) }
  let(:head_account_user) { head.account_users.first }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:agent_account_user) { agent.account_users.first }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:headers) { head.create_new_auth_token }

  before do
    account.enable_features!('support_roles')
    head_account_user.update!(custom_role_id: own_role.id)
  end

  describe 'agents' do
    it 'adds, edits and removes an agent within their reach' do
      post "#{base}/agents", params: { agent: { name: 'New', email: 'reach@example.com', custom_role_id: smaller_role.id } },
                             headers: headers, as: :json
      expect(response).to have_http_status(:success)

      patch "#{base}/agents/#{agent.id}", params: { agent: { name: 'Renamed', custom_role_id: smaller_role.id } }, headers: headers, as: :json
      expect(agent_account_user.reload.custom_role_id).to eq(smaller_role.id)

      delete "#{base}/agents/#{agent.id}", headers: headers, as: :json
      expect(response).to have_http_status(:success)
    end

    [['administrator'], [1], ['1']].each do |(role)|
      it "refuses to create an administrator with role #{role.inspect}" do
        post "#{base}/agents", params: { agent: { name: 'New', email: 'admin@example.com', role: role } }, headers: headers, as: :json

        expect(response).to have_http_status(:unauthorized)
        expect(User.from_email('admin@example.com')).to be_nil
      end

      it "refuses to promote an agent with role #{role.inspect}" do
        patch "#{base}/agents/#{agent.id}", params: { agent: { role: role } }, headers: headers, as: :json

        expect(response).to have_http_status(:unauthorized)
        expect(agent_account_user.reload).to be_agent
      end
    end

    it 'refuses to give a role with a permission they lack' do
      patch "#{base}/agents/#{agent.id}", params: { agent: { custom_role_id: bigger_role.id } }, headers: headers, as: :json

      expect(response).to have_http_status(:unauthorized)
      expect(agent_account_user.reload.custom_role_id).to be_nil
    end

    it 'refuses to add an agent with such a role' do
      post "#{base}/agents", params: { agent: { name: 'New', email: 'big@example.com', custom_role_id: bigger_role.id } }, headers: headers, as: :json

      expect(response).to have_http_status(:unauthorized)
    end

    it 'refuses to edit or remove an administrator' do
      patch "#{base}/agents/#{admin.id}", params: { agent: { name: 'Taken' } }, headers: headers, as: :json
      expect(response).to have_http_status(:unauthorized)

      delete "#{base}/agents/#{admin.id}", headers: headers, as: :json
      expect(response).to have_http_status(:unauthorized)
      expect(admin.reload.name).not_to eq('Taken')
    end

    it 'refuses to edit or remove someone with more access' do
      agent_account_user.update!(custom_role_id: bigger_role.id)

      patch "#{base}/agents/#{agent.id}", params: { agent: { custom_role_id: nil } }, headers: headers, as: :json
      expect(response).to have_http_status(:unauthorized)

      delete "#{base}/agents/#{agent.id}", headers: headers, as: :json
      expect(response).to have_http_status(:unauthorized)
    end

    it 'refuses to change their own role' do
      patch "#{base}/agents/#{head.id}", params: { agent: { custom_role_id: smaller_role.id } }, headers: headers, as: :json
      expect(response).to have_http_status(:unauthorized)

      patch "#{base}/agents/#{head.id}", params: { agent: { role: 'administrator' } }, headers: headers, as: :json
      expect(response).to have_http_status(:unauthorized)
      expect(head_account_user.reload).to have_attributes(role: 'agent', custom_role_id: own_role.id)
    end

    it 'refuses an agent without agent_manage' do
      post "#{base}/agents", params: { agent: { name: 'New', email: 'no@example.com' } }, headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'roles' do
    it 'creates and edits a role within their permissions' do
      post "#{base}/custom_roles", params: { name: 'Reports', permissions: ['report_manage'] }, headers: headers, as: :json
      expect(response).to have_http_status(:success)

      patch "#{base}/custom_roles/#{smaller_role.id}", params: { permissions: %w[report_manage team_manage] }, headers: headers, as: :json
      expect(smaller_role.reload.permissions).to eq(%w[report_manage team_manage])
    end

    it 'refuses a permission they lack, on create and update' do
      post "#{base}/custom_roles", params: { name: 'Bigger', permissions: ['vip_manage'] }, headers: headers, as: :json
      expect(response).to have_http_status(:unauthorized)

      patch "#{base}/custom_roles/#{smaller_role.id}", params: { permissions: ['vip_manage'] }, headers: headers, as: :json
      expect(response).to have_http_status(:unauthorized)
      expect(smaller_role.reload.permissions).to eq(['report_manage'])
    end

    it 'refuses to edit or delete their own role' do
      patch "#{base}/custom_roles/#{own_role.id}", params: { name: 'Mine' }, headers: headers, as: :json
      expect(response).to have_http_status(:unauthorized)

      delete "#{base}/custom_roles/#{own_role.id}", headers: headers, as: :json
      expect(response).to have_http_status(:unauthorized)
      expect(own_role.reload.name).to eq('Head')
    end

    it 'refuses to edit or delete a role with more access' do
      patch "#{base}/custom_roles/#{bigger_role.id}", params: { name: 'Taken' }, headers: headers, as: :json
      expect(response).to have_http_status(:unauthorized)

      delete "#{base}/custom_roles/#{bigger_role.id}", headers: headers, as: :json
      expect(response).to have_http_status(:unauthorized)
    end

    it 'lets agent_manage alone list roles but not change them' do
      helper_user = create(:user, account: account, role: :agent)
      helper_user.account_users.first.update!(custom_role_id: create(:support_role, account: account, permissions: ['agent_manage']).id)
      helper_headers = helper_user.create_new_auth_token

      get "#{base}/custom_roles", headers: helper_headers, as: :json
      expect(response).to have_http_status(:success)

      post "#{base}/custom_roles", params: { name: 'Nope', permissions: ['agent_manage'] }, headers: helper_headers, as: :json
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'team leads' do
    let(:team) { create(:team, account: account) }

    it 'refuses to make themselves a lead' do
      create(:team_member, team: team, user: head)

      patch "#{base}/teams/#{team.id}/team_members", params: { user_ids: [head.id], lead_ids: [head.id] }, headers: headers, as: :json

      expect(response).to have_http_status(:unauthorized)
      expect(team.team_members.leads).to be_empty
    end

    it 'lets them make someone else a lead' do
      patch "#{base}/teams/#{team.id}/team_members", params: { user_ids: [agent.id], lead_ids: [agent.id] }, headers: headers, as: :json

      expect(team.team_members.leads.pluck(:user_id)).to eq([agent.id])
    end
  end
end
