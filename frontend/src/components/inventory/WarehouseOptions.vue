<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import { useBackofficeStore } from '../../stores/backoffice'

const props = defineProps<{
  modelValue: string
  warehouses?: { id: string; name: string; code?: string | null }[] | null
}>()

const emit = defineEmits<{
  'update:modelValue': [value: string]
}>()

const { t } = useI18n()
const store = useBackofficeStore()
const loaded = ref<{ id: string; name: string; code?: string | null }[]>([])
const loading = ref(false)

const options = computed(() => {
  const fromParent = Array.isArray(props.warehouses) ? props.warehouses : []
  const source = fromParent.length ? fromParent : loaded.value
  return source.filter((item) => item?.id && item?.name)
})

onMounted(() => {
  if (options.value.length) return
  void load()
})

watch(() => props.warehouses, (list) => {
  if (!Array.isArray(list) || !list.length) void load()
}, { immediate: true })

watch(options, (list) => {
  if (!props.modelValue && list[0]) emit('update:modelValue', list[0].id)
}, { immediate: true })

async function load() {
  if (loading.value || options.value.length) return
  loading.value = true
  try {
    loaded.value = await store.loadAllWarehouses()
  } catch {
    loaded.value = []
  } finally {
    loading.value = false
  }
}

function choose(id: string) {
  emit('update:modelValue', id)
}
</script>

<template>
  <div class="warehouse-field">
    <select
      class="field"
      :value="modelValue"
      required
      @change="choose(($event.target as HTMLSelectElement).value)"
    >
      <option v-if="loading && !options.length" value="" disabled>{{ t('common.loading') }}</option>
      <option v-else-if="!options.length" value="" disabled>{{ t('org.noWarehouses') }}</option>
      <option v-for="warehouse in options" :key="warehouse.id" :value="warehouse.id">
        {{ warehouse.name }}<template v-if="warehouse.code"> ({{ warehouse.code }})</template>
      </option>
    </select>
    <div v-if="options.length" class="warehouse-field__list" role="listbox" :aria-label="t('inventory.warehouse')">
      <button
        v-for="warehouse in options"
        :key="warehouse.id"
        type="button"
        class="warehouse-field__option"
        :class="{ 'warehouse-field__option--active': modelValue === warehouse.id }"
        role="option"
        :aria-selected="modelValue === warehouse.id"
        @click="choose(warehouse.id)"
      >
        {{ warehouse.name }}<template v-if="warehouse.code"> · {{ warehouse.code }}</template>
      </button>
    </div>
  </div>
</template>

<style scoped>
.warehouse-field__list {
  margin-top: 0.4rem;
  max-height: 8.5rem;
  overflow: auto;
  border: 1px solid #cbd5e1;
  border-radius: 0.6rem;
  background: #fff;
}

.warehouse-field__option {
  display: block;
  width: 100%;
  padding: 0.5rem 0.75rem;
  border: 0;
  border-bottom: 1px solid #f1f5f9;
  background: #fff;
  text-align: left;
  font-size: 0.875rem;
  font-weight: 600;
  color: #0f172a;
  cursor: pointer;
}

.warehouse-field__option:last-child {
  border-bottom: 0;
}

.warehouse-field__option--active,
.warehouse-field__option:hover {
  background: #e8f0f5;
  color: #1e3a4c;
}
</style>
