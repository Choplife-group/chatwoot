<script setup>
import { computed, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import { useDocumentVisibility, useIntervalFn } from '@vueuse/core';
import { useAlert } from 'dashboard/composables';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import { useEscalationGuard } from 'dashboard/composables/useEscalationGuard';
import InsightDashboardsAPI from 'dashboard/api/insightDashboards';
import { PERIODS } from './constants';

import Button from 'dashboard/components-next/button/Button.vue';
import Select from 'dashboard/components-next/select/Select.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import TagMultiSelectComboBox from 'dashboard/components-next/combobox/TagMultiSelectComboBox.vue';
import InsightsWidget from './components/InsightsWidget.vue';
import InsightsWidgetDialog from './components/InsightsWidgetDialog.vue';
import InsightsDashboardDialog from './components/InsightsDashboardDialog.vue';
import InsightsDrilldownPanel from './components/InsightsDrilldownPanel.vue';

const route = useRoute();
const router = useRouter();
const store = useStore();
const { t } = useI18n();
const currentUser = useMapGetter('getCurrentUser');
const markets = useMapGetter('markets/getMarkets');
const teams = useMapGetter('teams/getTeams');
const { isAdministrator, holds } = useEscalationGuard();
const visibility = useDocumentVisibility();

const dashboard = ref(null);
const editing = ref(route.query.edit === '1');
const isSaving = ref(false);
const refreshKey = ref(0);
const lastUpdated = ref(null);
const widgetDialogRef = ref(null);
const settingsDialogRef = ref(null);
const drilldownRef = ref(null);

const canShare = computed(
  () => isAdministrator.value || holds(['report_manage'])
);
const canEdit = computed(
  () =>
    dashboard.value &&
    (dashboard.value.user_id === currentUser.value.id || canShare.value)
);
const widgets = computed(() => dashboard.value?.widgets || []);
const filters = computed(() => dashboard.value?.filters || {});

const periodOptions = computed(() => [
  { value: '', label: t('INSIGHTS.DASHBOARD.EACH_WIDGET_PERIOD') },
  ...PERIODS.filter(period => period !== 'custom').map(period => ({
    value: period,
    label: t(`INSIGHTS.PERIODS.${period.toUpperCase()}`),
  })),
]);
const toOptions = records =>
  records.map(record => ({ value: record.id, label: record.name }));

// The dashboard's period and filters replace each widget's own
const widgetParams = widget => {
  const { period, ...dashboardFilters } = filters.value;
  const { filters: widgetFilters = {}, ...config } = widget.config;
  const params = { ...config, filters: { ...widgetFilters } };
  Object.entries(dashboardFilters).forEach(([key, values]) => {
    if (values?.length) params.filters[key] = values;
  });
  if (period) {
    params.period = period;
    delete params.since;
    delete params.until;
    if (params.compare === 'custom') delete params.compare;
  }
  return params;
};

const save = async changes => {
  isSaving.value = true;
  try {
    const { data } = await InsightDashboardsAPI.update(dashboard.value.id, {
      insight_dashboard: changes,
    });
    dashboard.value = data;
    return true;
  } catch (error) {
    useAlert(error.response?.data?.error || t('INSIGHTS.API_ERROR'));
    return false;
  } finally {
    isSaving.value = false;
  }
};

const saveWidgets = list => save({ widgets: list });

const onWidgetSave = widget => {
  const index = widgets.value.findIndex(item => item.id === widget.id);
  const list = [...widgets.value];
  if (index === -1) list.push(widget);
  else list[index] = widget;
  saveWidgets(list);
};

const removeWidget = widget =>
  saveWidgets(widgets.value.filter(item => item.id !== widget.id));

const moveWidget = (index, step) => {
  const list = [...widgets.value];
  [list[index], list[index + step]] = [list[index + step], list[index]];
  saveWidgets(list);
};

const setFilter = (key, value) =>
  save({ filters: { ...filters.value, [key]: value } });

const saveSettings = async settings => {
  if (await save(settings)) settingsDialogRef.value.close();
};

const refresh = () => {
  refreshKey.value += 1;
};

const onLoaded = () => {
  lastUpdated.value = new Date().toLocaleTimeString([], {
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
  });
};

const openDrilldown = ({ figure, params, labels }) =>
  drilldownRef.value.open(figure, labels, params);

// Refreshes while the tab is in view, and catches up as soon as it comes back
const { pause, resume } = useIntervalFn(
  () => {
    if (visibility.value === 'visible') refresh();
  },
  computed(() => (dashboard.value?.refresh_seconds || 60) * 1000),
  { immediate: false }
);
watch(visibility, (state, previous) => {
  if (state === 'visible' && previous === 'hidden') refresh();
});

onMounted(async () => {
  store.dispatch('markets/get');
  store.dispatch('teams/get');
  try {
    const { data } = await InsightDashboardsAPI.show(route.params.dashboardId);
    dashboard.value = data;
    resume();
  } catch (error) {
    pause();
    useAlert(t('INSIGHTS.API_ERROR'));
    router.push({ name: 'insights_index' });
  }
});
</script>

<template>
  <div class="flex flex-col gap-4 pt-6">
    <div v-if="!dashboard" class="flex justify-center py-16">
      <Spinner />
    </div>
    <template v-else>
      <div class="flex flex-wrap items-start justify-between gap-3">
        <div class="flex flex-col gap-1 min-w-0">
          <router-link
            :to="{ name: 'insights_index' }"
            class="text-label-small text-n-slate-11 hover:text-n-slate-12"
          >
            {{ t('INSIGHTS.BUILDER.BACK') }}
          </router-link>
          <h1 class="text-heading-1 text-n-slate-12 truncate">
            {{ dashboard.name }}
          </h1>
          <span class="text-label-small text-n-slate-11">
            {{
              t(
                `INSIGHTS.DASHBOARD.AUDIENCES.${dashboard.audience.toUpperCase()}`
              )
            }}
            <template v-if="lastUpdated">
              ·
              {{ t('INSIGHTS.DASHBOARD.UPDATED', { time: lastUpdated }) }}
            </template>
          </span>
        </div>
        <div class="flex flex-wrap items-center gap-2">
          <Button
            v-tooltip.top="t('INSIGHTS.DASHBOARD.REFRESH_NOW')"
            icon="i-lucide-refresh-cw"
            slate
            faded
            sm
            @click="refresh"
          />
          <template v-if="canEdit">
            <Button
              :label="t('INSIGHTS.DASHBOARD.SETTINGS')"
              icon="i-lucide-settings"
              slate
              faded
              sm
              @click="settingsDialogRef.open(dashboard)"
            />
            <Button
              :label="
                editing
                  ? t('INSIGHTS.DASHBOARD.DONE_EDITING')
                  : t('INSIGHTS.DASHBOARD.EDIT')
              "
              :icon="editing ? 'i-lucide-check' : 'i-lucide-layout-grid'"
              slate
              faded
              sm
              @click="editing = !editing"
            />
            <Button
              :label="t('INSIGHTS.DASHBOARD.ADD_WIDGET')"
              icon="i-lucide-plus"
              sm
              @click="widgetDialogRef.open()"
            />
          </template>
        </div>
      </div>

      <div
        class="flex flex-wrap items-end gap-3 p-4 rounded-xl outline outline-1 outline-n-weak bg-n-solid-1"
      >
        <label class="flex flex-col gap-1 text-label-small text-n-slate-11">
          {{ t('INSIGHTS.BUILDER.PERIOD') }}
          <Select
            :model-value="filters.period || ''"
            :options="periodOptions"
            :disabled="!canEdit || isSaving"
            :aria-label="t('INSIGHTS.BUILDER.PERIOD')"
            @update:model-value="value => setFilter('period', value)"
          />
        </label>
        <div class="flex flex-col flex-1 gap-1 min-w-48">
          <span class="text-label-small text-n-slate-11">
            {{ t('INSIGHTS.DIMENSIONS.MARKET') }}
          </span>
          <TagMultiSelectComboBox
            :model-value="filters.market_ids || []"
            :options="toOptions(markets)"
            :disabled="!canEdit || isSaving"
            :placeholder="t('INSIGHTS.BUILDER.FILTER_PLACEHOLDER')"
            @update:model-value="value => setFilter('market_ids', [...value])"
          />
        </div>
        <div class="flex flex-col flex-1 gap-1 min-w-48">
          <span class="text-label-small text-n-slate-11">
            {{ t('INSIGHTS.DIMENSIONS.TEAM') }}
          </span>
          <TagMultiSelectComboBox
            :model-value="filters.team_ids || []"
            :options="toOptions(teams)"
            :disabled="!canEdit || isSaving"
            :placeholder="t('INSIGHTS.BUILDER.FILTER_PLACEHOLDER')"
            @update:model-value="value => setFilter('team_ids', [...value])"
          />
        </div>
      </div>

      <p
        v-if="!widgets.length"
        class="py-12 mb-0 text-center text-body-main text-n-slate-11"
      >
        {{
          canEdit
            ? t('INSIGHTS.DASHBOARD.EMPTY_EDITABLE')
            : t('INSIGHTS.DASHBOARD.EMPTY')
        }}
      </p>
      <div v-else class="grid grid-cols-1 gap-3 md:grid-cols-2">
        <InsightsWidget
          v-for="(widget, index) in widgets"
          :key="widget.id"
          :widget="widget"
          :params="widgetParams(widget)"
          :refresh-key="refreshKey"
          :editing="editing && canEdit"
          :is-first="index === 0"
          :is-last="index === widgets.length - 1"
          @loaded="onLoaded"
          @drill="openDrilldown"
          @edit="widgetDialogRef.open(widget)"
          @remove="removeWidget(widget)"
          @move="step => moveWidget(index, step)"
        />
      </div>

      <InsightsDrilldownPanel ref="drilldownRef" />
      <InsightsWidgetDialog ref="widgetDialogRef" @save="onWidgetSave" />
      <InsightsDashboardDialog
        ref="settingsDialogRef"
        :can-share="canShare"
        :is-loading="isSaving"
        @save="saveSettings"
      />
    </template>
  </div>
</template>
