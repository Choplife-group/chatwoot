<script setup>
import { computed, onBeforeMount, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import { MAX_DEPTH } from 'dashboard/store/modules/conversationCategories';

import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import SettingsLayout from '../SettingsLayout.vue';
import CategoryDialog from './CategoryDialog.vue';
import Button from 'dashboard/components-next/button/Button.vue';

// Static classes so Tailwind keeps them
const DEPTH_INDENT = {
  1: 'ps-0',
  2: 'ps-6',
  3: 'ps-12',
  4: 'ps-[4.5rem]',
  5: 'ps-24',
};

const store = useStore();
const { t } = useI18n();

const uiFlags = useMapGetter('conversationCategories/getUIFlags');
const getFlatTree = useMapGetter('conversationCategories/getFlatTree');
const getChildren = useMapGetter('conversationCategories/getChildren');

const dialogRef = ref(null);
const busyId = ref(null);

const rows = computed(() => getFlatTree.value({ includeArchived: true }));

const siblingsOf = category =>
  getChildren.value(category.parent_id, { includeArchived: true });

const canMove = (category, offset) => {
  const siblings = siblingsOf(category);
  const index = siblings.findIndex(item => item.id === category.id);
  return index + offset >= 0 && index + offset < siblings.length;
};

const run = async (category, action) => {
  busyId.value = category.id;
  try {
    await action();
  } catch (error) {
    useAlert(error.message || t('CATEGORIES_SETTINGS.API_ERROR'));
  } finally {
    busyId.value = null;
  }
};

const move = (category, offset) =>
  run(category, () => {
    const ids = siblingsOf(category).map(item => item.id);
    const index = ids.indexOf(category.id);
    [ids[index], ids[index + offset]] = [ids[index + offset], ids[index]];
    return store.dispatch('conversationCategories/reorder', ids);
  });

const toggleArchived = category =>
  run(category, async () => {
    await store.dispatch('conversationCategories/setArchived', {
      id: category.id,
      archived: !category.archived,
    });
    useAlert(
      category.archived
        ? t('CATEGORIES_SETTINGS.RESTORED')
        : t('CATEGORIES_SETTINGS.ARCHIVED_MESSAGE')
    );
  });

onBeforeMount(() => {
  store.dispatch('conversationCategories/get');
});
</script>

<template>
  <SettingsLayout
    :is-loading="uiFlags.isFetching && !rows.length"
    :loading-message="$t('CATEGORIES_SETTINGS.LOADING')"
    :no-records-found="!rows.length"
    :no-records-message="$t('CATEGORIES_SETTINGS.EMPTY')"
  >
    <template #header>
      <BaseSettingsHeader
        :title="$t('CATEGORIES_SETTINGS.HEADER')"
        :description="$t('CATEGORIES_SETTINGS.DESCRIPTION')"
      >
        <template #actions>
          <Button
            :label="$t('CATEGORIES_SETTINGS.ADD.BUTTON')"
            size="sm"
            @click="dialogRef.openCreate()"
          />
        </template>
      </BaseSettingsHeader>
    </template>
    <template #body>
      <ul class="flex flex-col divide-y divide-n-weak">
        <li
          v-for="category in rows"
          :key="category.id"
          class="flex items-center gap-2 py-2"
          :class="DEPTH_INDENT[category.depth]"
        >
          <span
            class="i-lucide-corner-down-right size-4 text-n-slate-9 flex-shrink-0"
            :class="{ invisible: category.depth === 1 }"
          />
          <span
            class="flex-1 min-w-0 truncate text-body-main"
            :class="
              category.archived
                ? 'text-n-slate-10 line-through'
                : 'text-n-slate-12'
            "
          >
            {{ category.name }}
          </span>
          <span
            v-if="category.archived"
            class="text-xs text-n-slate-10 flex-shrink-0"
          >
            {{ $t('CATEGORIES_SETTINGS.ARCHIVED') }}
          </span>
          <div class="flex gap-1 flex-shrink-0">
            <Button
              v-if="!category.archived && category.depth < MAX_DEPTH"
              v-tooltip.top="$t('CATEGORIES_SETTINGS.ADD_CHILD.BUTTON')"
              icon="i-lucide-plus"
              slate
              xs
              ghost
              @click="dialogRef.openCreate(category)"
            />
            <Button
              v-tooltip.top="$t('CATEGORIES_SETTINGS.RENAME.BUTTON')"
              icon="i-woot-edit-pen"
              slate
              xs
              ghost
              @click="dialogRef.openRename(category)"
            />
            <Button
              v-tooltip.top="$t('CATEGORIES_SETTINGS.MOVE_UP')"
              icon="i-lucide-arrow-up"
              slate
              xs
              ghost
              :disabled="!canMove(category, -1)"
              :is-loading="busyId === category.id"
              @click="move(category, -1)"
            />
            <Button
              v-tooltip.top="$t('CATEGORIES_SETTINGS.MOVE_DOWN')"
              icon="i-lucide-arrow-down"
              slate
              xs
              ghost
              :disabled="!canMove(category, 1)"
              @click="move(category, 1)"
            />
            <Button
              v-tooltip.top="
                category.archived
                  ? $t('CATEGORIES_SETTINGS.RESTORE')
                  : $t('CATEGORIES_SETTINGS.ARCHIVE')
              "
              :icon="
                category.archived
                  ? 'i-lucide-archive-restore'
                  : 'i-lucide-archive'
              "
              slate
              xs
              ghost
              @click="toggleArchived(category)"
            />
          </div>
        </li>
      </ul>
    </template>
    <CategoryDialog ref="dialogRef" />
  </SettingsLayout>
</template>
