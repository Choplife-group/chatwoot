require 'rails_helper'

RSpec.describe 'Saved reports API', type: :request do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:other_agent) { create(:user, account: account, role: :agent) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:base_url) { "/api/v2/accounts/#{account.id}/saved_reports" }
  let(:config) { { metrics: %w[received resolved], group_by: %w[market team category], period: 'last_month', compare: 'previous_period' } }

  before { account.enable_features!('insights') }

  it 'saves a report with its named period and no dates' do
    post base_url, params: { saved_report: { name: 'Monthly by market', config: config } }, headers: agent.create_new_auth_token, as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body).to include('name' => 'Monthly by market', 'shared' => false, 'owner_name' => agent.name)
    expect(response.parsed_body['config']).to include('period' => 'last_month', 'compare' => 'previous_period',
                                                      'group_by' => %w[market team category])
    expect(response.parsed_body['config']).not_to have_key('since')
  end

  it 'rejects an invalid report' do
    post base_url, params: { saved_report: { name: 'Bad', config: config.merge(metrics: %w[happiness]) } }, headers: agent.create_new_auth_token,
                   as: :json

    expect(response).to have_http_status(:unprocessable_entity)
  end

  it 'lists your own reports and shared ones, not other people\'s private ones' do
    own = account.saved_reports.create!(user: agent, name: 'Mine', config: config)
    shared = account.saved_reports.create!(user: admin, name: 'Team', config: config, shared: true)
    account.saved_reports.create!(user: other_agent, name: 'Theirs', config: config)

    get base_url, headers: agent.create_new_auth_token, as: :json

    expect(response.parsed_body.pluck('id')).to contain_exactly(own.id, shared.id)
  end

  it 'stops an agent sharing a report, opening someone else\'s private one or changing a shared one' do
    theirs = account.saved_reports.create!(user: other_agent, name: 'Theirs', config: config)
    shared = account.saved_reports.create!(user: admin, name: 'Team', config: config, shared: true)

    post base_url, params: { saved_report: { name: 'Mine', config: config, shared: true } }, headers: agent.create_new_auth_token, as: :json
    expect(response).to have_http_status(:unauthorized)

    get "#{base_url}/#{theirs.id}", headers: agent.create_new_auth_token, as: :json
    expect(response).to have_http_status(:unauthorized)

    patch "#{base_url}/#{shared.id}", params: { saved_report: { name: 'Renamed' } }, headers: agent.create_new_auth_token, as: :json
    expect(response).to have_http_status(:unauthorized)
  end

  it 'lets an administrator share and delete a report' do
    report = account.saved_reports.create!(user: admin, name: 'Team', config: config)

    patch "#{base_url}/#{report.id}", params: { saved_report: { shared: true } }, headers: admin.create_new_auth_token, as: :json
    expect(report.reload.shared).to be(true)

    delete "#{base_url}/#{report.id}", headers: admin.create_new_auth_token, as: :json
    expect(SavedReport.exists?(report.id)).to be(false)
  end
end
