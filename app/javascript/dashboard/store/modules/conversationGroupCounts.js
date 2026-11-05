import { debounce } from '@chatwoot/utils';
import types from '../mutation-types';
import ConversationApi from '../../api/inbox/conversation';

// Open and waiting conversation counts per team and per market, shown in the sidebar.
export const GROUPS = ['team', 'market'];
const REFRESH_WAIT_MS = 2000;
const REFRESH_MAX_WAIT_MS = 10000;
const EMPTY_COUNT = { open_count: 0, waiting_count: 0 };

export const state = {
  team: {},
  market: {},
};

export const getters = {
  getCount: _state => (groupBy, id) =>
    _state[groupBy][Number(id)] || EMPTY_COUNT,
};

const fetchGroup = async (commit, groupBy) => {
  try {
    const response = await ConversationApi.groupCounts(groupBy);
    commit(types.SET_CONVERSATION_GROUP_COUNTS, {
      groupBy,
      rows: response.data.payload,
    });
  } catch (error) {
    // Ignore error, the sidebar keeps the last counts
  }
};

const fetchAll = commit =>
  Promise.all(GROUPS.map(groupBy => fetchGroup(commit, groupBy)));

const debouncedFetchAll = debounce(
  fetchAll,
  REFRESH_WAIT_MS,
  false,
  REFRESH_MAX_WAIT_MS
);

export const actions = {
  get: ({ commit }) => fetchAll(commit),
  refresh: ({ commit }) => debouncedFetchAll(commit),
};

export const mutations = {
  [types.SET_CONVERSATION_GROUP_COUNTS](_state, { groupBy, rows }) {
    _state[groupBy] = Object.fromEntries(rows.map(row => [row.id, row]));
  },
};

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations,
};
