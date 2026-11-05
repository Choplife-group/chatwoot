class Api::V1::Accounts::MarketsController < Api::V1::Accounts::BaseController
  before_action :fetch_market, only: [:show, :update, :destroy]
  before_action :check_authorization

  def index
    @markets = Current.account.markets.ordered
  end

  def show; end

  def create
    @market = Current.account.markets.create!(market_params)
  end

  def update
    @market.update!(market_params)
  end

  # Markets are archived, not deleted, so existing conversations and reports keep their market
  def destroy
    @market.update!(archived_at: Time.current)
    head :ok
  end

  private

  def fetch_market
    @market = Current.account.markets.find(params[:id])
  end

  def market_params
    permitted = params.require(:market).permit(:name, :code, :position, :archived)
    return permitted unless permitted.key?(:archived)

    permitted.except(:archived).merge(archived_at: ActiveModel::Type::Boolean.new.cast(permitted[:archived]) ? Time.current : nil)
  end
end
