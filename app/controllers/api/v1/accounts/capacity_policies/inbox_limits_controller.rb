# Choplife fork: per-inbox open-conversation limits on a capacity policy.
class Api::V1::Accounts::CapacityPolicies::InboxLimitsController < Api::V1::Accounts::BaseController
  before_action :fetch_capacity_policy
  before_action :fetch_capacity_limit, only: [:update, :destroy]
  before_action -> { check_authorization(CapacityPolicy) }

  def create
    inbox = Current.account.inboxes.find(params[:inbox_id])
    @capacity_limit = @capacity_policy.capacity_limits.create!(inbox: inbox, conversation_limit: params[:conversation_limit])
  end

  def update
    @capacity_limit.update!(conversation_limit: params[:conversation_limit])
  end

  def destroy
    @capacity_limit.destroy!
    head :ok
  end

  private

  def fetch_capacity_policy
    @capacity_policy = CapacityPolicy.where(account: Current.account).find(params[:agent_capacity_policy_id])
  end

  def fetch_capacity_limit
    @capacity_limit = @capacity_policy.capacity_limits.find(params[:id])
  end
end
