class Macros::ExecutionService < ActionService
  def initialize(macro, conversation, user)
    super(conversation)
    @macro = macro
    @account = macro.account
    @user = user
    Current.user = user
  end

  def perform
    @macro.actions.each do |action|
      action = action.with_indifferent_access
      begin
        send(action[:action_name], action[:action_params])
      rescue StandardError => e
        ChatwootExceptionTracker.new(e, account: @account).capture_exception
      end
    end
  ensure
    Current.reset
  end

  private

  # A person can't resolve an uncategorised conversation (Conversations::ResolveGuard); the macro leaves a note instead
  def resolve_conversation(params)
    return note_resolve_skipped if Conversations::ResolveGuard.blocked?(@conversation, @user)

    super
  end

  def change_status(status)
    return note_resolve_skipped if status[0] == 'resolved' && Conversations::ResolveGuard.blocked?(@conversation, @user)

    super
  end

  def note_resolve_skipped
    note_activity(I18n.t('conversations.activity.category.resolve_skipped', user_name: @user.name))
  end

  def note_assignment_skipped
    note_activity(I18n.t('conversations.activity.assignment_skipped', user_name: @user.name))
  end

  def note_activity(content)
    ::Conversations::ActivityMessageJob.perform_later(
      @conversation, { account_id: @conversation.account_id, inbox_id: @conversation.inbox_id, message_type: :activity, content: content }
    )
  end

  def assignment_allowed?(assignee_id = nil)
    Conversations::AssignmentGuard.allowed?(@conversation, @user) &&
      Conversations::AssignmentGuard.assignee_allowed?(@conversation, @user, assignee_id)
  end

  def assign_agent(agent_ids)
    agent_ids = agent_ids.map { |id| id == 'self' ? @user.id : id }
    return note_assignment_skipped unless assignment_allowed?(agent_ids[0] == 'nil' ? nil : agent_ids[0])

    super(agent_ids)
  end

  def assign_team(team_ids = [])
    return note_assignment_skipped unless assignment_allowed?

    super
  end

  def remove_assigned_team(params)
    return note_assignment_skipped unless assignment_allowed?

    super
  end

  def add_private_note(message)
    return if conversation_a_tweet?

    params = { content: message[0], private: true }

    # Added reload here to ensure conversation us persistent with the latest updates
    mb = Messages::MessageBuilder.new(@user, @conversation.reload, params)
    mb.perform
  end

  def send_message(message)
    return if conversation_a_tweet?

    params = { content: message[0], private: false }

    # Added reload here to ensure conversation us persistent with the latest updates
    mb = Messages::MessageBuilder.new(@user, @conversation.reload, params)
    mb.perform
  end

  def send_attachment(blob_ids)
    return if conversation_a_tweet?

    return unless @macro.files.attached?

    blobs = ActiveStorage::Blob.where(id: blob_ids)

    return if blobs.blank?

    params = { content: nil, private: false, attachments: blobs }

    # Added reload here to ensure conversation us persistent with the latest updates
    mb = Messages::MessageBuilder.new(@user, @conversation.reload, params)
    mb.perform
  end

  def send_webhook_event(webhook_url)
    payload = @conversation.webhook_data.merge(event: 'macro.executed')
    WebhookJob.perform_later(webhook_url.first, payload)
  end
end

Macros::ExecutionService.include_mod_with('Macros::ExecutionService')
