const roleMapping = {
  0: 'agent',
  1: 'administrator',
};

const availabilityMapping = {
  0: 'online',
  1: 'offline',
  2: 'busy',
};

const translationKeys = {
  'automationrule:create': `AUDIT_LOGS.AUTOMATION_RULE.ADD`,
  'automationrule:update': `AUDIT_LOGS.AUTOMATION_RULE.EDIT`,
  'automationrule:destroy': `AUDIT_LOGS.AUTOMATION_RULE.DELETE`,
  'webhook:create': `AUDIT_LOGS.WEBHOOK.ADD`,
  'webhook:update': `AUDIT_LOGS.WEBHOOK.EDIT`,
  'webhook:destroy': `AUDIT_LOGS.WEBHOOK.DELETE`,
  'inbox:create': `AUDIT_LOGS.INBOX.ADD`,
  'inbox:update': `AUDIT_LOGS.INBOX.EDIT`,
  'inbox:destroy': `AUDIT_LOGS.INBOX.DELETE`,
  'user:sign_in': `AUDIT_LOGS.USER_ACTION.SIGN_IN`,
  'user:sign_out': `AUDIT_LOGS.USER_ACTION.SIGN_OUT`,
  'team:create': `AUDIT_LOGS.TEAM.ADD`,
  'team:update': `AUDIT_LOGS.TEAM.EDIT`,
  'team:destroy': `AUDIT_LOGS.TEAM.DELETE`,
  'macro:create': `AUDIT_LOGS.MACRO.ADD`,
  'macro:update': `AUDIT_LOGS.MACRO.EDIT`,
  'macro:destroy': `AUDIT_LOGS.MACRO.DELETE`,
  'accountuser:create': `AUDIT_LOGS.ACCOUNT_USER.ADD`,
  'accountuser:update:self': `AUDIT_LOGS.ACCOUNT_USER.EDIT.SELF`,
  'accountuser:update:other': `AUDIT_LOGS.ACCOUNT_USER.EDIT.OTHER`,
  'accountuser:update:deleted': `AUDIT_LOGS.ACCOUNT_USER.EDIT.DELETED`,
  'inboxmember:create': `AUDIT_LOGS.INBOX_MEMBER.ADD`,
  'inboxmember:destroy': `AUDIT_LOGS.INBOX_MEMBER.REMOVE`,
  'teammember:create': `AUDIT_LOGS.TEAM_MEMBER.ADD`,
  'teammember:destroy': `AUDIT_LOGS.TEAM_MEMBER.REMOVE`,
  'account:update': `AUDIT_LOGS.ACCOUNT.EDIT`,
  'conversation:destroy': `AUDIT_LOGS.CONVERSATION.DELETE`,
  'message:destroy': `AUDIT_LOGS.MESSAGE.DELETE`,
  // Choplife fork: our own settings
  'market:create': `AUDIT_LOGS.COUNTRY.ADD`,
  'market:update': `AUDIT_LOGS.COUNTRY.EDIT`,
  'market:destroy': `AUDIT_LOGS.COUNTRY.DELETE`,
  'conversationcategory:create': `AUDIT_LOGS.CATEGORY.ADD`,
  'conversationcategory:update': `AUDIT_LOGS.CATEGORY.EDIT`,
  'conversationcategory:destroy': `AUDIT_LOGS.CATEGORY.DELETE`,
  'supportrole:create': `AUDIT_LOGS.CUSTOM_ROLE.ADD`,
  'supportrole:update': `AUDIT_LOGS.CUSTOM_ROLE.EDIT`,
  'supportrole:destroy': `AUDIT_LOGS.CUSTOM_ROLE.DELETE`,
  'slatarget:create': `AUDIT_LOGS.SLA_TARGET.ADD`,
  'slatarget:update': `AUDIT_LOGS.SLA_TARGET.EDIT`,
  'slatarget:destroy': `AUDIT_LOGS.SLA_TARGET.DELETE`,
  'assignmentpolicy:create': `AUDIT_LOGS.ASSIGNMENT_POLICY.ADD`,
  'assignmentpolicy:update': `AUDIT_LOGS.ASSIGNMENT_POLICY.EDIT`,
  'assignmentpolicy:destroy': `AUDIT_LOGS.ASSIGNMENT_POLICY.DELETE`,
  'capacitypolicy:create': `AUDIT_LOGS.CAPACITY_POLICY.ADD`,
  'capacitypolicy:update': `AUDIT_LOGS.CAPACITY_POLICY.EDIT`,
  'capacitypolicy:destroy': `AUDIT_LOGS.CAPACITY_POLICY.DELETE`,
};

