<script setup>
import { computed, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import { useDebounceFn } from '@vueuse/core';
import { useAlert } from 'dashboard/composables';
import { useMapGetter } from 'dashboard/composables/store';
import { useEscalationGuard } from 'dashboard/composables/useEscalationGuard';
import {
  isAbortError,
  useAbortableRequest,
} from 'dashboard/composables/useAbortableRequest';
import InsightsAPI from 'dashboard/api/insights';
import ReportSnapshotsAPI from 'dashboard/api/reportSnapshots';
import SavedReportsAPI from 'dashboard/api/savedReports';
import { QUERY_DEBOUNCE_MS, defaultConfig } from './constants';

import Button from 'dashboard/components-next/button/Button.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import InsightsControls from './components/InsightsControls.vue';
import InsightsResults from './components/InsightsResults.vue';
import InsightsDrilldownPanel from './components/InsightsDrilldownPanel.vue';
import InsightsNameDialog from './components/InsightsNameDialog.vue';
import InsightsExportMenu from './components/InsightsExportMenu.vue';
import InsightsScheduleDialog from './components/InsightsScheduleDialog.vue';

const route = useRoute();
const router = useRouter();
const { t } = useI18n();
const currentUser = useMapGetter('getCurrentUser');
const { isAdministrator, holds } = useEscalationGuard();
const { run, isPending } = useAbortableRequest();

const config = ref(defaultConfig());
const savedReport = ref(null);
const result = ref(null);
const isSaving = ref(false);
const saveDialogRef = ref(null);
const snapshotDialogRef = ref(null);
const drilldownRef = ref(null);
const scheduleDialogRef = ref(null);

const canShare = computed(
  () => isAdministrator.value || holds(['report_manage'])
);
const canEditSaved = computed(
  () =>
    savedReport.value &&
    (savedReport.value.user_id === currentUser.value.id ||
      (savedReport.value.shared && canShare.value))
);
const title = computed(
  () => savedReport.value?.name || t('INSIGHTS.BUILDER.UNTITLED')
);

// What the API takes: named periods without dates, and no empty filters or comparison
const queryParams = computed(() => {
  const { filters, compare, since, until, ...rest } = config.value;
  return {
    ...rest,
    ...(compare ? { compare } : {}),
    ...(rest.period === 'custom' ? { since, until } : {}),
    filters: Object.fromEntries(
      Object.entries(filters).filter(([, values]) => values?.length)
    ),
  };
});

const fetchResult = async () => {
  if (!config.value.metrics.length) {
    result.value = null;
    return;
  }
  try {
    const response = await run(signal =>
      InsightsAPI.query(queryParams.value, { signal })
    );
    if (response) result.value = response.data;
  } catch (error) {
    if (!isAbortError(error)) {
      useAlert(error.response?.data?.error || t('INSIGHTS.API_ERROR'));
    }
  }
};

const debouncedFetch = useDebounceFn(fetchResult, QUERY_DEBOUNCE_MS);
watch(queryParams, debouncedFetch, { deep: true });

const loadSavedReport = async id => {
  try {
    const { data } = await SavedReportsAPI.show(id);
    savedReport.value = data;
    config.value = { ...defaultConfig(), compare: '', ...data.config };
  } catch (error) {
    useAlert(t('INSIGHTS.API_ERROR'));
    router.push({ name: 'insights_index' });
  }
};

const saveReport = async ({ name, shared }) => {
  isSaving.value = true;
  const payload = {
    saved_report: { name, config: queryParams.value, shared },
  };
  try {
    const { data } = canEditSaved.value
      ? await SavedReportsAPI.update(savedReport.value.id, payload)
      : await SavedReportsAPI.create(payload);
    savedReport.value = data;
    saveDialogRef.value.close();
    useAlert(t('INSIGHTS.BUILDER.SAVED'));
    if (route.params.reportId !== String(data.id)) {
      router.replace({
        name: 'insights_report',
        params: { reportId: data.id },
      });
    }
  } catch (error) {
    useAlert(error.response?.data?.error || t('INSIGHTS.API_ERROR'));
  } finally {
    isSaving.value = false;
  }
};

const saveAsNew = () => {
  savedReport.value = null;
  saveDialogRef.value.open();
};

const takeSnapshot = async ({ name }) => {
  isSaving.value = true;
  try {
    await ReportSnapshotsAPI.create({
      report_snapshot: {
        name,
        config: queryParams.value,
        saved_report_id: savedReport.value?.id,
      },
    });
    snapshotDialogRef.value.close();
    useAlert(t('INSIGHTS.BUILDER.SNAPSHOT_TAKEN'));
  } catch (error) {
    useAlert(error.response?.data?.error || t('INSIGHTS.API_ERROR'));
  } finally {
    isSaving.value = false;
  }
};

const exportReport = fileType =>
  InsightsAPI.export(queryParams.value, fileType, title.value);

const openDrilldown = figure =>
  drilldownRef.value.open(figure, result.value.labels);

onMounted(async () => {
  if (route.params.reportId) await loadSavedReport(route.params.reportId);
  fetchResult();
});
</script>

<template>
  <div class="flex flex-col gap-4 pt-6">
    <div class="flex flex-wrap items-center justify-between gap-3">
      <div class="flex flex-col gap-1 min-w-0">
        <router-link
          :to="{ name: 'insights_index' }"
          class="text-label-small text-n-slate-11 hover:text-n-slate-12"
        >
          {{ t('INSIGHTS.BUILDER.BACK') }}
        </router-link>
        <h1 class="text-heading-1 text-n-slate-12 truncate">{{ title }}</h1>
      </div>
      <div class="flex items-center gap-2">
        <InsightsExportMenu :download="exportReport" :disabled="!result" />
        <Button
          v-if="savedReport"
          :label="t('INSIGHTS.BUILDER.SCHEDULE')"
          icon="i-lucide-mail"
          slate
          faded
          sm
          @click="scheduleDialogRef.open()"
        />
        <Button
          :label="t('INSIGHTS.BUILDER.SNAPSHOT')"
          icon="i-lucide-camera"
          slate
          faded
          sm
          :disabled="!result"
          @click="snapshotDialogRef.open({ name: title })"
        />
        <Button
          v-if="canEditSaved"
          :label="t('INSIGHTS.BUILDER.SAVE_AS')"
          slate
          faded
          sm
          @click="saveAsNew"
        />
        <Button
          :label="t('INSIGHTS.BUILDER.SAVE')"
          icon="i-lucide-save"
          sm
          @click="
            saveDialogRef.open(
              canEditSaved ? savedReport : { name: '', shared: false }
            )
          "
        />
      </div>
    </div>

    <InsightsControls v-model="config" />

    <div v-if="isPending && !result" class="flex justify-center py-16">
      <Spinner />
    </div>
    <InsightsResults
      v-else-if="result"
      :class="{ 'opacity-60 transition-opacity': isPending }"
      :result="result"
      :metrics="config.metrics"
      :group-by="config.group_by"
      @drill="openDrilldown"
    />

    <InsightsDrilldownPanel ref="drilldownRef" :params="queryParams" />
    <InsightsScheduleDialog
      v-if="savedReport"
      ref="scheduleDialogRef"
      :saved-report="savedReport"
      :can-share="canShare"
    />
    <InsightsNameDialog
      ref="saveDialogRef"
      text-key="SAVE_DIALOG"
      :can-share="canShare"
      :is-loading="isSaving"
      @confirm="saveReport"
    />
    <InsightsNameDialog
      ref="snapshotDialogRef"
      text-key="SNAPSHOT_DIALOG"
      :is-loading="isSaving"
      @confirm="takeSnapshot"
    />
  </div>
</template>
