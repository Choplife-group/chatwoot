<script setup>
import { computed, reactive, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useMapGetter } from 'dashboard/composables/store';
import SlaTargetsAPI from 'dashboard/api/slaTargets';
import { SLA_PRIORITIES, toDuration, toSeconds } from './constants';

import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Select from 'dashboard/components-next/select/Select.vue';
import Switch from 'dashboard/components-next/switch/Switch.vue';

const emit = defineEmits(['saved']);

const { t } = useI18n();
const activeMarkets = useMapGetter('markets/getActiveMarkets');

const dialogRef = ref(null);
const editingTarget = ref(null);
const isSaving = ref(false);
const form = reactive({
  marketId: '',
  priority: '',
  firstResponse: { value: '', unit: 'minutes' },
  resolution: { value: '', unit: 'hours' },
  businessHours: false,
});

const marketOptions = computed(() => [
  { value: '', label: t('SLA_TARGETS.ALL_MARKETS') },
  ...activeMarkets.value.map(market => ({
    value: market.id,
    label: market.name,
  })),
]);
const priorityOptions = computed(() => [
  { value: '', label: t('SLA_TARGETS.ANY_PRIORITY') },
  ...SLA_PRIORITIES.map(priority => ({
    value: priority,
    label: t(`SLA_TARGETS.PRIORITIES.${priority.toUpperCase()}`),
  })),
]);
const unitOptions = computed(() => [
  { value: 'minutes', label: t('SLA_TARGETS.UNITS.MINUTES') },
  { value: 'hours', label: t('SLA_TARGETS.UNITS.HOURS') },
]);

const hasATarget = computed(
  () => !!toSeconds(form.firstResponse) || !!toSeconds(form.resolution)
);

const open = (target = null) => {
  editingTarget.value = target;
  form.marketId = target?.market_id || '';
  form.priority = target?.priority || '';
  form.firstResponse = toDuration(target?.first_response_seconds);
  form.resolution = target?.resolution_seconds
    ? toDuration(target.resolution_seconds)
    : { value: '', unit: 'hours' };
  form.businessHours = target?.business_hours || false;
  dialogRef.value.open();
};

const onConfirm = async () => {
  const payload = {
    market_id: form.marketId || null,
    priority: form.priority || null,
    first_response_seconds: toSeconds(form.firstResponse),
    resolution_seconds: toSeconds(form.resolution),
    business_hours: form.businessHours,
  };
  isSaving.value = true;
  try {
    if (editingTarget.value) {
      await SlaTargetsAPI.update(editingTarget.value.id, {
        sla_target: payload,
      });
    } else {
      await SlaTargetsAPI.create({ sla_target: payload });
    }
    useAlert(t('SLA_TARGETS.SAVE.SUCCESS'));
    dialogRef.value.close();
    emit('saved');
  } catch (error) {
    useAlert(error.response?.data?.message || t('SLA_TARGETS.API_ERROR'));
  } finally {
    isSaving.value = false;
  }
};

defineExpose({ open });
</script>

<template>
  <Dialog
    ref="dialogRef"
    :title="
      editingTarget ? t('SLA_TARGETS.EDIT.TITLE') : t('SLA_TARGETS.ADD.TITLE')
    "
    :description="t('SLA_TARGETS.ADD.DESCRIPTION')"
    :confirm-button-label="t('SLA_TARGETS.SAVE.BUTTON')"
    :disable-confirm-button="!hasATarget"
    :is-loading="isSaving"
    @confirm="onConfirm"
  >
    <div class="flex flex-col gap-4">
      <div class="grid grid-cols-2 gap-3">
        <label class="flex flex-col gap-1 text-label-small text-n-slate-12">
          {{ t('SLA_TARGETS.FORM.MARKET') }}
          <Select
            v-model="form.marketId"
            :options="marketOptions"
            :aria-label="t('SLA_TARGETS.FORM.MARKET')"
          />
        </label>
        <label class="flex flex-col gap-1 text-label-small text-n-slate-12">
          {{ t('SLA_TARGETS.FORM.PRIORITY') }}
          <Select
            v-model="form.priority"
            :options="priorityOptions"
            :aria-label="t('SLA_TARGETS.FORM.PRIORITY')"
          />
        </label>
      </div>
      <div
        v-for="field in ['firstResponse', 'resolution']"
        :key="field"
        class="flex items-end gap-2"
      >
        <Input
          v-model="form[field].value"
          type="number"
          min="1"
          class="flex-1"
          :label="
            t(
              `SLA_TARGETS.FORM.${field === 'firstResponse' ? 'FIRST_RESPONSE' : 'RESOLUTION'}`
            )
          "
          :placeholder="t('SLA_TARGETS.FORM.NO_TARGET')"
        />
        <Select
          v-model="form[field].unit"
          :options="unitOptions"
          :aria-label="t('SLA_TARGETS.FORM.UNIT')"
        />
      </div>
      <div class="flex items-center justify-between gap-3">
        <div class="flex flex-col">
          <span class="text-label-small text-n-slate-12">
            {{ t('SLA_TARGETS.FORM.BUSINESS_HOURS') }}
          </span>
          <span class="text-label-small text-n-slate-11">
            {{ t('SLA_TARGETS.FORM.BUSINESS_HOURS_HELP') }}
          </span>
        </div>
        <Switch v-model="form.businessHours" />
      </div>
      <p v-if="!hasATarget" class="mb-0 text-label-small text-n-slate-11">
        {{ t('SLA_TARGETS.FORM.NEEDS_A_TARGET') }}
      </p>
    </div>
  </Dialog>
</template>
