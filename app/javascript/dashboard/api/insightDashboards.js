import ApiClient from './ApiClient';

export default new ApiClient('insight_dashboards', {
  accountScoped: true,
  apiVersion: 'v2',
});
