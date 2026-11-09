<script setup>
import { computed, reactive, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import SavedReportsAPI from 'dashboard/api/savedReports';
import { useInsightFormat } from '../useInsightFormat';

import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Select from 'dashboard/components-next/select/Select.vue';

const emit = defineEmits(['save']);

const DISPLAYS = ['number', 'bar', 'table'];

const { t } = useI18n();
const { metricLabel } = useInsightFormat();

const dialogRef = ref(null);
const reports = ref([]);
const editing = ref(null);
const form = reactive({
  reportId: '',
  display: 'number',
  metric: '',
  title: '',
});

const selectedReport = computed(() =>
  reports.value.find(report => report.id === form.reportId)
);
// A widget being edited keeps its own copy of the settings, even if its report was changed or deleted since
const config = computed(
  () => selectedReport.value?.config || editing.value?.config
);
const reportOptions = computed(() =>
  reports.value.map(report => ({ value: report.id, label: report.name }))
);
const metricOptions = computed(() =>
  (config.value?.metrics || []).map(metric => ({
    value: metric,
    label: metricLabel(metric),
  }))
);
const displayOptions = computed(() =>
  DISPLAYS.map(display => ({
    value: display,
    label: t(`INSIGHTS.DASHBOARD.DISPLAYS.${display.toUpperCase()}`),
  }))
);
const isValid = computed(
  () => config.value && config.value.metrics.includes(form.metric)
);

const onReportChange = reportId => {
  form.reportId = reportId;
  [form.metric] = selectedReport.value?.config.metrics || [];
  form.title = selectedReport.value?.name || '';
};

const open = async (widget = null) => {
  editing.value = widget;
  Object.assign(form, {
    reportId: widget?.saved_report_id || '',
    display: widget?.display || 'number',
    metric: widget?.metric || '',
    title: widget?.title || '',
  });
  dialogRef.value.open();
  try {
    const { data } = await SavedReportsAPI.get();
    reports.value = data;
  } catch (error) {
    useAlert(t('INSIGHTS.API_ERROR'));
  }
};

const onConfirm = () => {
  emit('save', {
    id:
      editing.value?.id ||
      `${Date.now()}-${Math.random().toString(36).slice(2, 8)}`,
    saved_report_id: form.reportId || editing.value?.saved_report_id,
    config: config.value,
    display: form.display,
    metric: form.metric,
    title: form.title.trim(),
  });
  dialogRef.value.close();
};

defineExpose({ open });
</script>

<template>
  <Dialog
    ref="dialogRef"
    :title="
      editing
        ? t('INSIGHTS.DASHBOARD.EDIT_WIDGET')
        : t('INSIGHTS.DASHBOARD.ADD_WIDGET')
    "
    :description="t('INSIGHTS.DASHBOARD.WIDGET_DESCRIPTION')"
    :confirm-button-label="t('INSIGHTS.DASHBOARD.SAVE_WIDGET')"
    :disable-confirm-button="!isValid"
    @confirm="onConfirm"
  >
    <div class="flex flex-col gap-4">
      <p v-if="!reports.length" class="mb-0 text-label-small text-n-slate-11">
        {{ t('INSIGHTS.DASHBOARD.NO_REPORTS') }}
      </p>
      <label class="flex flex-col gap-1 text-label-small text-n-slate-11">
        {{ t('INSIGHTS.DASHBOARD.REPORT') }}
        <Select
          :model-value="form.reportId"
          :options="reportOptions"
          :placeholder="t('INSIGHTS.DASHBOARD.CHOOSE_REPORT')"
          :aria-label="t('INSIGHTS.DASHBOARD.REPORT')"
          @update:model-value="onReportChange"
        />
      </label>
      <div class="flex flex-wrap gap-3">
        <label class="flex flex-col gap-1 text-label-small text-n-slate-11">
          {{ t('INSIGHTS.DASHBOARD.SHOW') }}
          <Select
            v-model="form.metric"
            :options="metricOptions"
            :disabled="!config"
            :aria-label="t('INSIGHTS.DASHBOARD.SHOW')"
          />
        </label>
        <label class="flex flex-col gap-1 text-label-small text-n-slate-11">
          {{ t('INSIGHTS.DASHBOARD.AS') }}
          <Select
            v-model="form.display"
            :options="displayOptions"
            :aria-label="t('INSIGHTS.DASHBOARD.AS')"
          />
        </label>
      </div>
      <Input
        v-model="form.title"
        :label="t('INSIGHTS.DASHBOARD.WIDGET_TITLE')"
        :placeholder="t('INSIGHTS.DASHBOARD.WIDGET_TITLE')"
      />
    </div>
  </Dialog>
</template>
