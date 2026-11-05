import * as MutationHelpers from 'shared/helpers/vuex/mutationHelpers';
import types from '../mutation-types';
import MarketsAPI from '../../api/markets';

const sortByPosition = (a, b) =>
  a.position - b.position || a.name.localeCompare(b.name);

export const state = {
  records: [],
  uiFlags: {
    isFetching: false,
    isCreating: false,
    isUpdating: false,
  },
};

export const getters = {
  getMarkets(_state) {
    return [..._state.records].sort(sortByPosition);
  },
  getActiveMarkets(_state, _getters) {
    return _getters.getMarkets.filter(market => !market.archived);
  },
  getMarketById: _state => id =>
    _state.records.find(record => record.id === Number(id)) || {},
  getUIFlags(_state) {
    return _state.uiFlags;
  },
};

const errorMessage = error => error?.response?.data?.message;

export const actions = {
  get: async ({ commit }) => {
    commit(types.SET_MARKET_UI_FLAG, { isFetching: true });
    try {
      const response = await MarketsAPI.get();
      commit(types.SET_MARKETS, response.data);
    } catch (error) {
      // Ignore error
    } finally {
      commit(types.SET_MARKET_UI_FLAG, { isFetching: false });
    }
  },

  create: async ({ commit }, market) => {
    commit(types.SET_MARKET_UI_FLAG, { isCreating: true });
    try {
      const response = await MarketsAPI.create({ market });
      commit(types.ADD_MARKET, response.data);
    } catch (error) {
      throw new Error(errorMessage(error));
    } finally {
      commit(types.SET_MARKET_UI_FLAG, { isCreating: false });
    }
  },

  update: async ({ commit }, { id, ...market }) => {
    commit(types.SET_MARKET_UI_FLAG, { isUpdating: true });
    try {
      const response = await MarketsAPI.update(id, { market });
      commit(types.EDIT_MARKET, response.data);
    } catch (error) {
      throw new Error(errorMessage(error));
    } finally {
      commit(types.SET_MARKET_UI_FLAG, { isUpdating: false });
    }
  },
};

export const mutations = {
  [types.SET_MARKET_UI_FLAG](_state, data) {
    _state.uiFlags = { ..._state.uiFlags, ...data };
  },
  [types.SET_MARKETS]: MutationHelpers.set,
  [types.ADD_MARKET]: MutationHelpers.create,
  [types.EDIT_MARKET]: MutationHelpers.update,
};

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations,
};
