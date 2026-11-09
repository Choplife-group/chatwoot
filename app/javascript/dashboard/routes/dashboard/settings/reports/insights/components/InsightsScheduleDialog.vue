<script setup>
import { computed, reactive, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useMapGetter } from 'dashboard/composables/store';
import ReportSchedulesAPI from 'dashboard/api/reportSchedules';

import Button from 'dashboard/components-next/button/Button.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Select from 'dashboard/components-next/select/Select.vue';
import TagMultiSelectComboBox from 'dashboard/components-next/combobox/TagMultiSelectComboBox.vue';

const props = defineProps({
  savedReport: { type: Object, required: true },
  // Can email the report to other people
  canShare: { type: Boolean, default: false },
});

const FREQUENCIES = ['daily', 'weekly', 'monthly'];
const FILE_TYPES = ['pdf', 'xlsx', 'csv'];
const HOURS = [...Array(24).keys()];
const MONTH_DAYS = [...Array(28).keys()].map(index => index + 1);
// 8 November 2026 is a Sunday, so day 0 of this week is Sunday, as the API counts them
const SUNDAY = new Date(2026, 10, 8);

const { t, locale } = useI18n();
const currentUser = useMapGetter('getCurrentUser');
const agents = useMapGetter('agents/getAgents');

const dialogRef = ref(null);
const schedules = ref([]);
const isSaving = ref(false);
const busy = ref({});
const form = reactive({});

const weekdayName = day =>
  new Intl.DateTimeFormat(locale.value, { weekday: 'long' }).format(
    new Date(SUNDAY.getFullYear(), SUNDAY.getMonth(), SUNDAY.getDate() + day)
  );
const hourLabel = hour => `${String(hour).padStart(2, '0')}:00`;

const frequencyOptions = computed(() =>
  FREQUENCIES.map(value => ({
    value,
    label: t(`INSIGHTS.SCHEDULE.FREQUENCIES.${value.toUpperCase()}`),
  }))
);
const weekdayOptions = computed(() =>
  [1, 2, 3, 4, 5, 6, 0].map(value => ({ value, label: weekdayName(value) }))
);
const dayOptions = MONTH_DAYS.map(value => ({ value, label: `${value}` }));
const hourOptions = HOURS.map(value => ({ value, label: hourLabel(value) }));
const fileTypeOptions = computed(() =>
  FILE_TYPES.map(value => ({
    value,
    label: t(`INSIGHTS.EXPORT.${value.toUpperCase()}`),
  }))
);
const recipientOptions = computed(() =>
  agents.value.map(agent => ({ value: agent.id, label: agent.name }))
);

const isValid = computed(
  () => form.recipient_ids?.length && form.file_types?.length
);

const resetForm = () =>
  Object.assign(form, {
    frequency: 'weekly',
    weekday: 1,
    day_of_month: 1,
    hour: 8,
    recipient_ids: [currentUser.value.id],
    file_types: ['pdf'],
  });

const describe = schedule => {
  const when = {
    daily: t('INSIGHTS.SCHEDULE.EVERY_DAY'),
    weekly: t('INSIGHTS.SCHEDULE.EVERY_WEEKDAY', {
      day: weekdayName(schedule.weekday ?? 1),
    }),
    monthly: t('INSIGHTS.SCHEDULE.EVERY_MONTH', { day: schedule.day_of_month }),
  }[schedule.frequency];
  const files = schedule.file_types
    .map(type => t(`INSIGHTS.EXPORT.${type.toUpperCase()}`))
    .join(', ');
  return t('INSIGHTS.SCHEDULE.SUMMARY', {
    when,
    time: hourLabel(schedule.hour),
    people: t(
      'INSIGHTS.SCHEDULE.PEOPLE',
      { n: schedule.recipient_ids.length },
      schedule.recipient_ids.length
    ),
    files,
  });
};

const nextRun = schedule =>
  schedule.next_run_at
    ? new Date(schedule.next_run_at).toLocaleString(locale.value, {
        dateStyle: 'medium',
        timeStyle: 'short',
      })
    : '';

const load = async () => {
  try {
    const { data } = await ReportSchedulesAPI.forReport(props.savedReport.id);
    schedules.value = data;
  } catch (error) {
    useAlert(t('INSIGHTS.API_ERROR'));
  }
};

const open = () => {
  resetForm();
  schedules.value = [];
  dialogRef.value.open();
  load();
};

const addSchedule = async () => {
  isSaving.value = true;
  try {
    const { data } = await ReportSchedulesAPI.createForReport(
      props.savedReport.id,
      {
        ...form,
        timezone: Intl.DateTimeFormat().resolvedOptions().timeZone,
      }
    );
    schedules.value = [...schedules.value, data];
    resetForm();
    useAlert(t('INSIGHTS.SCHEDULE.ADDED'));
  } catch (error) {
    useAlert(error.response?.data?.error || t('INSIGHTS.API_ERROR'));
  } finally {
    isSaving.value = false;
  }
};

const sendNow = async schedule => {
  busy.value[schedule.id] = true;
  try {
    await ReportSchedulesAPI.deliver(schedule.id);
    useAlert(t('INSIGHTS.SCHEDULE.SENDING'));
  } catch (error) {
    useAlert(t('INSIGHTS.API_ERROR'));
  } finally {
    busy.value[schedule.id] = false;
  }
};

