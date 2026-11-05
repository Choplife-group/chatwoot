# Open and waiting conversation counts per team or market, for the sidebar.
# Waiting = open conversations whose last customer message has no reply yet.
class Api::V1::Accounts::Conversations::GroupCountsController < Api::V1::Accounts::BaseController
  GROUP_COLUMNS = { 'team' => :team_id, 'market' => :market_id }.freeze

  def index
    column = GROUP_COLUMNS[params[:group_by]]
    return render_could_not_create_error('Invalid group_by') unless column

    rows = visible_open_conversations.where.not(column => nil).group(column)
                                     .pluck(column, Arel.sql('COUNT(*)'), Arel.sql('COUNT(*) FILTER (WHERE waiting_since IS NOT NULL)'))
    render json: { payload: rows.map { |id, open_count, waiting_count| { id: id, open_count: open_count, waiting_count: waiting_count } } }
  end

  private

  def visible_open_conversations
    Conversations::PermissionFilterService.new(Current.account.conversations.open, Current.user, Current.account).perform
  end
end
