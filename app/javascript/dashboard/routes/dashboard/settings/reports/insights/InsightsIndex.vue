<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import { useAlert } from 'dashboard/composables';
import { useMapGetter } from 'dashboard/composables/store';
import { useEscalationGuard } from 'dashboard/composables/useEscalationGuard';
import { dynamicTime } from 'shared/helpers/timeHelper';
import ReportSnapshotsAPI from 'dashboard/api/reportSnapshots';
import SavedReportsAPI from 'dashboard/api/savedReports';
import InsightDashboardsAPI from 'dashboard/api/insightDashboards';

import Button from 'dashboard/components-next/button/Button.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import InsightsDashboardDialog from './components/InsightsDashboardDialog.vue';

const { t } = useI18n();
const router = useRouter();
const currentUser = useMapGetter('getCurrentUser');
const { isAdministrator, holds } = useEscalationGuard();

const savedReports = ref([]);
const snapshots = ref([]);
const dashboards = ref([]);
const dashboardDialogRef = ref(null);
const isCreating = ref(false);
const isLoading = ref(true);
const deleting = ref({});

const canManageShared = computed(
  () => isAdministrator.value || holds(['report_manage'])
);
const canDelete = report =>
  report.user_id === currentUser.value.id ||
  (report.shared && canManageShared.value);

const unix = timestamp => Math.floor(new Date(timestamp).getTime() / 1000);

const load = async () => {
  try {
    const [reports, taken, boards] = await Promise.all([
      SavedReportsAPI.get(),
      ReportSnapshotsAPI.get(),
      InsightDashboardsAPI.get(),
    ]);
    savedReports.value = reports.data;
    snapshots.value = taken.data;
    dashboards.value = boards.data;
  } catch (error) {
    useAlert(t('INSIGHTS.API_ERROR'));
  } finally {
    isLoading.value = false;
  }
};

const remove = async (api, list, item) => {
  deleting.value[`${list}-${item.id}`] = true;
  try {
    await api.delete(item.id);
    const records = { reports: savedReports, snapshots, dashboards }[list];
    records.value = records.value.filter(record => record.id !== item.id);
    useAlert(t('INSIGHTS.INDEX.DELETED'));
  } catch (error) {
    useAlert(t('INSIGHTS.API_ERROR'));
  } finally {
    deleting.value[`${list}-${item.id}`] = false;
  }
};

const createDashboard = async settings => {
  isCreating.value = true;
  try {
    const { data } = await InsightDashboardsAPI.create({
      insight_dashboard: settings,
    });
    dashboardDialogRef.value.close();
    router.push({
      name: 'insights_dashboard',
      params: { dashboardId: data.id },
      query: { edit: '1' },
    });
  } catch (error) {
    useAlert(error.response?.data?.error || t('INSIGHTS.API_ERROR'));
  } finally {
    isCreating.value = false;
  }
};

onMounted(load);
</script>

