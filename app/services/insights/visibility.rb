# Which figures a user may see in Insights: everything with report_manage (Head of Support, admins),
# their own and their teams' figures as a team lead, and only their own as an agent.
class Insights::Visibility
  attr_reader :account, :user

  def initialize(account, user)
    @account = account
    @user = user
  end

  def everything?
    @everything ||= account.account_users.find_by!(user: user).can?('report_manage')
  end

  def apply(relation, team_column:, agent_column:)
    return relation if everything?
    return relation.where(agent_column => user.id) if lead_team_ids.empty?

    relation.where("#{team_column} IN (?) OR #{agent_column} = ?", lead_team_ids, user.id)
  end

  def lead_team_ids
    @lead_team_ids ||= TeamMember.leads.joins(:team).where(user: user, teams: { account_id: account.id }).pluck(:team_id)
  end
end
