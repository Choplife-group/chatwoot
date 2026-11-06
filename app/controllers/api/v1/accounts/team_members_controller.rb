class Api::V1::Accounts::TeamMembersController < Api::V1::Accounts::BaseController
  before_action :fetch_team
  before_action :check_authorization
  before_action :validate_member_id_params, only: [:create, :update, :destroy]
  before_action :validate_lead_ids, only: [:update]

  helper_method :lead_ids

  def index
    @team_members = @team.team_members.map(&:user)
  end

  def create
    ActiveRecord::Base.transaction do
      @team_members = @team.add_members(members_to_be_added_ids)
    end
  end

  def update
    ActiveRecord::Base.transaction do
      @team.add_members(members_to_be_added_ids)
      @team.remove_members(members_to_be_removed_ids)
      update_leads if params.key?(:lead_ids)
    end
    @team_members = @team.members
    render action: 'create'
  end

  def destroy
    ActiveRecord::Base.transaction do
      @team.remove_members(params[:user_ids])
    end
    head :ok
  end

  private

  def update_leads
    @team.team_members.each { |team_member| team_member.update!(lead: params[:lead_ids].include?(team_member.user_id)) }
  end

  def lead_ids
    @lead_ids ||= @team.team_members.leads.pluck(:user_id)
  end

  def members_to_be_added_ids
    params[:user_ids] - current_members_ids
  end

  def members_to_be_removed_ids
    current_members_ids - params[:user_ids]
  end

  def current_members_ids
    @current_members_ids ||= @team.members.pluck(:id)
  end

  def fetch_team
    @team = Current.account.teams.find(params[:team_id])
  end

  def validate_member_id_params
    invalid_ids = params[:user_ids].map(&:to_i) - @team.account.user_ids

    render json: { error: 'Invalid User IDs' }, status: :unauthorized and return if invalid_ids.present?
  end

  # A team lead must be a member of the team
  def validate_lead_ids
    return unless params.key?(:lead_ids)

    return render_could_not_create_error('Team leads must be team members') if (params[:lead_ids] - params[:user_ids]).present?

    # Being a lead opens the team's conversations, so someone with team_manage can't give it to themselves
    raise Pundit::NotAuthorizedError if leading_themselves? && !Current.account_user.administrator?
  end

  def leading_themselves?
    params[:lead_ids].include?(Current.user.id) && lead_ids.exclude?(Current.user.id)
  end
end
