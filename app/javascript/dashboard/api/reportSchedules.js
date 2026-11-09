/* global axios */
import ApiClient from './ApiClient';

class ReportSchedulesAPI extends ApiClient {
  constructor() {
    super('report_schedules', { accountScoped: true, apiVersion: 'v2' });
  }

  forReport(savedReportId) {
    return axios.get(this.url, { params: { saved_report_id: savedReportId } });
  }

  createForReport(savedReportId, schedule) {
    return axios.post(this.url, {
      saved_report_id: savedReportId,
      report_schedule: schedule,
    });
  }

  // Sends the schedule now, to see what the email looks like
  deliver(id) {
    return axios.post(`${this.url}/${id}/deliver`);
  }
}

export default new ReportSchedulesAPI();
