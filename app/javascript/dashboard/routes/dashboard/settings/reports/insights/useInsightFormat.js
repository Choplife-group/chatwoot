import { useI18n } from 'vue-i18n';
import { formatTime } from '@chatwoot/utils';
import format from 'date-fns/format';
import parseISO from 'date-fns/parseISO';
import { LOWER_IS_BETTER, METRIC_TYPES, TIME_DIMENSIONS } from './constants';

const TIME_FORMATS = {
  day: 'd MMM yyyy',
  week: 'd MMM yyyy',
  month: 'MMM yyyy',
};

/** Labels and number formats shared by the builder, results, snapshots and drill-down */
export function useInsightFormat() {
  const { t } = useI18n();

  const metricLabel = metric => t(`INSIGHTS.METRICS.${metric.toUpperCase()}`);
  const dimensionLabel = dimension =>
    t(`INSIGHTS.DIMENSIONS.${dimension.toUpperCase()}`);

  const formatValue = (metric, value) => {
    if (value === null || value === undefined) return '—';
    if (METRIC_TYPES[metric] === 'time')
      return formatTime(value) || `${Math.round(value)}s`;
    if (METRIC_TYPES[metric] === 'percent') return `${value}%`;
    return value.toLocaleString();
  };

  const dimensionValueLabel = (dimension, value, labels = {}) => {
    if (value === null || value === undefined) return t('INSIGHTS.NONE');
    if (TIME_DIMENSIONS.includes(dimension)) {
      const date = format(parseISO(value), TIME_FORMATS[dimension]);
      return dimension === 'week'
        ? t('INSIGHTS.TIME_LABELS.WEEK_OF', { date })
        : date;
    }
    return labels[dimension]?.[value] ?? `#${value}`;
  };

  // In the report's grouping order: stored snapshots don't keep the order of their keys
  const rowLabel = (dimensions, labels, order = Object.keys(dimensions)) =>
    order
      .map(dimension =>
        dimensionValueLabel(dimension, dimensions[dimension], labels)
      )
      .join(' · ') || t('INSIGHTS.RESULTS.TOTAL');

  // The change from the compared period, and whether it's good news for this metric
  const change = (metric, current, previous) => {
    if (current === null || previous === null || current === undefined)
      return null;
    if (previous === undefined) return null;
    const difference = current - previous;
    if (difference === 0) return { text: '0%', tone: 'neutral' };
    const better = LOWER_IS_BETTER.includes(metric)
      ? difference < 0
      : difference > 0;
    const text =
      METRIC_TYPES[metric] === 'percent' || previous === 0
        ? `${difference > 0 ? '+' : ''}${formatValue(metric, Math.round(difference * 10) / 10)}`
        : `${difference > 0 ? '+' : ''}${Math.round((difference / previous) * 100)}%`;
    return { text, tone: better ? 'good' : 'bad' };
  };

  return {
    metricLabel,
    dimensionLabel,
    formatValue,
    dimensionValueLabel,
    rowLabel,
    change,
  };
}
