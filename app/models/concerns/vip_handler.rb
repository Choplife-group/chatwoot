# A VIP conversation is shown first and highlighted. Only team leads and administrators can change it
# (ConversationPolicy#update_vip?), through the one endpoint that writes it.
module VipHandler
  extend ActiveSupport::Concern

  included do
    after_update_commit :create_vip_change_activity, if: :saved_change_to_vip?
  end

  private

  def create_vip_change_activity
    user_name = activity_message_owner(Current.user&.name)
    return if user_name.blank?

    content = I18n.t(vip? ? 'conversations.activity.vip.added' : 'conversations.activity.vip.removed', user_name: user_name)
    ::Conversations::ActivityMessageJob.perform_later(self, activity_message_params(content))
  end
end
