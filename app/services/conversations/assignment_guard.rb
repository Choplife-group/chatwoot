# With restricted_inbox_access on, only team leads and people with conversation_assign can change a conversation's assignee or team.
# Leads assign within their team. Auto-assignment, automations and bots aren't people, so they are not checked.
class Conversations::AssignmentGuard
  def self.restricted?(account, user)
    limited?(account, user) { |account_user| account_user&.can?('conversation_assign') }
  end

  # Someone who can't see every conversation keeps sight of what they start by having it assigned to them
  def self.assigned_to_creator?(account, user)
    limited?(account, user) { |account_user| account_user&.sees_all_conversations? }
  end

  def self.limited?(account, user)
    user.is_a?(User) && account.feature_enabled?('restricted_inbox_access') && !yield(account.account_users.find_by(user: user))
  end
  private_class_method :limited?

  def self.allowed?(conversation, user)
    return true unless restricted?(conversation.account, user)

    conversation.team_id.present? && user.team_members.leads.exists?(team_id: conversation.team_id)
  end

  def self.assignee_allowed?(conversation, user, assignee_id)
    return true unless restricted?(conversation.account, user)

    assignee_id.blank? || conversation.team.members.exists?(id: assignee_id)
  end
end
