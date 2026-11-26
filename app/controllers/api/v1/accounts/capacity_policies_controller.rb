# Choplife fork: serves /agent_capacity_policies for the existing capacity settings UI (see CapacityPolicy).
class Api::V1::Accounts::CapacityPoliciesController < Api::V1::Accounts::BaseController
  before_action :fetch_capacity_policy, only: [:show, :update, :destroy]
  before_action -> { check_authorization(CapacityPolicy) }

  def index
    @capacity_policies = capacity_policies.includes(:capacity_limits).order(:id)
  end

  def show; end

  def create
    @capacity_policy = capacity_policies.create!(capacity_policy_params)
  end

  def update
    @capacity_policy.update!(capacity_policy_params)
  end

  def destroy
    @capacity_policy.destroy!
    head :ok
  end

  private

  def capacity_policies
    CapacityPolicy.where(account: Current.account)
  end

  def fetch_capacity_policy
    @capacity_policy = capacity_policies.find(params[:id])
  end

  def capacity_policy_params
    params.permit(:name, :description, exclusion_rules: [:exclude_older_than_hours, { excluded_labels: [] }])
  end
end
