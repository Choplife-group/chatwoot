# The rows behind one Insights metric in one period, already limited to what the user may see and to the report's filters,
# plus the SQL for its dimensions and its aggregate. QueryService totals these rows; DrilldownService lists them.
class Insights::MetricScope
  EVENT_NAMES = {
    'resolved' => 'conversation_resolved',
    'resolution_time' => 'conversation_resolved',
    'median_resolution_time' => 'conversation_resolved',
    'resolution_sla' => 'conversation_resolved',
    'first_response_time' => 'first_response',
    'median_first_response_time' => 'first_response',
    'first_response_sla' => 'first_response',
    'reopened' => 'conversation_opened'
  }.freeze
  SLA_TARGET_COLUMNS = { 'first_response_sla' => 'first_response_seconds', 'resolution_sla' => 'resolution_seconds' }.freeze
  CATEGORY_SQL = 'COALESCE(insight_categories.ancestor_ids[1], insight_categories.id)'.freeze
  EVENT_COLUMNS = {
    'market' => 'reporting_events.market_id',
    'team' => 'reporting_events.team_id',
    'category' => CATEGORY_SQL,
    'subcategory' => 'reporting_events.category_id',
    'agent' => 'reporting_events.user_id',
    'inbox' => 'reporting_events.inbox_id',
    'time' => 'reporting_events.event_end_time'
  }.freeze
  CONVERSATION_COLUMNS = {
    'market' => 'conversations.market_id',
    'team' => 'conversations.team_id',
    'category' => CATEGORY_SQL,
    'subcategory' => 'conversations.category_id',
    'agent' => 'conversations.assignee_id',
    'inbox' => 'conversations.inbox_id',
    'time' => 'conversations.created_at'
  }.freeze
  FILTER_DIMENSIONS = { 'market_ids' => 'market', 'team_ids' => 'team', 'agent_ids' => 'agent', 'inbox_ids' => 'inbox' }.freeze

  attr_reader :account, :config, :visibility, :metric

  def initialize(account:, config:, visibility:, metric:)
    @account = account
    @config = config
    @visibility = visibility
    @metric = metric
  end

  def event_metric?
    EVENT_NAMES.key?(metric)
  end

  def sla_metric?
    SLA_TARGET_COLUMNS.key?(metric)
  end

  def relation(range, with_conversation: false)
    event_metric? ? event_relation(range, with_conversation) : conversation_relation(range)
  end

  def dimension_sql(dimension)
    return columns.fetch(dimension) unless Insights::ReportConfig::TIME_DIMENSIONS.include?(dimension)

    zone = ActiveRecord::Base.connection.quote(config.tz_identifier)
    "date_trunc('#{dimension}', (#{columns['time']} AT TIME ZONE 'UTC') AT TIME ZONE #{zone})"
  end

  def aggregate_sql
    case metric
    when 'first_response_time', 'resolution_time' then "AVG(#{value_column})"
    when 'median_first_response_time', 'median_resolution_time' then "percentile_cont(0.5) WITHIN GROUP (ORDER BY #{value_column})"
    when 'first_response_sla', 'resolution_sla' then "ROUND(100.0 * COUNT(*) FILTER (WHERE #{sla_met_sql}) / NULLIF(COUNT(*), 0), 1)"
    else 'COUNT(*)'
    end
  end

  def columns
    event_metric? ? EVENT_COLUMNS : CONVERSATION_COLUMNS
  end

  def value_column
    config.business_hours ? 'reporting_events.value_in_business_hours' : 'reporting_events.value'
  end

  # Each target says whether it counts business hours, so SLA ignores the report's business hours switch
  def sla_met_sql
    'CASE WHEN insight_sla_targets.business_hours THEN reporting_events.value_in_business_hours ' \
      'ELSE reporting_events.value END <= insight_sla_targets.seconds'
  end

  private

  def event_relation(range, with_conversation)
    scope = ReportingEvent.where(account_id: account.id, name: EVENT_NAMES.fetch(metric), event_end_time: range)
                          .joins(category_join('reporting_events'))
    scope = first_reopenings(scope) if metric == 'reopened'
    scope = scope.joins('INNER JOIN conversations ON conversations.id = reporting_events.conversation_id') if joins_conversation?(with_conversation)
    scope = scope.joins(sla_target_join) if sla_metric?
    scope = apply_filters(scope)
    visibility.apply(scope, team_column: 'reporting_events.team_id', agent_column: 'reporting_events.user_id')
  end

  def conversation_relation(range)
    scope = metric == 'open' ? open_at(range.end) : account.conversations.where(created_at: range)
    scope = apply_filters(scope.joins(category_join('conversations')))
    visibility.apply(scope, team_column: 'conversations.team_id', agent_column: 'conversations.assignee_id')
  end

  def joins_conversation?(with_conversation)
    with_conversation || sla_metric? || config.filters['priorities'].present?
  end

  def category_join(table)
    "LEFT JOIN conversation_categories insight_categories ON insight_categories.id = #{table}.category_id"
  end

  # A conversation is opened again after a resolve once; later opens (after snoozing, say) carry the same resolve time
  def first_reopenings(scope)
    scope.where('reporting_events.value > 0').where(<<~SQL.squish)
      NOT EXISTS (
        SELECT 1 FROM reporting_events earlier
        WHERE earlier.conversation_id = reporting_events.conversation_id AND earlier.name = 'conversation_opened'
          AND earlier.value > 0 AND earlier.event_start_time = reporting_events.event_start_time AND earlier.id < reporting_events.id
      )
    SQL
  end

  # Conversations not resolved at that moment: no resolve before it, or a reopen after their latest resolve.
  # Only conversations unresolved now, or resolved again since, can qualify, which keeps the scan small.
  def open_at(moment)
    created = account.conversations.where('conversations.created_at <= ?', moment)
    resolved_since = ReportingEvent.where(account_id: account.id, name: 'conversation_resolved').where('event_end_time > ?', moment)
    created.where.not(status: :resolved).or(created.where(id: resolved_since.select(:conversation_id))).where(<<~SQL.squish, moment: moment)
      NOT EXISTS (
        SELECT 1 FROM reporting_events resolves
        WHERE resolves.conversation_id = conversations.id AND resolves.name = 'conversation_resolved' AND resolves.event_end_time <= :moment
          AND NOT EXISTS (
            SELECT 1 FROM reporting_events reopens
            WHERE reopens.conversation_id = conversations.id AND reopens.name = 'conversation_opened' AND reopens.value > 0
              AND reopens.event_end_time > resolves.event_end_time AND reopens.event_end_time <= :moment
          )
      )
    SQL
  end

  # The most specific target wins: market and priority, then market, then priority, then the default
  def sla_target_join
    column = SLA_TARGET_COLUMNS.fetch(metric)
    <<~SQL.squish
      INNER JOIN LATERAL (
        SELECT sla_targets.#{column} AS seconds, sla_targets.business_hours
        FROM sla_targets
        WHERE sla_targets.account_id = reporting_events.account_id AND sla_targets.#{column} IS NOT NULL
          AND (sla_targets.market_id = reporting_events.market_id OR sla_targets.market_id IS NULL)
          AND (sla_targets.priority = conversations.priority OR sla_targets.priority IS NULL)
        ORDER BY sla_targets.market_id IS NULL, sla_targets.priority IS NULL
        LIMIT 1
      ) insight_sla_targets ON true
    SQL
  end

  def apply_filters(scope)
    FILTER_DIMENSIONS.each do |filter, dimension|
      ids = config.filter_ids(filter)
      scope = scope.where("#{columns.fetch(dimension)} IN (?)", ids) if ids.any?
    end
    category_ids = config.filter_ids('category_ids')
    scope = scope.where("#{columns.fetch('subcategory')} IN (?)", ConversationCategory.subtree_ids(account, category_ids)) if category_ids.any?
    priorities = config.filters['priorities']
    scope = scope.where(conversations: { priority: priorities }) if priorities.present?
    scope
  end
end
