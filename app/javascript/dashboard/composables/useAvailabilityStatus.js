import { computed, h } from 'vue';
import { useI18n } from 'vue-i18n';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import { useImpersonation } from 'dashboard/composables/useImpersonation';
import wootConstants from 'dashboard/constants/globals';

const STATUS_COLORS = ['bg-n-teal-9', 'bg-n-amber-9', 'bg-n-slate-9'];

export function useAvailabilityStatus() {
  const { t } = useI18n();
  const store = useStore();
  const currentUserAvailability = useMapGetter('getCurrentUserAvailability');
  const currentAccountId = useMapGetter('getCurrentAccountId');
  const { isImpersonating } = useImpersonation();
  const { AVAILABILITY_STATUS_KEYS } = wootConstants;

  const availabilityStatuses = computed(() =>
    [
      t('PROFILE_SETTINGS.FORM.AVAILABILITY.STATUS.ONLINE'),
      t('PROFILE_SETTINGS.FORM.AVAILABILITY.STATUS.BUSY'),
      t('PROFILE_SETTINGS.FORM.AVAILABILITY.STATUS.OFFLINE'),
    ].map((label, index) => ({
      label,
      value: AVAILABILITY_STATUS_KEYS[index],
      color: STATUS_COLORS[index],
      icon: h('span', { class: [STATUS_COLORS[index], 'size-[12px] rounded'] }),
      active: currentUserAvailability.value === AVAILABILITY_STATUS_KEYS[index],
    }))
  );

  const activeStatus = computed(() =>
    availabilityStatuses.value.find(status => status.active)
  );

  const changeAvailabilityStatus = availability => {
    if (isImpersonating.value) {
      useAlert(t('PROFILE_SETTINGS.FORM.AVAILABILITY.IMPERSONATING_ERROR'));
      return;
    }
    try {
      store.dispatch('updateAvailability', {
        availability,
        account_id: currentAccountId.value,
      });
    } catch (error) {
      useAlert(t('PROFILE_SETTINGS.FORM.AVAILABILITY.SET_AVAILABILITY_ERROR'));
    }
  };

  return { availabilityStatuses, activeStatus, changeAvailabilityStatus };
}
