/* global axios */
import ApiClient from './ApiClient';

class ConversationCategoriesAPI extends ApiClient {
  constructor() {
    super('conversation_categories', { accountScoped: true });
  }

  reorder(ids) {
    return axios.patch(`${this.url}/reorder`, { ids });
  }
}

export default new ConversationCategoriesAPI();
