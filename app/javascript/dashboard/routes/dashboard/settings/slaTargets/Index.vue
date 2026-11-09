<script setup>
import { computed, onBeforeMount, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import SlaTargetsAPI from 'dashboard/api/slaTargets';
import { toDuration } from './constants';

import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import SettingsLayout from '../SettingsLayout.vue';
import SlaTargetDialog from './SlaTargetDialog.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import {
  BaseTable,
  BaseTableRow,
  BaseTableCell,
} from 'dashboard/components-next/table';

const store = useStore();
const { t } = useI18n();
const markets = useMapGetter('markets/getMarkets');

const targets = ref([]);
const isFetching = ref(true);
const deleting = ref({});
const dialogRef = ref(null);

const tableHeaders = computed(() => [
  t('SLA_TARGETS.LIST.TABLE_HEADER.MARKET'),
  t('SLA_TARGETS.LIST.TABLE_HEADER.PRIORITY'),
  t('SLA_TARGETS.LIST.TABLE_HEADER.FIRST_RESPONSE'),
  t('SLA_TARGETS.LIST.TABLE_HEADER.RESOLUTION'),
  t('SLA_TARGETS.LIST.TABLE_HEADER.HOURS'),
  t('SLA_TARGETS.LIST.TABLE_HEADER.ACTIONS'),
]);

const marketName = marketId =>
  marketId
    ? markets.value.find(market => market.id === marketId)?.name
    : t('SLA_TARGETS.ALL_MARKETS');

const priorityName = priority =>
  priority
    ? t(`SLA_TARGETS.PRIORITIES.${priority.toUpperCase()}`)
    : t('SLA_TARGETS.ANY_PRIORITY');

const formatDuration = seconds => {
  if (!seconds) return t('SLA_TARGETS.LIST.NO_TARGET');
  const { value, unit } = toDuration(seconds);
  return t(`SLA_TARGETS.LIST.${unit.toUpperCase()}`, { n: value });
};

const fetchTargets = async () => {
  try {
    const { data } = await SlaTargetsAPI.get();
    targets.value = data;
  } catch (error) {
    useAlert(t('SLA_TARGETS.API_ERROR'));
  } finally {
    isFetching.value = false;
  }
};

const deleteTarget = async target => {
  deleting.value[target.id] = true;
  try {
    await SlaTargetsAPI.delete(target.id);
    targets.value = targets.value.filter(item => item.id !== target.id);
    useAlert(t('SLA_TARGETS.DELETE.SUCCESS'));
  } catch (error) {
    useAlert(t('SLA_TARGETS.API_ERROR'));
  } finally {
    deleting.value[target.id] = false;
  }
};

onBeforeMount(() => {
  store.dispatch('markets/get');
  fetchTargets();
});
</script>

<template>
  <SettingsLayout
    :is-loading="isFetching"
    :loading-message="$t('SLA_TARGETS.LOADING')"
    :no-records-found="!targets.length"
    :no-records-message="$t('SLA_TARGETS.LIST.404')"
  >
    <template #header>
      <BaseSettingsHeader
        :title="$t('SLA_TARGETS.HEADER')"
        :description="$t('SLA_TARGETS.DESCRIPTION')"
      >
        <template #actions>
          <Button
            :label="$t('SLA_TARGETS.ADD.BUTTON')"
            size="sm"
            @click="dialogRef.open()"
          />
        </template>
      </BaseSettingsHeader>
    </template>
    <template #body>
      <BaseTable
        :headers="tableHeaders"
        :items="targets"
        :no-data-message="$t('SLA_TARGETS.LIST.404')"
      >
        <template #row="{ items }">
          <BaseTableRow v-for="target in items" :key="target.id" :item="target">
            <template #default>
              <BaseTableCell class="whitespace-nowrap">
                <span class="text-body-main text-n-slate-12">
                  {{ marketName(target.market_id) }}
                </span>
              </BaseTableCell>
              <BaseTableCell class="whitespace-nowrap">
                <span class="text-body-main text-n-slate-12">
                  {{ priorityName(target.priority) }}
                </span>
              </BaseTableCell>
              <BaseTableCell class="whitespace-nowrap">
                <span class="text-body-main text-n-slate-11">
                  {{ formatDuration(target.first_response_seconds) }}
                </span>
              </BaseTableCell>
              <BaseTableCell class="whitespace-nowrap">
                <span class="text-body-main text-n-slate-11">
                  {{ formatDuration(target.resolution_seconds) }}
                </span>
              </BaseTableCell>
              <BaseTableCell class="w-full">
                <span class="text-body-main text-n-slate-11">
                  {{
                    target.business_hours
                      ? $t('SLA_TARGETS.LIST.BUSINESS_HOURS')
                      : $t('SLA_TARGETS.LIST.CALENDAR_HOURS')
                  }}
                </span>
              </BaseTableCell>
              <BaseTableCell align="end">
                <div class="flex gap-3 justify-end flex-shrink-0">
                  <Button
                    v-tooltip.top="$t('SLA_TARGETS.EDIT.BUTTON')"
                    icon="i-woot-edit-pen"
                    slate
                    sm
                    @click="dialogRef.open(target)"
                  />
                  <Button
                    v-tooltip.top="$t('SLA_TARGETS.DELETE.BUTTON')"
                    icon="i-woot-bin"
                    slate
                    sm
                    class="hover:enabled:text-n-ruby-11 hover:enabled:bg-n-ruby-2"
                    :is-loading="deleting[target.id]"
                    @click="deleteTarget(target)"
                  />
                </div>
              </BaseTableCell>
            </template>
          </BaseTableRow>
        </template>
      </BaseTable>
    </template>
    <SlaTargetDialog ref="dialogRef" @saved="fetchTargets" />
  </SettingsLayout>
</template>
