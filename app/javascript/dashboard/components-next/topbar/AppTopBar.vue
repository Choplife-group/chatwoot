<script setup>
import { computed } from 'vue';
import { useRoute } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useMapGetter } from 'dashboard/composables/store';
import { useAccount } from 'dashboard/composables/useAccount';
import { useAvailabilityStatus } from 'dashboard/composables/useAvailabilityStatus';
import Button from 'dashboard/components-next/button/Button.vue';
import ComposeConversation from 'dashboard/components-next/NewConversation/ComposeConversation.vue';
import GlobalSearch from 'dashboard/components-next/search/GlobalSearch.vue';
import SidebarProfileMenu from 'dashboard/components-next/sidebar/SidebarProfileMenu.vue';
import {
  DropdownContainer,
  DropdownBody,
  DropdownItem,
} from 'next/dropdown-menu/base';

const emit = defineEmits(['openKeyShortcutModal']);

const CONVERSATION_SECTIONS = [
  'dashboard',
  'conversations',
  'inbox',
  'label',
  'team',
  'market',
  'custom_view',
  'mentions',
  'unattended',
  'participating',
];
const MAX_BADGE_COUNT = 99;

const { t } = useI18n();
const route = useRoute();
const { accountScopedRoute } = useAccount();
const unreadNotificationCount = useMapGetter('notifications/getUnreadCount');
const { availabilityStatuses, activeStatus, changeAvailabilityStatus } =
  useAvailabilityStatus();

const sectionTitles = computed(() => ({
  'inbox-view': t('SIDEBAR.INBOX'),
  calls: t('SIDEBAR.CALLS'),
  contacts: t('SIDEBAR.CONTACTS'),
  companies: t('SIDEBAR.COMPANIES'),
  campaigns: t('SIDEBAR.CAMPAIGNS'),
  captain: t('SIDEBAR.CAPTAIN'),
  portals: t('SIDEBAR.HELP_CENTER.TITLE'),
  settings: t('SIDEBAR.SETTINGS'),
  profile: t('SIDEBAR_ITEMS.PROFILE_SETTINGS'),
  insights: t('SIDEBAR.DASHBOARD'),
  reports: t('SIDEBAR.REPORTS'),
  conversations: t('SIDEBAR.CONVERSATIONS'),
}));

const pageTitle = computed(() => {
  const [section, subSection] =
    route.path.split(/\/accounts\/\d+\//)[1]?.split('/') || [];
  if (CONVERSATION_SECTIONS.includes(section)) {
    return sectionTitles.value.conversations;
  }
  if (section === 'reports' && subSection === 'insights') {
    return sectionTitles.value.insights;
  }
  return sectionTitles.value[section] || '';
});

const notificationBadge = computed(() =>
  unreadNotificationCount.value > MAX_BADGE_COUNT
    ? `${MAX_BADGE_COUNT}+`
    : unreadNotificationCount.value
);

// The search page has its own input
const showSearch = computed(() => route.name !== 'search');
</script>

<template>
  <header
    class="relative z-50 flex flex-shrink-0 items-center gap-2 h-14 px-4 border-b border-n-weak dark:border-n-strong bg-n-background dark:bg-n-solid-2"
  >
    <h1
      v-if="pageTitle"
      class="hidden sm:block min-w-0 m-0 text-base font-medium truncate text-n-slate-12"
    >
      {{ pageTitle }}
    </h1>
    <div class="flex items-center flex-shrink-0 gap-2 ms-auto">
      <GlobalSearch v-if="showSearch" />
      <ComposeConversation>
        <template #trigger="{ isOpen }">
          <Button
            icon="i-lucide-plus"
            :label="t('SIDEBAR.NEW_CONVERSATION')"
            :aria-label="t('SIDEBAR.NEW_CONVERSATION')"
            size="sm"
            class="max-md:[&>span:last-child]:hidden"
            :class="{ 'brightness-95': isOpen }"
          />
        </template>
      </ComposeConversation>
      <RouterLink
        v-tooltip.bottom="t('SIDEBAR.NOTIFICATIONS')"
        :to="accountScopedRoute('inbox_view')"
        :aria-label="t('SIDEBAR.NOTIFICATIONS')"
        class="relative grid rounded-lg size-8 place-content-center text-n-slate-11 hover:bg-n-alpha-2 hover:text-n-slate-12"
      >
        <span class="i-lucide-bell size-4" />
        <span
          v-if="unreadNotificationCount"
          class="absolute -top-0.5 ltr:-right-0.5 rtl:-left-0.5 inline-grid h-4 min-w-4 place-items-center rounded-full bg-n-brand px-1 text-xxs font-medium leading-none text-white"
        >
          {{ notificationBadge }}
        </span>
      </RouterLink>
      <DropdownContainer v-if="activeStatus" class="relative hidden md:block">
        <template #trigger="{ toggle, isOpen }">
          <button
            type="button"
            class="flex items-center gap-1.5 h-8 px-2.5 rounded-lg text-sm text-n-slate-12 outline outline-1 outline-n-weak hover:bg-n-alpha-2"
            :class="{ 'bg-n-alpha-2': isOpen }"
            :aria-label="t('SIDEBAR.SET_YOUR_AVAILABILITY')"
            @click="toggle"
          >
            <span class="size-2 rounded-sm" :class="activeStatus.color" />
            {{ activeStatus.label }}
            <span class="i-lucide-chevron-down size-3.5 text-n-slate-10" />
          </button>
        </template>
        <DropdownBody
          class="top-full z-50 mt-2 min-w-36 ltr:right-0 rtl:left-0"
        >
          <DropdownItem
            v-for="status in availabilityStatuses"
            :key="status.value"
            :label="status.label"
            :icon="status.icon"
            class="cursor-pointer"
            @click="changeAvailabilityStatus(status.value)"
          />
        </DropdownBody>
      </DropdownContainer>
      <SidebarProfileMenu
        @open-key-shortcut-modal="emit('openKeyShortcutModal')"
      />
    </div>
  </header>
</template>
