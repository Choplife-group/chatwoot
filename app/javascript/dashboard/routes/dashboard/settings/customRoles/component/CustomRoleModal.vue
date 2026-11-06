<script setup>
import { ref, reactive, computed, onMounted } from 'vue';
import { useStore } from 'dashboard/composables/store';
import { useI18n } from 'vue-i18n';
import { useVuelidate } from '@vuelidate/core';
import { required, minLength } from '@vuelidate/validators';
import { useAlert } from 'dashboard/composables';
import {
  CUSTOM_ROLE_PERMISSION_GROUPS,
  CUSTOM_ROLE_PERMISSIONS_WITH_HINTS,
} from 'dashboard/constants/permissions.js';
import { useEscalationGuard } from 'dashboard/composables/useEscalationGuard';

import Button from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  mode: {
    type: String,
    default: 'add',
    validator: value => ['add', 'edit'].includes(value),
  },
  selectedRole: {
    type: Object,
    default: () => ({}),
  },
});

const emit = defineEmits(['close']);

const store = useStore();
const { t } = useI18n();

const name = ref('');
const description = ref('');
const selectedPermissions = ref([]);

const nameInput = ref(null);

const addCustomRole = reactive({
  showLoading: false,
  message: '',
});

const rules = computed(() => ({
  name: { required, minLength: minLength(2) },
  description: { required },
  selectedPermissions: { required, minLength: minLength(1) },
}));

const v$ = useVuelidate(rules, { name, description, selectedPermissions });

const resetForm = () => {
  name.value = '';
  description.value = '';
  selectedPermissions.value = [];
  v$.value.$reset();
};

const { holds } = useEscalationGuard();

// Select all only covers what this user can hand out
const selectablePermissions = group =>
  group.permissions.filter(permission => holds([permission]));

const isGroupSelected = group =>
  selectablePermissions(group).every(permission =>
    selectedPermissions.value.includes(permission)
  );

const toggleGroup = group => {
  const selectable = selectablePermissions(group);
  const others = selectedPermissions.value.filter(
    permission => !selectable.includes(permission)
  );
  selectedPermissions.value = isGroupSelected(group)
    ? others
    : [...others, ...selectable];
};

const populateEditForm = () => {
  name.value = props.selectedRole.name || '';
  description.value = props.selectedRole.description || '';
  selectedPermissions.value = props.selectedRole.permissions || [];
};

onMounted(() => {
  if (props.mode === 'edit') {
    populateEditForm();
  }
  // Focus the name input when mounted
  nameInput.value?.focus();
});

const getTranslationKey = base => {
  return props.mode === 'edit'
    ? `CUSTOM_ROLE.EDIT.${base}`
    : `CUSTOM_ROLE.ADD.${base}`;
};

const modalTitle = computed(() => t(getTranslationKey('TITLE')));
const modalDescription = computed(() => t(getTranslationKey('DESC')));
const submitButtonText = computed(() => t(getTranslationKey('SUBMIT')));

const handleCustomRole = async () => {
  v$.value.$touch();
  if (v$.value.$invalid) return;

  addCustomRole.showLoading = true;
  try {
    const roleData = {
      name: name.value,
      description: description.value,
      permissions: selectedPermissions.value,
    };

    if (props.mode === 'edit') {
      await store.dispatch('customRole/updateCustomRole', {
        id: props.selectedRole.id,
        ...roleData,
      });
      useAlert(t('CUSTOM_ROLE.EDIT.API.SUCCESS_MESSAGE'));
    } else {
      await store.dispatch('customRole/createCustomRole', roleData);
      useAlert(t('CUSTOM_ROLE.ADD.API.SUCCESS_MESSAGE'));
    }

    resetForm();
    emit('close');
  } catch (error) {
    const errorMessage =
      error?.message || t(`CUSTOM_ROLE.FORM.API.ERROR_MESSAGE`);
    useAlert(errorMessage);
  } finally {
    addCustomRole.showLoading = false;
  }
};

