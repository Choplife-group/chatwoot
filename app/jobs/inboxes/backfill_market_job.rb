# Runs when an inbox is mapped to a market: gives its existing conversations without a market that market,
# then remembers it on their contacts that have none yet.
class Inboxes::BackfillMarketJob < ApplicationJob
  queue_as :low

  def perform(inbox)
    market_id = inbox.market_id
    return if market_id.blank?

    # rubocop:disable Rails/SkipsModelValidations
    inbox.conversations.where(market_id: nil).in_batches(of: 1000) { |batch| batch.update_all(market_id: market_id) }
    inbox.account.contacts.where(market_id: nil, id: inbox.conversations.select(:contact_id))
         .in_batches(of: 1000) { |batch| batch.update_all(market_id: market_id) }
    # rubocop:enable Rails/SkipsModelValidations
  end
end
