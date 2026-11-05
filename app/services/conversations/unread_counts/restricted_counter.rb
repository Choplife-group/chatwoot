# Unread counts for agents and team leads when restricted_inbox_access is on. The Redis store is keyed by inbox,
# team and assignee and can't express "my conversations plus my team's", so these come from the database.
class Conversations::UnreadCounts::RestrictedCounter
  pattr_initialize [:account!, :user!]

  def applies?
    account.feature_enabled?('restricted_inbox_access') && !account.account_users.find_by(user_id: user.id)&.administrator?
  end

  def perform
    {
      all_count: rows.size,
      inboxes: tally(rows.pluck(:inbox_id)),
      labels: tally(rows.flat_map { |row| sidebar_label_ids.values_at(*row[:labels]).compact }),
      teams: tally(rows.pluck(:team_id).compact)
    }
  end

  private

  def rows
    @rows ||= unread_conversations.pluck(:id, :inbox_id, :team_id, :cached_label_list).map do |_id, inbox_id, team_id, label_list|
      { inbox_id: inbox_id, team_id: team_id, labels: label_list.to_s.split(',').map(&:strip) }
    end
  end

  def unread_conversations
    Conversations::PermissionFilterService.new(Conversations::UnreadCounts::Builder.new(account).unread_conversations, user, account).perform
  end

  def sidebar_label_ids
    @sidebar_label_ids ||= account.labels.where(show_on_sidebar: true).pluck(:title, :id).to_h
  end

  def tally(ids)
    ids.tally.transform_keys(&:to_s)
  end
end
