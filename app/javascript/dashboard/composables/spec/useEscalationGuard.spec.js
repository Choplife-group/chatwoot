import { ref } from 'vue';
import { useMapGetter } from 'dashboard/composables/store';
import { useEscalationGuard } from '../useEscalationGuard';

vi.mock('dashboard/composables/store');

const setup = ({ role = 'agent', permissions = ['agent'] } = {}) => {
  const getters = {
    getCurrentUser: ref({
      id: 1,
      accounts: [{ id: 1, custom_role_id: 5, permissions }],
    }),
    getCurrentRole: ref(role),
    getCurrentAccountId: ref(1),
  };
  useMapGetter.mockImplementation(name => getters[name]);
  return useEscalationGuard();
};

describe('useEscalationGuard', () => {
  const held = ['agent', 'agent_manage', 'report_manage'];

  it('lets an administrator do everything', () => {
    const guard = setup({ role: 'administrator', permissions: [] });

    expect(guard.holds(['vip_manage'])).toBe(true);
    expect(guard.canManageAgent({ id: 2, role: 'administrator' })).toBe(true);
    expect(guard.canManageRole({ id: 5, permissions: ['vip_manage'] })).toBe(
      true
    );
  });

  it('only reaches agents with no more access, never themselves or admins', () => {
    const guard = setup({ permissions: held });
    const agent = (id, role, permissions) => ({ id, role, permissions });

    expect(guard.canManageAgent(agent(2, 'agent', ['agent']))).toBe(true);
    expect(guard.canManageAgent(agent(1, 'agent', ['agent']))).toBe(false);
    expect(guard.canManageAgent(agent(2, 'administrator', []))).toBe(false);
    expect(guard.canManageAgent(agent(2, 'agent', ['vip_manage']))).toBe(false);
  });

  it('refuses their own role and roles with more access', () => {
    const guard = setup({ permissions: held });

    expect(guard.canManageRole({ id: 6, permissions: ['report_manage'] })).toBe(
      true
    );
    expect(guard.canManageRole({ id: 5, permissions: ['report_manage'] })).toBe(
      false
    );
    expect(guard.canManageRole({ id: 6, permissions: ['vip_manage'] })).toBe(
      false
    );
  });
});
