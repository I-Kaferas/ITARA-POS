<script setup lang="ts">
import { computed } from 'vue'
import { useI18n } from 'vue-i18n'
import FieldLabel from '../ui/FieldLabel.vue'
import { useContextStore } from '../../stores/context'

const props = defineProps<{
  modelValue: string[]
}>()

const emit = defineEmits<{
  'update:modelValue': [string[]]
}>()

const { t } = useI18n()
const context = useContextStore()
const stores = computed(() => context.activeStores)
const allSelected = computed(() =>
  stores.value.length > 0 && stores.value.every(store => props.modelValue.includes(store.id)),
)

function toggle(id: string) {
  emit('update:modelValue', props.modelValue.includes(id)
    ? props.modelValue.filter(storeId => storeId !== id)
    : [...props.modelValue, id])
}

function toggleAll() {
  emit('update:modelValue', allSelected.value ? [] : stores.value.map(store => store.id))
}
</script>

<template>
  <div class="store-multi">
    <div class="store-multi__head">
      <FieldLabel icon="stores">{{ t('catalog.targetStores') }}</FieldLabel>
      <button type="button" class="store-multi__all" :disabled="!stores.length" @click="toggleAll">
        {{ allSelected ? t('catalog.clearStores') : t('catalog.selectAllStores') }}
      </button>
    </div>
    <p class="store-multi__hint">{{ t('catalog.targetStoresHint') }}</p>
    <div class="store-multi__list">
      <label v-for="store in stores" :key="store.id" class="store-multi__item">
        <input
          type="checkbox"
          :checked="modelValue.includes(store.id)"
          @change="toggle(store.id)"
        />
        <span>{{ context.storeLabel(store) }}</span>
      </label>
      <p v-if="!stores.length" class="store-multi__empty">{{ t('catalog.noStores') }}</p>
    </div>
  </div>
</template>

<style scoped>
.store-multi { display: grid; gap: 0.35rem; }
.store-multi__head { display: flex; align-items: center; justify-content: space-between; gap: 0.75rem; }
.store-multi__all {
  border: 0;
  background: none;
  padding: 0;
  font-size: 0.75rem;
  font-weight: 600;
  color: var(--color-brand-600);
  cursor: pointer;
}
.store-multi__all:disabled { color: #94a3b8; cursor: default; }
.store-multi__hint { margin: 0; font-size: 0.75rem; color: #64748b; }
.store-multi__list {
  display: grid;
  gap: 0.35rem;
  max-height: 11rem;
  overflow: auto;
  border: 1px solid #cbd5e1;
  border-radius: 0.5rem;
  padding: 0.5rem 0.75rem;
  background: #fff;
}
.store-multi__item { display: flex; align-items: center; gap: 0.5rem; font-size: 0.875rem; cursor: pointer; }
.store-multi__empty { margin: 0; font-size: 0.8125rem; color: #94a3b8; }
</style>
