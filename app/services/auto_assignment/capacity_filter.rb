# Choplife fork: drops agents who already hold as many open conversations in this inbox as their
# CapacityPolicy allows. Agents without a policy, or whose policy sets no limit for this inbox, are unlimited.
class AutoAssignment::CapacityFilter
  pattr_initialize [:inbox!]

  # agents: InboxMember records
  def filter(agents)
    return agents if limits_by_policy_id.empty?

    policy_ids = policy_ids_by_user_id(agents.map(&:user_id))
    agents.select do |agent|
      policy = policies_by_id[policy_ids[agent.user_id]]
      policy.nil? || open_count(policy, agent.user_id) < limits_by_policy_id[policy.id]
    end
  end

  private

  def limits_by_policy_id
    @limits_by_policy_id ||= CapacityLimit.where(inbox_id: inbox.id).pluck(:agent_capacity_policy_id, :conversation_limit).to_h
  end

  def policies_by_id
    @policies_by_id ||= CapacityPolicy.where(id: limits_by_policy_id.keys).index_by(&:id)
  end

  def policy_ids_by_user_id(user_ids)
    inbox.account.account_users.where(user_id: user_ids).pluck(:user_id, :agent_capacity_policy_id).to_h
  end

  def open_count(policy, user_id)
    scope = inbox.conversations.open.where(assignee_id: user_id)
    scope = scope.tagged_with(policy.excluded_labels, on: :labels, any: true, exclude: true) if policy.excluded_labels.any?
    scope = scope.where(last_activity_at: policy.exclude_older_than_minutes.minutes.ago..) if policy.exclude_older_than_minutes
    scope.count
  end
end
