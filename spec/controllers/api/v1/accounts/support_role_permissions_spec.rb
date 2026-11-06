require 'rails_helper'

# Each permission opens its own area and nothing else
RSpec.describe 'Support role permissions', type: :request do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account, role: :agent) }
  let(:base) { "/api/v1/accounts/#{account.id}" }
  let(:headers) { user.create_new_auth_token }

  def give(*permissions)
    role = create(:support_role, account: account, permissions: permissions)
    user.account_users.first.update!(custom_role_id: role.id)
  end

  before { account.enable_features!('support_roles') }

  describe 'market_manage' do
    let(:market) { create(:market, account: account) }

    it 'opens markets' do
      give('market_manage')

      post "#{base}/markets", params: { market: { name: 'Namibia', code: 'NA' } }, headers: headers, as: :json
      expect(response).to have_http_status(:success)

      patch "#{base}/markets/#{market.id}", params: { market: { name: 'Renamed' } }, headers: headers, as: :json
      expect(market.reload.name).to eq('Renamed')
    end

    it 'stays closed without it' do
      give('category_manage')

      post "#{base}/markets", params: { market: { name: 'Namibia', code: 'NA' } }, headers: headers, as: :json

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'category_manage' do
    it 'opens conversation categories' do
      give('category_manage')

      post "#{base}/conversation_categories", params: { conversation_category: { name: 'Bonus' } }, headers: headers, as: :json

      expect(response).to have_http_status(:success)
    end

    it 'stays closed without it' do
      give('market_manage')

      post "#{base}/conversation_categories", params: { conversation_category: { name: 'Bonus' } }, headers: headers, as: :json

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'team_manage' do
    let(:team) { create(:team, account: account) }
    let(:member) { create(:user, account: account, role: :agent) }

    it 'opens teams, members and leads' do
      give('team_manage')

      post "#{base}/teams", params: { team: { name: 'namibia' } }, headers: headers, as: :json
      expect(response).to have_http_status(:success)

      patch "#{base}/teams/#{team.id}/team_members", params: { user_ids: [member.id], lead_ids: [member.id] }, headers: headers, as: :json
      expect(team.team_members.leads.pluck(:user_id)).to eq([member.id])
    end

    it 'stays closed without it' do
      give('market_manage')

      post "#{base}/teams", params: { team: { name: 'namibia' } }, headers: headers, as: :json
      expect(response).to have_http_status(:unauthorized)

      patch "#{base}/teams/#{team.id}/team_members", params: { user_ids: [user.id], lead_ids: [user.id] }, headers: headers, as: :json
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'report_manage' do
    let(:summary_url) { "/api/v2/accounts/#{account.id}/summary_reports/agent" }
    let(:range) { { since: 1.week.ago.to_i.to_s, until: Time.current.to_i.to_s } }

    it 'opens reports and CSAT' do
      give('report_manage')

      get summary_url, params: range, headers: headers
      expect(response).to have_http_status(:success)

      get "#{base}/csat_survey_responses", headers: headers
      expect(response).to have_http_status(:success)
    end

    it 'stays closed without it' do
      give('market_manage')

      get summary_url, params: range, headers: headers
      expect(response).to have_http_status(:unauthorized)

      get "#{base}/csat_survey_responses", headers: headers
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'conversation_delete' do
    let(:inbox) { create(:inbox, account: account) }
    let(:conversation) { create(:conversation, account: account, inbox: inbox) }
    let(:url) { "#{base}/conversations/#{conversation.display_id}" }

    before { create(:inbox_member, user: user, inbox: inbox) }

    it 'deletes a conversation they can see' do
      give('conversation_delete')

      expect { delete url, headers: headers, as: :json }.to have_enqueued_job(DeleteObjectJob)
      expect(response).to have_http_status(:success)
    end

    it 'does not delete one they can\'t see' do
      give('conversation_delete')
      account.enable_features!('restricted_inbox_access')

      expect { delete url, headers: headers, as: :json }.not_to have_enqueued_job(DeleteObjectJob)
      expect(response).to have_http_status(:unauthorized)
    end

    it 'stays closed without it' do
      give('conversation_manage')

      expect { delete url, headers: headers, as: :json }.not_to have_enqueued_job(DeleteObjectJob)
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'inbox_manage' do
    let(:inbox) { create(:inbox, account: account) }
    let(:api_inbox) { create(:channel_api, account: account, webhook_url: 'https://safe.example.com').inbox }
    let(:member) { create(:user, account: account, role: :agent) }

    before { give('inbox_manage') }

    it 'lists every inbox and opens one they are not in' do
      inbox

      get "#{base}/inboxes", headers: headers, as: :json
      expect(response.parsed_body['payload'].pluck('id')).to include(inbox.id)

      get "#{base}/inboxes/#{inbox.id}", headers: headers, as: :json
      expect(response).to have_http_status(:success)
    end

    it 'changes inbox settings and widget appearance' do
      patch "#{base}/inboxes/#{inbox.id}", params: { name: 'Renamed', channel: { widget_color: '#000000' } }, headers: headers, as: :json

      expect(response).to have_http_status(:success)
      expect(inbox.reload.name).to eq('Renamed')
      expect(inbox.channel.widget_color).to eq('#000000')
    end

    it 'does not change a widget\'s identity or domain protection' do
      patch "#{base}/inboxes/#{inbox.id}", params: { channel: { hmac_mandatory: true, allowed_domains: 'evil.example.com' } },
                                           headers: headers, as: :json

      expect(inbox.channel.reload).to have_attributes(hmac_mandatory: false, allowed_domains: '')
    end

    it 'does not change a channel\'s connection' do
      patch "#{base}/inboxes/#{api_inbox.id}", params: { channel: { webhook_url: 'https://evil.example.com' } }, headers: headers, as: :json

      expect(api_inbox.channel.reload.webhook_url).to eq('https://safe.example.com')
    end

    it 'does not return secrets' do
      get "#{base}/inboxes/#{inbox.id}", headers: headers, as: :json

      expect(response.parsed_body).not_to have_key('hmac_token')
    end

    it 'does not delete an inbox or rotate its secrets' do
      delete "#{base}/inboxes/#{inbox.id}", headers: headers, as: :json
      expect(response).to have_http_status(:unauthorized)

      post "#{base}/inboxes/#{inbox.id}/rotate_hmac_token", headers: headers, as: :json
      expect(response).to have_http_status(:unauthorized)
    end

    it 'manages members, but they can\'t add themselves' do
      patch "#{base}/inbox_members", params: { inbox_id: inbox.id, user_ids: [member.id] }, headers: headers, as: :json
      expect(inbox.reload.members).to contain_exactly(member)

      patch "#{base}/inbox_members", params: { inbox_id: inbox.id, user_ids: [member.id, user.id.to_s] }, headers: headers, as: :json
      expect(response).to have_http_status(:unauthorized)

      post "#{base}/inbox_members", params: { inbox_id: inbox.id, user_ids: [user.id] }, headers: headers, as: :json
      expect(response).to have_http_status(:unauthorized)
      expect(inbox.reload.members).not_to include(user)
    end

    it 'does not open the inbox\'s conversations' do
      conversation = create(:conversation, account: account, inbox: inbox)

      get "#{base}/conversations/#{conversation.display_id}", headers: headers, as: :json

      expect(response).to have_http_status(:unauthorized)
    end

    it 'does not let them start a conversation in it' do
      contact_inbox = create(:contact_inbox, inbox: inbox, contact: create(:contact, account: account))

      post "#{base}/conversations", params: { source_id: contact_inbox.source_id }, headers: headers, as: :json

      expect(response).to have_http_status(:unauthorized)
    end
  end

  it 'keeps inboxes closed without inbox_manage' do
    give('market_manage')
    inbox = create(:inbox, account: account)

    get "#{base}/inboxes/#{inbox.id}", headers: headers, as: :json
    expect(response).to have_http_status(:unauthorized)

    post "#{base}/inboxes", params: { name: 'New', channel: { type: 'api' } }, headers: headers, as: :json
    expect(response).to have_http_status(:unauthorized)
  end

  it 'gives nothing when support_roles is off' do
    give('market_manage')
    account.disable_features!('support_roles')

    post "#{base}/markets", params: { market: { name: 'Namibia', code: 'NA' } }, headers: headers, as: :json

    expect(response).to have_http_status(:unauthorized)
  end

  it 'leaves everything else closed for the full role' do
    give(*SupportRole::PERMISSIONS)

    post "#{base}/agent_bots", params: { name: 'Bot' }, headers: headers, as: :json
    expect(response).to have_http_status(:unauthorized)

    post "#{base}/automation_rules", params: { name: 'Rule' }, headers: headers, as: :json
    expect(response).to have_http_status(:unauthorized)

    post "#{base}/webhooks", params: { webhook: { url: 'https://example.com' } }, headers: headers, as: :json
    expect(response).to have_http_status(:unauthorized)

    patch base, params: { name: 'Mine' }, headers: headers, as: :json
    expect(response).to have_http_status(:unauthorized)
  end
end
