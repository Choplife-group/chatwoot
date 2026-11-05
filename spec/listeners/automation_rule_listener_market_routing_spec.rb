require 'rails_helper'

RSpec.describe AutomationRuleListener do
  let(:account) { create(:account) }
  let(:uganda) { create(:market, account: account, code: 'UG') }
  let(:team) { create(:team, account: account) }

  it 'routes a new conversation to a team by market' do
    create(:automation_rule, account: account, event_name: 'conversation_created',
                             conditions: [{ attribute_key: 'market_id', filter_operator: 'equal_to', values: [uganda.id], query_operator: nil }],
                             actions: [{ action_name: 'assign_team', action_params: [team.id] }])
    conversation = create(:conversation, account: account, inbox: create(:inbox, account: account, market: uganda))
    event = Events::Base.new('conversation_created', Time.zone.now, { conversation: conversation })

    described_class.instance.conversation_created(event)

    expect(conversation.reload.team).to eq(team)
  end
end
