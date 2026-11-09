# Turns a named period ("last_month") into dates in the report's time zone, and finds the period to compare a period with.
# Saved and scheduled reports keep the name, so "last month" always means the month before the one they run in.
class Insights::Period
  PRESETS = %w[today yesterday last_7_days last_30_days last_90_days this_week last_week this_month last_month this_year].freeze
  COMPARISONS = %w[previous_period previous_year].freeze
  CALENDAR_STEPS = {
    'today' => 1.day, 'yesterday' => 1.day, 'this_week' => 1.week, 'last_week' => 1.week,
    'this_month' => 1.month, 'last_month' => 1.month, 'this_year' => 1.year
  }.freeze

  # custom: the [since, until] of a period that isn't named
  def initialize(preset, zone, now: Time.current, custom: nil)
    @preset = preset
    @now = now.in_time_zone(zone)
    @custom = custom&.map { |time| time.in_time_zone(zone) }
  end

  def range
    return @custom if @custom

    today = @now.beginning_of_day
    case @preset
    when 'today', 'this_week', 'this_month', 'this_year' then [@now.public_send(:"beginning_of_#{calendar_unit}"), @now]
    when 'yesterday' then [today - 1.day, (today - 1.day).end_of_day]
    when 'last_week' then [(@now - 1.week).beginning_of_week, (@now - 1.week).end_of_week]
    when 'last_month' then [(@now - 1.month).beginning_of_month, (@now - 1.month).end_of_month]
    else [today - (days - 1).days, @now]
    end
  end

  # The same stretch one step back: the month before a month, the week before a week, the days just before a run of days.
  # A finished month compares with the whole month before it; a month so far with the same days of the month before.
  def compare_range(comparison)
    since, to = range
    step = comparison == 'previous_year' ? 1.year : self.step(since, to)
    return [since - step, (since - step).end_of_month] if @preset == 'last_month' && comparison == 'previous_period'

    [since - step, to - step]
  end

  def step(since, to)
    return to - since + 1.second if @custom

    CALENDAR_STEPS[@preset] || days.days
  end

  private

  def days
    @preset[/\d+/].to_i
  end

  def calendar_unit
    { 'today' => 'day', 'this_week' => 'week', 'this_month' => 'month', 'this_year' => 'year' }.fetch(@preset)
  end
end
