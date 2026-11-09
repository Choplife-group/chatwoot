/* global axios */
import ApiClient from './ApiClient';

class ReportSnapshotsAPI extends ApiClient {
  constructor() {
    super('report_snapshots', { accountScoped: true, apiVersion: 'v2' });
  }

  // fileType: csv, xlsx or pdf
  export(id, fileType) {
    return axios.get(`${this.url}/${id}/export`, {
      params: { file_type: fileType },
      responseType: 'blob',
    });
  }
}

export default new ReportSnapshotsAPI();
