require 'rails_helper'

# Each permission opens its own area and nothing else
RSpec.describe 'Support role permissions', type: :request do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account, role: :agent) }
  let(:base) { "/api/v1/accounts/#{account.id}" }
  let(:headers) { user.create_new_auth_token }

  def give(*permissions)
    role = create(:support_role, account: account, permissions: permissions)
    user.account_users.first.update!(custom_role_id: role.id)
  end

  before { account.enable_features!('support_roles') }

  describe 'market_manage' do
    let(:market) { create(:market, account: account) }

    it 'opens markets' do
      give('market_manage')

      post "#{base}/markets", params: { market: { name: 'Namibia', code: 'NA' } }, headers: headers, as: :json
      expect(response).to have_http_status(:success)

      patch "#{base}/markets/#{market.id}", params: { market: { name: 'Renamed' } }, headers: headers, as: :json
      expect(market.reload.name).to eq('Renamed')
    end

    it 'stays closed without it' do
      give('category_manage')

      post "#{base}/markets", params: { market: { name: 'Namibia', code: 'NA' } }, headers: headers, as: :json

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'category_manage' do
    it 'opens conversation categories' do
      give('category_manage')

      post "#{base}/conversation_categories", params: { conversation_category: { name: 'Bonus' } }, headers: headers, as: :json

      expect(response).to have_http_status(:success)
    end

    it 'stays closed without it' do
      give('market_manage')

      post "#{base}/conversation_categories", params: { conversation_category: { name: 'Bonus' } }, headers: headers, as: :json

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'team_manage' do
    let(:team) { create(:team, account: account) }
    let(:member) { create(:user, account: account, role: :agent) }

    it 'opens teams, members and leads' do
      give('team_manage')

      post "#{base}/teams", params: { team: { name: 'namibia' } }, headers: headers, as: :json
      expect(response).to have_http_status(:success)

      patch "#{base}/teams/#{team.id}/team_members", params: { user_ids: [member.id], lead_ids: [member.id] }, headers: headers, as: :json
      expect(team.team_members.leads.pluck(:user_id)).to eq([member.id])
    end

    it 'stays closed without it' do
      give('market_manage')

      post "#{base}/teams", params: { team: { name: 'namibia' } }, headers: headers, as: :json
      expect(response).to have_http_status(:unauthorized)

      patch "#{base}/teams/#{team.id}/team_members", params: { user_ids: [user.id], lead_ids: [user.id] }, headers: headers, as: :json
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'report_manage' do
    let(:summary_url) { "/api/v2/accounts/#{account.id}/summary_reports/agent" }
    let(:range) { { since: 1.week.ago.to_i.to_s, until: Time.current.to_i.to_s } }

    it 'opens reports and CSAT' do
      give('report_manage')

      get summary_url, params: range, headers: headers
      expect(response).to have_http_status(:success)

      get "#{base}/csat_survey_responses", headers: headers
      expect(response).to have_http_status(:success)
    end

    it 'stays closed without it' do
      give('market_manage')

      get summary_url, params: range, headers: headers
      expect(response).to have_http_status(:unauthorized)

      get "#{base}/csat_survey_responses", headers: headers
      expect(response).to have_http_status(:unauthorized)
    end
  end

  it 'gives nothing when support_roles is off' do
    give('market_manage')
    account.disable_features!('support_roles')

    post "#{base}/markets", params: { market: { name: 'Namibia', code: 'NA' } }, headers: headers, as: :json

    expect(response).to have_http_status(:unauthorized)
  end

  it 'leaves everything else closed for the full role' do
    give(*SupportRole::PERMISSIONS)

    post "#{base}/inboxes", params: { name: 'New' }, headers: headers, as: :json
    expect(response).to have_http_status(:unauthorized)

    post "#{base}/automation_rules", params: { name: 'Rule' }, headers: headers, as: :json
    expect(response).to have_http_status(:unauthorized)

    post "#{base}/webhooks", params: { webhook: { url: 'https://example.com' } }, headers: headers, as: :json
    expect(response).to have_http_status(:unauthorized)

    patch base, params: { name: 'Mine' }, headers: headers, as: :json
    expect(response).to have_http_status(:unauthorized)
  end
end
