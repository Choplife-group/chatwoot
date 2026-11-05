import { conversationListPageURL, conversationUrl } from '../URLHelper';

describe('market URLs', () => {
  it('builds the market list URL', () => {
    expect(conversationListPageURL({ accountId: 1, marketId: 4 })).toBe(
      '/app/accounts/1/market/4'
    );
  });

  it('builds a conversation URL inside a market', () => {
    expect(conversationUrl({ accountId: 1, marketId: 4, id: 7 })).toBe(
      'accounts/1/market/4/conversations/7'
    );
  });
});
