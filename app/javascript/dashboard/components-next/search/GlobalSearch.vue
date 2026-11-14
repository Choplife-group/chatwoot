<script setup>
import { ref, computed } from 'vue';
import { useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import Icon from 'dashboard/components-next/icon/Icon.vue';

const { t } = useI18n();
const router = useRouter();

const query = ref('');
const isFocused = ref(false);
const inputRef = ref(null);

const isExpanded = computed(() => isFocused.value || query.value.length > 0);

const submit = () => {
  const q = query.value.trim();
  if (!q) return;
  router.push({ name: 'search', query: { q } });
  query.value = '';
  inputRef.value?.blur();
};

const clear = () => {
  query.value = '';
  inputRef.value?.focus();
};

const onEscape = () => {
  query.value = '';
  inputRef.value?.blur();
};
</script>

<template>
  <form
    role="search"
    class="flex items-center gap-2 h-8 px-3 rounded-full border transition-[width,background-color,border-color] duration-200 ease-out"
    :class="
      isExpanded
        ? 'w-96 max-w-[calc(100vw-8rem)] bg-n-solid-2 border-n-strong shadow-sm'
        : 'w-32 bg-n-alpha-2 border-transparent hover:bg-n-alpha-3'
    "
    @submit.prevent="submit"
  >
    <Icon icon="i-lucide-search" class="flex-shrink-0 size-4 text-n-slate-11" />
    <input
      ref="inputRef"
      v-model="query"
      type="search"
      :aria-label="t('SEARCH.GLOBAL.LABEL')"
      :placeholder="
        isExpanded ? t('SEARCH.GLOBAL.PLACEHOLDER') : t('SEARCH.GLOBAL.LABEL')
      "
      class="flex-1 min-w-0 p-0 m-0 text-sm bg-transparent border-0 outline-none reset-base text-n-slate-12 placeholder:text-n-slate-10 [&::-webkit-search-cancel-button]:hidden"
      @focus="isFocused = true"
      @blur="isFocused = false"
      @keydown.esc="onEscape"
    />
    <button
      v-if="query"
      type="button"
      :aria-label="t('SEARCH.GLOBAL.CLEAR')"
      class="flex items-center justify-center flex-shrink-0 rounded-full size-5 text-n-slate-10 hover:text-n-slate-12"
      @mousedown.prevent
      @click="clear"
    >
      <Icon icon="i-lucide-x" class="size-4" />
    </button>
  </form>
</template>
