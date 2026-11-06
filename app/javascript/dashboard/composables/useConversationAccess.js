import { computed } from 'vue';
import { useMapGetter } from 'dashboard/composables/store';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';
import { getUserPermissions } from 'dashboard/helper/permissionsHelper';

/**
 * What the current user can do when restricted_inbox_access is on.
 * The API enforces all of this; here it only decides what the dashboard offers.
 */
export function useConversationAccess() {
  const currentUser = useMapGetter('getCurrentUser');
  const currentRole = useMapGetter('getCurrentRole');
  const accountId = useMapGetter('getCurrentAccountId');
  const isFeatureEnabled = useMapGetter('accounts/isFeatureEnabledonAccount');

  const isAccountRestricted = computed(() =>
    isFeatureEnabled.value(
      accountId.value,
      FEATURE_FLAGS.RESTRICTED_INBOX_ACCESS
    )
  );

  const permissions = computed(() =>
    getUserPermissions(currentUser.value, accountId.value)
  );
  const hasPermission = permission =>
    currentRole.value === 'administrator' ||
    permissions.value.includes(permission);

  // Restricted users can only assign within the teams they lead
  const isRestricted = computed(
    () => isAccountRestricted.value && !hasPermission('conversation_assign')
  );

  const ledTeamIds = computed(() => {
    const { accounts = [] } = currentUser.value;
    return (
      accounts.find(account => account.id === accountId.value)?.led_team_ids ||
      []
    );
  });

  const canSeeQueues = computed(
    () =>
      !isAccountRestricted.value ||
      hasPermission('conversation_manage') ||
      ledTeamIds.value.length > 0
  );

  const canAssign = conversation =>
    !isRestricted.value ||
    ledTeamIds.value.includes(conversation?.meta?.team?.id);

  // Doesn't depend on restricted_inbox_access: the VIP mark is always limited to leads and above
  const canChangeVip = conversation =>
    hasPermission('vip_manage') ||
    ledTeamIds.value.includes(conversation?.meta?.team?.id);

  return {
    isAccountRestricted,
    isRestricted,
    canSeeQueues,
    canAssign,
    canChangeVip,
  };
}
