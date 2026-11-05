import { ref } from 'vue';
import { useMapGetter } from 'dashboard/composables/store';
import { useConversationAccess } from '../useConversationAccess';

vi.mock('dashboard/composables/store');

const setup = ({ enabled = true, role = 'agent', ledTeamIds = [] } = {}) => {
  const getters = {
    getCurrentUser: ref({
      accounts: [{ id: 1, led_team_ids: ledTeamIds }],
    }),
    getCurrentRole: ref(role),
    getCurrentAccountId: ref(1),
    'accounts/isFeatureEnabledonAccount': ref(() => enabled),
  };
  useMapGetter.mockImplementation(name => getters[name]);
  return useConversationAccess();
};

const conversationInTeam = id => ({ meta: { team: { id } } });

describe('useConversationAccess', () => {
  it('allows everything when the feature is off', () => {
    const { isRestricted, canSeeQueues, canAssign } = setup({ enabled: false });

    expect(isRestricted.value).toBe(false);
    expect(canSeeQueues.value).toBe(true);
    expect(canAssign(conversationInTeam(1))).toBe(true);
  });

  it('does not restrict an administrator, but knows the account is restricted', () => {
    const { isAccountRestricted, isRestricted, canAssign } = setup({
      role: 'administrator',
    });

    expect(isAccountRestricted.value).toBe(true);
    expect(isRestricted.value).toBe(false);
    expect(canAssign({ meta: {} })).toBe(true);
  });

  it('limits an agent to their own list and no assigning', () => {
    const { canSeeQueues, canAssign } = setup();

    expect(canSeeQueues.value).toBe(false);
    expect(canAssign(conversationInTeam(1))).toBe(false);
  });

  it('lets a lead assign only in the teams they lead', () => {
    const { canSeeQueues, canAssign } = setup({ ledTeamIds: [3] });

    expect(canSeeQueues.value).toBe(true);
    expect(canAssign(conversationInTeam(3))).toBe(true);
    expect(canAssign(conversationInTeam(4))).toBe(false);
  });

  it('limits the VIP mark to leads of the team and administrators', () => {
    expect(setup({ enabled: false }).canChangeVip(conversationInTeam(3))).toBe(
      false
    );
    expect(setup({ ledTeamIds: [3] }).canChangeVip(conversationInTeam(3))).toBe(
      true
    );
    expect(setup({ ledTeamIds: [3] }).canChangeVip(conversationInTeam(4))).toBe(
      false
    );
    expect(setup({ role: 'administrator' }).canChangeVip({ meta: {} })).toBe(
      true
    );
  });
});
