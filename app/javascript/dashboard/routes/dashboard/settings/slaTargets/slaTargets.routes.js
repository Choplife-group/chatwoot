import { frontendURL } from '../../../../helper/URLHelper';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';

import SettingsWrapper from '../SettingsWrapper.vue';
import Index from './Index.vue';

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/settings/sla-targets'),
      component: SettingsWrapper,
      children: [
        {
          path: '',
          name: 'sla_targets_list',
          meta: {
            featureFlag: FEATURE_FLAGS.INSIGHTS,
            permissions: ['administrator', 'sla_manage'],
          },
          component: Index,
        },
      ],
    },
  ],
};
