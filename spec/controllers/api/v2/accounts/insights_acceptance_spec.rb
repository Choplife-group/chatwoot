require 'rails_helper'

# Ticket 3's acceptance criteria, one by one, through the API the dashboard uses
RSpec.describe 'Insights acceptance', type: :request do
  let(:account) { create(:account) }
  let(:market) { create(:market, account: account) }
  let(:team_a) { create(:team, account: account) }
  let(:team_b) { create(:team, account: account) }
  let(:category) { create(:conversation_category, account: account, parent: create(:conversation_category, account: account)) }
  let(:manager) { create(:user, account: account, role: :administrator) }
  let(:lead) { create(:user, account: account, role: :agent).tap { |user| create(:team_member, team: team_a, user: user, lead: true) } }
  let(:agent_a) { create(:user, account: account, role: :agent).tap { |user| create(:team_member, team: team_a, user: user) } }
  let(:agent_b) { create(:user, account: account, role: :agent).tap { |user| create(:team_member, team: team_b, user: user) } }
  let(:inbox) { create(:inbox, account: account, market: market) }
  let!(:conversation_a) do
    create(:conversation, account: account, inbox: inbox, team: team_a, assignee: agent_a, category: category, created_at: 2.days.ago)
  end
  let(:query) { { metrics: %w[received resolved], group_by: %w[market team category], period: 'last_7_days' } }

  before do
    account.enable_features!('insights')
    create(:conversation, account: account, inbox: inbox, team: team_a, created_at: 2.days.ago)
    create(:conversation, account: account, inbox: inbox, team: team_b, assignee: agent_b, created_at: 2.days.ago)
    create(:conversation, account: account, inbox: inbox, created_at: 40.days.ago)
    create(:reporting_event, account: account, conversation: conversation_a, inbox: inbox, user: agent_a, name: 'conversation_resolved',
                             event_end_time: 1.day.ago)
  end

  def get_json(path, user, params = {})
    get "/api/v2/accounts/#{account.id}/#{path}", params: params, headers: user.create_new_auth_token
    response
  end

  it 'breaks every metric down by every dimension within a date range' do
    custom = { since: 7.days.ago.to_i, until: Time.current.to_i }
    (Insights::ReportConfig::DIMENSIONS + Insights::ReportConfig::TIME_DIMENSIONS).each do |dimension|
      metrics = Insights::ReportConfig::METRICS - (Insights::ReportConfig::TIME_DIMENSIONS.include?(dimension) ? ['open'] : [])

      expect(get_json('insights/query', manager, custom.merge(metrics: metrics, group_by: [dimension]))).to have_http_status(:success)
    end
  end

  it 'builds and saves a report by market, team and category' do
    post "/api/v2/accounts/#{account.id}/saved_reports", params: { saved_report: { name: 'Monthly', config: query } },
                                                         headers: manager.create_new_auth_token, as: :json
    saved = SavedReport.find(response.parsed_body['id'])

    rows = get_json('insights/query', manager, saved.config).parsed_body['rows']
    expect(rows.first['dimensions'].keys).to eq(%w[market team category])
    expect(rows.sum { |row| row['metrics']['received'] }).to eq(3)
  end

  it 'opens a past period and compares it with another' do
    body = get_json('insights/query', manager, metrics: %w[received], since: 45.days.ago.to_i, until: 30.days.ago.to_i,
                                               compare_since: 10.days.ago.to_i, compare_until: Time.current.to_i).parsed_body

    expect(body['totals']).to eq('received' => 1)
    expect(body['previous_totals']).to eq('received' => 3)
  end

  it 'keeps a snapshot\'s figures after recategorisation' do
    post "/api/v2/accounts/#{account.id}/report_snapshots", params: { report_snapshot: { name: 'Week', config: query.merge(metrics: %w[resolved]) } },
                                                            headers: manager.create_new_auth_token, as: :json
    snapshot = response.parsed_body
    conversation_a.update!(team: team_b, category: create(:conversation_category, account: account))

    expect(get_json("report_snapshots/#{snapshot['id']}", manager).parsed_body['result']).to eq(snapshot['result'])
  end

  it 'configures a dashboard with chosen widgets, filters and a refresh interval' do
    dashboard = { name: 'Floor', refresh_seconds: 30, widgets: [{ id: 'w1', display: 'bar', metric: 'received', config: query }],
                  filters: { period: 'today', team_ids: [team_a.id] } }
    post "/api/v2/accounts/#{account.id}/insight_dashboards", params: { insight_dashboard: dashboard }, headers: manager.create_new_auth_token,
                                                              as: :json

    expect(response.parsed_body).to include('refresh_seconds' => 30, 'filters' => { 'period' => 'today', 'team_ids' => [team_a.id] })
    expect(response.parsed_body['widgets']).to contain_exactly(include('display' => 'bar', 'metric' => 'received'))
  end

  it 'schedules a report daily, weekly or monthly' do
    report = account.saved_reports.create!(user: manager, name: 'Monthly', config: query)
    [{ frequency: 'daily' }, { frequency: 'weekly', weekday: 1 }, { frequency: 'monthly', day_of_month: 1 }].each do |cadence|
      post "/api/v2/accounts/#{account.id}/report_schedules",
           params: { saved_report_id: report.id, report_schedule: cadence.merge(hour: 8, recipient_ids: [manager.id], file_types: %w[pdf]) },
           headers: manager.create_new_auth_token, as: :json

      expect(response.parsed_body).to include('frequency' => cadence[:frequency], 'next_run_at' => be_present)
    end
  end

  it 'exports any report to CSV, Excel and PDF' do
    Insights::ExportService::CONTENT_TYPES.each do |file_type, content_type|
      expect(get_json('insights/export', manager, query.merge(file_type: file_type)).media_type).to eq(content_type)
    end
  end

  it 'shows the conversations behind a figure' do
    payload = get_json('insights/drilldown', manager, query.merge(metric: 'resolved', dimensions: { team: team_a.id })).parsed_body['payload']

    expect(payload).to contain_exactly(include('conversation_id' => conversation_a.id))
  end

  it 'limits a team lead to their team and an agent to their own figures, in reports, drill-downs and exports' do
    { manager => 3, lead => 2, agent_a => 1, agent_b => 1 }.each do |user, received|
      expect(get_json('insights/query', user, query).parsed_body['totals']['received']).to eq(received)
      expect(get_json('insights/drilldown', user, query.merge(metric: 'received')).parsed_body['meta']['total_count']).to eq(received)
      csv_total = CSV.parse(get_json('insights/export', user, query.merge(file_type: 'csv')).body).last
      expect(csv_total[3]).to eq(received.to_s)
    end
  end
end
