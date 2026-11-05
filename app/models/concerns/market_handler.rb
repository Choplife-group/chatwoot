# A conversation's market comes from its inbox (one inbox per market website/number).
# Shared inboxes such as the support email have no market, so the contact's market is used instead.
module MarketHandler
  extend ActiveSupport::Concern

  included do
    belongs_to :market, optional: true

    before_create :set_market
    after_save :remember_market_on_contact, if: :saved_change_to_market_id?
    after_update_commit :create_market_change_activity, if: :saved_change_to_market_id?
  end

  private

  def set_market
    self.market_id ||= inbox.market_id || contact.market_id
  end

  def remember_market_on_contact
    return if market_id.blank? || contact.market_id.present?

    contact.update!(market_id: market_id)
  end

  def create_market_change_activity
    user_name = activity_message_owner(Current.user&.name)
    return if user_name.blank?

    old_market_id, new_market_id = previous_changes['market_id']
    content = if new_market_id.nil?
                I18n.t('conversations.activity.market.removed', user_name: user_name)
              elsif old_market_id.nil?
                I18n.t('conversations.activity.market.added', user_name: user_name, market_name: market.name)
              else
                I18n.t('conversations.activity.market.updated', user_name: user_name, old_market_name: Market.find(old_market_id).name,
                                                                market_name: market.name)
              end

    ::Conversations::ActivityMessageJob.perform_later(self, activity_message_params(content))
  end
end
