require 'rails_helper'

# Market and category on conversations, and the rule that a person can't resolve an uncategorised conversation
RSpec.describe 'Conversation market and category', type: :request do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:inbox) { create(:inbox, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox) }
  let(:withdrawal) { create(:conversation_category, account: account, name: 'Withdrawal') }
  let(:pending_approval) { create(:conversation_category, account: account, name: 'Pending approval', parent: withdrawal) }
  let(:market) { create(:market, account: account, name: 'Uganda', code: 'UG') }
  let(:conversation_url) { "/api/v1/accounts/#{account.id}/conversations/#{conversation.display_id}" }

  before { create(:inbox_member, user: agent, inbox: inbox) }

  describe 'PATCH /api/v1/accounts/{account.id}/conversations/{id}' do
    it 'sets the market and category' do
      patch conversation_url, params: { market_id: market.id, category_id: pending_approval.id }, headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['meta']).to include('market' => { 'id' => market.id, 'name' => 'Uganda', 'code' => 'UG' },
                                                      'category' => { 'id' => pending_approval.id, 'name' => 'Pending approval',
                                                                      'ancestor_ids' => [withdrawal.id] })
    end

    it 'rejects a category that is not the last level' do
      pending_approval
      patch conversation_url, params: { category_id: withdrawal.id }, headers: agent.create_new_auth_token, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'returns not found for archived markets and categories' do
      market.update!(archived_at: Time.current)
      patch conversation_url, params: { market_id: market.id }, headers: agent.create_new_auth_token, as: :json
      expect(response).to have_http_status(:not_found)

      pending_approval.update!(archived_at: Time.current)
      patch conversation_url, params: { category_id: pending_approval.id }, headers: agent.create_new_auth_token, as: :json
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST /api/v1/accounts/{account.id}/conversations/{id}/toggle_status' do
    def toggle(params = {})
      post "#{conversation_url}/toggle_status", params: params, headers: agent.create_new_auth_token, as: :json
    end

    it 'does not let a person resolve an uncategorised conversation' do
      toggle
      expect(response).to have_http_status(:unprocessable_entity)

      toggle(status: 'resolved')
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body['error']).to eq('Choose a category and subcategory before resolving this conversation')
      expect(conversation.reload).to be_open
    end

    it 'still allows other status changes' do
      toggle(status: 'pending')

      expect(response).to have_http_status(:success)
      expect(conversation.reload).to be_pending
    end

    it 'resolves a categorised conversation' do
      conversation.update!(category: pending_approval)
      toggle

      expect(conversation.reload).to be_resolved
    end
  end

  describe 'POST /api/v1/accounts/{account.id}/bulk_actions' do
    it 'resolves categorised conversations and reports the skipped ones' do
      categorised = create(:conversation, account: account, inbox: inbox, category: pending_approval)
      ids = [conversation.display_id, categorised.display_id]

      perform_enqueued_jobs do
        post "/api/v1/accounts/#{account.id}/bulk_actions", params: { type: 'Conversation', ids: ids, fields: { status: 'resolved' } },
                                                            headers: agent.create_new_auth_token, as: :json
      end

      expect(response.parsed_body['skipped_ids']).to eq([conversation.display_id])
      expect(conversation.reload).to be_open
      expect(categorised.reload).to be_resolved
    end
  end

  describe 'POST /api/v1/accounts/{account.id}/conversations/filter' do
    it 'matches subcategories when filtering by a parent category' do
      conversation.update!(category: pending_approval)
      other = create(:conversation, account: account, inbox: inbox)

      post "/api/v1/accounts/#{account.id}/conversations/filter",
           params: { payload: [{ attribute_key: 'category_id', filter_operator: 'equal_to', values: [withdrawal.id], query_operator: nil }] },
           headers: agent.create_new_auth_token, as: :json

      ids = response.parsed_body['payload'].pluck('id')
      expect(ids).to include(conversation.display_id)
      expect(ids).not_to include(other.display_id)
    end
  end

  describe 'GET /api/v1/accounts/{account.id}/conversations' do
    it 'lists conversations of one market' do
      in_market = create(:conversation, account: account, inbox: inbox, market: market)
      conversation

      get "/api/v1/accounts/#{account.id}/conversations", params: { market_id: market.id }, headers: agent.create_new_auth_token, as: :json

      expect(response.parsed_body['data']['payload'].pluck('id')).to eq([in_market.display_id])
    end
  end
end