<template>
  <div class="flex flex-col gap-8 pt-6">
    <div class="flex flex-wrap items-start justify-between gap-3">
      <div class="flex flex-col gap-1 max-w-2xl">
        <h1 class="text-heading-1 text-n-slate-12">
          {{ t('INSIGHTS.HEADER') }}
        </h1>
        <p class="mb-0 text-body-main text-n-slate-11">
          {{ t('INSIGHTS.DESCRIPTION') }}
        </p>
      </div>
      <div class="flex items-center gap-2">
        <Button
          :label="t('INSIGHTS.DASHBOARD.NEW')"
          icon="i-lucide-layout-dashboard"
          slate
          faded
          sm
          @click="dashboardDialogRef.open()"
        />
        <router-link :to="{ name: 'insights_new' }">
          <Button
            :label="t('INSIGHTS.INDEX.NEW_REPORT')"
            icon="i-lucide-plus"
            sm
          />
        </router-link>
      </div>
    </div>

    <div v-if="isLoading" class="flex justify-center py-10">
      <Spinner />
    </div>
    <template v-else>
      <section class="flex flex-col gap-3">
        <h2 class="text-heading-3 text-n-slate-12">
          {{ t('INSIGHTS.INDEX.DASHBOARDS') }}
        </h2>
        <p
          v-if="!dashboards.length"
          class="mb-0 text-body-main text-n-slate-11"
        >
          {{ t('INSIGHTS.INDEX.NO_DASHBOARDS') }}
        </p>
        <div
          v-for="board in dashboards"
          :key="board.id"
          class="flex items-center justify-between gap-3 p-3 rounded-xl outline outline-1 outline-n-weak bg-n-solid-1"
        >
          <router-link
            :to="{
              name: 'insights_dashboard',
              params: { dashboardId: board.id },
            }"
            class="flex flex-col min-w-0 gap-0.5 group"
          >
            <span
              class="text-body-main font-medium text-n-slate-12 truncate group-hover:text-n-blue-11"
            >
              {{ board.name }}
              <span
                v-if="board.audience !== 'private'"
                class="px-1.5 py-0.5 ms-2 text-xs rounded-md bg-n-alpha-2 text-n-slate-11"
              >
                {{
                  t(
                    `INSIGHTS.DASHBOARD.AUDIENCES.${board.audience.toUpperCase()}`
                  )
                }}
              </span>
            </span>
            <span class="text-label-small text-n-slate-11">
              {{ t('INSIGHTS.INDEX.BY', { name: board.owner_name }) }}
            </span>
          </router-link>
          <Button
            v-if="board.user_id === currentUser.id || canManageShared"
            v-tooltip.top="t('INSIGHTS.INDEX.DELETE')"
            icon="i-woot-bin"
            slate
            sm
            class="hover:enabled:text-n-ruby-11 hover:enabled:bg-n-ruby-2"
            :is-loading="deleting[`dashboards-${board.id}`]"
            @click="remove(InsightDashboardsAPI, 'dashboards', board)"
          />
        </div>
      </section>

      <section class="flex flex-col gap-3">
        <h2 class="text-heading-3 text-n-slate-12">
          {{ t('INSIGHTS.INDEX.SAVED_REPORTS') }}
        </h2>
        <p
          v-if="!savedReports.length"
          class="mb-0 text-body-main text-n-slate-11"
        >
          {{ t('INSIGHTS.INDEX.NO_SAVED_REPORTS') }}
        </p>
        <div
          v-for="report in savedReports"
          :key="report.id"
          class="flex items-center justify-between gap-3 p-3 rounded-xl outline outline-1 outline-n-weak bg-n-solid-1"
        >
          <router-link
            :to="{ name: 'insights_report', params: { reportId: report.id } }"
            class="flex flex-col min-w-0 gap-0.5 group"
          >
            <span
              class="text-body-main font-medium text-n-slate-12 truncate group-hover:text-n-blue-11"
            >
              {{ report.name }}
              <span
                v-if="report.shared"
                class="px-1.5 py-0.5 ms-2 text-xs rounded-md bg-n-alpha-2 text-n-slate-11"
              >
                {{ t('INSIGHTS.INDEX.SHARED') }}
              </span>
            </span>
            <span class="text-label-small text-n-slate-11">
              {{ t('INSIGHTS.INDEX.BY', { name: report.owner_name }) }} ·
              {{
                t('INSIGHTS.INDEX.UPDATED', {
                  time: dynamicTime(unix(report.updated_at)),
                })
              }}
            </span>
          </router-link>
          <Button
            v-if="canDelete(report)"
            v-tooltip.top="t('INSIGHTS.INDEX.DELETE')"
            icon="i-woot-bin"
            slate
            sm
            class="hover:enabled:text-n-ruby-11 hover:enabled:bg-n-ruby-2"
            :is-loading="deleting[`reports-${report.id}`]"
            @click="remove(SavedReportsAPI, 'reports', report)"
          />
        </div>
      </section>

      <section class="flex flex-col gap-3">
        <h2 class="text-heading-3 text-n-slate-12">
          {{ t('INSIGHTS.INDEX.SNAPSHOTS') }}
        </h2>
        <p v-if="!snapshots.length" class="mb-0 text-body-main text-n-slate-11">
          {{ t('INSIGHTS.INDEX.NO_SNAPSHOTS') }}
        </p>
        <div
          v-for="snapshot in snapshots"
          :key="snapshot.id"
          class="flex items-center justify-between gap-3 p-3 rounded-xl outline outline-1 outline-n-weak bg-n-solid-1"
        >
          <router-link
            :to="{
              name: 'insights_snapshot',
              params: { snapshotId: snapshot.id },
            }"
            class="flex flex-col min-w-0 gap-0.5 group"
          >
            <span
              class="text-body-main font-medium text-n-slate-12 truncate group-hover:text-n-blue-11"
            >
              {{ snapshot.name }}
            </span>
            <span class="text-label-small text-n-slate-11">
              {{
                t('INSIGHTS.INDEX.CAPTURED', {
                  time: dynamicTime(unix(snapshot.captured_at)),
                })
              }}
            </span>
          </router-link>
          <Button
            v-tooltip.top="t('INSIGHTS.INDEX.DELETE')"
            icon="i-woot-bin"
            slate
            sm
            class="hover:enabled:text-n-ruby-11 hover:enabled:bg-n-ruby-2"
            :is-loading="deleting[`snapshots-${snapshot.id}`]"
            @click="remove(ReportSnapshotsAPI, 'snapshots', snapshot)"
          />
        </div>
      </section>
    </template>
    <InsightsDashboardDialog
      ref="dashboardDialogRef"
      :can-share="canManageShared"
      :is-loading="isCreating"
      @save="createDashboard"
    />
  </div>
</template>
