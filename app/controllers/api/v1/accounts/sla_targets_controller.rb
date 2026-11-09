class Api::V1::Accounts::SlaTargetsController < Api::V1::Accounts::BaseController
  before_action :fetch_sla_target, only: [:update, :destroy]
  before_action :check_authorization

  def index
    @sla_targets = Current.account.sla_targets.order(Arel.sql('market_id NULLS FIRST, priority NULLS FIRST'))
  end

  def create
    @sla_target = Current.account.sla_targets.create!(sla_target_params)
  end

  def update
    @sla_target.update!(sla_target_params)
  end

  def destroy
    @sla_target.destroy!
    head :ok
  end

  private

  def fetch_sla_target
    @sla_target = Current.account.sla_targets.find(params[:id])
  end

  def sla_target_params
    params.require(:sla_target).permit(:market_id, :priority, :first_response_seconds, :resolution_seconds, :business_hours)
  end
end
