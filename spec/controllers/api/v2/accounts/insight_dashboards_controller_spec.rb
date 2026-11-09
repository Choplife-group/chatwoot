require 'rails_helper'

RSpec.describe 'Insight dashboards API', type: :request do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:role) { create(:support_role, account: account, permissions: ['vip_manage']) }
  let(:base_url) { "/api/v2/accounts/#{account.id}/insight_dashboards" }
  let(:widget) do
    { id: 'w1', title: 'Received', display: 'number', metric: 'received',
      config: { metrics: %w[received resolved], group_by: %w[market], period: 'last_7_days' } }
  end

  before { account.enable_features!('insights') }

  it 'lets an agent make a private dashboard, keeping each widget\'s period as a name' do
    post base_url, params: { insight_dashboard: { name: 'Mine', widgets: [widget], filters: { period: 'today', team_ids: [] } } },
                   headers: agent.create_new_auth_token, as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body).to include('name' => 'Mine', 'audience' => 'private', 'refresh_seconds' => 60, 'filters' => { 'period' => 'today' })
    expect(response.parsed_body['widgets'].first['config']).to include('period' => 'last_7_days', 'metrics' => %w[received resolved])
    expect(response.parsed_body['widgets'].first['config']).not_to have_key('since')
  end

  it 'rejects a widget whose metric is not in its report, and a dashboard period that does not exist' do
    [{ name: 'Bad', widgets: [widget.merge(metric: 'open')] }, { name: 'Bad', filters: { period: 'last_decade' } }].each do |attributes|
      post base_url, params: { insight_dashboard: attributes }, headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  it 'stops an agent sharing a dashboard' do
    post base_url, params: { insight_dashboard: { name: 'Team', audience: 'everyone' } }, headers: agent.create_new_auth_token, as: :json

    expect(response).to have_http_status(:unauthorized)
  end

  it 'shows each person their own dashboards, the ones for everyone and the ones for their role' do
    own = account.insight_dashboards.create!(user: agent, name: 'Mine')
    everyone = account.insight_dashboards.create!(user: admin, name: 'Everyone', audience: :everyone)
    for_role = account.insight_dashboards.create!(user: admin, name: 'Role', audience: :role, custom_role_id: role.id)
    private_to_admin = account.insight_dashboards.create!(user: admin, name: 'Admin only')

    get base_url, headers: agent.create_new_auth_token, as: :json
    expect(response.parsed_body.pluck('id')).to contain_exactly(own.id, everyone.id)

    account.enable_features!('support_roles')
    agent.account_users.first.update!(custom_role_id: role.id)
    get base_url, headers: agent.create_new_auth_token, as: :json
    expect(response.parsed_body.pluck('id')).to contain_exactly(own.id, everyone.id, for_role.id)

    get "#{base_url}/#{private_to_admin.id}", headers: agent.create_new_auth_token, as: :json
    expect(response).to have_http_status(:not_found)
  end

  it 'hides a role dashboard from people without a role once its role is deleted' do
    dashboard = account.insight_dashboards.create!(user: admin, name: 'Role', audience: :role, custom_role_id: role.id)
    role.destroy!

    get base_url, headers: agent.create_new_auth_token, as: :json

    expect(response.parsed_body.pluck('id')).not_to include(dashboard.id)
  end

  it 'lets the owner of a shared dashboard change its widgets but not who sees it, once they can no longer view all reports' do
    shared = account.insight_dashboards.create!(user: agent, name: 'Everyone', audience: :everyone)

    patch "#{base_url}/#{shared.id}", params: { insight_dashboard: { widgets: [widget] } }, headers: agent.create_new_auth_token, as: :json
    expect(response).to have_http_status(:success)

    patch "#{base_url}/#{shared.id}", params: { insight_dashboard: { audience: 'role', custom_role_id: role.id } },
                                      headers: agent.create_new_auth_token, as: :json
    expect(response).to have_http_status(:unauthorized)
  end

  it 'lets only the owner or a manager change a dashboard' do
    shared = account.insight_dashboards.create!(user: admin, name: 'Everyone', audience: :everyone)

    patch "#{base_url}/#{shared.id}", params: { insight_dashboard: { name: 'Mine now' } }, headers: agent.create_new_auth_token, as: :json
    expect(response).to have_http_status(:unauthorized)

    patch "#{base_url}/#{shared.id}", params: { insight_dashboard: { refresh_seconds: 300, widgets: [widget] } },
                                      headers: admin.create_new_auth_token, as: :json
    expect(shared.reload).to have_attributes(refresh_seconds: 300, widgets: [include('id' => 'w1')])
  end
end
