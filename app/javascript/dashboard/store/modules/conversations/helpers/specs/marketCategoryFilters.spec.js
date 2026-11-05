import { matchesFilters } from '../filterHelpers';
import { applyPageFilters } from '../../helpers';

const conversation = {
  status: 'open',
  labels: [],
  meta: {
    market: { id: 4, name: 'Uganda', code: 'UG' },
    category: { id: 12, name: 'Pending approval', ancestor_ids: [10] },
  },
};

const filter = (attributeKey, values, filterOperator = 'equal_to') => [
  {
    attribute_key: attributeKey,
    filter_operator: filterOperator,
    values,
    query_operator: 'and',
  },
];

describe('market and category filters', () => {
  it('matches the market', () => {
    expect(matchesFilters(conversation, filter('market_id', { id: 4 }))).toBe(
      true
    );
    expect(matchesFilters(conversation, filter('market_id', { id: 5 }))).toBe(
      false
    );
  });

  it('matches a category by itself or by any parent', () => {
    expect(
      matchesFilters(conversation, filter('category_id', { id: 12 }))
    ).toBe(true);
    expect(
      matchesFilters(conversation, filter('category_id', { id: 10 }))
    ).toBe(true);
    expect(
      matchesFilters(conversation, filter('category_id', { id: 11 }))
    ).toBe(false);
  });

  it('treats an uncategorised conversation as not present', () => {
    const uncategorised = { ...conversation, meta: {} };
    expect(
      matchesFilters(uncategorised, filter('category_id', [], 'is_not_present'))
    ).toBe(true);
  });

  it('keeps a conversation on the market page only for its market', () => {
    expect(
      applyPageFilters(conversation, { status: 'open', marketId: '4' })
    ).toBe(true);
    expect(
      applyPageFilters(conversation, { status: 'open', marketId: '5' })
    ).toBe(false);
  });
});
