<script setup>
import { computed, reactive, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useMapGetter, useStore } from 'dashboard/composables/store';

import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Input from 'dashboard/components-next/input/Input.vue';

// ISO-3166 alpha-2, the same codes our backend services use
const MARKET_CODE_PATTERN = /^[A-Za-z]{2}$/;

const store = useStore();
const { t } = useI18n();
const uiFlags = useMapGetter('markets/getUIFlags');

const dialogRef = ref(null);
const editingMarket = ref(null);
const form = reactive({ name: '', code: '', position: 0 });

const isEditing = computed(() => !!editingMarket.value);
const nameError = computed(() =>
  form.name.trim() ? '' : t('MARKETS_SETTINGS.FORM.NAME.ERROR')
);
const codeError = computed(() =>
  MARKET_CODE_PATTERN.test(form.code.trim())
    ? ''
    : t('MARKETS_SETTINGS.FORM.CODE.ERROR')
);

const open = (market = null) => {
  editingMarket.value = market;
  form.name = market?.name || '';
  form.code = market?.code || '';
  form.position = market?.position || 0;
  dialogRef.value.open();
};

const onConfirm = async () => {
  const payload = {
    name: form.name.trim(),
    code: form.code.trim().toUpperCase(),
    position: Number(form.position) || 0,
  };
  try {
    if (isEditing.value) {
      await store.dispatch('markets/update', {
        id: editingMarket.value.id,
        ...payload,
      });
      useAlert(t('MARKETS_SETTINGS.EDIT.SUCCESS'));
    } else {
      await store.dispatch('markets/create', payload);
      useAlert(t('MARKETS_SETTINGS.ADD.SUCCESS'));
    }
    dialogRef.value.close();
  } catch (error) {
    useAlert(error.message || t('MARKETS_SETTINGS.API_ERROR'));
  }
};

defineExpose({ open });
</script>

<template>
  <Dialog
    ref="dialogRef"
    :title="
      isEditing
        ? t('MARKETS_SETTINGS.EDIT.TITLE')
        : t('MARKETS_SETTINGS.ADD.TITLE')
    "
    :description="t('MARKETS_SETTINGS.ADD.DESCRIPTION')"
    :confirm-button-label="
      isEditing
        ? t('MARKETS_SETTINGS.EDIT.SUBMIT')
        : t('MARKETS_SETTINGS.ADD.SUBMIT')
    "
    :disable-confirm-button="!!nameError || !!codeError"
    :is-loading="uiFlags.isCreating || uiFlags.isUpdating"
    @confirm="onConfirm"
  >
    <div class="flex flex-col gap-4">
      <Input
        v-model="form.name"
        :label="t('MARKETS_SETTINGS.FORM.NAME.LABEL')"
        :placeholder="t('MARKETS_SETTINGS.FORM.NAME.PLACEHOLDER')"
        :message="form.name ? nameError : ''"
        :message-type="nameError ? 'error' : 'info'"
      />
      <Input
        v-model="form.code"
        :label="t('MARKETS_SETTINGS.FORM.CODE.LABEL')"
        :placeholder="t('MARKETS_SETTINGS.FORM.CODE.PLACEHOLDER')"
        :message="form.code ? codeError : t('MARKETS_SETTINGS.FORM.CODE.HELP')"
        :message-type="form.code && codeError ? 'error' : 'info'"
        custom-input-class="uppercase"
      />
      <Input
        v-model="form.position"
        type="number"
        min="0"
        :label="t('MARKETS_SETTINGS.FORM.POSITION.LABEL')"
        :message="t('MARKETS_SETTINGS.FORM.POSITION.HELP')"
      />
    </div>
  </Dialog>
</template>
