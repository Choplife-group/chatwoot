import ApiClient from './ApiClient';

class SlaTargetsAPI extends ApiClient {
  constructor() {
    super('sla_targets', { accountScoped: true });
  }
}

export default new SlaTargetsAPI();
