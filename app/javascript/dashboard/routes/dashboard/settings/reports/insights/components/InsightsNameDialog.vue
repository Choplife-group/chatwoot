<script setup>
import { ref } from 'vue';
import { useI18n } from 'vue-i18n';

import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Switch from 'dashboard/components-next/switch/Switch.vue';

// Names a report before it's saved, or a snapshot before it's taken
const props = defineProps({
  // SAVE_DIALOG or SNAPSHOT_DIALOG
  textKey: { type: String, required: true },
  canShare: { type: Boolean, default: false },
  isLoading: { type: Boolean, default: false },
});

const emit = defineEmits(['confirm']);

const { t } = useI18n();
const dialogRef = ref(null);
const name = ref('');
const shared = ref(false);

const text = key => t(`INSIGHTS.${props.textKey}.${key}`);

const open = (defaults = {}) => {
  name.value = defaults.name || '';
  shared.value = defaults.shared || false;
  dialogRef.value.open();
};

const close = () => dialogRef.value.close();

const onConfirm = () =>
  emit('confirm', {
    name: name.value.trim(),
    ...(props.canShare ? { shared: shared.value } : {}),
  });

defineExpose({ open, close });
</script>

<template>
  <Dialog
    ref="dialogRef"
    :title="text('TITLE')"
    :description="text('DESCRIPTION')"
    :confirm-button-label="text('SUBMIT')"
    :disable-confirm-button="!name.trim()"
    :is-loading="isLoading"
    @confirm="onConfirm"
  >
    <div class="flex flex-col gap-4">
      <Input
        v-model="name"
        :label="text('NAME')"
        :placeholder="t('INSIGHTS.SAVE_DIALOG.NAME_PLACEHOLDER')"
      />
      <div
        v-if="canShare && textKey === 'SAVE_DIALOG'"
        class="flex items-center justify-between gap-3"
      >
        <div class="flex flex-col">
          <span class="text-label-small text-n-slate-12">
            {{ t('INSIGHTS.SAVE_DIALOG.SHARED') }}
          </span>
          <span class="text-label-small text-n-slate-11">
            {{ t('INSIGHTS.SAVE_DIALOG.SHARED_HELP') }}
          </span>
        </div>
        <Switch v-model="shared" />
      </div>
    </div>
  </Dialog>
</template>
