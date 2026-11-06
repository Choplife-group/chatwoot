class InboxPolicy < ApplicationPolicy
  class Scope
    attr_reader :user_context, :user, :scope, :account, :account_user

    def initialize(user_context, scope)
      @user_context = user_context
      @user = user_context[:user]
      @account = user_context[:account]
      @account_user = user_context[:account_user]
      @scope = scope
    end

    def resolve
      account_user.can?('inbox_manage') ? account.inboxes : user.assigned_inboxes
    end
  end

  def index?
    true
  end

  def show?
    # FIXME: for agent bots, lets bring this validation to policies as well in future
    return true if @user.is_a?(AgentBot)

    Current.user.assigned_inboxes.include? record
  end

  # Opening an inbox in Settings. Separate from show?, which also lets someone start conversations in it.
  def view_settings?
    @account_user.can?('inbox_manage') || show?
  end

  # Changing how a channel connects. Its credentials and webhook URLs can redirect or expose messages, so this stays with administrators.
  def update_connection?
    @account_user.administrator?
  end

  def assignable_agents?
    true
  end

  def agent_bot?
    true
  end

  def message_templates?
    true
  end

  def campaigns?
    @account_user.can?('inbox_manage')
  end

  def create?
    @account_user.can?('inbox_manage')
  end

  def update?
    @account_user.can?('inbox_manage')
  end

  def destroy?
    @account_user.administrator?
  end

  def set_agent_bot?
    @account_user.can?('inbox_manage')
  end

  def avatar?
    @account_user.can?('inbox_manage')
  end

  def sync_templates?
    @account_user.can?('inbox_manage')
  end

  def whatsapp_business_management_token?
    @account_user.administrator?
  end

  def health?
    @account_user.administrator?
  end

  def reset_secret?
    @account_user.administrator?
  end

  def rotate_hmac_token?
    @account_user.administrator?
  end

  def enable_whatsapp_calling?
    @account_user.administrator?
  end

  def disable_whatsapp_calling?
    @account_user.administrator?
  end

  def set_inbound_calls?
    @account_user.administrator?
  end

  def set_call_recording?
    @account_user.administrator?
  end
end
