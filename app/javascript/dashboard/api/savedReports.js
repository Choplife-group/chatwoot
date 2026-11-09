import ApiClient from './ApiClient';

export default new ApiClient('saved_reports', {
  accountScoped: true,
  apiVersion: 'v2',
});
