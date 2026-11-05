module ConversationAssignmentTargetsConcern
  private

  def validate_assignment_targets
    assignee_id = params[:assignee_id]
    return render_could_not_create_error('Invalid assignee_id') if assignee_id.present? && !Current.account.users.exists?(id: assignee_id)

    team_id = params[:team_id]
    return if team_id.blank? || Current.account.teams.exists?(id: team_id)

    render_could_not_create_error('Invalid team_id')
  end

  # Someone with restricted access can only see what's assigned to them, so what they start is theirs
  def assign_new_conversation_to_restricted_user
    return unless Conversations::AssignmentGuard.restricted?(Current.account, Current.user)

    params[:assignee_id] = Current.user.id
    params.delete(:team_id) unless Current.user.team_members.leads.exists?(team_id: params[:team_id])
  end
end
