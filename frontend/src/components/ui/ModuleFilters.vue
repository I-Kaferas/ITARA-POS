<script setup lang="ts">
import { ref } from 'vue'
import { useI18n } from 'vue-i18n'
import AppIcon from './AppIcon.vue'
import { emptyListFilters, type ListFilters } from '../../utils/listFilters'

const props = withDefaults(defineProps<{
  modelValue: ListFilters
  searchPlaceholder?: string
  statuses?: { value: string; label: string }[]
  suppliers?: { id: string; name: string }[]
  warehouses?: { id: string; name: string }[]
  categories?: { id: string; name: string }[]
  methods?: { value: string; label: string }[]
  priorities?: { value: string; label: string }[]
  frequencies?: { value: string; label: string }[]
  showSearch?: boolean
  showPeriod?: boolean
  showStatus?: boolean
  showSupplier?: boolean
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
  warehouses: () => [],
  categories: () => [],
  methods: () => [],
  priorities: () => [],
  frequencies: () => [],
  showSearch: true,
  showPeriod: true,
  showStatus: false,
  showSupplier: false,
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
const open = ref(true)

function patch(partial: Partial<ListFilters>, reload = true) {
  emit('update:modelValue', { ...props.modelValue, ...partial })
  if (reload) emit('apply')
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
      class="field grow"
      :placeholder="searchPlaceholder || t('filters.search')"
      @input="patch({ search: ($event.target as HTMLInputElement).value }, false)"
      @keyup.enter="emit('apply')"
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
    <input v-if="showDepartment" :value="modelValue.department" class="field" :placeholder="t('expenses.department')" @change="patch({ department: ($event.target as HTMLInputElement).value })" />
    <input v-if="showCostCenter" :value="modelValue.cost_center" class="field" :placeholder="t('expenses.costCenter')" @change="patch({ cost_center: ($event.target as HTMLInputElement).value })" />
    <button type="button" class="btn" @click="emit('apply')">{{ t('filters.apply') }}</button>
    <button type="button" class="btn ghost" @click="reset">{{ t('filters.reset') }}</button>
    </div>
  </div>
</template>

<style scoped>
.filters-wrap {
  display: flex;
  flex-direction: column;
  align-items: stretch;
  gap: 0.65rem;
  width: 100%;
  padding: 0.75rem;
  border: 1px solid #e4e8ec;
  border-radius: 1rem;
  background: rgba(255, 255, 255, 0.86);
  box-shadow: 0 1px 2px rgba(18, 24, 30, 0.04);
}
.toggle {
  display: inline-flex;
  align-items: center;
  align-self: flex-start;
  gap: 0.4rem;
  border: 1px solid #e4e8ec;
  border-radius: 999px;
  padding: 0.38rem 0.8rem;
  background: #f7f4ef;
  color: #3d5c73;
  font-size: 0.78rem;
  font-weight: 700;
  letter-spacing: 0.02em;
}
.filters { display: flex; flex-wrap: wrap; gap: 0.6rem; align-items: center; width: 100%; }
.field { border: 1px solid #d7dbe6; border-radius: 0.75rem; padding: 0.5rem 0.75rem; background: white; min-width: 9.5rem; }
.grow { flex: 1; min-width: 14rem; }
.btn { border-radius: 0.75rem; padding: 0.5rem 0.9rem; color: white; background: #4a6d86; font-weight: 650; }
.btn.ghost { background: white; color: #334155; border: 1px solid #d7dbe6; }
</style>
