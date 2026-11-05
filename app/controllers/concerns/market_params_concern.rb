module MarketParamsConcern
  private

  # Adds market_id to the permitted params when the request sends it. Only active markets of the account can be set.
  def with_market_id(permitted)
    return permitted unless params.key?(:market_id)

    market_id = params[:market_id]
    permitted.merge(market_id: market_id.present? ? Current.account.markets.active.find(market_id).id : nil)
  end
end
