import types from '../../mutation-types';
import { getters, mutations } from '../conversationGroupCounts';

describe('#conversationGroupCounts', () => {
  it('stores the counts by id and reads them back', () => {
    const state = { team: {}, market: {} };
    mutations[types.SET_CONVERSATION_GROUP_COUNTS](state, {
      groupBy: 'market',
      rows: [{ id: 4, open_count: 12, waiting_count: 3 }],
    });

    expect(getters.getCount(state)('market', '4')).toEqual({
      id: 4,
      open_count: 12,
      waiting_count: 3,
    });
    expect(getters.getCount(state)('team', 1)).toEqual({
      open_count: 0,
      waiting_count: 0,
    });
  });
});