const isSubmitDisabled = computed(
  () => v$.value.$invalid || addCustomRole.showLoading
);
</script>

<template>
  <div class="flex flex-col h-auto overflow-auto">
    <woot-modal-header
      :header-title="modalTitle"
      :header-content="modalDescription"
    />
    <form class="flex flex-col w-full" @submit.prevent="handleCustomRole">
      <div class="w-full">
        <label :class="{ error: v$.name.$error }">
          {{ $t('CUSTOM_ROLE.FORM.NAME.LABEL') }}
          <input
            ref="nameInput"
            v-model.trim="name"
            type="text"
            :placeholder="$t('CUSTOM_ROLE.FORM.NAME.PLACEHOLDER')"
            @blur="v$.name.$touch"
          />
        </label>
      </div>

      <div class="w-full">
        <label :class="{ error: v$.description.$error }">
          {{ $t('CUSTOM_ROLE.FORM.DESCRIPTION.LABEL') }}

          <textarea
            v-model="description"
            :rows="3"
            :placeholder="$t('CUSTOM_ROLE.FORM.DESCRIPTION.PLACEHOLDER')"
            @blur="v$.description.$touch"
          />
        </label>
      </div>

      <div class="w-full">
        <label :class="{ 'text-n-ruby-9': v$.selectedPermissions.$error }">
          {{ $t('CUSTOM_ROLE.FORM.PERMISSIONS.LABEL') }}
        </label>
        <div class="flex flex-col gap-4 mb-4 mt-2">
          <fieldset
            v-for="group in CUSTOM_ROLE_PERMISSION_GROUPS"
            :key="group.key"
            class="flex flex-col gap-2 p-0 m-0 border-0"
          >
            <legend class="w-full p-0 mb-2">
              <span class="flex items-center justify-between gap-2">
                <span class="text-sm font-medium text-n-slate-11">
                  {{ $t(`CUSTOM_ROLE.PERMISSION_GROUPS.${group.key}`) }}
                </span>
                <Button
                  v-if="selectablePermissions(group).length > 1"
                  link
                  xs
                  :label="
                    isGroupSelected(group)
                      ? $t('CUSTOM_ROLE.FORM.PERMISSIONS.CLEAR_ALL')
                      : $t('CUSTOM_ROLE.FORM.PERMISSIONS.SELECT_ALL')
                  "
                  @click="toggleGroup(group)"
                />
              </span>
            </legend>
            <div
              v-for="permission in group.permissions"
              :key="permission"
              class="flex items-start"
            >
              <input
                :id="permission"
                v-model="selectedPermissions"
                type="checkbox"
                :value="permission"
                :disabled="!holds([permission])"
                name="permissions"
                class="mt-0.5 ltr:mr-2 rtl:ml-2"
              />
              <label :for="permission" class="text-sm font-normal">
                {{ $t(`CUSTOM_ROLE.PERMISSIONS.${permission.toUpperCase()}`) }}
                <span
                  v-if="CUSTOM_ROLE_PERMISSIONS_WITH_HINTS.includes(permission)"
                  class="block text-xs text-n-slate-11"
                >
                  {{
                    $t(
                      `CUSTOM_ROLE.PERMISSION_HINTS.${permission.toUpperCase()}`
                    )
                  }}
                </span>
              </label>
            </div>
          </fieldset>
        </div>
      </div>

      <div class="flex flex-row justify-end w-full gap-2 px-0 py-2">
        <Button
          faded
          slate
          type="reset"
          :label="$t('CUSTOM_ROLE.FORM.CANCEL_BUTTON_TEXT')"
          @click.prevent="emit('close')"
        />
        <Button
          type="submit"
          :label="submitButtonText"
          :disabled="isSubmitDisabled"
          :is-loading="addCustomRole.showLoading"
        />
      </div>
    </form>
  </div>
</template>
