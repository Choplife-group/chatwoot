<script setup>
import { computed, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useTimeoutFn } from '@vueuse/core';
import { useAlert } from 'dashboard/composables';
import { useEmitter } from 'dashboard/composables/emitter';
import { useMapGetter, useStore } from 'dashboard/composables/store';
import { FOCUS_CATEGORY_PICKER } from 'dashboard/constants/categories';
import MultiselectDropdown from 'shared/components/ui/MultiselectDropdown.vue';

// One dropdown per level (category → subcategory → …); the conversation is saved once a last-level category is picked
const HIGHLIGHT_DURATION = 2500;

const store = useStore();
const { t } = useI18n();

const currentChat = useMapGetter('getSelectedChat');
const getChildren = useMapGetter('conversationCategories/getChildren');
const getCategoryById = useMapGetter('conversationCategories/getCategoryById');

const pickerRef = ref(null);
const isHighlighted = ref(false);
const { start: clearHighlight } = useTimeoutFn(
  () => {
    isHighlighted.value = false;
  },
  HIGHLIGHT_DURATION,
  { immediate: false }
);

const savedCategory = computed(() => currentChat.value?.meta?.category);
const savedPath = () =>
  savedCategory.value
    ? [...savedCategory.value.ancestor_ids, savedCategory.value.id]
    : [];

// Ids picked so far, top level first
const path = ref(savedPath());
watch(
  () => [currentChat.value?.id, savedCategory.value?.id],
  () => {
    path.value = savedPath();
  }
);

const toOption = category => ({ id: category.id, name: category.name });

const levels = computed(() => {
  const result = [];
  let parentId = null;
  for (let depth = 0; ; depth += 1) {
    const options = getChildren.value(parentId);
    if (!options.length) break;
    const selectedId = path.value[depth];
    result.push({
      depth,
      options: options.map(toOption),
      selected: selectedId
        ? toOption(getCategoryById.value(selectedId) || {})
        : null,
    });
    if (!selectedId) break;
    parentId = selectedId;
  }
  return result;
});

const isComplete = computed(() => !!savedCategory.value);

const save = async categoryId => {
  try {
    await store.dispatch('assignCategory', {
      conversationId: currentChat.value.id,
      categoryId,
    });
    useAlert(t('CONVERSATION_SIDEBAR.CATEGORY.UPDATED'));
  } catch (error) {
    path.value = savedPath();
    useAlert(
      error?.response?.data?.message || t('CONVERSATION_SIDEBAR.CATEGORY.ERROR')
    );
  }
};

const onSelect = (depth, option) => {
  const isSame = path.value[depth] === option.id;
  path.value = isSame
    ? path.value.slice(0, depth)
    : [...path.value.slice(0, depth), option.id];

  const lastId = path.value[path.value.length - 1];
  if (lastId && !getChildren.value(lastId).length) {
    save(lastId);
  } else if (!path.value.length && savedCategory.value) {
    save(null);
  }
};

useEmitter(FOCUS_CATEGORY_PICKER, () => {
  pickerRef.value?.scrollIntoView({ behavior: 'smooth', block: 'center' });
  isHighlighted.value = true;
  clearHighlight();
});
</script>

<template>
  <div
    ref="pickerRef"
    class="flex flex-col gap-1 rounded-lg transition-shadow"
    :class="{ 'ring-2 ring-n-amber-9 ring-offset-2': isHighlighted }"
  >
    <p v-if="!levels.length" class="mb-0 text-sm text-n-slate-11">
      {{ $t('CONVERSATION_SIDEBAR.CATEGORY.NONE_CONFIGURED') }}
    </p>
    <MultiselectDropdown
      v-for="level in levels"
      :key="level.depth"
      :options="level.options"
      :selected-item="level.selected"
      :multiselector-title="
        level.depth === 0
          ? $t('CONVERSATION_SIDEBAR.CATEGORY.SELECT_CATEGORY')
          : $t('CONVERSATION_SIDEBAR.CATEGORY.SELECT_SUBCATEGORY')
      "
      :multiselector-placeholder="
        level.depth === 0
          ? $t('CONVERSATION_SIDEBAR.CATEGORY.CATEGORY_PLACEHOLDER')
          : $t('CONVERSATION_SIDEBAR.CATEGORY.SUBCATEGORY_PLACEHOLDER')
      "
      :no-search-result="$t('CONVERSATION_SIDEBAR.CATEGORY.NO_RESULTS')"
      :input-placeholder="$t('CONVERSATION_SIDEBAR.CATEGORY.SEARCH')"
      @select="option => onSelect(level.depth, option)"
    />
    <p v-if="levels.length && !isComplete" class="mb-0 text-xs text-n-amber-11">
      {{ $t('CONVERSATION_SIDEBAR.CATEGORY.REQUIRED_HINT') }}
    </p>
  </div>
</template>
