require 'rails_helper'

RSpec.describe 'Report schedules API', type: :request do
  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:admin) { create(:user, account: account, role: :administrator) }
  let(:base_url) { "/api/v2/accounts/#{account.id}/report_schedules" }
  let(:own_report) { account.saved_reports.create!(user: agent, name: 'Mine', config: { metrics: %w[received], period: 'yesterday' }) }
  let(:schedule_params) { { frequency: 'weekly', weekday: 1, hour: 8, timezone: 'Africa/Dar_es_Salaam', file_types: %w[xlsx] } }

  before { account.enable_features!('insights') }

  it 'lets an agent email a report to themselves' do
    post base_url, params: { saved_report_id: own_report.id, report_schedule: schedule_params.merge(recipient_ids: [agent.id]) },
                   headers: agent.create_new_auth_token, as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body).to include('frequency' => 'weekly', 'recipient_ids' => [agent.id], 'file_types' => %w[xlsx])
    expect(response.parsed_body['next_run_at']).to be_present
  end

  it 'stops an agent emailing a report to someone else' do
    post base_url, params: { saved_report_id: own_report.id, report_schedule: schedule_params.merge(recipient_ids: [agent.id, admin.id]) },
                   headers: agent.create_new_auth_token, as: :json

    expect(response).to have_http_status(:unauthorized)
  end

  it 'asks a manager to share a private report before emailing it to others' do
    report = account.saved_reports.create!(user: admin, name: 'Team', config: { metrics: %w[received], period: 'yesterday' })
    body = { saved_report_id: report.id, report_schedule: schedule_params.merge(recipient_ids: [admin.id, agent.id]) }

    post base_url, params: body, headers: admin.create_new_auth_token, as: :json
    expect(response).to have_http_status(:unprocessable_entity)

    report.update!(shared: true)
    post base_url, params: body, headers: admin.create_new_auth_token, as: :json
    expect(response).to have_http_status(:success)
  end

  it 'lists, sends now and deletes a schedule' do
    schedule = account.report_schedules.create!(saved_report: own_report, user: agent, recipient_ids: [agent.id], file_types: %w[pdf],
                                                frequency: :daily)

    get base_url, params: { saved_report_id: own_report.id }, headers: agent.create_new_auth_token
    expect(response.parsed_body.pluck('id')).to eq([schedule.id])

    expect do
      post "#{base_url}/#{schedule.id}/deliver", headers: agent.create_new_auth_token
    end.to have_enqueued_job(Insights::DeliverReportScheduleJob).with(schedule.id)

    delete "#{base_url}/#{schedule.id}", headers: agent.create_new_auth_token
    expect(ReportSchedule.exists?(schedule.id)).to be(false)
  end

  it 'stops someone else changing your schedule' do
    schedule = account.report_schedules.create!(saved_report: own_report, user: agent, recipient_ids: [agent.id], file_types: %w[pdf],
                                                frequency: :daily)

    delete "#{base_url}/#{schedule.id}", headers: create(:user, account: account, role: :agent).create_new_auth_token

    expect(response).to have_http_status(:unauthorized)
  end
end
