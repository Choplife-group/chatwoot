<script setup>
import { ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useMutationObserver } from '@vueuse/core';
import Button from 'dashboard/components-next/button/Button.vue';
import { setAppearance } from 'dashboard/composables/commands/useAppearanceHotKeys';

defineProps({
  isCollapsed: { type: Boolean, default: false },
});

const { t } = useI18n();

// Theme can also change from the command bar or OS, so read it from the body class
const isDark = ref(document.body.classList.contains('dark'));
useMutationObserver(
  document.body,
  () => {
    isDark.value = document.body.classList.contains('dark');
  },
  { attributeFilter: ['class'] }
);

const toggleTheme = () => setAppearance(isDark.value ? 'light' : 'dark');
</script>

<template>
  <Button
    v-tooltip.right="
      isCollapsed
        ? t(isDark ? 'SIDEBAR.LIGHT_MODE' : 'SIDEBAR.DARK_MODE')
        : undefined
    "
    :icon="isDark ? 'i-lucide-sun' : 'i-lucide-moon'"
    :label="
      isCollapsed ? '' : t(isDark ? 'SIDEBAR.LIGHT_MODE' : 'SIDEBAR.DARK_MODE')
    "
    :aria-label="t(isDark ? 'SIDEBAR.LIGHT_MODE' : 'SIDEBAR.DARK_MODE')"
    slate
    ghost
    sm
    :justify="isCollapsed ? 'center' : 'start'"
    :class="isCollapsed ? '!size-8 !px-0' : 'w-full'"
    @click="toggleTheme"
  />
</template>
