<script>
import SnackbarContainer from './components/SnackBar/Container.vue';
import { setColorTheme } from 'dashboard/helper/themeHelper';

export default {
  components: { SnackbarContainer },
  mounted() {
    const mql = window.matchMedia('(prefers-color-scheme: dark)');
    setColorTheme(mql.matches);
    mql.onchange = e => setColorTheme(e.matches);
    this.setLocale(window.chatwootConfig.selectedLocale);
  },
  methods: {
    setLocale(locale) {
      if (locale) {
        this.$root.$i18n.locale = locale;
      }
    },
  },
};
</script>

<template>
  <div class="h-full min-h-screen w-full antialiased">
    <router-view />
    <SnackbarContainer />
  </div>
</template>

<style lang="scss">
@tailwind base;
@tailwind components;
@tailwind utilities;

@import '../dashboard/assets/scss/next-colors';
@import 'shared/assets/fonts/satoshi';

html,
body {
  font-family:
    'GT Standard',
    'Satoshi',
    -apple-system,
    BlinkMacSystemFont,
    'Segoe UI',
    Roboto,
    'Helvetica Neue',
    sans-serif;
  @apply h-full w-full;

  input,
  select {
    outline: none;
  }
}

.text-link {
  @apply text-n-brand font-medium hover:text-n-blue-10;
}

.v-popper--theme-tooltip .v-popper__inner {
  background: black !important;
  font-size: 0.75rem;
  padding: 4px 8px !important;
  border-radius: 6px;
  font-weight: 400;
}

.v-popper--theme-tooltip .v-popper__arrow-container {
  display: none;
}
</style>
