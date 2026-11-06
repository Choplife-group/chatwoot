<script setup>
import { useI18n } from 'vue-i18n';
import { getPermissionGroupSummary } from 'dashboard/helper/permissionsHelper';
import { getI18nKey } from 'dashboard/routes/dashboard/settings/helper/settingsHelper';

import Button from 'dashboard/components-next/button/Button.vue';
import { useEscalationGuard } from 'dashboard/composables/useEscalationGuard';
import { BaseTableRow, BaseTableCell } from 'dashboard/components-next/table';

defineProps({
  roles: {
    type: Array,
    required: true,
  },
  loading: {
    type: Object,
    default: () => ({}),
  },
});

const emit = defineEmits(['edit', 'delete']);

const { t } = useI18n();
const { canManageRole } = useEscalationGuard();

const permissionNames = permissions =>
  permissions
    .map(permission => t(getI18nKey('CUSTOM_ROLE.PERMISSIONS', permission)))
    .join(', ');
</script>

<template>
  <BaseTableRow
    v-for="customRole in roles"
    :key="customRole.id"
    :item="customRole"
  >
    <template #default>
      <BaseTableCell>
        <span class="text-body-main text-n-slate-12 truncate block">
          {{ customRole.name }}
        </span>
      </BaseTableCell>

      <BaseTableCell>
        <span class="text-body-main text-n-slate-11 truncate block">
          {{ customRole.description }}
        </span>
      </BaseTableCell>

      <BaseTableCell>
        <div class="flex flex-wrap gap-1.5">
          <span
            v-for="group in getPermissionGroupSummary(customRole.permissions)"
            :key="group.key"
            v-tooltip.top="permissionNames(group.selected)"
            class="px-2 py-0.5 text-xs rounded-md whitespace-nowrap bg-n-alpha-2 text-n-slate-11"
          >
            {{ $t(`CUSTOM_ROLE.PERMISSION_GROUPS.${group.key}`) }}
            {{ group.selected.length }}/{{ group.total }}
          </span>
        </div>
      </BaseTableCell>

      <BaseTableCell align="end" class="w-24">
        <div class="flex gap-3 justify-end flex-shrink-0">
          <Button
            v-if="canManageRole(customRole)"
            v-tooltip.top="$t('CUSTOM_ROLE.EDIT.BUTTON_TEXT')"
            icon="i-woot-edit-pen"
            slate
            sm
            @click="emit('edit', customRole)"
          />
          <Button
            v-if="canManageRole(customRole)"
            v-tooltip.top="$t('CUSTOM_ROLE.DELETE.BUTTON_TEXT')"
            icon="i-woot-bin"
            slate
            sm
            class="hover:enabled:text-n-ruby-11 hover:enabled:bg-n-ruby-2"
            :is-loading="loading[customRole.id]"
            @click="emit('delete', customRole)"
          />
        </div>
      </BaseTableCell>
    </template>
  </BaseTableRow>
</template>
