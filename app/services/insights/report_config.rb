# What an Insights report shows: metrics, up to 3 dimensions to group by, filters, the period and an optional period to compare with.
# Built from request params and, later, from saved reports, so every entry point is validated the same way.
class Insights::ReportConfig
  include ActiveModel::Model

  METRICS = %w[
    received resolved open reopened first_response_time median_first_response_time resolution_time median_resolution_time
    first_response_sla resolution_sla
  ].freeze
  DIMENSIONS = %w[market team category subcategory agent inbox].freeze
  TIME_DIMENSIONS = %w[day week month].freeze
  FILTERS = %w[market_ids team_ids category_ids agent_ids inbox_ids priorities].freeze
  PRIORITIES = %w[low medium high urgent].freeze
  MAX_GROUP_BY = 3
  MAX_RANGE = 366.days

  PERMITTED_PARAMS = [:period, :since, :until, :compare, :compare_since, :compare_until, :business_hours, :timezone,
                      { metrics: [], group_by: [], filters: FILTERS.index_with { [] } }].freeze

  attr_reader :metrics, :group_by, :filters, :period, :compare, :since, :until, :compare_since, :compare_until, :business_hours, :timezone

  validates :metrics, presence: true
  validate :known_choices, :known_periods, :known_filters, :valid_ranges, :supported_combinations

  def initialize(params)
    params = params.to_h.with_indifferent_access
    @metrics = list(params[:metrics])
    @group_by = list(params[:group_by])
    @filters = params.fetch(:filters, {}).to_h.slice(*FILTERS).transform_values { |values| list(values) }
    @business_hours = ActiveModel::Type::Boolean.new.cast(params[:business_hours]) || false
    @timezone = params[:timezone].presence || 'UTC'
    assign_periods(params)
  end

  def range
    Time.zone.at(since)..Time.zone.at(self.until)
  end

  def compare_range
    Time.zone.at(compare_since)..Time.zone.at(compare_until) if compare?
  end

  def compare?
    compare.present?
  end

  def time_dimension
    (group_by & TIME_DIMENSIONS).first
  end

  def tz_identifier
    ActiveSupport::TimeZone[timezone].tzinfo.identifier
  end

  def filter_ids(key)
    filters.fetch(key, []).map(&:to_i)
  end

  def to_h
    { metrics: metrics, group_by: group_by, filters: filters, period: period, since: since, until: self.until, compare: compare,
      compare_since: compare_since, compare_until: compare_until, business_hours: business_hours, timezone: timezone }
  end

  # What a saved report keeps: named periods without their dates, so they move on with time
  def definition
    hash = to_h
    hash.except!(:since, :until) unless period == 'custom'
    hash.except!(:compare_since, :compare_until) unless compare == 'custom'
    hash.compact
  end

  private

  def list(values)
    Array(values).map(&:to_s).uniq
  end

  def integer(value)
    Integer(value.to_s, exception: false) if value.present?
  end

  def assign_periods(params)
    @since, @until, @compare_since, @compare_until = params.values_at(:since, :until, :compare_since, :compare_until).map { |value| integer(value) }
    @period = params[:period].presence || 'custom'
    @compare = params[:compare].presence || ('custom' if compare_since || compare_until)
    resolve_named_periods
  end

  # Named periods get their dates now; a named comparison gets its dates from the period, named or not
  def resolve_named_periods
    resolved = resolved_period
    return unless resolved

    @since, @until = resolved.range.map(&:to_i)
    @compare_since, @compare_until = resolved.compare_range(compare).map(&:to_i) if Insights::Period::COMPARISONS.include?(compare)
  end

  def resolved_period
    return if ActiveSupport::TimeZone[timezone].nil?
    return Insights::Period.new(period, timezone) if Insights::Period::PRESETS.include?(period)

    Insights::Period.new(period, timezone, custom: [Time.zone.at(since), Time.zone.at(self.until)]) if since && self.until
  end

  def known_choices
    errors.add(:metrics, :inclusion) if (metrics - METRICS).any?
    errors.add(:group_by, :inclusion) if (group_by - DIMENSIONS - TIME_DIMENSIONS).any?
    errors.add(:group_by, :too_long, count: MAX_GROUP_BY) if group_by.size > MAX_GROUP_BY
    errors.add(:timezone, :invalid) if ActiveSupport::TimeZone[timezone].nil?
  end

  def known_periods
    errors.add(:period, :inclusion) unless [*Insights::Period::PRESETS, 'custom'].include?(period)
    errors.add(:compare, :inclusion) unless [nil, *Insights::Period::COMPARISONS, 'custom'].include?(compare)
  end

  def known_filters
    errors.add(:filters, :invalid) if (filters.fetch('priorities', []) - PRIORITIES).any?
    errors.add(:filters, :invalid) if filters.except('priorities').values.flatten.any? { |id| id !~ /\A\d+\z/ }
  end

  def valid_ranges
    errors.add(:base, I18n.t('errors.insights.invalid_range')) unless valid_range?(since, self.until)
    errors.add(:base, I18n.t('errors.insights.invalid_compare_range')) if compare? && !valid_range?(compare_since, compare_until)
  end

  def valid_range?(from, to)
    from.present? && to.present? && from < to && (to - from) <= MAX_RANGE.to_i
  end

  def supported_combinations
    errors.add(:group_by, I18n.t('errors.insights.one_time_dimension')) if (group_by & TIME_DIMENSIONS).size > 1
    return unless time_dimension

    errors.add(:metrics, I18n.t('errors.insights.open_over_time')) if metrics.include?('open')
    errors.add(:base, I18n.t('errors.insights.compare_over_time')) if compare?
  end
end
