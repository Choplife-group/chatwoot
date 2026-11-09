# The conversations behind one figure of an Insights report: the same rows the figure was worked out from, a page at a time
class Insights::DrilldownService
  PER_PAGE = 25
  ROW_DIMENSIONS = %w[market team subcategory agent inbox].freeze

  # figure: the metric, the row's dimension values, and whether it's from the comparison period
  def initialize(account:, user:, config:, figure:, page: 1)
    @account = account
    @scope = Insights::MetricScope.new(account: account, config: config, visibility: Insights::Visibility.new(account, user), metric: figure[:metric])
    @dimensions = figure[:dimensions]
    @range = figure[:previous] ? config.compare_range : config.range
    @page = [page.to_i, 1].max
  end

  def perform
    relation = filtered_relation
    payload = page_of(relation).map { |record| serialize(record) }

    {
      meta: { metric: @scope.metric, total_count: relation.count, current_page: @page, per_page: PER_PAGE },
      payload: payload,
      labels: Insights::Labels.new(@account, ROW_DIMENSIONS.index_with { |dimension| payload.pluck(:"#{dimension}_id") }).perform
    }
  end

  private

  def page_of(relation)
    relation.reorder(Arel.sql("#{@scope.columns['time']} DESC")).offset((@page - 1) * PER_PAGE).limit(PER_PAGE)
            .pluck(*selected_columns.values.map { |sql| Arel.sql(sql) })
            .map { |values| selected_columns.keys.zip(values).to_h }
  end

  def filtered_relation
    @dimensions.reduce(@scope.relation(@range, with_conversation: true)) do |relation, (dimension, value)|
      sql = @scope.dimension_sql(dimension)
      next relation.where("#{sql} IS NULL") if value.nil?

      cast = Insights::ReportConfig::TIME_DIMENSIONS.include?(dimension) ? '::timestamp' : ''
      relation.where("#{sql} = ?#{cast}", value)
    end
  end

  def selected_columns
    @selected_columns ||= begin
      columns = @scope.columns
      selected = {
        conversation_id: 'conversations.id', display_id: 'conversations.display_id', status: 'conversations.status',
        market_id: columns['market'], team_id: columns['team'], subcategory_id: columns['subcategory'], agent_id: columns['agent'],
        inbox_id: columns['inbox'], happened_at: columns['time']
      }
      selected[:value] = @scope.value_column if @scope.event_metric?
      selected[:sla_met] = @scope.sla_met_sql if @scope.sla_metric?
      selected
    end
  end

  def serialize(record)
    # Conversation sources already return the status name; event sources return the stored number
    record[:status] = Conversation.statuses.key(record[:status]) || record[:status]
    record[:happened_at] = record[:happened_at].to_i
    record[:value] = record[:value]&.round if record.key?(:value)
    record
  end
end
