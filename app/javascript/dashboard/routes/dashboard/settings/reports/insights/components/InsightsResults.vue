<script setup>
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import BarChart from 'shared/components/charts/BarChart.vue';
import Select from 'dashboard/components-next/select/Select.vue';
import { CHART_ROW_LIMIT, TIME_DIMENSIONS } from '../constants';
import { useInsightFormat } from '../useInsightFormat';

const props = defineProps({
  // The query response: rows, totals, previous_totals, labels, truncated
  result: { type: Object, required: true },
  metrics: { type: Array, required: true },
  groupBy: { type: Array, required: true },
  // Snapshots keep figures only, so their numbers don't open conversations
  drillable: { type: Boolean, default: true },
});

const emit = defineEmits(['drill']);

const { t } = useI18n();
const { metricLabel, dimensionLabel, formatValue, rowLabel, change } =
  useInsightFormat();

const CHANGE_TONES = {
  good: 'text-n-teal-11',
  bad: 'text-n-ruby-11',
  neutral: 'text-n-slate-11',
};

const chartMetric = ref(props.metrics[0]);
watch(
  () => props.metrics,
  metrics => {
    if (!metrics.includes(chartMetric.value)) [chartMetric.value] = metrics;
  }
);

const hasPrevious = computed(() => !!props.result.previous_totals);
const isTimeSeries = computed(() =>
  props.groupBy.some(dimension => TIME_DIMENSIONS.includes(dimension))
);
const chartRows = computed(() => props.result.rows.slice(0, CHART_ROW_LIMIT));

const chartData = computed(() => ({
  categories: chartRows.value.map(row =>
    rowLabel(row.dimensions, props.result.labels, props.groupBy)
  ),
  series: [
    {
      id: 'current',
      label: t('INSIGHTS.RESULTS.CURRENT'),
      color: 'rgb(var(--blue-9))',
      data: chartRows.value.map(row => row.metrics[chartMetric.value] ?? 0),
    },
    ...(hasPrevious.value
      ? [
          {
            id: 'previous',
            label: t('INSIGHTS.RESULTS.PREVIOUS'),
            color: 'rgb(var(--slate-8))',
            data: chartRows.value.map(
              row => row.previous?.[chartMetric.value] ?? 0
            ),
          },
        ]
      : []),
  ],
}));

const chartOptions = computed(() =>
  props.metrics.map(metric => ({ value: metric, label: metricLabel(metric) }))
);

const valueFormatter = value => formatValue(chartMetric.value, value);
const totalChange = metric =>
  hasPrevious.value
    ? change(
        metric,
        props.result.totals[metric],
        props.result.previous_totals[metric]
      )
    : null;
const rowChange = (row, metric) =>
  row.previous
    ? change(metric, row.metrics[metric], row.previous[metric])
    : null;

const drill = (metric, dimensions, previous = false) => {
  if (!props.drillable) return;
  const ordered = Object.fromEntries(
    props.groupBy
      .filter(dimension => dimension in dimensions)
      .map(dimension => [dimension, dimensions[dimension]])
  );
  emit('drill', { metric, dimensions: ordered, previous });
};

const onChartClick = ({ seriesId, pointIndex }) => {
  const row = chartRows.value[pointIndex];
  if (row) drill(chartMetric.value, row.dimensions, seriesId === 'previous');
};
</script>

