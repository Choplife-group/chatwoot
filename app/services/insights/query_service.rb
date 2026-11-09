# Works out an Insights report: each metric grouped by the chosen dimensions, totals, and the same for the comparison period
class Insights::QueryService
  MAX_ROWS = 1000
  COUNT_METRICS = %w[received resolved open reopened].freeze

  attr_reader :account, :config, :visibility

  def initialize(account:, user:, config:)
    @account = account
    @config = config
    @visibility = Insights::Visibility.new(account, user)
  end

  def perform
    current = figures(config.range)
    previous = figures(config.compare_range) if config.compare?
    keys = sorted_keys(current, previous)
    rows = keys.first(MAX_ROWS).map { |key| row(key, current, previous) }

    {
      rows: rows,
      totals: current[:totals],
      previous_totals: previous&.dig(:totals),
      truncated: keys.size > MAX_ROWS,
      labels: Insights::Labels.new(account, label_dimensions.index_with { |dimension| rows.pluck(:dimensions).pluck(dimension) }).perform
    }
  end

  private

  def figures(range)
    rows = Hash.new { |hash, key| hash[key] = {} }
    totals = config.metrics.index_with do |metric|
      scope = Insights::MetricScope.new(account: account, config: config, visibility: visibility, metric: metric)
      relation = scope.relation(range)
      aggregate = Arel.sql(scope.aggregate_sql)
      add_grouped_figures(rows, metric, scope, relation, aggregate) if config.group_by.any?
      number(relation.pick(aggregate))
    end
    { rows: rows, totals: totals }
  end

  def add_grouped_figures(rows, metric, scope, relation, aggregate)
    dimensions = config.group_by.map { |dimension| Arel.sql(scope.dimension_sql(dimension)) }
    relation.group(*dimensions).pluck(*dimensions, aggregate).each do |*key, value|
      rows[key.map { |part| dimension_value(part) }][metric] = number(value)
    end
  end

  def label_dimensions
    config.group_by - Insights::ReportConfig::TIME_DIMENSIONS
  end

  def row(key, current, previous)
    {
      dimensions: config.group_by.zip(key).to_h,
      metrics: metrics_for(current[:rows][key]),
      previous: (metrics_for(previous[:rows][key]) if previous)
    }.compact
  end

  def metrics_for(values)
    config.metrics.index_with { |metric| values&.fetch(metric, nil) || (COUNT_METRICS.include?(metric) ? 0 : nil) }
  end

  # Over time in date order; otherwise largest first by the first metric
  def sorted_keys(current, previous)
    keys = (current[:rows].keys + (previous ? previous[:rows].keys : [])).uniq
    return keys.sort_by { |key| key.map(&:to_s) } if config.time_dimension

    metric = config.metrics.first
    keys.sort_by { |key| -(current[:rows].dig(key, metric) || 0) }
  end

  def dimension_value(value)
    value.respond_to?(:to_date) ? value.to_date.iso8601 : value
  end

  def number(value)
    return if value.nil?

    value.is_a?(Integer) ? value : value.to_f.round(1)
  end
end
