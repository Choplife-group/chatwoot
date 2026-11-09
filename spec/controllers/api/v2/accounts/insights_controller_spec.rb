require 'rails_helper'

RSpec.describe 'Insights API', type: :request do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:params) { { metrics: %w[received resolved], group_by: %w[market], since: 7.days.ago.to_i, until: Time.current.to_i } }

  before { account.enable_features!('insights') }

  describe 'GET /api/v2/accounts/{account.id}/insights/query' do
    it 'is forbidden when insights is off' do
      account.disable_features!('insights')

      get "/api/v2/accounts/#{account.id}/insights/query", params: params, headers: agent.create_new_auth_token

      expect(response).to have_http_status(:forbidden)
    end

    it "returns an agent's own figures" do
      create(:conversation, account: account, assignee: agent, created_at: 1.day.ago)
      create(:conversation, account: account, created_at: 1.day.ago)

      get "/api/v2/accounts/#{account.id}/insights/query", params: params, headers: agent.create_new_auth_token

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['totals']).to eq('received' => 1, 'resolved' => 0)
    end

    it 'rejects unknown metrics, too many dimensions and long periods' do
      [
        params.merge(metrics: %w[happiness]),
        params.merge(group_by: %w[market team category agent]),
        params.merge(since: 2.years.ago.to_i),
        params.merge(group_by: %w[day], metrics: %w[open])
      ].each do |body|
        get "/api/v2/accounts/#{account.id}/insights/query", params: body, headers: agent.create_new_auth_token

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe 'GET /api/v2/accounts/{account.id}/insights/export' do
    it 'downloads the report as a file of the chosen type' do
      create(:conversation, account: account, assignee: agent, created_at: 1.day.ago)

      get "/api/v2/accounts/#{account.id}/insights/export", params: params.merge(file_type: 'csv', title: 'My week'),
                                                            headers: agent.create_new_auth_token

      expect(response).to have_http_status(:success)
      expect(response.headers['Content-Disposition']).to include('my-week-')
      expect(CSV.parse(response.body).last).to eq(%w[Total 1 0])
    end

    it 'rejects an unknown file type' do
      get "/api/v2/accounts/#{account.id}/insights/export", params: params.merge(file_type: 'docx'), headers: agent.create_new_auth_token

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe 'GET /api/v2/accounts/{account.id}/insights/drilldown' do
    it 'lists the conversations behind a figure' do
      conversation = create(:conversation, account: account, assignee: agent, created_at: 1.day.ago)

      get "/api/v2/accounts/#{account.id}/insights/drilldown", params: params.merge(metric: 'received', dimensions: { market: '' }),
                                                               headers: agent.create_new_auth_token

      expect(response).to have_http_status(:success)
      expect(response.parsed_body['payload'].pluck('conversation_id')).to eq([conversation.id])
    end

    it 'rejects a row the report is not grouped by, or a previous period without a comparison' do
      [params.merge(metric: 'received', dimensions: { team: '1' }), params.merge(metric: 'received', from_comparison: true)].each do |body|
        get "/api/v2/accounts/#{account.id}/insights/drilldown", params: body, headers: agent.create_new_auth_token

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end
end
