require 'rails_helper'

RSpec.describe 'Conversation categories API', type: :request do
  let(:account) { create(:account) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let!(:withdrawal) { create(:conversation_category, account: account, name: 'Withdrawal', position: 1) }
  let!(:pending_approval) { create(:conversation_category, account: account, name: 'Pending approval', parent: withdrawal) }
  let(:base_url) { "/api/v1/accounts/#{account.id}/conversation_categories" }

  describe 'GET index' do
    it 'lists the whole tree for an agent' do
      get base_url, headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(response).to conform_schema(200)
      expect(response.parsed_body.pluck('name', 'depth', 'ancestor_ids')).to eq([['Withdrawal', 1, []], ['Pending approval', 2, [withdrawal.id]]])
    end
  end

  describe 'POST create' do
    it 'returns unauthorized for an agent' do
      post base_url, params: { conversation_category: { name: 'Deposit' } }, headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:unauthorized)
    end

    it 'creates a subcategory for an admin' do
      post base_url, params: { conversation_category: { name: 'Not received', parent_id: withdrawal.id } },
                     headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body).to include('name' => 'Not received', 'depth' => 2, 'parent_id' => withdrawal.id)
    end
  end

  describe 'PATCH reorder' do
    let!(:deposit) { create(:conversation_category, account: account, name: 'Deposit', position: 2) }

    it 'sets the order of siblings' do
      patch "#{base_url}/reorder", params: { ids: [deposit.id, withdrawal.id] }, headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect([deposit.reload.position, withdrawal.reload.position]).to eq([0, 1])
    end

    it 'rejects categories with different parents' do
      patch "#{base_url}/reorder", params: { ids: [pending_approval.id, deposit.id] }, headers: admin.create_new_auth_token, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe 'archiving' do
    it 'archives a category with everything below it' do
      delete "#{base_url}/#{withdrawal.id}", headers: admin.create_new_auth_token, as: :json

      expect(withdrawal.reload.archived_at).to be_present
      expect(pending_approval.reload.archived_at).to be_present
    end

    it 'restores a branch only when its parent is active' do
      withdrawal.update!(archived_at: Time.current)
      pending_approval.update!(archived_at: Time.current)

      patch "#{base_url}/#{pending_approval.id}", params: { conversation_category: { archived: false } }, headers: admin.create_new_auth_token,
                                                  as: :json
      expect(response).to have_http_status(:unprocessable_entity)

      patch "#{base_url}/#{withdrawal.id}", params: { conversation_category: { archived: false } }, headers: admin.create_new_auth_token, as: :json
      expect(response.parsed_body['archived']).to be false
      expect(pending_approval.reload.archived_at).to be_nil
    end
  end
end
