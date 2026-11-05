class Conversations::PermissionFilterService
  attr_reader :conversations, :user, :account

  def initialize(conversations, user, account, plan_hint_selective_filter: false)
    @conversations = conversations
    @user = user
    @account = account
    @plan_hint_selective_filter = plan_hint_selective_filter
  end

  def perform
    return conversations if user_role == 'administrator'
    return restricted_conversations if account.feature_enabled?('restricted_inbox_access')

    accessible_conversations
  end

  private

  # Agents see what's assigned to them. Team leads also see everything in the teams they lead.
  def restricted_conversations
    led_team_ids = user.team_members.leads.joins(:team).where(teams: { account_id: account.id }).select(:team_id)

    conversations.where(assignee_id: user.id).or(conversations.where(team_id: led_team_ids))
  end

  def accessible_conversations
    return hinted_accessible_conversations if @plan_hint_selective_filter

    conversations.where(inbox: user.inboxes.where(account_id: account.id))
  end

  # Same rows as accessible_conversations. `inbox_id + 0` keeps the planner from
  # driving the query through an inbox scan, which it grossly misestimates when a
  # highly selective filter (e.g. labels) is present on large accounts (CW-7787).
  def hinted_accessible_conversations
    conversations.where(
      '(conversations.inbox_id + 0) IN (
        SELECT inbox_members.inbox_id FROM inbox_members
        INNER JOIN inboxes ON inboxes.id = inbox_members.inbox_id
        WHERE inbox_members.user_id = :user_id AND inboxes.account_id = :account_id
      )',
      user_id: user.id, account_id: account.id
    )
  end

  def account_user
    AccountUser.find_by(account_id: account.id, user_id: user.id)
  end

  def user_role
    account_user&.role
  end
end

Conversations::PermissionFilterService.prepend_mod_with('Conversations::PermissionFilterService')
