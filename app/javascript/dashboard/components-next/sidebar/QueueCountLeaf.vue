<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import SidebarUnreadBadge from './SidebarUnreadBadge.vue';

const props = defineProps({
  label: { type: String, required: true },
  // eslint-disable-next-line vue/no-unused-properties
  active: { type: Boolean, default: false },
  leadingIcon: { type: Object, default: null },
  badgeCount: { type: [Number, String], default: 0 },
  openCount: { type: Number, default: 0 },
  waitingCount: { type: Number, default: 0 },
});

const { t } = useI18n();

const countTitle = computed(() =>
  t('SIDEBAR.QUEUE_COUNTS', {
    open: props.openCount,
    waiting: props.waitingCount,
  })
);
</script>

<template>
  <span
    v-if="leadingIcon"
    class="size-4 grid place-content-center rounded-full"
  >
    <component :is="leadingIcon" />
  </span>
  <div class="flex-1 truncate min-w-0 text-sm">{{ label }}</div>
  <span
    v-if="openCount"
    v-tooltip.top="countTitle"
    class="flex items-center gap-1 text-xs tabular-nums flex-shrink-0"
  >
    <span class="text-n-slate-11">{{ openCount }}</span>
    <span
      v-if="waitingCount"
      class="rounded px-1 bg-n-amber-3 text-n-amber-11 font-medium"
    >
      {{ waitingCount }}
    </span>
  </span>
  <SidebarUnreadBadge :count="badgeCount" />
</template>
