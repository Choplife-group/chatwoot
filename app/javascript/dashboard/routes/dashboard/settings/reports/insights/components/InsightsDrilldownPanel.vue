<script setup>
import { computed, nextTick, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useMapGetter } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import {
  isAbortError,
  useAbortableRequest,
} from 'dashboard/composables/useAbortableRequest';
import { frontendURL, conversationUrl } from 'dashboard/helper/URLHelper';
import { dynamicTime } from 'shared/helpers/timeHelper';
import { formatTime } from '@chatwoot/utils';
import InsightsAPI from 'dashboard/api/insights';
import { METRIC_TYPES } from '../constants';
import { useInsightFormat } from '../useInsightFormat';

import Button from 'dashboard/components-next/button/Button.vue';
import SidePanel from 'dashboard/components-next/side-panel/SidePanel.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';

const props = defineProps({
  // The query params the figure came from, unless open() is given its own
  params: { type: Object, default: () => ({}) },
});

const { t } = useI18n();
const accountId = useMapGetter('getCurrentAccountId');
const { metricLabel, rowLabel, dimensionValueLabel } = useInsightFormat();
const { run, isPending } = useAbortableRequest();

const ROW_DIMENSIONS = ['market', 'team', 'subcategory', 'agent', 'inbox'];

const panelRef = ref(null);
const figure = ref(null);
const page = ref(1);
const response = ref(null);
const parentLabels = ref({});
const openedParams = ref(null);

const title = computed(() => {
  if (!figure.value) return '';
  const row = rowLabel(figure.value.dimensions, parentLabels.value);
  const label = t('INSIGHTS.DRILLDOWN.TITLE', {
    metric: metricLabel(figure.value.metric),
    row,
  });
  return figure.value.previous
    ? `${label} (${t('INSIGHTS.DRILLDOWN.PREVIOUS')})`
    : label;
});

const totalCount = computed(() => response.value?.meta.total_count || 0);
const hasNextPage = computed(
  () => page.value * (response.value?.meta.per_page || 0) < totalCount.value
);
const showsValue = computed(
  () => figure.value && METRIC_TYPES[figure.value.metric] !== 'count'
);

const load = async () => {
  try {
    const { data } = await run(signal =>
      InsightsAPI.drilldown(
        {
          ...(openedParams.value || props.params),
          metric: figure.value.metric,
          // An empty value asks for the row without one, such as conversations with no team
          dimensions: Object.fromEntries(
            Object.entries(figure.value.dimensions).map(([key, value]) => [
              key,
              value ?? '',
            ])
          ),
          from_comparison: figure.value.previous || undefined,
          page: page.value,
        },
        { signal }
      )
    );
    if (data) response.value = data;
  } catch (error) {
    if (!isAbortError(error)) useAlert(t('INSIGHTS.API_ERROR'));
  }
};

// params: for a dashboard widget, whose report differs from one widget to the next
const open = async (nextFigure, labels, params = null) => {
  figure.value = nextFigure;
  parentLabels.value = labels;
  openedParams.value = params;
  page.value = 1;
  response.value = null;
  await nextTick();
  panelRef.value.open();
  load();
};

const goToPage = nextPage => {
  page.value = nextPage;
  load();
};

const conversationLink = row =>
  frontendURL(
    conversationUrl({ accountId: accountId.value, id: row.display_id })
  );

const rowDetails = row =>
  ROW_DIMENSIONS.map(dimension =>
    row[`${dimension}_id`]
      ? dimensionValueLabel(
          dimension,
          row[`${dimension}_id`],
          response.value.labels
        )
      : null
  ).filter(Boolean);

defineExpose({ open });
</script>

<template>
  <SidePanel ref="panelRef" :title="title" width="xl">
    <div class="flex flex-col gap-3 p-4">
      <div v-if="isPending && !response" class="flex justify-center py-10">
        <Spinner />
      </div>
      <template v-else-if="response">
        <span class="text-label-small text-n-slate-11">
          {{ t('INSIGHTS.DRILLDOWN.COUNT', { n: totalCount }, totalCount) }}
        </span>
        <p
          v-if="!response.payload.length"
          class="py-6 mb-0 text-center text-body-main text-n-slate-11"
        >
          {{ t('INSIGHTS.DRILLDOWN.EMPTY') }}
        </p>
        <router-link
          v-for="row in response.payload"
          :key="`${row.conversation_id}-${row.happened_at}`"
          :to="conversationLink(row)"
          class="flex flex-col gap-1 p-3 rounded-lg outline outline-1 outline-n-weak hover:bg-n-alpha-1"
        >
          <div class="flex items-center justify-between gap-2">
            <span class="text-body-main font-medium text-n-slate-12">
              #{{ row.display_id }}
              <span class="ms-2 text-label-small text-n-slate-11">
                {{ t(`INSIGHTS.STATUS.${row.status.toUpperCase()}`) }}
              </span>
            </span>
            <span class="text-label-small text-n-slate-11">
              {{ dynamicTime(row.happened_at) }}
            </span>
          </div>
          <div class="flex flex-wrap items-center gap-1.5">
            <span
              v-for="detail in rowDetails(row)"
              :key="detail"
              class="px-2 py-0.5 text-xs rounded-md bg-n-alpha-2 text-n-slate-11"
            >
              {{ detail }}
            </span>
            <span
              v-if="showsValue && row.value !== undefined"
              class="ms-auto text-label-small text-n-slate-12 tabular-nums"
            >
              {{ formatTime(row.value) || `${row.value}s` }}
            </span>
            <span
              v-if="row.sla_met !== undefined"
              class="px-2 py-0.5 text-xs rounded-md"
              :class="
                row.sla_met
                  ? 'bg-n-teal-3 text-n-teal-11'
                  : 'bg-n-ruby-3 text-n-ruby-11'
              "
            >
              {{
                row.sla_met
                  ? t('INSIGHTS.DRILLDOWN.MET')
                  : t('INSIGHTS.DRILLDOWN.MISSED')
              }}
            </span>
          </div>
        </router-link>
        <div
          v-if="page > 1 || hasNextPage"
          class="flex justify-between gap-2 pt-2"
        >
          <Button
            :label="t('INSIGHTS.DRILLDOWN.PREV_PAGE')"
            slate
            faded
            sm
            :disabled="page === 1 || isPending"
            @click="goToPage(page - 1)"
          />
          <Button
            :label="t('INSIGHTS.DRILLDOWN.NEXT_PAGE')"
            slate
            faded
            sm
            :disabled="!hasNextPage || isPending"
            @click="goToPage(page + 1)"
          />
        </div>
      </template>
    </div>
  </SidePanel>
</template>
