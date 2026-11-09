require 'rails_helper'

RSpec.describe 'Report snapshots API', type: :request do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:base_url) { "/api/v2/accounts/#{account.id}/report_snapshots" }
  let(:team) { create(:team, account: account) }
  let(:category) { create(:conversation_category, account: account) }
  let(:conversation) { create(:conversation, account: account, team: team, category: category, created_at: 2.days.ago) }
  let(:config) { { metrics: %w[resolved], group_by: %w[team subcategory], period: 'last_7_days' } }

  before do
    account.enable_features!('insights')
    create(:reporting_event, account: account, conversation: conversation, inbox: conversation.inbox, name: 'conversation_resolved',
                             event_end_time: 1.day.ago)
  end

  it 'returns the same figures after the conversation is recategorised' do
    post base_url, params: { report_snapshot: { name: 'Week', config: config } }, headers: admin.create_new_auth_token, as: :json
    snapshot_id = response.parsed_body['id']
    original = response.parsed_body['result']

    conversation.update!(team: create(:team, account: account), category: create(:conversation_category, account: account))
    create(:reporting_event, account: account, conversation: conversation, inbox: conversation.inbox, name: 'conversation_resolved',
                             event_end_time: 1.hour.ago)

    get "#{base_url}/#{snapshot_id}", headers: admin.create_new_auth_token, as: :json

    expect(response.parsed_body['result']).to eq(original)
    expect(original['rows']).to eq([{ 'dimensions' => { 'team' => team.id, 'subcategory' => category.id }, 'metrics' => { 'resolved' => 1 } }])
  end

  it 'exports the stored figures and dates, not today\'s' do
    snapshot = account.report_snapshots.create!(
      user: admin, name: 'October', captured_at: Time.current,
      config: Insights::ReportConfig.new(config.merge(period: 'custom', since: Time.find_zone('UTC').parse('2026-10-01').to_i,
                                                      until: Time.find_zone('UTC').parse('2026-10-31').to_i)).to_h.merge(period: 'last_7_days'),
      result: { rows: [], totals: { resolved: 42 }, labels: {} }
    )

    get "#{base_url}/#{snapshot.id}/export", params: { file_type: 'csv' }, headers: admin.create_new_auth_token

    expect(response.headers['Content-Disposition']).to include('october-2026-10-31.csv')
    expect(CSV.parse(response.body).last).to eq(['Total', nil, '42'])
  end

  it 'keeps snapshots private to whoever took them' do
    snapshot = account.report_snapshots.create!(user: admin, name: 'Week', config: config, result: { 'rows' => [] }, captured_at: Time.current)

    get base_url, headers: agent.create_new_auth_token, as: :json
    expect(response.parsed_body).to eq([])

    get "#{base_url}/#{snapshot.id}", headers: agent.create_new_auth_token, as: :json
    expect(response).to have_http_status(:not_found)
  end
end
