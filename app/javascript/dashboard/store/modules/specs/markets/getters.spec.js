import { getters } from '../../markets';

const records = [
  { id: 1, name: 'Uganda', code: 'UG', position: 2, archived: false },
  { id: 2, name: 'Kenya', code: 'KE', position: 1, archived: true },
  { id: 3, name: 'Ghana', code: 'GH', position: 2, archived: false },
];

describe('#markets getters', () => {
  const state = { records };

  it('sorts by position, then name', () => {
    expect(getters.getMarkets(state).map(m => m.code)).toEqual([
      'KE',
      'GH',
      'UG',
    ]);
  });

  it('leaves out archived markets for pickers', () => {
    const activeMarkets = getters.getActiveMarkets(state, {
      getMarkets: getters.getMarkets(state),
    });
    expect(activeMarkets.map(m => m.code)).toEqual(['GH', 'UG']);
  });

  it('finds a market by id', () => {
    expect(getters.getMarketById(state)('3').name).toBe('Ghana');
    expect(getters.getMarketById(state)(9)).toEqual({});
  });
});
