import { computed } from 'vue';
import { useMapGetter } from 'dashboard/composables/store';
import {
  getCurrentAccount,
  getUserPermissions,
} from 'dashboard/helper/permissionsHelper';

/**
 * What someone with agent_manage or role_manage can hand out.
 * Agents::EscalationGuard enforces this in the API; here it only decides what the dashboard offers.
 */
export function useEscalationGuard() {
  const currentUser = useMapGetter('getCurrentUser');
  const currentRole = useMapGetter('getCurrentRole');
  const accountId = useMapGetter('getCurrentAccountId');

  const isAdministrator = computed(() => currentRole.value === 'administrator');
  const permissions = computed(() =>
    getUserPermissions(currentUser.value, accountId.value)
  );

  const holds = (required = []) =>
    isAdministrator.value ||
    required.every(permission => permissions.value.includes(permission));

  const canManageAgent = agent =>
    isAdministrator.value ||
    (agent.id !== currentUser.value.id &&
      agent.role !== 'administrator' &&
      holds(agent.permissions));

  const canManageRole = role => {
    if (isAdministrator.value) return true;

    const account = getCurrentAccount(currentUser.value, accountId.value) || {};
    return role.id !== account.custom_role_id && holds(role.permissions);
  };

  return { isAdministrator, holds, canManageAgent, canManageRole };
}
