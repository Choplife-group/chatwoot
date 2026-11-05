<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useMapGetter, useStore } from 'dashboard/composables/store';

import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Input from 'dashboard/components-next/input/Input.vue';

const store = useStore();
const { t } = useI18n();
const uiFlags = useMapGetter('conversationCategories/getUIFlags');
const getPath = useMapGetter('conversationCategories/getPath');

const dialogRef = ref(null);
const name = ref('');
// Either the category being renamed, or the parent of a new category (null for top level)
const editing = ref(null);
const parent = ref(null);

const title = computed(() => {
  if (editing.value) return t('CATEGORIES_SETTINGS.RENAME.TITLE');
  if (parent.value) {
    return t('CATEGORIES_SETTINGS.ADD_CHILD.TITLE', {
      parent: getPath.value(parent.value.id),
    });
  }
  return t('CATEGORIES_SETTINGS.ADD.TITLE');
});

const openCreate = (parentCategory = null) => {
  editing.value = null;
  parent.value = parentCategory;
  name.value = '';
  dialogRef.value.open();
};

const openRename = category => {
  editing.value = category;
  parent.value = null;
  name.value = category.name;
  dialogRef.value.open();
};

const onConfirm = async () => {
  try {
    if (editing.value) {
      await store.dispatch('conversationCategories/update', {
        id: editing.value.id,
        name: name.value.trim(),
      });
    } else {
      await store.dispatch('conversationCategories/create', {
        name: name.value.trim(),
        parent_id: parent.value?.id ?? null,
        position: store.getters['conversationCategories/getChildren'](
          parent.value?.id ?? null,
          { includeArchived: true }
        ).length,
      });
    }
    useAlert(t('CATEGORIES_SETTINGS.SAVED'));
    dialogRef.value.close();
  } catch (error) {
    useAlert(error.message || t('CATEGORIES_SETTINGS.API_ERROR'));
  }
};

defineExpose({ openCreate, openRename });
</script>

<template>
  <Dialog
    ref="dialogRef"
    :title="title"
    :confirm-button-label="t('CATEGORIES_SETTINGS.SAVE')"
    :disable-confirm-button="!name.trim()"
    :is-loading="uiFlags.isSaving"
    @confirm="onConfirm"
  >
    <Input
      v-model="name"
      :label="t('CATEGORIES_SETTINGS.FORM.NAME.LABEL')"
      :placeholder="t('CATEGORIES_SETTINGS.FORM.NAME.PLACEHOLDER')"
      autofocus
    />
  </Dialog>
</template>
