# Choplife fork: the "balanced" assignment order. Picks the agent with the fewest open conversations
# across the account; ties go round robin so equally busy agents still take turns.
class AutoAssignment::LeastBusySelector
  pattr_initialize [:inbox!]

  # agents: InboxMember records. Returns a User, like RoundRobinSelector.
  def select_agent(agents)
    return nil if agents.empty?

    counts = inbox.account.conversations.open.where(assignee_id: agents.map(&:user_id)).group(:assignee_id).count
    fewest = agents.map { |agent| counts.fetch(agent.user_id, 0) }.min
    least_busy = agents.select { |agent| counts.fetch(agent.user_id, 0) == fewest }

    AutoAssignment::RoundRobinSelector.new(inbox: inbox).select_agent(least_busy)
  end
end
