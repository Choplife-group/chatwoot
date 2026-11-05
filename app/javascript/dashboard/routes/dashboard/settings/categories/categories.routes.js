import { frontendURL } from '../../../../helper/URLHelper';

import SettingsWrapper from '../SettingsWrapper.vue';
import Index from './Index.vue';

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/settings/categories'),
      component: SettingsWrapper,
      children: [
        {
          path: '',
          name: 'conversation_categories_list',
          meta: {
            permissions: ['administrator'],
          },
          component: Index,
        },
      ],
    },
  ],
};
