require 'rails_helper'

RSpec.describe 'Custom roles API', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:url) { "/api/v1/accounts/#{account.id}/custom_roles" }
  let!(:role) { create(:support_role, account: account, name: 'Head of Support') }

  context 'when the feature is enabled' do
    before { account.enable_features!('support_roles') }

    it 'lists the account\'s roles for an administrator' do
      create(:support_role)

      get url, headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body.pluck('id')).to eq([role.id])
    end

    it 'creates a role from the dashboard\'s payload' do
      post url, params: { name: 'QA reviewer', description: 'Reads', permissions: %w[conversation_manage report_manage] },
                headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body).to include('name' => 'QA reviewer', 'permissions' => %w[conversation_manage report_manage])
    end

    it 'rejects an unknown permission' do
      post url, params: { name: 'Bad', permissions: ['do_anything'] }, headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'updates and deletes a role' do
      patch "#{url}/#{role.id}", params: { permissions: ['report_manage'] }, headers: admin.create_new_auth_token, as: :json
      expect(role.reload.permissions).to eq(['report_manage'])

      delete "#{url}/#{role.id}", headers: admin.create_new_auth_token, as: :json
      expect(SupportRole.exists?(role.id)).to be(false)
    end

    it 'does not reach another account\'s role' do
      other = create(:support_role)

      patch "#{url}/#{other.id}", params: { name: 'Taken' }, headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:not_found)
    end

    it 'rejects agents on every action' do
      headers = agent.create_new_auth_token

      get url, headers: headers, as: :json
      expect(response).to have_http_status(:unauthorized)

      post url, params: { name: 'Mine', permissions: ['role_manage'] }, headers: headers, as: :json
      expect(response).to have_http_status(:unauthorized)

      delete "#{url}/#{role.id}", headers: headers, as: :json
      expect(response).to have_http_status(:unauthorized)
    end
  end

  it 'is forbidden when the feature is off' do
    get url, headers: admin.create_new_auth_token, as: :json

    expect(response).to have_http_status(:forbidden)
  end
end
