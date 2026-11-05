import * as MutationHelpers from 'shared/helpers/vuex/mutationHelpers';
import types from '../mutation-types';
import ConversationCategoriesAPI from '../../api/conversationCategories';

// Reason-for-contact tree. The API returns a flat list; parent_id / ancestor_ids give the shape.
export const PATH_SEPARATOR = ' › ';
export const MAX_DEPTH = 5;

const byPosition = (a, b) =>
  a.position - b.position || a.name.localeCompare(b.name);

export const state = {
  records: [],
  uiFlags: {
    isFetching: false,
    isSaving: false,
  },
};

export const getters = {
  getCategories: _state => _state.records,
  getCategoryById: _state => id =>
    _state.records.find(record => record.id === Number(id)) || null,
  // Children of a category (null for top level), in display order
  getChildren:
    _state =>
    (parentId, { includeArchived = false } = {}) =>
      _state.records
        .filter(
          record =>
            (record.parent_id ?? null) === (parentId ?? null) &&
            (includeArchived || !record.archived)
        )
        .sort(byPosition),
  // Depth-first list, the order the settings tree and filter options show
  getFlatTree:
    (_state, _getters) =>
    ({ includeArchived = false } = {}) => {
      const walk = parentId =>
        _getters
          .getChildren(parentId, { includeArchived })
          .flatMap(category => [category, ...walk(category.id)]);
      return walk(null);
    },
  isLeaf: (_state, _getters) => id => !_getters.getChildren(id).length,
  getPath: (_state, _getters) => id => {
    const category = _getters.getCategoryById(id);
    if (!category) return '';
    return [...category.ancestor_ids, category.id]
      .map(ancestorId => _getters.getCategoryById(ancestorId)?.name)
      .filter(Boolean)
      .join(PATH_SEPARATOR);
  },
  // Every category (archived too) with its full path as the name, for filters and saved views
  getPathOptions: (_state, _getters) =>
    _getters.getFlatTree({ includeArchived: true }).map(category => ({
      id: category.id,
      name: _getters.getPath(category.id),
    })),
  getUIFlags: _state => _state.uiFlags,
};

const errorMessage = error =>
  error?.response?.data?.message || error?.response?.data?.error;

export const actions = {
  get: async ({ commit }) => {
    commit(types.SET_CONVERSATION_CATEGORY_UI_FLAG, { isFetching: true });
    try {
      const response = await ConversationCategoriesAPI.get();
      commit(types.SET_CONVERSATION_CATEGORIES, response.data);
    } catch (error) {
      // Ignore error
    } finally {
      commit(types.SET_CONVERSATION_CATEGORY_UI_FLAG, { isFetching: false });
    }
  },

  create: async ({ commit }, category) => {
    commit(types.SET_CONVERSATION_CATEGORY_UI_FLAG, { isSaving: true });
    try {
      const response = await ConversationCategoriesAPI.create({
        conversation_category: category,
      });
      commit(types.ADD_CONVERSATION_CATEGORY, response.data);
    } catch (error) {
      throw new Error(errorMessage(error));
    } finally {
      commit(types.SET_CONVERSATION_CATEGORY_UI_FLAG, { isSaving: false });
    }
  },

  update: async ({ commit }, { id, ...category }) => {
    commit(types.SET_CONVERSATION_CATEGORY_UI_FLAG, { isSaving: true });
    try {
      const response = await ConversationCategoriesAPI.update(id, {
        conversation_category: category,
      });
      commit(types.EDIT_CONVERSATION_CATEGORY, response.data);
    } catch (error) {
      throw new Error(errorMessage(error));
    } finally {
      commit(types.SET_CONVERSATION_CATEGORY_UI_FLAG, { isSaving: false });
    }
  },

  // Archiving or restoring changes the whole branch, so reload the list
  setArchived: async ({ dispatch }, { id, archived }) => {
    try {
      await ConversationCategoriesAPI.update(id, {
        conversation_category: { archived },
      });
    } catch (error) {
      throw new Error(errorMessage(error));
    }
    await dispatch('get');
  },

  reorder: async ({ dispatch }, ids) => {
    try {
      await ConversationCategoriesAPI.reorder(ids);
    } catch (error) {
      throw new Error(errorMessage(error));
    }
    await dispatch('get');
  },
};

export const mutations = {
  [types.SET_CONVERSATION_CATEGORY_UI_FLAG](_state, data) {
    _state.uiFlags = { ..._state.uiFlags, ...data };
  },
  [types.SET_CONVERSATION_CATEGORIES]: MutationHelpers.set,
  [types.ADD_CONVERSATION_CATEGORY]: MutationHelpers.create,
  [types.EDIT_CONVERSATION_CATEGORY]: MutationHelpers.update,
};

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations,
};
