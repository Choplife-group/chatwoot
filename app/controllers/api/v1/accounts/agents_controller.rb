class Api::V1::Accounts::AgentsController < Api::V1::Accounts::BaseController
  before_action :fetch_agent, except: [:create, :index, :bulk_create]
  before_action :check_authorization
  before_action :check_escalation, only: [:create, :update, :destroy]

  def index
    @agents = agents
  end

  def create
    builder = AgentBuilder.new(
      email: new_agent_params['email'],
      name: new_agent_params['name'],
      role: new_agent_params['role'],
      custom_role_id: new_agent_params['custom_role_id'],
      availability: new_agent_params['availability'],
      auto_offline: new_agent_params['auto_offline'],
      inviter: current_user,
      account: Current.account
    )

    @agent = builder.perform
  rescue AgentBuilder::LimitExceededError => e
    render_payment_required(e.message)
  end

  def update
    @agent.update!(agent_params.slice(:name).compact)
    @agent.current_account_user.update!(account_user_params)
  end

  def destroy
    @agent.current_account_user.destroy!
    delete_user_record(@agent)
    head :ok
  end

  def bulk_create
    emails = params[:emails]

    bulk_create_agents(emails)
    # This endpoint is used to bulk create agents during onboarding
    # onboarding_step key in present in Current account custom attributes, since this is a one time operation
    clear_onboarding_step
    head :ok
  rescue AgentBuilder::LimitExceededError => e
    render_payment_required(e.message)
  end

  private

  def check_authorization
    super(User)
  end

  def check_escalation
    guard = Agents::EscalationGuard.new(account_user: Current.account_user)
    allowed = guard.can_give?(params.dig(:agent, :role), params.dig(:agent, :custom_role_id)) &&
              (@agent.nil? || guard.can_manage_agent?(@agent.current_account_user))

    raise Pundit::NotAuthorizedError unless allowed
  end

  def fetch_agent
    @agent = agents.find(params[:id])
  end

  def account_user_attributes
    [:role, :availability, :auto_offline]
  end

  # custom_role_id is kept when null, as that's how a role is taken away
  def account_user_params
    attributes = agent_params.slice(*account_user_attributes).compact
    agent_params.key?(:custom_role_id) ? attributes.merge(custom_role_id: agent_params[:custom_role_id]) : attributes
  end

  def allowed_agent_params
    [:name, :email, :role, :custom_role_id, :availability, :auto_offline]
  end

  def agent_params
    params.require(:agent).permit(allowed_agent_params)
  end

  def new_agent_params
    params.require(:agent).permit(:email, :name, :role, :custom_role_id, :availability, :auto_offline)
  end

  def agents
    @agents ||= Current.account.users.order_by_full_name.includes({ account_users: :support_role }, { avatar_attachment: [:blob] })
  end

  def bulk_create_agents(emails)
    email_limit_error = nil

    Current.account.with_lock do
      raise AgentBuilder::LimitExceededError if emails.count > available_agent_count

      emails.each do |email|
        create_agent_from_email(email)
      rescue CustomExceptions::Account::EmailLimitExceeded => e
        email_limit_error = e
      end
    end

    raise email_limit_error if email_limit_error
  end

  def create_agent_from_email(email)
    builder = AgentBuilder.new(
      email: email,
      name: email.split('@').first,
      inviter: current_user,
      account: Current.account
    )
    builder.perform
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.info "[Agent#bulk_create] ignoring email #{email}, errors: #{e.record.errors}"
  end

  def clear_onboarding_step
    Current.account.custom_attributes.delete('onboarding_step')
    Current.account.save!
  end

  def available_agent_count
    Current.account.usage_limits[:agents] - Current.account.account_users.count
  end

  def delete_user_record(agent)
    DeleteObjectJob.perform_later(agent) if agent.reload.account_users.blank?
  end
end

Api::V1::Accounts::AgentsController.prepend_mod_with('Api::V1::Accounts::AgentsController')
