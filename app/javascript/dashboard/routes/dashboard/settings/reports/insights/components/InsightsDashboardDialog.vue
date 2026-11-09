<script setup>
import { computed, reactive, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useMapGetter, useStore } from 'dashboard/composables/store';

import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Select from 'dashboard/components-next/select/Select.vue';

const props = defineProps({
  // Can share dashboards with a role or everyone
  canShare: { type: Boolean, default: false },
  isLoading: { type: Boolean, default: false },
});

const emit = defineEmits(['save']);

const AUDIENCES = ['private', 'role', 'everyone'];
const REFRESH_SECONDS = [30, 60, 300, 900];

const { t } = useI18n();
const store = useStore();
const roles = useMapGetter('customRole/getCustomRoles');

const dialogRef = ref(null);
const isNew = ref(true);
const form = reactive({});

const audienceOptions = computed(() =>
  AUDIENCES.map(audience => ({
    value: audience,
    label: t(`INSIGHTS.DASHBOARD.AUDIENCES.${audience.toUpperCase()}`),
  }))
);
const roleOptions = computed(() =>
  roles.value.map(role => ({ value: role.id, label: role.name }))
);
const refreshOptions = computed(() =>
  REFRESH_SECONDS.map(seconds => ({
    value: seconds,
    label:
      seconds < 60
        ? t('INSIGHTS.DASHBOARD.EVERY_SECONDS', { n: seconds })
        : t('INSIGHTS.DASHBOARD.EVERY_MINUTES', { n: seconds / 60 }),
  }))
);
const isValid = computed(
  () => form.name?.trim() && (form.audience !== 'role' || form.custom_role_id)
);

const open = (dashboard = null) => {
  isNew.value = !dashboard;
  Object.assign(form, {
    name: dashboard?.name || '',
    audience: dashboard?.audience || 'private',
    custom_role_id: dashboard?.custom_role_id || '',
    refresh_seconds: dashboard?.refresh_seconds || 60,
  });
  if (props.canShare) store.dispatch('customRole/getCustomRole');
  dialogRef.value.open();
};

const close = () => dialogRef.value.close();

const onConfirm = () =>
  emit('save', {
    name: form.name.trim(),
    refresh_seconds: form.refresh_seconds,
    ...(props.canShare
      ? { audience: form.audience, custom_role_id: form.custom_role_id || null }
      : {}),
  });

defineExpose({ open, close });
</script>

<template>
  <Dialog
    ref="dialogRef"
    :title="
      isNew
        ? t('INSIGHTS.DASHBOARD.NEW_TITLE')
        : t('INSIGHTS.DASHBOARD.SETTINGS')
    "
    :description="t('INSIGHTS.DASHBOARD.DIALOG_DESCRIPTION')"
    :confirm-button-label="t('INSIGHTS.DASHBOARD.SAVE')"
    :disable-confirm-button="!isValid"
    :is-loading="isLoading"
    @confirm="onConfirm"
  >
    <div class="flex flex-col gap-4">
      <Input
        v-model="form.name"
        :label="t('INSIGHTS.DASHBOARD.NAME')"
        :placeholder="t('INSIGHTS.DASHBOARD.NAME_PLACEHOLDER')"
      />
      <div class="flex flex-wrap gap-3">
        <label
          v-if="canShare"
          class="flex flex-col gap-1 text-label-small text-n-slate-11"
        >
          {{ t('INSIGHTS.DASHBOARD.WHO') }}
          <Select
            v-model="form.audience"
            :options="audienceOptions"
            :aria-label="t('INSIGHTS.DASHBOARD.WHO')"
          />
        </label>
        <label
          v-if="canShare && form.audience === 'role'"
          class="flex flex-col gap-1 text-label-small text-n-slate-11"
        >
          {{ t('INSIGHTS.DASHBOARD.ROLE') }}
          <Select
            v-model="form.custom_role_id"
            :options="roleOptions"
            :placeholder="t('INSIGHTS.DASHBOARD.CHOOSE_ROLE')"
            :aria-label="t('INSIGHTS.DASHBOARD.ROLE')"
          />
        </label>
        <label class="flex flex-col gap-1 text-label-small text-n-slate-11">
          {{ t('INSIGHTS.DASHBOARD.REFRESH') }}
          <Select
            v-model="form.refresh_seconds"
            :options="refreshOptions"
            :aria-label="t('INSIGHTS.DASHBOARD.REFRESH')"
          />
        </label>
      </div>
      <p v-if="canShare" class="mb-0 text-label-small text-n-slate-11">
        {{ t('INSIGHTS.DASHBOARD.SHARE_HELP') }}
      </p>
    </div>
  </Dialog>
</template>