const remove = async schedule => {
  busy.value[schedule.id] = true;
  try {
    await ReportSchedulesAPI.delete(schedule.id);
    schedules.value = schedules.value.filter(item => item.id !== schedule.id);
  } catch (error) {
    useAlert(t('INSIGHTS.API_ERROR'));
  } finally {
    busy.value[schedule.id] = false;
  }
};

defineExpose({ open });
</script>

<template>
  <Dialog
    ref="dialogRef"
    :title="t('INSIGHTS.SCHEDULE.TITLE')"
    :description="t('INSIGHTS.SCHEDULE.DESCRIPTION')"
    :confirm-button-label="t('INSIGHTS.SCHEDULE.ADD')"
    :cancel-button-label="t('INSIGHTS.SCHEDULE.DONE')"
    :disable-confirm-button="!isValid"
    :is-loading="isSaving"
    width="xl"
    @confirm="addSchedule"
  >
    <div class="flex flex-col gap-4">
      <div v-if="schedules.length" class="flex flex-col gap-2">
        <div
          v-for="schedule in schedules"
          :key="schedule.id"
          class="flex items-center justify-between gap-3 p-3 rounded-lg outline outline-1 outline-n-weak"
        >
          <div class="flex flex-col min-w-0">
            <span class="text-body-main text-n-slate-12">
              {{ describe(schedule) }}
            </span>
            <span class="text-label-small text-n-slate-11">
              {{ t('INSIGHTS.SCHEDULE.NEXT', { time: nextRun(schedule) }) }}
            </span>
          </div>
          <div class="flex items-center gap-1 shrink-0">
            <Button
              :label="t('INSIGHTS.SCHEDULE.SEND_NOW')"
              slate
              faded
              xs
              :is-loading="busy[schedule.id]"
              @click="sendNow(schedule)"
            />
            <Button
              v-tooltip.top="t('INSIGHTS.SCHEDULE.DELETE')"
              icon="i-woot-bin"
              slate
              ghost
              xs
              class="hover:enabled:text-n-ruby-11"
              :disabled="busy[schedule.id]"
              @click="remove(schedule)"
            />
          </div>
        </div>
      </div>

      <div class="flex flex-wrap items-end gap-3">
        <label class="flex flex-col gap-1 text-label-small text-n-slate-11">
          {{ t('INSIGHTS.SCHEDULE.FREQUENCY') }}
          <Select
            v-model="form.frequency"
            :options="frequencyOptions"
            :aria-label="t('INSIGHTS.SCHEDULE.FREQUENCY')"
          />
        </label>
        <label
          v-if="form.frequency === 'weekly'"
          class="flex flex-col gap-1 text-label-small text-n-slate-11"
        >
          {{ t('INSIGHTS.SCHEDULE.WEEKDAY') }}
          <Select
            v-model="form.weekday"
            :options="weekdayOptions"
            :aria-label="t('INSIGHTS.SCHEDULE.WEEKDAY')"
          />
        </label>
        <label
          v-if="form.frequency === 'monthly'"
          class="flex flex-col gap-1 text-label-small text-n-slate-11"
        >
          {{ t('INSIGHTS.SCHEDULE.DAY_OF_MONTH') }}
          <Select
            v-model="form.day_of_month"
            :options="dayOptions"
            :aria-label="t('INSIGHTS.SCHEDULE.DAY_OF_MONTH')"
          />
        </label>
        <label class="flex flex-col gap-1 text-label-small text-n-slate-11">
          {{ t('INSIGHTS.SCHEDULE.HOUR') }}
          <Select
            v-model="form.hour"
            :options="hourOptions"
            :aria-label="t('INSIGHTS.SCHEDULE.HOUR')"
          />
        </label>
      </div>

      <div v-if="canShare" class="flex flex-col gap-1">
        <span class="text-label-small text-n-slate-11">
          {{ t('INSIGHTS.SCHEDULE.RECIPIENTS') }}
        </span>
        <TagMultiSelectComboBox
          v-model="form.recipient_ids"
          :options="recipientOptions"
          :placeholder="t('INSIGHTS.SCHEDULE.RECIPIENTS')"
        />
        <span class="text-label-small text-n-slate-11">
          {{ t('INSIGHTS.SCHEDULE.RECIPIENTS_HELP') }}
        </span>
      </div>
      <p v-else class="mb-0 text-label-small text-n-slate-11">
        {{ t('INSIGHTS.SCHEDULE.ONLY_YOU') }}
      </p>

      <div class="flex flex-col gap-1">
        <span class="text-label-small text-n-slate-11">
          {{ t('INSIGHTS.SCHEDULE.FILES') }}
        </span>
        <TagMultiSelectComboBox
          v-model="form.file_types"
          :options="fileTypeOptions"
          :placeholder="t('INSIGHTS.SCHEDULE.FILES')"
        />
      </div>

      <p class="mb-0 text-label-small text-n-slate-11">
        {{ t('INSIGHTS.SCHEDULE.PERIOD_HINT') }}
      </p>
    </div>
  </Dialog>
</template>
