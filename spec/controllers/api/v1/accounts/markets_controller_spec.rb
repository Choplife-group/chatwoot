require 'rails_helper'

RSpec.describe 'Markets API', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let!(:market) { create(:market, account: account, name: 'Uganda', code: 'UG') }

  describe 'GET /api/v1/accounts/{account.id}/markets' do
    it 'returns unauthorized for an unauthenticated user' do
      get "/api/v1/accounts/#{account.id}/markets"

      expect(response).to have_http_status(:unauthorized)
    end

    it 'lists the markets for an agent' do
      get "/api/v1/accounts/#{account.id}/markets", headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(response).to conform_schema(200)
      expect(response.parsed_body).to eq([{ 'id' => market.id, 'name' => 'Uganda', 'code' => 'UG', 'position' => 0, 'archived' => false }])
    end
  end

  describe 'POST /api/v1/accounts/{account.id}/markets' do
    let(:params) { { market: { name: 'Sierra Leone', code: 'sl' } } }

    it 'returns unauthorized for an agent' do
      post "/api/v1/accounts/#{account.id}/markets", params: params, headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:unauthorized)
    end

    it 'creates the market for an admin' do
      post "/api/v1/accounts/#{account.id}/markets", params: params, headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body).to include('name' => 'Sierra Leone', 'code' => 'SL')
    end

    it 'rejects a duplicate code' do
      post "/api/v1/accounts/#{account.id}/markets", params: { market: { name: 'Other', code: 'UG' } }, headers: admin.create_new_auth_token,
                                                     as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe 'PATCH /api/v1/accounts/{account.id}/markets/{id}' do
    it 'renames and restores a market' do
      market.update!(archived_at: Time.current)

      patch "/api/v1/accounts/#{account.id}/markets/#{market.id}", params: { market: { name: 'Uganda (new)', archived: false } },
                                                                   headers: admin.create_new_auth_token, as: :json

      expect(response.parsed_body).to include('name' => 'Uganda (new)', 'archived' => false)
    end
  end

  describe 'DELETE /api/v1/accounts/{account.id}/markets/{id}' do
    it 'archives the market instead of deleting it' do
      delete "/api/v1/accounts/#{account.id}/markets/#{market.id}", headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(market.reload.archived_at).to be_present
    end
  end
end
