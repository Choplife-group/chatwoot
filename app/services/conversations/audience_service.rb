# Who gets a conversation's live updates. Administrators are added by the caller, as they always see everything.
# People whose role has conversation_manage are included here, as the caller doesn't know about them.
class Conversations::AudienceService
  pattr_initialize [:conversation!]

  def users
    return conversation.inbox.members unless restricted?

    audience_for(conversation.assignee_id, conversation.team_id)
  end

  # People who could see the conversation before these assignee or team changes and can't any more
  def removed_users(changed_attributes)
    return User.none unless restricted?

    changes = changed_attributes.to_h.with_indifferent_access
    former_assignee_id = changes[:assignee_id]&.first || conversation.assignee_id
    former_team_id = changes[:team_id]&.first || conversation.team_id

    audience_for(former_assignee_id, former_team_id).where.not(id: users.select(:id))
                                                    .where.not(id: conversation.account.administrators.select(:id))
  end

  private

  def restricted?
    conversation.account.feature_enabled?('restricted_inbox_access')
  end

  def audience_for(assignee_id, team_id)
    User.where(id: assignee_id).or(User.where(id: TeamMember.leads.where(team_id: team_id).select(:user_id))).or(User.where(id: see_all_user_ids))
  end

  def see_all_user_ids
    return AccountUser.none.select(:user_id) unless conversation.account.feature_enabled?('support_roles')

    conversation.account.account_users.with_permission('conversation_manage').select(:user_id)
  end
end
