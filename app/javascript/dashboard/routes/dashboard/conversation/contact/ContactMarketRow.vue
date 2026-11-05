<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useMapGetter } from 'dashboard/composables/store';
import Icon from 'dashboard/components-next/icon/Icon.vue';

const props = defineProps({
  marketId: { type: Number, default: null },
});

const emit = defineEmits(['update']);

const { t } = useI18n();
const markets = useMapGetter('markets/getMarkets');

// Archived markets stay selectable only when the contact already has one
const options = computed(() =>
  markets.value.filter(
    market => !market.archived || market.id === props.marketId
  )
);

const onChange = event => {
  const value = event.target.value;
  emit('update', value ? Number(value) : null);
};
</script>

<template>
  <label
    class="flex items-center w-full gap-2 text-sm text-n-slate-11 min-w-0"
    :title="t('CONTACT_PANEL.MARKET')"
  >
    <Icon icon="i-lucide-globe" class="size-4 flex-shrink-0" />
    <select
      :value="marketId || ''"
      class="!mb-0 !h-7 !py-0 !px-1 text-sm bg-transparent border-0 outline-none truncate cursor-pointer text-n-slate-12"
      @change="onChange"
    >
      <option value="">{{ t('CONTACT_PANEL.NO_MARKET') }}</option>
      <option v-for="market in options" :key="market.id" :value="market.id">
        {{ market.name }} ({{ market.code }})
      </option>
    </select>
  </label>
</template>
