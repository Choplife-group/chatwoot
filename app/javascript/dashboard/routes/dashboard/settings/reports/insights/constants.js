export const METRIC_TYPES = {
  received: 'count',
  resolved: 'count',
  open: 'count',
  reopened: 'count',
  first_response_time: 'time',
  median_first_response_time: 'time',
  resolution_time: 'time',
  median_resolution_time: 'time',
  first_response_sla: 'percent',
  resolution_sla: 'percent',
};

export const METRICS = Object.keys(METRIC_TYPES);

// Lower is better for times; higher is better for everything else except open and reopened
export const LOWER_IS_BETTER = [
  'open',
  'reopened',
  'first_response_time',
  'median_first_response_time',
  'resolution_time',
  'median_resolution_time',
];

export const DIMENSIONS = [
  'market',
  'team',
  'category',
  'subcategory',
  'agent',
  'inbox',
];

export const TIME_DIMENSIONS = ['day', 'week', 'month'];

export const MAX_GROUP_BY = 3;

export const PERIODS = [
  'today',
  'yesterday',
  'last_7_days',
  'last_30_days',
  'last_90_days',
  'this_week',
  'last_week',
  'this_month',
  'last_month',
  'this_year',
  'custom',
];

export const COMPARISONS = ['previous_period', 'previous_year'];

export const PRIORITIES = ['low', 'medium', 'high', 'urgent'];

export const FILTER_DIMENSIONS = {
  market_ids: 'market',
  team_ids: 'team',
  category_ids: 'category',
  agent_ids: 'agent',
  inbox_ids: 'inbox',
};

export const CHART_ROW_LIMIT = 20;

export const QUERY_DEBOUNCE_MS = 300;

export const defaultConfig = () => ({
  metrics: ['received', 'resolved', 'first_response_time', 'resolution_time'],
  group_by: ['market'],
  filters: {},
  period: 'last_7_days',
  compare: 'previous_period',
  business_hours: false,
  timezone: Intl.DateTimeFormat().resolvedOptions().timeZone,
});
