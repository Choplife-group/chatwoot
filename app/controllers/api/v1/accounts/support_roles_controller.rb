class Api::V1::Accounts::SupportRolesController < Api::V1::Accounts::BaseController
  before_action :ensure_feature_enabled
  before_action :fetch_role, only: [:show, :update, :destroy]
  before_action :check_authorization
  before_action :check_escalation, only: [:create, :update, :destroy]

  def index
    @roles = Current.account.support_roles.order(:name)
  end

  def show; end

  def create
    @role = Current.account.support_roles.create!(role_params)
  end

  def update
    @role.update!(role_params)
  end

  def destroy
    @role.destroy!
    head :ok
  end

  private

  def ensure_feature_enabled
    return if Current.account.feature_enabled?('support_roles')

    render json: { error: I18n.t('errors.support_roles.feature_not_enabled') }, status: :forbidden
  end

  def check_escalation
    guard = Agents::EscalationGuard.new(account_user: Current.account_user)
    allowed = guard.can_set_permissions?(params[:permissions]) && (@role.nil? || guard.can_manage_role?(@role))

    raise Pundit::NotAuthorizedError unless allowed
  end

  def fetch_role
    @role = Current.account.support_roles.find(params[:id])
  end

  def role_params
    params.permit(:name, :description, permissions: [])
  end
end
