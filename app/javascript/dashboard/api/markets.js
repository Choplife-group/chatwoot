import ApiClient from './ApiClient';

class MarketsAPI extends ApiClient {
  constructor() {
    super('markets', { accountScoped: true });
  }
}

export default new MarketsAPI();
