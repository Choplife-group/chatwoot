<script setup>
import { computed, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import format from 'date-fns/format';
import fromUnixTime from 'date-fns/fromUnixTime';
import { getUnixStartOfDay, getUnixEndOfDay } from 'helpers/DateHelper';
import {
  COMPARISONS,
  DIMENSIONS,
  FILTER_DIMENSIONS,
  MAX_GROUP_BY,
  METRICS,
  PERIODS,
  PRIORITIES,
  TIME_DIMENSIONS,
} from '../constants';
import { useInsightFormat } from '../useInsightFormat';

import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Select from 'dashboard/components-next/select/Select.vue';
import Switch from 'dashboard/components-next/switch/Switch.vue';
import TagMultiSelectComboBox from 'dashboard/components-next/combobox/TagMultiSelectComboBox.vue';

const config = defineModel({ type: Object, required: true });

const { t } = useI18n();
const store = useStore();
const { metricLabel, dimensionLabel } = useInsightFormat();

const markets = useMapGetter('markets/getMarkets');
const teams = useMapGetter('teams/getTeams');
const agents = useMapGetter('agents/getAgents');
const inboxes = useMapGetter('inboxes/getInboxes');
const categoryOptions = useMapGetter('conversationCategories/getPathOptions');

const toOptions = (records, labelKey = 'name') =>
  records.map(record => ({ value: record.id, label: record[labelKey] }));

const filterOptions = computed(() => ({
  market_ids: toOptions(markets.value),
  team_ids: toOptions(teams.value),
  category_ids: toOptions(categoryOptions.value),
  agent_ids: toOptions(agents.value),
  inbox_ids: toOptions(inboxes.value),
  priorities: PRIORITIES.map(priority => ({
    value: priority,
    label: t(`INSIGHTS.PRIORITIES.${priority.toUpperCase()}`),
  })),
}));

const filterLabel = key => dimensionLabel(FILTER_DIMENSIONS[key] || 'priority');

const metricOptions = computed(() =>
  METRICS.map(metric => ({ value: metric, label: metricLabel(metric) }))
);
const periodOptions = computed(() =>
  PERIODS.map(period => ({
    value: period,
    label: t(`INSIGHTS.PERIODS.${period.toUpperCase()}`),
  }))
);
const compareOptions = computed(() => [
  { value: '', label: t('INSIGHTS.BUILDER.NO_COMPARISON') },
  ...COMPARISONS.map(comparison => ({
    value: comparison,
    label: t(`INSIGHTS.COMPARISONS.${comparison.toUpperCase()}`),
  })),
]);

const hasTimeGrouping = computed(() =>
  config.value.group_by.some(dimension => TIME_DIMENSIONS.includes(dimension))
);

// Over time there's nothing to compare row by row, and "open" is a moment, not a period
const groupOptions = index => {
  const taken = config.value.group_by.filter((_, i) => i !== index);
  const takenTime = taken.some(dimension =>
    TIME_DIMENSIONS.includes(dimension)
  );
  return [...DIMENSIONS, ...(takenTime ? [] : TIME_DIMENSIONS)]
    .filter(dimension => !taken.includes(dimension))
    .map(dimension => ({ value: dimension, label: dimensionLabel(dimension) }));
};

const update = changes => {
  config.value = { ...config.value, ...changes };
};

const setGroup = (index, dimension) => {
  const groupBy = [...config.value.group_by];
  groupBy[index] = dimension;
  const timeGrouped = groupBy.some(item => TIME_DIMENSIONS.includes(item));
  update({
    group_by: groupBy,
    ...(timeGrouped
      ? {
          compare: '',
          metrics: config.value.metrics.filter(metric => metric !== 'open'),
        }
      : {}),
  });
};

const addGroup = () => {
  const [next] = groupOptions(config.value.group_by.length);
  if (next) update({ group_by: [...config.value.group_by, next.value] });
};

const removeGroup = index =>
  update({ group_by: config.value.group_by.filter((_, i) => i !== index) });

const setFilter = (key, values) =>
  update({ filters: { ...config.value.filters, [key]: values } });

const setPeriod = period => {
  if (period !== 'custom') {
    update({ period, since: undefined, until: undefined });
    return;
  }
  const today = new Date();
  update({
    period,
    since: getUnixStartOfDay(new Date(today.getTime() - 6 * 86400000)),
    until: getUnixEndOfDay(today),
  });
};

const dateInput = key =>
  config.value[key]
    ? format(fromUnixTime(config.value[key]), 'yyyy-MM-dd')
    : '';

const setDate = (key, value) => {
  if (!value) return;
  const [year, month, day] = value.split('-').map(Number);
  const date = new Date(year, month - 1, day);
  update({
    [key]: key === 'since' ? getUnixStartOfDay(date) : getUnixEndOfDay(date),
  });
};

const availableMetrics = computed(() =>
  hasTimeGrouping.value
    ? metricOptions.value.filter(option => option.value !== 'open')
    : metricOptions.value
);

onMounted(() => {
  store.dispatch('markets/get');
  store.dispatch('teams/get');
  store.dispatch('agents/get');
  store.dispatch('conversationCategories/get');
});
</script>

<template>
  <div
    class="flex flex-col gap-4 p-4 rounded-xl outline outline-1 outline-n-weak bg-n-solid-1"
  >
    <div class="flex flex-wrap items-end gap-3">
      <label class="flex flex-col gap-1 text-label-small text-n-slate-11">
        {{ t('INSIGHTS.BUILDER.PERIOD') }}
        <Select
          :model-value="config.period"
          :options="periodOptions"
          :aria-label="t('INSIGHTS.BUILDER.PERIOD')"
          @update:model-value="setPeriod"
        />
      </label>
      <template v-if="config.period === 'custom'">
        <Input
          type="date"
          :label="t('INSIGHTS.BUILDER.FROM')"
          :model-value="dateInput('since')"
          @update:model-value="value => setDate('since', value)"
        />
        <Input
          type="date"
          :label="t('INSIGHTS.BUILDER.TO')"
          :model-value="dateInput('until')"
          @update:model-value="value => setDate('until', value)"
        />
      </template>
      <label class="flex flex-col gap-1 text-label-small text-n-slate-11">
        {{ t('INSIGHTS.BUILDER.COMPARE') }}
        <Select
          :model-value="config.compare || ''"
          :options="compareOptions"
          :disabled="hasTimeGrouping"
          :aria-label="t('INSIGHTS.BUILDER.COMPARE')"
          @update:model-value="value => update({ compare: value })"
        />
      </label>
      <div
        v-tooltip.top="t('INSIGHTS.BUILDER.BUSINESS_HOURS_HELP')"
        class="flex items-center gap-2 h-9 text-label-small text-n-slate-12"
      >
        <Switch
          :model-value="config.business_hours"
          @update:model-value="value => update({ business_hours: value })"
        />
        {{ t('INSIGHTS.BUILDER.BUSINESS_HOURS') }}
      </div>
    </div>

    <div class="flex flex-col gap-1">
      <span class="text-label-small text-n-slate-11">
        {{ t('INSIGHTS.BUILDER.METRICS') }}
      </span>
      <TagMultiSelectComboBox
        :model-value="config.metrics"
        :options="availableMetrics"
        :placeholder="t('INSIGHTS.BUILDER.METRICS_PLACEHOLDER')"
        @update:model-value="value => update({ metrics: [...value] })"
      />
    </div>

    <div class="flex flex-col gap-1">
      <span class="text-label-small text-n-slate-11">
        {{ t('INSIGHTS.BUILDER.GROUP_BY') }}
      </span>
      <div class="flex flex-wrap items-center gap-2">
        <div
          v-for="(dimension, index) in config.group_by"
          :key="index"
          class="flex items-center gap-1"
        >
          <Select
            :model-value="dimension"
            :options="groupOptions(index)"
            :aria-label="t('INSIGHTS.BUILDER.GROUP_BY')"
            @update:model-value="value => setGroup(index, value)"
          />
          <Button
            v-tooltip.top="t('INSIGHTS.BUILDER.REMOVE_GROUP')"
            icon="i-lucide-x"
            slate
            ghost
            xs
            @click="removeGroup(index)"
          />
        </div>
        <Button
          v-if="config.group_by.length < MAX_GROUP_BY"
          :label="t('INSIGHTS.BUILDER.ADD_GROUP')"
          icon="i-lucide-plus"
          slate
          faded
          sm
          @click="addGroup"
        />
      </div>
    </div>

    <div class="flex flex-col gap-1">
      <span class="text-label-small text-n-slate-11">
        {{ t('INSIGHTS.BUILDER.FILTERS') }}
      </span>
      <div class="grid grid-cols-1 gap-2 sm:grid-cols-2 lg:grid-cols-3">
        <div
          v-for="(options, key) in filterOptions"
          :key="key"
          class="flex flex-col gap-1"
        >
          <span class="text-label-small text-n-slate-12">
            {{ filterLabel(key) }}
          </span>
          <TagMultiSelectComboBox
            :model-value="config.filters[key] || []"
            :options="options"
            :placeholder="t('INSIGHTS.BUILDER.FILTER_PLACEHOLDER')"
            @update:model-value="value => setFilter(key, [...value])"
          />
        </div>
      </div>
    </div>
  </div>
</template>
