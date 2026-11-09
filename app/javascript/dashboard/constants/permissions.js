export const CUSTOM_ROLE_PERMISSION_GROUPS = [
  {
    key: 'CONVERSATIONS',
    permissions: [
      'conversation_manage',
      'conversation_assign',
      'conversation_delete',
      'vip_manage',
    ],
  },
  { key: 'REPORTS', permissions: ['report_manage'] },
  { key: 'INBOXES', permissions: ['inbox_manage'] },
  {
    key: 'SUPPORT_SETUP',
    permissions: ['category_manage', 'market_manage', 'sla_manage'],
  },
  {
    key: 'PEOPLE_AND_ACCESS',
    permissions: ['team_manage', 'agent_manage', 'role_manage'],
  },
];

export const AVAILABLE_CUSTOM_ROLE_PERMISSIONS =
  CUSTOM_ROLE_PERMISSION_GROUPS.flatMap(group => group.permissions);

// These have side effects worth explaining when the permission is ticked
export const CUSTOM_ROLE_PERMISSIONS_WITH_HINTS = [
  'conversation_manage',
  'conversation_delete',
  'report_manage',
  'inbox_manage',
  'team_manage',
  'agent_manage',
  'role_manage',
];

export const ROLES = ['agent', 'administrator'];

export const CONVERSATION_PERMISSIONS = [
  'conversation_manage',
  'conversation_unassigned_manage',
  'conversation_participating_manage',
];

export const MANAGE_ALL_CONVERSATION_PERMISSIONS = 'conversation_manage';

export const CONVERSATION_UNASSIGNED_PERMISSIONS =
  'conversation_unassigned_manage';

export const CONVERSATION_PARTICIPATING_PERMISSIONS =
  'conversation_participating_manage';

export const CONTACT_PERMISSIONS = 'contact_manage';

export const REPORTS_PERMISSIONS = 'report_manage';

export const PORTAL_PERMISSIONS = 'knowledge_base_manage';

export const ASSIGNEE_TYPE_TAB_PERMISSIONS = {
  me: {
    count: 'mineCount',
    permissions: [...ROLES, ...CONVERSATION_PERMISSIONS],
  },
  unassigned: {
    count: 'unAssignedCount',
    permissions: [
      ...ROLES,
      MANAGE_ALL_CONVERSATION_PERMISSIONS,
      CONVERSATION_UNASSIGNED_PERMISSIONS,
    ],
  },
  all: {
    count: 'allCount',
    permissions: [
      ...ROLES,
      MANAGE_ALL_CONVERSATION_PERMISSIONS,
      CONVERSATION_PARTICIPATING_PERMISSIONS,
    ],
  },
};
