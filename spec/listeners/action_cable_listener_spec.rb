require 'rails_helper'
describe ActionCableListener do
  let(:listener) { described_class.instance }
  let!(:account) { create(:account) }
  let!(:admin) { create(:user, account: account, role: :administrator) }
  let!(:inbox) { create(:inbox, account: account) }
  let!(:agent) { create(:user, account: account, role: :agent) }
  let!(:conversation) { create(:conversation, account: account, inbox: inbox, assignee: agent) }

  before do
    create(:inbox_member, inbox: inbox, user: agent)
    Current.user = nil
    Current.account = nil
  end

  describe '#conversation_bot_handoff' do
    let(:event) { Events::Base.new(:'conversation.bot_handoff', Time.zone.now, conversation: conversation) }

    it 'broadcasts the handoff to inbox agents and account admins only' do
      expect(ActionCableBroadcastJob).to receive(:perform_later).with(
        a_collection_containing_exactly(agent.pubsub_token, admin.pubsub_token),
        'conversation.bot_handoff',
        conversation.push_event_data.merge(account_id: account.id)
      )

      listener.conversation_bot_handoff(event)
    end

    it 'includes the performer so dashboards can distinguish human takeovers' do
      Current.user = agent
      expect(ActionCableBroadcastJob).to receive(:perform_later).with(
        a_collection_containing_exactly(agent.pubsub_token, admin.pubsub_token),
        'conversation.bot_handoff',
        conversation.push_event_data.merge(account_id: account.id, performer: agent.push_event_data)
      )

      listener.conversation_bot_handoff(event)
    end
  end

  describe '#account_cache_invalidated' do
    let!(:event) do
      Events::Base.new(
        :'account.cache_invalidated',
        Time.zone.now,
        account: account,
        cache_keys: account.cache_keys
      )
    end

    it 'sends cache invalidation to account agents and admins' do
      expect(ActionCableBroadcastJob).to receive(:perform_later).with(
        a_collection_containing_exactly(agent.pubsub_token, admin.pubsub_token),
        'account.cache_invalidated',
        {
          cache_keys: account.cache_keys,
          account_id: account.id
        }
      )

      listener.account_cache_invalidated(event)
    end
  end

  describe '#message_created' do
    let(:event_name) { :'message.created' }
    let!(:message) do
      create(:message, message_type: 'outgoing',
                       account: account, inbox: inbox, conversation: conversation)
    end
    let!(:event) { Events::Base.new(event_name, Time.zone.now, message: message) }

    it 'sends message to account admins, inbox agents and the contact' do
      # HACK: to reload conversation inbox members
      expect(conversation.inbox.reload.inbox_members.count).to eq(1)

      expect(ActionCableBroadcastJob).to receive(:perform_later).with(
        a_collection_containing_exactly(
          agent.pubsub_token, admin.pubsub_token, conversation.contact_inbox.pubsub_token
        ),
        'message.created',
        message.push_event_data.merge(account_id: account.id)
      )
      listener.message_created(event)
    end

    it 'sends message to all hmac verified contact inboxes' do
      # HACK: to reload conversation inbox members
      expect(conversation.inbox.reload.inbox_members.count).to eq(1)
      conversation.contact_inbox.update(hmac_verified: true)
      # creating a non verified contact inbox to ensure the events are not sent to it
      create(:contact_inbox, contact: conversation.contact, inbox: inbox)
      verified_contact_inbox = create(:contact_inbox, contact: conversation.contact, inbox: inbox, hmac_verified: true)

      expect(ActionCableBroadcastJob).to receive(:perform_later).with(
        a_collection_containing_exactly(
          agent.pubsub_token, admin.pubsub_token, conversation.contact_inbox.pubsub_token, verified_contact_inbox.pubsub_token
        ),
        'message.created',
        message.push_event_data.merge(account_id: account.id)
      )
      listener.message_created(event)
    end
  end

  describe '#typing_on' do
    let(:event_name) { :'conversation.typing_on' }
    let!(:event) { Events::Base.new(event_name, Time.zone.now, conversation: conversation, user: agent, is_private: false) }

    it 'sends message to account admins, inbox agents and the contact' do
      # HACK: to reload conversation inbox members
      expect(conversation.inbox.reload.inbox_members.count).to eq(1)
      expect(ActionCableBroadcastJob).to receive(:perform_later).with(
        a_collection_containing_exactly(
          admin.pubsub_token, conversation.contact_inbox.pubsub_token
        ),
        'conversation.typing_on', { conversation: conversation.push_event_data,
                                    user: agent.push_event_data,
                                    account_id: account.id,
                                    is_private: false }
      )
      listener.conversation_typing_on(event)
    end
  end

  describe '#typing_on with contact' do
    let(:event_name) { :'conversation.typing_on' }
    let!(:event) { Events::Base.new(event_name, Time.zone.now, conversation: conversation, user: conversation.contact, is_private: false) }

    it 'sends message to account admins, inbox agents and the contact' do
      # HACK: to reload conversation inbox members
      expect(conversation.inbox.reload.inbox_members.count).to eq(1)
      expect(ActionCableBroadcastJob).to receive(:perform_later).with(
        a_collection_containing_exactly(
          admin.pubsub_token, agent.pubsub_token
        ),
        'conversation.typing_on', { conversation: conversation.push_event_data,
                                    user: conversation.contact.push_event_data,
                                    account_id: account.id,
                                    is_private: false }
      )
      listener.conversation_typing_on(event)
    end
  end

  describe '#typing_on with agent bot' do
    let(:event_name) { :'conversation.typing_on' }
    let!(:agent_bot) { create(:agent_bot, account: account) }
    let!(:event) { Events::Base.new(event_name, Time.zone.now, conversation: conversation, user: agent_bot, is_private: false) }

    it 'sends message to account admins, inbox agents and the contact' do
      expect(conversation.inbox.reload.inbox_members.count).to eq(1)
      expect(ActionCableBroadcastJob).to receive(:perform_later).with(
        a_collection_containing_exactly(
          admin.pubsub_token, agent.pubsub_token, conversation.contact_inbox.pubsub_token
        ),
        'conversation.typing_on', { conversation: conversation.push_event_data,
                                    user: agent_bot.push_event_data,
                                    account_id: account.id,
                                    is_private: false }
      )
      listener.conversation_typing_on(event)
    end
  end

  describe '#typing_off' do
    let(:event_name) { :'conversation.typing_off' }
    let!(:event) { Events::Base.new(event_name, Time.zone.now, conversation: conversation, user: agent, is_private: false) }

    it 'sends message to account admins, inbox agents and the contact' do
      # HACK: to reload conversation inbox members
      expect(conversation.inbox.reload.inbox_members.count).to eq(1)
      expect(ActionCableBroadcastJob).to receive(:perform_later).with(
        a_collection_containing_exactly(
          admin.pubsub_token, conversation.contact_inbox.pubsub_token
        ),
        'conversation.typing_off', { conversation: conversation.push_event_data,
                                     user: agent.push_event_data,
                                     account_id: account.id,
                                     is_private: false }
      )
      listener.conversation_typing_off(event)
    end
  end

  describe '#contact_deleted' do
    let(:event_name) { :'contact.deleted' }
    let!(:contact) { create(:contact, account: account) }
    let(:contact_data) { contact.push_event_data.merge(account_id: contact.account_id) }
    let!(:event) { Events::Base.new(event_name, Time.zone.now, contact_data: contact_data) }

    it 'sends message to account admins, inbox agents' do
      expect(ActionCableBroadcastJob).to receive(:perform_later).with(
        ["account_#{account.id}"],
        'contact.deleted',
        contact_data
      )
      listener.contact_deleted(event)
    end
  end

  describe '#notification_deleted' do
    let(:event_name) { :'notification.deleted' }
    let!(:notification) { create(:notification, account: account, user: agent) }
    let(:notification_data) do
      {
        id: notification.id,
        user_id: agent.id,
        account_id: account.id
      }
    end
    let!(:event) { Events::Base.new(event_name, Time.zone.now, notification_data: notification_data) }

    it 'sends message to account admins, inbox agents' do
      expect(ActionCableBroadcastJob).to receive(:perform_later).with(
        [agent.pubsub_token],
        'notification.deleted',
        {
          account_id: notification.account_id,
          notification: {
            id: notification.id
          },
          unread_count: 1,
          count: 1
        }
      )

      listener.notification_deleted(event)
    end
  end

  describe '#notification_updated' do
    let(:event_name) { :'notification.updated' }
    let!(:notification) { create(:notification, account: account, user: agent) }
    let!(:event) { Events::Base.new(event_name, Time.zone.now, notification: notification) }

    it 'sends notification to account admins, inbox agents' do
      expect(ActionCableBroadcastJob).to receive(:perform_later).with(
        [agent.pubsub_token],
        'notification.updated',
        {
          account_id: notification.account_id,
          notification: notification.push_event_data,
          unread_count: 1,
          count: 1
        }
      )

      listener.notification_updated(event)
    end
  end

  describe '#conversation_updated' do
    let(:event_name) { :'conversation.updated' }
    let!(:event) { Events::Base.new(event_name, Time.zone.now, conversation: conversation, user: agent, is_private: false) }

    before do
      conversation.add_labels(['support'])
    end

    it 'sends update to inbox members' do
      expect(conversation.inbox.reload.inbox_members.count).to eq(1)

      expect(ActionCableBroadcastJob).to receive(:perform_later).with(
        [agent.pubsub_token, admin.pubsub_token, conversation.contact_inbox.pubsub_token],
        'conversation.updated',
        conversation.push_event_data.merge(account_id: account.id)
      )
      listener.conversation_updated(event)
    end

    it 'broadcast event with label data' do
      expect(conversation.reload.push_event_data[:labels]).to eq(conversation.labels.pluck(:name))

      expect(ActionCableBroadcastJob).to receive(:perform_later).with(
        [agent.pubsub_token, admin.pubsub_token, conversation.contact_inbox.pubsub_token],
        'conversation.updated',
        conversation.push_event_data.merge(account_id: account.id)
      )
      listener.conversation_updated(event)
    end
  end

  describe '#conversation_unread_count_changed' do
    let(:event_name) { :'conversation.unread_count_changed' }
    let!(:agent_without_inbox_access) { create(:user, account: account, role: :agent) }
    let!(:event) { Events::Base.new(event_name, Time.zone.now, conversation: conversation) }

    before do
      account.enable_features!(:conversation_unread_counts)
    end

    it 'sends a lightweight refresh event to inbox agents and admins' do
      expect(conversation.inbox.reload.inbox_members.count).to eq(1)

      expect(ActionCableBroadcastJob).to receive(:perform_later).with(
        a_collection_containing_exactly(agent.pubsub_token, admin.pubsub_token),
        'conversation.unread_count_changed',
        {
          account_id: account.id
        }
      )

      listener.conversation_unread_count_changed(event)
    end

    it 'does not broadcast unread count refresh to agents outside the inbox' do
      expect(ActionCableBroadcastJob).not_to receive(:perform_later).with(
        array_including(agent_without_inbox_access.pubsub_token),
        anything,
        anything
      )

      listener.conversation_unread_count_changed(event)
    end

    it 'does not broadcast when conversation unread counts feature is disabled' do
      account.disable_features!(:conversation_unread_counts)

      expect(ActionCableBroadcastJob).not_to receive(:perform_later)

      listener.conversation_unread_count_changed(event)
    end

    it 'supports deleted conversation data' do
      event = Events::Base.new(
        event_name,
        Time.zone.now,
        conversation_data: {
          id: conversation.id,
          account_id: account.id,
          inbox_id: conversation.inbox_id
        }
      )

      expect(ActionCableBroadcastJob).to receive(:perform_later).with(
        a_collection_containing_exactly(agent.pubsub_token, admin.pubsub_token),
        'conversation.unread_count_changed',
        {
          account_id: account.id
        }
      )

      listener.conversation_unread_count_changed(event)
    end
  end

  context 'when restricted_inbox_access is enabled' do
    let(:team) { create(:team, account: account) }
    let!(:lead) { create(:user, account: account, role: :agent) }
    let!(:bystander) { create(:user, account: account, role: :agent) }
    let(:message) { create(:message, account: account, inbox: inbox, conversation: conversation) }
    let(:tokens) { [] }

    before do
      account.enable_features!('restricted_inbox_access')
      create(:inbox_member, inbox: inbox, user: bystander)
      create(:team_member, team: team, user: lead, lead: true)
      create(:team_member, team: team, user: agent)
      conversation.update!(team: team)
      allow(ActionCableBroadcastJob).to receive(:perform_later) { |broadcast_tokens, event_name, _data| tokens << [event_name, broadcast_tokens] }
    end

    it 'sends messages to the assignee, the team lead and administrators, not other inbox members' do
      listener.message_created(Events::Base.new(:'message.created', Time.zone.now, message: message))

      expect(tokens.to_h['message.created']).to contain_exactly(agent.pubsub_token, lead.pubsub_token, admin.pubsub_token,
                                                                conversation.contact_inbox.pubsub_token)
    end

    it 'sends typing events to the same audience' do
      listener.conversation_typing_on(Events::Base.new(:'conversation.typing_on', Time.zone.now, conversation: conversation, user: admin))

      expect(tokens.to_h['conversation.typing_on']).not_to include(bystander.pubsub_token)
    end

    it 'tells the previous assignee they lost the conversation, with only its id' do
      conversation.update!(assignee: bystander)
      changes = { 'assignee_id' => [agent.id, bystander.id] }

      expect(ActionCableBroadcastJob).to receive(:perform_later)
        .with([agent.pubsub_token], 'conversation.access_removed', hash_including(id: conversation.display_id, account_id: account.id))
      expect(ActionCableBroadcastJob).to receive(:perform_later).with(anything, 'assignee.changed', anything)

      listener.assignee_changed(Events::Base.new(:'assignee.changed', Time.zone.now, conversation: conversation, changed_attributes: changes))
    end

    it 'tells the previous team lead when the conversation moves to another team' do
      other_team = create(:team, account: account)
      conversation.update!(team: other_team)
      tokens.clear

      listener.team_changed(Events::Base.new(:'team.changed', Time.zone.now, conversation: conversation,
                                                                             changed_attributes: { 'team_id' => [team.id, other_team.id] }))

      expect(tokens.to_h['conversation.access_removed']).to eq([lead.pubsub_token])
    end

    it 'does not tell someone who can still see it' do
      changes = { 'assignee_id' => [lead.id, agent.id] }

      listener.assignee_changed(Events::Base.new(:'assignee.changed', Time.zone.now, conversation: conversation, changed_attributes: changes))

      expect(tokens.to_h).not_to have_key('conversation.access_removed')
    end

    it 'copes with an assignee event that has no changed attributes' do
      expect do
        listener.assignee_changed(Events::Base.new(:'assignee.changed', Time.zone.now, conversation: conversation))
      end.not_to raise_error
    end
  end
end
