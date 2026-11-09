require 'rails_helper'

RSpec.describe 'SLA targets API', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:market) { create(:market, account: account) }
  let(:base_url) { "/api/v1/accounts/#{account.id}/sla_targets" }
  let(:params) { { sla_target: { market_id: market.id, priority: 'high', first_response_seconds: 300, resolution_seconds: 7200 } } }

  it 'lists targets for an agent' do
    target = account.sla_targets.create!(first_response_seconds: 600)

    get base_url, headers: agent.create_new_auth_token, as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body).to eq([{ 'id' => target.id, 'market_id' => nil, 'priority' => nil, 'first_response_seconds' => 600,
                                          'resolution_seconds' => nil, 'business_hours' => false }])
  end

  it 'stops an agent without sla_manage from creating a target' do
    post base_url, params: params, headers: agent.create_new_auth_token, as: :json

    expect(response).to have_http_status(:unauthorized)
  end

  it 'lets a role with sla_manage create a target' do
    account.enable_features!('support_roles')
    agent.account_users.first.update!(custom_role_id: create(:support_role, account: account, permissions: ['sla_manage']).id)

    post base_url, params: params, headers: agent.create_new_auth_token, as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body).to include('market_id' => market.id, 'priority' => 'high', 'first_response_seconds' => 300)
  end

  it 'rejects a second target for the same market and priority' do
    account.sla_targets.create!(market: market, priority: :high, first_response_seconds: 60)

    post base_url, params: params, headers: admin.create_new_auth_token, as: :json

    expect(response).to have_http_status(:unprocessable_entity)
  end

  it 'rejects a target with no times, an unknown priority or another account\'s market' do
    other_market = create(:market, account: create(:account))
    [{ market_id: market.id }, { priority: 'critical', first_response_seconds: 60 },
     { market_id: other_market.id, first_response_seconds: 60 }].each do |body|
      post base_url, params: { sla_target: body }, headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  it 'updates and deletes a target' do
    target = account.sla_targets.create!(first_response_seconds: 600)

    patch "#{base_url}/#{target.id}", params: { sla_target: { resolution_seconds: 3600 } }, headers: admin.create_new_auth_token, as: :json
    expect(target.reload.resolution_seconds).to eq(3600)

    delete "#{base_url}/#{target.id}", headers: admin.create_new_auth_token, as: :json
    expect(SlaTarget.exists?(target.id)).to be(false)
  end
end
