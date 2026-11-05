<script setup>
import { computed, onBeforeMount, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import { picoSearch } from '@chatwoot/pico-search';

import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import SettingsLayout from '../SettingsLayout.vue';
import MarketDialog from './MarketDialog.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import {
  BaseTable,
  BaseTableRow,
  BaseTableCell,
} from 'dashboard/components-next/table';

const store = useStore();
const { t } = useI18n();

const markets = useMapGetter('markets/getMarkets');
const uiFlags = useMapGetter('markets/getUIFlags');
const inboxes = useMapGetter('inboxes/getInboxes');

const marketDialogRef = ref(null);
const searchQuery = ref('');
const loading = ref({});

const filteredMarkets = computed(() => {
  const query = searchQuery.value.trim();
  if (!query) return markets.value;
  return picoSearch(markets.value, query, ['name', 'code']);
});

const inboxNamesFor = market =>
  inboxes.value
    .filter(inbox => inbox.market_id === market.id)
    .map(inbox => inbox.name)
    .join(', ');

const tableHeaders = computed(() => [
  t('MARKETS_SETTINGS.LIST.TABLE_HEADER.NAME'),
  t('MARKETS_SETTINGS.LIST.TABLE_HEADER.CODE'),
  t('MARKETS_SETTINGS.LIST.TABLE_HEADER.INBOXES'),
  t('MARKETS_SETTINGS.LIST.TABLE_HEADER.STATUS'),
  t('MARKETS_SETTINGS.LIST.TABLE_HEADER.ACTIONS'),
]);

const toggleArchived = async market => {
  loading.value[market.id] = true;
  try {
    await store.dispatch('markets/update', {
      id: market.id,
      archived: !market.archived,
    });
    useAlert(
      market.archived
        ? t('MARKETS_SETTINGS.RESTORE.SUCCESS')
        : t('MARKETS_SETTINGS.ARCHIVE.SUCCESS')
    );
  } catch (error) {
    useAlert(error.message || t('MARKETS_SETTINGS.API_ERROR'));
  } finally {
    loading.value[market.id] = false;
  }
};

onBeforeMount(() => {
  store.dispatch('markets/get');
});
</script>

<template>
  <SettingsLayout
    :is-loading="uiFlags.isFetching"
    :loading-message="$t('MARKETS_SETTINGS.LOADING')"
    :no-records-found="!markets.length"
    :no-records-message="$t('MARKETS_SETTINGS.LIST.404')"
  >
    <template #header>
      <BaseSettingsHeader
        v-model:search-query="searchQuery"
        :title="$t('MARKETS_SETTINGS.HEADER')"
        :description="$t('MARKETS_SETTINGS.DESCRIPTION')"
        :search-placeholder="$t('MARKETS_SETTINGS.SEARCH_PLACEHOLDER')"
      >
        <template v-if="markets.length" #count>
          <span class="text-body-main text-n-slate-11">
            {{ $t('MARKETS_SETTINGS.COUNT', { n: markets.length }) }}
          </span>
        </template>
        <template #actions>
          <Button
            :label="$t('MARKETS_SETTINGS.ADD.BUTTON')"
            size="sm"
            @click="marketDialogRef.open()"
          />
        </template>
      </BaseSettingsHeader>
    </template>
    <template #body>
      <BaseTable
        :headers="tableHeaders"
        :items="filteredMarkets"
        :no-data-message="
          searchQuery
            ? $t('MARKETS_SETTINGS.NO_RESULTS')
            : $t('MARKETS_SETTINGS.LIST.404')
        "
      >
        <template #row="{ items }">
          <BaseTableRow v-for="market in items" :key="market.id" :item="market">
            <template #default>
              <BaseTableCell class="whitespace-nowrap">
                <span
                  class="text-body-main"
                  :class="
                    market.archived ? 'text-n-slate-10' : 'text-n-slate-12'
                  "
                >
                  {{ market.name }}
                </span>
              </BaseTableCell>
              <BaseTableCell>
                <span class="text-body-main text-n-slate-12">
                  {{ market.code }}
                </span>
              </BaseTableCell>
              <BaseTableCell class="w-full">
                <span class="text-body-main text-n-slate-11">
                  {{
                    inboxNamesFor(market) ||
                    $t('MARKETS_SETTINGS.LIST.NO_INBOXES')
                  }}
                </span>
              </BaseTableCell>
              <BaseTableCell class="whitespace-nowrap">
                <span class="text-body-main text-n-slate-11">
                  {{
                    market.archived
                      ? $t('MARKETS_SETTINGS.LIST.ARCHIVED')
                      : $t('MARKETS_SETTINGS.LIST.ACTIVE')
                  }}
                </span>
              </BaseTableCell>
              <BaseTableCell align="end">
                <div class="flex gap-3 justify-end flex-shrink-0">
                  <Button
                    v-tooltip.top="$t('MARKETS_SETTINGS.EDIT.BUTTON')"
                    icon="i-woot-edit-pen"
                    slate
                    sm
                    :is-loading="loading[market.id]"
                    @click="marketDialogRef.open(market)"
                  />
                  <Button
                    v-tooltip.top="
                      market.archived
                        ? $t('MARKETS_SETTINGS.RESTORE.BUTTON')
                        : $t('MARKETS_SETTINGS.ARCHIVE.BUTTON')
                    "
                    :icon="
                      market.archived
                        ? 'i-lucide-archive-restore'
                        : 'i-lucide-archive'
                    "
                    slate
                    sm
                    :is-loading="loading[market.id]"
                    @click="toggleArchived(market)"
                  />
                </div>
              </BaseTableCell>
            </template>
          </BaseTableRow>
        </template>
      </BaseTable>
    </template>
    <MarketDialog ref="marketDialogRef" />
  </SettingsLayout>
</template>
