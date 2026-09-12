<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import PurchasingLayout from '../../../components/purchasing/PurchasingLayout.vue'
import AppIcon from '../../../components/ui/AppIcon.vue'
import { useBackofficeStore } from '../../../stores/backoffice'
import type { Supplier, Warehouse } from '../../../types'
import { formatMoney } from '../../../utils/money'

const { t } = useI18n()
const store = useBackofficeStore()
const period = ref('month')
const from = ref('')
const to = ref('')
const supplierId = ref('')
const warehouseId = ref('')
const suppliers = ref<Supplier[]>([])
const warehouses = ref<Warehouse[]>([])
const data = ref<Record<string, any>>({})
const showFilters = ref(false)

function range() {
  const now = new Date()
  const end = now.toISOString().slice(0, 10)
  const start = new Date(now)
  if (period.value === 'today') return { from: end, to: end }
  if (period.value === 'week') { start.setDate(now.getDate() - 6); return { from: start.toISOString().slice(0, 10), to: end } }
  if (period.value === 'quarter') { start.setMonth(Math.floor(now.getMonth() / 3) * 3, 1); return { from: start.toISOString().slice(0, 10), to: end } }
  if (period.value === 'year') return { from: `${now.getFullYear()}-01-01`, to: end }
  if (period.value === 'custom') return { from: from.value, to: to.value }
  return { from: `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-01`, to: end }
}

async function load() {
  const dates = range()
  data.value = await store.loadPurchaseOverview({
    from: dates.from || undefined,
    to: dates.to || undefined,
    supplier_id: supplierId.value || undefined,
    warehouse_id: warehouseId.value || undefined,
  })
}

onMounted(async () => {
  suppliers.value = await store.loadSuppliers()
  warehouses.value = await store.loadAllWarehouses()
  await load()
})

const cards = [
  ['purchases_total', 'total'],
  ['pending_purchases', 'pending'],
  ['pending_requisitions', 'requisitions'],
  ['pending_proformas', 'proformas'],
  ['open_orders', 'orders'],
  ['unpaid_invoices', 'unpaid'],
  ['partial_invoices', 'partial'],
  ['amount_due', 'due'],
  ['payments_total', 'payments'],
  ['returns_total', 'returns'],
  ['month_purchases', 'month'],
] as const

function display(key: string) {
  const value = Number(data.value[key] ?? 0)
  return ['purchases_total', 'amount_due', 'payments_total', 'returns_total', 'month_purchases'].includes(key)
    ? formatMoney(value)
    : value
}
</script>

<template>
  <PurchasingLayout>
    <div class="space-y-4">
      <div class="filters-wrap">
        <button type="button" class="toggle" @click="showFilters = !showFilters">
          <AppIcon name="filter" :size="15" />
          {{ showFilters ? t('filters.hide') : t('filters.show') }}
        </button>
      <div v-show="showFilters" class="filters">
        <select v-model="period" class="field" @change="load">
          <option value="today">{{ t('purchases.hub.today') }}</option>
          <option value="week">{{ t('purchases.hub.week') }}</option>
          <option value="month">{{ t('purchases.hub.month') }}</option>
          <option value="quarter">{{ t('purchases.hub.quarter') }}</option>
          <option value="year">{{ t('purchases.hub.year') }}</option>
          <option value="custom">{{ t('purchases.hub.custom') }}</option>
        </select>
        <input v-if="period === 'custom'" v-model="from" type="date" class="field" />
        <input v-if="period === 'custom'" v-model="to" type="date" class="field" />
        <select v-model="supplierId" class="field" @change="load">
          <option value="">{{ t('purchases.hub.allSuppliers') }}</option>
          <option v-for="supplier in suppliers" :key="supplier.id" :value="supplier.id">{{ supplier.name }}</option>
        </select>
        <select v-model="warehouseId" class="field" @change="load">
          <option value="">{{ t('purchases.hub.allWarehouses') }}</option>
          <option v-for="warehouse in warehouses" :key="warehouse.id" :value="warehouse.id">{{ warehouse.name }}</option>
        </select>
        <button class="btn" @click="load">{{ t('purchases.hub.refresh') }}</button>
      </div>
      </div>

      <div class="kpis">
        <div v-for="[key, label] in cards" :key="key" class="kpi">
          <span>{{ t(`purchases.hub.kpi.${label}`) }}</span>
          <strong>{{ display(key) }}</strong>
        </div>
      </div>

      <div class="panel">
        <h3>{{ t('purchases.hub.topSuppliers') }}</h3>
        <table>
          <thead><tr><th>{{ t('purchases.hub.supplier') }}</th><th>{{ t('purchases.hub.orderCount') }}</th><th>{{ t('purchases.hub.amount') }}</th></tr></thead>
          <tbody>
            <tr v-for="row in data.top_suppliers || []" :key="row.supplier_id">
              <td>{{ row.name || '—' }}</td>
              <td>{{ row.orders }}</td>
              <td>{{ formatMoney(row.amount) }}</td>
            </tr>
          </tbody>
        </table>
        <p v-if="!(data.top_suppliers || []).length" class="empty">{{ t('org.empty') }}</p>
      </div>
    </div>
  </PurchasingLayout>
</template>

<style scoped>
.filters-wrap { display: flex; flex-direction: column; align-items: flex-end; gap: 0.55rem; width: 100%; }
.toggle { display: inline-flex; align-items: center; gap: 0.4rem; border: 1px solid #cbd5e1; border-radius: 0.5rem; padding: 0.4rem 0.8rem; background: white; color: #334155; font-size: 0.82rem; font-weight: 600; }
.filters, .kpis { display: flex; flex-wrap: wrap; gap: 0.75rem; width: 100%; }
.field { border: 1px solid #cbd5e1; border-radius: 0.5rem; padding: 0.45rem 0.7rem; background: white; }
.btn { border-radius: 0.5rem; padding: 0.45rem 0.9rem; color: white; background: #4a6d86; }
.kpi { min-width: 11rem; flex: 1; background: white; border-radius: 0.75rem; padding: 0.85rem 1rem; box-shadow: 0 1px 2px rgb(15 23 42 / 0.05); }
.kpi span { display: block; color: #64748b; font-size: 0.75rem; }
.kpi strong { font-size: 1.15rem; }
.panel { background: white; border-radius: 0.75rem; padding: 1rem; }
.panel h3 { font-weight: 600; margin-bottom: 0.75rem; }
table { width: 100%; font-size: 0.875rem; }
th, td { text-align: left; padding: 0.55rem 0.4rem; border-top: 1px solid #f1f5f9; }
.empty { color: #64748b; padding: 1rem 0; }
</style>
