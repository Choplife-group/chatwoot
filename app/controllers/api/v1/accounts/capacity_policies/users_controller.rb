# Choplife fork: which agents a capacity policy applies to. An agent has at most one policy.
class Api::V1::Accounts::CapacityPolicies::UsersController < Api::V1::Accounts::BaseController
  before_action :fetch_capacity_policy
  before_action -> { check_authorization(CapacityPolicy) }

  def index
    @users = User.joins(:account_users).where(account_users: { account_id: Current.account.id, agent_capacity_policy_id: @capacity_policy.id })
  end

  def create
    account_user = Current.account.account_users.find_by!(user_id: params[:user_id])
    account_user.update!(capacity_policy: @capacity_policy)
    @user = account_user.user
  end

  def destroy
    account_user = @capacity_policy.account_users.find_by!(user_id: params[:id])
    account_user.update!(capacity_policy: nil)
    head :ok
  end

  private

  def fetch_capacity_policy
    @capacity_policy = CapacityPolicy.where(account: Current.account).find(params[:agent_capacity_policy_id])
  end
end
