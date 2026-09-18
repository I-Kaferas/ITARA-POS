<script setup lang="ts">
import { onBeforeUnmount, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import AppIcon from './AppIcon.vue'
import { debounceFn } from '../../composables/useLiveSearch'
import { emptyListFilters, type ListFilters } from '../../utils/listFilters'

const props = withDefaults(defineProps<{
  modelValue: ListFilters
  searchPlaceholder?: string
  statuses?: { value: string; label: string }[]
  suppliers?: { id: string; name: string }[]
  branches?: { id: string; name: string }[]
  warehouses?: { id: string; name: string }[]
  categories?: { id: string; name: string }[]
  methods?: { value: string; label: string }[]
  priorities?: { value: string; label: string }[]
  frequencies?: { value: string; label: string }[]
  showSearch?: boolean
  showPeriod?: boolean
  showStatus?: boolean
  showSupplier?: boolean
  showBranch?: boolean
  showWarehouse?: boolean
  showCategory?: boolean
  showDepartment?: boolean
  showCostCenter?: boolean
  showMethod?: boolean
  showPriority?: boolean
  showFrequency?: boolean
  showActive?: boolean
}>(), {
  searchPlaceholder: '',
  statuses: () => [],
  suppliers: () => [],
  branches: () => [],
  warehouses: () => [],
  categories: () => [],
  methods: () => [],
  priorities: () => [],
  frequencies: () => [],
  showSearch: true,
  showPeriod: true,
  showStatus: false,
  showSupplier: false,
  showBranch: false,
  showWarehouse: false,
  showCategory: false,
  showDepartment: false,
  showCostCenter: false,
  showMethod: false,
  showPriority: false,
  showFrequency: false,
  showActive: false,
})

const emit = defineEmits<{
  'update:modelValue': [ListFilters]
  apply: []
}>()

const { t } = useI18n()
const open = ref(false)
const liveApply = debounceFn(() => emit('apply'), 280)
onBeforeUnmount(() => liveApply.cancel())

function patch(partial: Partial<ListFilters>, reload = true) {
  emit('update:modelValue', { ...props.modelValue, ...partial })
  if (reload) emit('apply')
}

function patchLive(partial: Partial<ListFilters>) {
  emit('update:modelValue', { ...props.modelValue, ...partial })
  liveApply()
}

function reset() {
  emit('update:modelValue', emptyListFilters(props.modelValue.period === 'month' ? 'all' : 'all'))
  emit('apply')
}
</script>

<template>
  <div class="filters-wrap">
    <button type="button" class="toggle" @click="open = !open">
      <AppIcon name="filter" :size="15" />
      {{ open ? t('filters.hide') : t('filters.show') }}
    </button>
    <div v-show="open" class="filters">
    <input
      v-if="showSearch"
      :value="modelValue.search"
      type="search"
      class="field grow"
      :placeholder="searchPlaceholder || t('filters.search')"
      @input="patchLive({ search: ($event.target as HTMLInputElement).value })"
    />
    <select v-if="showPeriod" :value="modelValue.period" class="field" @change="patch({ period: ($event.target as HTMLSelectElement).value })">
      <option value="all">{{ t('filters.allPeriods') }}</option>
      <option value="today">{{ t('purchases.hub.today') }}</option>
      <option value="week">{{ t('purchases.hub.week') }}</option>
      <option value="month">{{ t('purchases.hub.month') }}</option>
      <option value="quarter">{{ t('purchases.hub.quarter') }}</option>
      <option value="year">{{ t('purchases.hub.year') }}</option>
      <option value="custom">{{ t('purchases.hub.custom') }}</option>
    </select>
    <input v-if="showPeriod && modelValue.period === 'custom'" :value="modelValue.from" type="date" class="field" @change="patch({ from: ($event.target as HTMLInputElement).value })" />
    <input v-if="showPeriod && modelValue.period === 'custom'" :value="modelValue.to" type="date" class="field" @change="patch({ to: ($event.target as HTMLInputElement).value })" />
    <select v-if="showStatus" :value="modelValue.status" class="field" @change="patch({ status: ($event.target as HTMLSelectElement).value })">
      <option value="">{{ t('filters.allStatuses') }}</option>
      <option v-for="item in statuses" :key="item.value" :value="item.value">{{ item.label }}</option>
    </select>
    <select v-if="showSupplier" :value="modelValue.supplier_id" class="field" @change="patch({ supplier_id: ($event.target as HTMLSelectElement).value })">
      <option value="">{{ t('purchases.hub.allSuppliers') }}</option>
      <option v-for="item in suppliers" :key="item.id" :value="item.id">{{ item.name }}</option>
    </select>
    <select v-if="showBranch" :value="modelValue.branch_id" class="field" @change="patch({ branch_id: ($event.target as HTMLSelectElement).value })">
      <option value="">{{ t('filters.allBranches') }}</option>
      <option v-for="item in branches" :key="item.id" :value="item.id">{{ item.name }}</option>
    </select>
    <select v-if="showWarehouse" :value="modelValue.warehouse_id" class="field" @change="patch({ warehouse_id: ($event.target as HTMLSelectElement).value })">
      <option value="">{{ t('purchases.hub.allWarehouses') }}</option>
      <option v-for="item in warehouses" :key="item.id" :value="item.id">{{ item.name }}</option>
    </select>
    <select v-if="showCategory" :value="modelValue.category_id" class="field" @change="patch({ category_id: ($event.target as HTMLSelectElement).value })">
      <option value="">{{ t('filters.allCategories') }}</option>
      <option v-for="item in categories" :key="item.id" :value="item.id">{{ item.name }}</option>
    </select>
    <select v-if="showPriority" :value="modelValue.priority" class="field" @change="patch({ priority: ($event.target as HTMLSelectElement).value })">
      <option value="">{{ t('filters.allPriorities') }}</option>
      <option v-for="item in priorities" :key="item.value" :value="item.value">{{ item.label }}</option>
    </select>
    <select v-if="showMethod" :value="modelValue.payment_method" class="field" @change="patch({ payment_method: ($event.target as HTMLSelectElement).value })">
      <option value="">{{ t('filters.allMethods') }}</option>
      <option v-for="item in methods" :key="item.value" :value="item.value">{{ item.label }}</option>
    </select>
    <select v-if="showFrequency" :value="modelValue.frequency" class="field" @change="patch({ frequency: ($event.target as HTMLSelectElement).value })">
      <option value="">{{ t('filters.allFrequencies') }}</option>
      <option v-for="item in frequencies" :key="item.value" :value="item.value">{{ item.label }}</option>
    </select>
    <select v-if="showActive" :value="modelValue.active" class="field" @change="patch({ active: ($event.target as HTMLSelectElement).value })">
      <option value="">{{ t('filters.allStatuses') }}</option>
      <option value="1">{{ t('filters.active') }}</option>
      <option value="0">{{ t('filters.inactive') }}</option>
    </select>
    <input v-if="showDepartment" :value="modelValue.department" class="field" :placeholder="t('expenses.department')" @input="patchLive({ department: ($event.target as HTMLInputElement).value })" />
    <input v-if="showCostCenter" :value="modelValue.cost_center" class="field" :placeholder="t('expenses.costCenter')" @input="patchLive({ cost_center: ($event.target as HTMLInputElement).value })" />
    <button type="button" class="ui-btn ui-btn--primary" @click="emit('apply')">{{ t('filters.apply') }}</button>
    <button type="button" class="ui-btn ui-btn--secondary" @click="reset">{{ t('filters.reset') }}</button>
    </div>
  </div>
</template>

<style scoped>
.filters-wrap {
  display: flex;
  flex-direction: column;
  align-items: stretch;
  gap: var(--space-3);
  width: 100%;
  padding: var(--space-4);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-lg);
  background: var(--color-surface);
  box-shadow: var(--shadow-xs);
}
.toggle {
  display: inline-flex;
  align-items: center;
  align-self: flex-start;
  gap: var(--space-2);
  height: var(--control-sm);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-sm);
  padding: 0 var(--space-3);
  background: var(--color-brand-50);
  color: var(--color-brand-700);
  font-size: var(--text-sm);
  font-weight: 500;
  line-height: var(--line-sm);
  cursor: pointer;
}
.filters { display: flex; flex-wrap: wrap; gap: var(--space-2); align-items: center; width: 100%; }
.field {
  border: 1px solid var(--color-border-strong);
  border-radius: var(--radius-md);
  height: var(--control-lg);
  min-height: var(--control-lg);
  padding: 0 var(--space-3);
  background: white;
  min-width: 9.5rem;
  font-size: var(--text-md);
  line-height: var(--line-sm);
}
.field:focus {
  outline: none;
  border-color: var(--color-brand-400);
  box-shadow: 0 0 0 3px var(--color-focus-ring);
}
.grow { flex: 1; min-width: 14rem; }
</style>
