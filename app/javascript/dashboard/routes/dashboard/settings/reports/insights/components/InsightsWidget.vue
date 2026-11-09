<script setup>
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import {
  isAbortError,
  useAbortableRequest,
} from 'dashboard/composables/useAbortableRequest';
import InsightsAPI from 'dashboard/api/insights';
import BarChart from 'shared/components/charts/BarChart.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import { useInsightFormat } from '../useInsightFormat';

const props = defineProps({
  widget: { type: Object, required: true },
  // The widget's report settings with the dashboard's filters applied
  params: { type: Object, required: true },
  // Changes whenever the dashboard refreshes
  refreshKey: { type: Number, default: 0 },
  editing: { type: Boolean, default: false },
  isFirst: { type: Boolean, default: false },
  isLast: { type: Boolean, default: false },
});

const emit = defineEmits(['drill', 'edit', 'remove', 'move', 'loaded']);

const WIDGET_ROW_LIMIT = 10;

const { t } = useI18n();
const { metricLabel, formatValue, rowLabel, change, dimensionLabel } =
  useInsightFormat();
const { run, isPending } = useAbortableRequest();

const result = ref(null);
const failed = ref(false);

const metric = computed(() => props.widget.metric);
const groupBy = computed(() => props.params.group_by || []);
const rows = computed(() =>
  (result.value?.rows || []).slice(0, WIDGET_ROW_LIMIT)
);
const total = computed(() => result.value?.totals[metric.value]);
const totalChange = computed(() =>
  result.value?.previous_totals
    ? change(
        metric.value,
        total.value,
        result.value.previous_totals[metric.value]
      )
    : null
);
const showsRows = computed(
  () => props.widget.display !== 'number' && groupBy.value.length
);

const chartData = computed(() => ({
  categories: rows.value.map(row =>
    rowLabel(row.dimensions, result.value.labels, groupBy.value)
  ),
  series: [
    {
      id: 'current',
      label: metricLabel(metric.value),
      color: 'rgb(var(--blue-9))',
      data: rows.value.map(row => row.metrics[metric.value] ?? 0),
    },
  ],
}));

const CHANGE_TONES = {
  good: 'text-n-teal-11',
  bad: 'text-n-ruby-11',
  neutral: 'text-n-slate-11',
};

const load = async () => {
  try {
    const response = await run(signal =>
      InsightsAPI.query(props.params, { signal })
    );
    if (response) {
      result.value = response.data;
      failed.value = false;
      emit('loaded');
    }
  } catch (error) {
    if (!isAbortError(error)) failed.value = true;
  }
};

const drill = (dimensions, metricKey = metric.value) =>
  emit('drill', {
    figure: { metric: metricKey, dimensions, previous: false },
    params: props.params,
    labels: result.value.labels,
  });

// The page builds params afresh on every render, so reload only when they really change or the dashboard refreshes
const paramsKey = computed(() => JSON.stringify(props.params));
watch([paramsKey, () => props.refreshKey], load, { immediate: true });
</script>

<template>
  <div
    class="flex flex-col gap-3 p-4 rounded-xl outline outline-1 outline-n-weak bg-n-solid-1 min-h-40"
    :class="{ 'md:col-span-2': widget.display === 'table' }"
  >
    <div class="flex items-start justify-between gap-2">
      <div class="flex flex-col min-w-0">
        <span class="text-body-main font-medium text-n-slate-12 truncate">
          {{ widget.title || metricLabel(metric) }}
        </span>
        <span class="text-label-small text-n-slate-11">
          {{ metricLabel(metric) }}
          <template v-if="groupBy.length">
            · {{ groupBy.map(dimensionLabel).join(', ') }}
          </template>
        </span>
      </div>
      <div v-if="editing" class="flex items-center gap-1 shrink-0">
        <Button
          v-tooltip.top="t('INSIGHTS.DASHBOARD.MOVE_EARLIER')"
          icon="i-lucide-arrow-left"
          slate
          ghost
          xs
          :disabled="isFirst"
          @click="emit('move', -1)"
        />
        <Button
          v-tooltip.top="t('INSIGHTS.DASHBOARD.MOVE_LATER')"
          icon="i-lucide-arrow-right"
          slate
          ghost
          xs
          :disabled="isLast"
          @click="emit('move', 1)"
        />
        <Button
          v-tooltip.top="t('INSIGHTS.DASHBOARD.EDIT_WIDGET')"
          icon="i-woot-edit-pen"
          slate
          ghost
          xs
          @click="emit('edit')"
        />
        <Button
          v-tooltip.top="t('INSIGHTS.DASHBOARD.REMOVE_WIDGET')"
          icon="i-woot-bin"
          slate
          ghost
          xs
          class="hover:enabled:text-n-ruby-11"
          @click="emit('remove')"
        />
      </div>
      <Spinner v-else-if="isPending && result" class="size-4 shrink-0" />
    </div>

    <div v-if="!result && isPending" class="flex justify-center py-6">
      <Spinner />
    </div>
    <p v-else-if="failed" class="mb-0 text-label-small text-n-ruby-11">
      {{ t('INSIGHTS.DASHBOARD.WIDGET_ERROR') }}
    </p>
    <template v-else-if="result">
      <button
        type="button"
        class="flex flex-col items-start gap-1 text-start"
        :title="t('INSIGHTS.RESULTS.DRILL')"
        @click="drill({})"
      >
        <span class="text-heading-2 text-n-slate-12 tabular-nums">
          {{ formatValue(metric, total) }}
        </span>
        <span
          v-if="totalChange"
          class="text-label-small"
          :class="CHANGE_TONES[totalChange.tone]"
        >
          {{ t('INSIGHTS.RESULTS.CHANGE', { change: totalChange.text }) }}
        </span>
      </button>

      <template v-if="showsRows && rows.length">
        <BarChart
          v-if="widget.display === 'bar'"
          :data="chartData"
          :aria-label="metricLabel(metric)"
          :format-value="value => formatValue(metric, value)"
          :height="200"
          :timeseries="
            groupBy.some(item => ['day', 'week', 'month'].includes(item))
          "
          clickable
          @item-click="({ pointIndex }) => drill(rows[pointIndex].dimensions)"
        />
        <table v-else class="w-full text-sm">
          <tbody>
            <tr
              v-for="(row, index) in rows"
              :key="index"
              class="border-t border-n-weak first:border-t-0"
            >
              <td class="py-1.5 pe-2 text-n-slate-12">
                {{ rowLabel(row.dimensions, result.labels, groupBy) }}
              </td>
              <td
                v-for="key in params.metrics"
                :key="key"
                class="py-1.5 ps-2 text-end whitespace-nowrap"
              >
                <button
                  type="button"
                  class="tabular-nums hover:text-n-blue-11 hover:underline"
                  :class="
                    key === metric ? 'text-n-slate-12' : 'text-n-slate-11'
                  "
                  :title="metricLabel(key)"
                  @click="drill(row.dimensions, key)"
                >
                  {{ formatValue(key, row.metrics[key]) }}
                </button>
              </td>
            </tr>
          </tbody>
        </table>
      </template>
    </template>
  </div>
</template>