function extractAttrChange(attrChange) {
  if (Array.isArray(attrChange)) {
    return attrChange[attrChange.length - 1];
  }
  return attrChange;
}

export function extractChangedAccountUserValues(auditedChanges) {
  let changes = [];
  let values = [];

  // Check roles
  if (auditedChanges.role && auditedChanges.role.length) {
    changes.push('role');
    values.push(roleMapping[extractAttrChange(auditedChanges.role)]);
  }

  // Check availability
  if (auditedChanges.availability && auditedChanges.availability.length) {
    changes.push('availability');
    values.push(
      availabilityMapping[extractAttrChange(auditedChanges.availability)]
    );
  }

  // Choplife fork: custom role and capacity policy, shown by id ("none" when cleared)
  [
    ['custom_role_id', 'custom role'],
    ['agent_capacity_policy_id', 'capacity policy'],
  ].forEach(([key, label]) => {
    if (!(key in auditedChanges)) return;
    const id = extractAttrChange(auditedChanges[key]);
    changes.push(label);
    values.push(id ? `#${id}` : 'none');
  });

  return { changes, values };
}

function getAgentName(userId, agentList) {
  if (userId === null) {
    return 'System';
  }

  const agentName = agentList.find(agent => agent.id === userId)?.name;

  // If agent does not exist(removed/deleted), return userId
  return agentName || userId;
}

function handleAccountUserCreate(auditLogItem, translationPayload, agentList) {
  translationPayload.invitee = getAgentName(
    auditLogItem.audited_changes.user_id,
    agentList
  );

  const roleKey = auditLogItem.audited_changes.role;
  translationPayload.role = roleMapping[roleKey] || 'unknown'; // 'unknown' as a fallback in case an unrecognized key is provided

  return translationPayload;
}

function handleAccountUserUpdate(auditLogItem, translationPayload, agentList) {
  if (auditLogItem.user_id !== auditLogItem.auditable?.user_id) {
    translationPayload.user = getAgentName(
      auditLogItem.auditable?.user_id,
      agentList
    );
  }

  const accountUserChanges = extractChangedAccountUserValues(
    auditLogItem.audited_changes
  );
  if (accountUserChanges) {
    translationPayload.attributes = accountUserChanges.changes;
    translationPayload.values = accountUserChanges.values;
  }
  return translationPayload;
}

function setUserInPayload(auditLogItem, translationPayload, agentList) {
  const userIdChange = auditLogItem.audited_changes.user_id;
  if (userIdChange && userIdChange !== undefined) {
    translationPayload.user = getAgentName(userIdChange, agentList);
  }
  return translationPayload;
}

function setTeamIdInPayload(auditLogItem, translationPayload) {
  if (auditLogItem.audited_changes.team_id) {
    translationPayload.team_id = auditLogItem.audited_changes.team_id;
  }
  return translationPayload;
}

function setInboxIdInPayload(auditLogItem, translationPayload) {
  if (auditLogItem.audited_changes.inbox_id) {
    translationPayload.inbox_id = auditLogItem.audited_changes.inbox_id;
  }
  return translationPayload;
}

function handleInboxTeamMember(auditLogItem, translationPayload, agentList) {
  if (auditLogItem.audited_changes) {
    translationPayload = setUserInPayload(
      auditLogItem,
      translationPayload,
      agentList
    );
    translationPayload = setTeamIdInPayload(auditLogItem, translationPayload);
    translationPayload = setInboxIdInPayload(auditLogItem, translationPayload);
  }
  return translationPayload;
}

function handleAccountUser(
  auditLogItem,
  translationPayload,
  agentList,
  action
) {
  if (action === 'create') {
    return handleAccountUserCreate(auditLogItem, translationPayload, agentList);
  }

  if (action === 'update') {
    return handleAccountUserUpdate(auditLogItem, translationPayload, agentList);
  }

  return translationPayload;
}