<template>
  <div class="flex flex-col gap-4">
    <div class="grid grid-cols-2 gap-3 md:grid-cols-4">
      <button
        v-for="metric in metrics"
        :key="metric"
        type="button"
        class="flex flex-col items-start gap-1 p-4 text-start rounded-xl outline outline-1 outline-n-weak bg-n-solid-1 enabled:hover:bg-n-alpha-1"
        :disabled="!drillable"
        :title="drillable ? t('INSIGHTS.RESULTS.DRILL') : undefined"
        @click="drill(metric, {})"
      >
        <span class="text-label-small text-n-slate-11">
          {{ metricLabel(metric) }}
        </span>
        <span class="text-heading-2 text-n-slate-12">
          {{ formatValue(metric, result.totals[metric]) }}
        </span>
        <span
          v-if="totalChange(metric)"
          class="text-label-small"
          :class="CHANGE_TONES[totalChange(metric).tone]"
        >
          {{
            t('INSIGHTS.RESULTS.CHANGE', { change: totalChange(metric).text })
          }}
        </span>
      </button>
    </div>

    <template v-if="result.rows.length">
      <div
        v-if="groupBy.length"
        class="flex flex-col gap-3 p-4 rounded-xl outline outline-1 outline-n-weak bg-n-solid-1"
      >
        <div class="flex items-center justify-between gap-3">
          <span class="text-label-small text-n-slate-11">
            <template v-if="result.rows.length > CHART_ROW_LIMIT">
              {{ t('INSIGHTS.RESULTS.CHART_LIMIT', { n: CHART_ROW_LIMIT }) }}
            </template>
          </span>
          <Select
            v-model="chartMetric"
            :options="chartOptions"
            :aria-label="t('INSIGHTS.RESULTS.CHART_METRIC')"
          />
        </div>
        <BarChart
          :data="chartData"
          :aria-label="metricLabel(chartMetric)"
          :format-value="valueFormatter"
          :height="280"
          :timeseries="isTimeSeries"
          :clickable="drillable"
          @item-click="onChartClick"
        />
      </div>

      <div
        class="overflow-x-auto rounded-xl outline outline-1 outline-n-weak bg-n-solid-1"
      >
        <table class="w-full text-sm">
          <thead>
            <tr class="text-start text-label-small text-n-slate-11">
              <th
                v-for="dimension in groupBy"
                :key="dimension"
                class="px-4 py-3 font-medium text-start whitespace-nowrap"
              >
                {{ dimensionLabel(dimension) }}
              </th>
              <th
                v-for="metric in metrics"
                :key="metric"
                class="px-4 py-3 font-medium text-end whitespace-nowrap"
              >
                {{ metricLabel(metric) }}
              </th>
            </tr>
          </thead>
          <tbody>
            <tr
              v-for="(row, index) in result.rows"
              :key="index"
              class="border-t border-n-weak"
            >
              <td
                v-for="dimension in groupBy"
                :key="dimension"
                class="px-4 py-2 text-n-slate-12 whitespace-nowrap"
              >
                {{
                  rowLabel(
                    { [dimension]: row.dimensions[dimension] },
                    result.labels
                  )
                }}
              </td>
              <td
                v-for="metric in metrics"
                :key="metric"
                class="px-4 py-2 text-end whitespace-nowrap"
              >
                <button
                  type="button"
                  class="text-n-slate-12 tabular-nums enabled:hover:text-n-blue-11 enabled:hover:underline"
                  :disabled="!drillable || row.metrics[metric] === null"
                  @click="drill(metric, row.dimensions)"
                >
                  {{ formatValue(metric, row.metrics[metric]) }}
                </button>
                <div
                  v-if="row.previous"
                  class="flex justify-end gap-1 text-label-small"
                >
                  <button
                    type="button"
                    class="text-n-slate-10 tabular-nums enabled:hover:underline"
                    :disabled="!drillable || row.previous[metric] === null"
                    @click="drill(metric, row.dimensions, true)"
                  >
                    {{ formatValue(metric, row.previous[metric]) }}
                  </button>
                  <span
                    v-if="rowChange(row, metric)"
                    :class="CHANGE_TONES[rowChange(row, metric).tone]"
                  >
                    {{ rowChange(row, metric).text }}
                  </span>
                </div>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
      <p v-if="result.truncated" class="mb-0 text-label-small text-n-slate-11">
        {{ t('INSIGHTS.RESULTS.TRUNCATED') }}
      </p>
    </template>
    <p
      v-else-if="groupBy.length"
      class="py-10 mb-0 text-center text-body-main text-n-slate-11"
    >
      {{ t('INSIGHTS.RESULTS.NO_DATA') }}
    </p>
  </div>
</template>
