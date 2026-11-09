<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { vOnClickOutside } from '@vueuse/components';
import { useAlert } from 'dashboard/composables';
import { downloadResponseFile } from 'dashboard/helper/downloadHelper';

import Button from 'dashboard/components-next/button/Button.vue';
import DropdownMenu from 'dashboard/components-next/dropdown-menu/DropdownMenu.vue';

const props = defineProps({
  // Called with the file type; returns the API response holding the file
  download: { type: Function, required: true },
  disabled: { type: Boolean, default: false },
});

const FILE_TYPES = ['csv', 'xlsx', 'pdf'];

const { t } = useI18n();
const isOpen = ref(false);
const isDownloading = ref(false);

const menuItems = computed(() =>
  FILE_TYPES.map(fileType => ({
    label: t(`INSIGHTS.EXPORT.${fileType.toUpperCase()}`),
    value: fileType,
    action: 'export',
  }))
);

const onAction = async ({ value }) => {
  isOpen.value = false;
  isDownloading.value = true;
  try {
    downloadResponseFile(await props.download(value), `insights.${value}`);
  } catch (error) {
    useAlert(t('INSIGHTS.EXPORT.ERROR'));
  } finally {
    isDownloading.value = false;
  }
};
</script>

<template>
  <div v-on-click-outside="() => (isOpen = false)" class="relative">
    <Button
      :label="t('INSIGHTS.EXPORT.BUTTON')"
      icon="i-lucide-download"
      slate
      faded
      sm
      :disabled="disabled"
      :is-loading="isDownloading"
      @click="isOpen = !isOpen"
    />
    <DropdownMenu
      v-if="isOpen"
      :menu-items="menuItems"
      class="mt-1 min-w-40 top-full end-0"
      @action="onAction"
    />
  </div>
</template>
