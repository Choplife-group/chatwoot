/* global axios */
import ApiClient from './ApiClient';

class InsightsAPI extends ApiClient {
  constructor() {
    super('insights', { accountScoped: true, apiVersion: 'v2' });
  }

  query(params, { signal } = {}) {
    return axios.get(`${this.url}/query`, { params, signal });
  }

  drilldown(params, { signal } = {}) {
    return axios.get(`${this.url}/drilldown`, { params, signal });
  }

  // fileType: csv, xlsx or pdf
  export(params, fileType, title) {
    return axios.get(`${this.url}/export`, {
      params: { ...params, file_type: fileType, title },
      responseType: 'blob',
    });
  }
}

export default new InsightsAPI();
