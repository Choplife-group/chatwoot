import { getters as rawGetters } from '../../conversationCategories';

const records = [
  {
    id: 1,
    name: 'Withdrawal',
    parent_id: null,
    ancestor_ids: [],
    position: 1,
    archived: false,
  },
  {
    id: 2,
    name: 'Pending approval',
    parent_id: 1,
    ancestor_ids: [1],
    position: 0,
    archived: false,
  },
  {
    id: 3,
    name: 'Old',
    parent_id: 1,
    ancestor_ids: [1],
    position: 1,
    archived: true,
  },
  {
    id: 4,
    name: 'Deposit',
    parent_id: null,
    ancestor_ids: [],
    position: 0,
    archived: false,
  },
];

// Resolve getters that depend on other getters, like Vuex does
const buildGetters = state => {
  const resolved = {};
  Object.entries(rawGetters).forEach(([name, getter]) => {
    Object.defineProperty(resolved, name, {
      get: () => getter(state, resolved),
    });
  });
  return resolved;
};

describe('#conversationCategories getters', () => {
  const getters = buildGetters({ records });

  it('lists active children in display order', () => {
    expect(getters.getChildren(null).map(c => c.name)).toEqual([
      'Deposit',
      'Withdrawal',
    ]);
    expect(getters.getChildren(1).map(c => c.name)).toEqual([
      'Pending approval',
    ]);
    expect(
      getters.getChildren(1, { includeArchived: true }).map(c => c.name)
    ).toEqual(['Pending approval', 'Old']);
  });

  it('walks the tree depth first', () => {
    expect(getters.getFlatTree().map(c => c.id)).toEqual([4, 1, 2]);
  });

  it('builds the full path of a category', () => {
    expect(getters.getPath(2)).toBe('Withdrawal › Pending approval');
    expect(getters.getPath(99)).toBe('');
  });

  it('knows leaves ignore archived children', () => {
    expect(getters.isLeaf(2)).toBe(true);
    expect(getters.isLeaf(1)).toBe(false);
  });

  it('gives every category with its path for filters', () => {
    expect(getters.getPathOptions).toEqual([
      { id: 4, name: 'Deposit' },
      { id: 1, name: 'Withdrawal' },
      { id: 2, name: 'Withdrawal › Pending approval' },
      { id: 3, name: 'Withdrawal › Old' },
    ]);
  });
});
