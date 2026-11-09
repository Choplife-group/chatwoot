<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import format from 'date-fns/format';
import fromUnixTime from 'date-fns/fromUnixTime';
import { useAlert } from 'dashboard/composables';
import { dynamicTime } from 'shared/helpers/timeHelper';
import ReportSnapshotsAPI from 'dashboard/api/reportSnapshots';

import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import InsightsResults from './components/InsightsResults.vue';
import InsightsExportMenu from './components/InsightsExportMenu.vue';

const DATE_FORMAT = 'd MMM yyyy';

const route = useRoute();
const router = useRouter();
const { t } = useI18n();

const snapshot = ref(null);

const period = computed(() => {
  const { since, until } = snapshot.value.config;
  return t('INSIGHTS.SNAPSHOT.PERIOD', {
    from: format(fromUnixTime(since), DATE_FORMAT),
    to: format(fromUnixTime(until), DATE_FORMAT),
  });
});

const exportSnapshot = fileType =>
  ReportSnapshotsAPI.export(snapshot.value.id, fileType);

onMounted(async () => {
  try {
    const { data } = await ReportSnapshotsAPI.show(route.params.snapshotId);
    snapshot.value = data;
  } catch (error) {
    useAlert(t('INSIGHTS.API_ERROR'));
    router.push({ name: 'insights_index' });
  }
});
</script>

<template>
  <div class="flex flex-col gap-4 pt-6">
    <div v-if="!snapshot" class="flex justify-center py-16">
      <Spinner />
    </div>
    <template v-else>
      <div class="flex flex-wrap items-start justify-between gap-3">
        <div class="flex flex-col gap-1">
          <router-link
            :to="{ name: 'insights_index' }"
            class="text-label-small text-n-slate-11 hover:text-n-slate-12"
          >
            {{ t('INSIGHTS.BUILDER.BACK') }}
          </router-link>
          <h1 class="text-heading-1 text-n-slate-12">{{ snapshot.name }}</h1>
          <p class="mb-0 text-body-main text-n-slate-11">
            {{
              t('INSIGHTS.SNAPSHOT.NOTICE', {
                time: dynamicTime(
                  Math.floor(new Date(snapshot.captured_at).getTime() / 1000)
                ),
              })
            }}
            {{ period }}
          </p>
        </div>
        <InsightsExportMenu :download="exportSnapshot" />
      </div>
      <InsightsResults
        :result="snapshot.result"
        :metrics="snapshot.config.metrics"
        :group-by="snapshot.config.group_by"
        :drillable="false"
      />
    </template>
  </div>
</template>