export function generateTranslationPayload(auditLogItem, agentList) {
  let translationPayload = {
    agentName: getAgentName(auditLogItem.user_id, agentList),
    id: auditLogItem.auditable_id,
  };

  const auditableType = auditLogItem.auditable_type.toLowerCase();
  const action = auditLogItem.action.toLowerCase();

  if (auditableType === 'conversation' && action === 'destroy') {
    translationPayload.id =
      auditLogItem.audited_changes?.display_id || auditLogItem.auditable_id;
  }

  if (auditableType === 'message' && action === 'destroy') {
    translationPayload.conversationId =
      auditLogItem.audited_changes?.display_id;
  }

  if (auditableType === 'accountuser') {
    translationPayload = handleAccountUser(
      auditLogItem,
      translationPayload,
      agentList,
      action
    );
  }

  if (auditableType === 'inboxmember' || auditableType === 'teammember') {
    translationPayload = handleInboxTeamMember(
      auditLogItem,
      translationPayload,
      agentList
    );
  }

  return translationPayload;
}

function getAccountUserUpdateSuffix(auditLogItem) {
  if (auditLogItem.auditable === null) {
    // If the user is deleted, we don't need to check if the user is the same as the auditLogItem.user_id
    // Else we can use the deleted translation key
    // It doesn't need the agent name
    return ':deleted';
  }
  return auditLogItem.user_id === auditLogItem.auditable.user_id
    ? ':self'
    : ':other';
}

export const generateLogActionKey = auditLogItem => {
  const auditableType = auditLogItem.auditable_type.toLowerCase();
  const action = auditLogItem.action.toLowerCase();
  let logActionKey = `${auditableType}:${action}`;

  if (auditableType === 'accountuser' && action === 'update') {
    logActionKey += getAccountUserUpdateSuffix(auditLogItem);
  }

  return translationKeys[logActionKey] || '';
};

export const EVENT_TYPE_GROUPS = [
  { key: 'ACCESS', types: [{ value: 'User', key: 'SIGN_IN_OUT' }] },
  {
    key: 'AGENTS_TEAMS',
    types: [
      { value: 'AccountUser', key: 'AGENTS' },
      { value: 'Team', key: 'TEAMS' },
      { value: 'TeamMember', key: 'TEAM_MEMBERS' },
      { value: 'InboxMember', key: 'INBOX_MEMBERS' },
    ],
  },
  {
    key: 'CONFIGURATION',
    types: [
      { value: 'Account', key: 'ACCOUNT' },
      { value: 'Inbox', key: 'INBOXES' },
      { value: 'Webhook', key: 'WEBHOOKS' },
      { value: 'AutomationRule', key: 'AUTOMATION_RULES' },
      { value: 'Macro', key: 'MACROS' },
      { value: 'Market', key: 'COUNTRIES' },
      { value: 'ConversationCategory', key: 'CATEGORIES' },
      { value: 'SupportRole', key: 'CUSTOM_ROLES' },
      { value: 'SlaTarget', key: 'SLA_TARGETS' },
      { value: 'AssignmentPolicy', key: 'ASSIGNMENT_POLICIES' },
      { value: 'CapacityPolicy', key: 'CAPACITY_POLICIES' },
    ],
  },
  {
    key: 'CONVERSATIONS',
    types: [
      { value: 'Conversation', key: 'CONVERSATION_DELETIONS' },
      { value: 'Message', key: 'MESSAGE_DELETIONS' },
    ],
  },
];

const SUPPORTED_TYPES = EVENT_TYPE_GROUPS.flatMap(({ types }) =>
  types.map(({ value }) => value)
);
const SORT_ORDERS = ['asc', 'desc'];

export const auditLogFiltersFromQuery = (query = {}) => {
  const filters = { page: Number(query.page) || 1 };

  if (query.q) filters.q = query.q;
  if (SUPPORTED_TYPES.includes(query.type)) filters.types = [query.type];
  if (SORT_ORDERS.includes(query.sort)) filters.sort = query.sort;

  const since = Number(query.since);
  const until = Number(query.until);
  if (since > 0 && until > 0) {
    filters.since = since;
    filters.until = until;
  }

  return filters;
};

export const buildAuditLogRouteQuery = (query = {}) =>
  Object.fromEntries(
    Object.entries(query).filter(
      ([, value]) => value !== undefined && value !== ''
    )
  );
