<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import PurchasingLayout from '../../../components/purchasing/PurchasingLayout.vue'
import AppIcon from '../../../components/ui/AppIcon.vue'
import DataTableShell from '../../../components/ui/DataTableShell.vue'
import KpiCard from '../../../components/ui/KpiCard.vue'
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
const loading = ref(false)

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
  loading.value = true
  try {
    const dates = range()
    data.value = await store.loadPurchaseOverview({
      from: dates.from || undefined,
      to: dates.to || undefined,
      supplier_id: supplierId.value || undefined,
      warehouse_id: warehouseId.value || undefined,
    })
  } finally {
    loading.value = false
  }
}

onMounted(async () => {
  suppliers.value = await store.loadSuppliers()
  warehouses.value = await store.loadAllWarehouses()
  await load()
})

const primaryCards = [
  { key: 'purchases_total', label: 'total', icon: 'purchases', accent: '#4a6d86', iconBg: '#e4edf2' },
  { key: 'amount_due', label: 'due', icon: 'receipt', accent: '#dc2626', iconBg: '#fef2f2' },
  { key: 'payments_total', label: 'payments', icon: 'card', accent: '#059669', iconBg: '#ecfdf5' },
  { key: 'open_orders', label: 'orders', icon: 'package', accent: '#2563eb', iconBg: '#eff6ff' },
  { key: 'unpaid_invoices', label: 'unpaid', icon: 'bell', accent: '#c4841d', iconBg: '#f8efdc' },
  { key: 'pending_purchases', label: 'pending', icon: 'filter', accent: '#5c7f96', iconBg: '#f3f6f8' },
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
    <div class="space-y-5">
      <div class="ui-toolbar !mb-0">
        <button type="button" class="ui-btn ui-btn--secondary" @click="showFilters = !showFilters">
          <AppIcon name="filter" :size="15" />
          {{ showFilters ? t('filters.hide') : t('filters.show') }}
        </button>
        <div v-show="showFilters" class="flex w-full flex-wrap gap-2">
          <select v-model="period" class="ui-select" @change="load">
            <option value="today">{{ t('purchases.hub.today') }}</option>
            <option value="week">{{ t('purchases.hub.week') }}</option>
            <option value="month">{{ t('purchases.hub.month') }}</option>
            <option value="quarter">{{ t('purchases.hub.quarter') }}</option>
            <option value="year">{{ t('purchases.hub.year') }}</option>
            <option value="custom">{{ t('purchases.hub.custom') }}</option>
          </select>
          <input v-if="period === 'custom'" v-model="from" type="date" class="ui-input" />
          <input v-if="period === 'custom'" v-model="to" type="date" class="ui-input" />
          <select v-model="supplierId" class="ui-select" @change="load">
            <option value="">{{ t('purchases.hub.allSuppliers') }}</option>
            <option v-for="supplier in suppliers" :key="supplier.id" :value="supplier.id">{{ supplier.name }}</option>
          </select>
          <select v-model="warehouseId" class="ui-select" @change="load">
            <option value="">{{ t('purchases.hub.allWarehouses') }}</option>
            <option v-for="warehouse in warehouses" :key="warehouse.id" :value="warehouse.id">{{ warehouse.name }}</option>
          </select>
          <button type="button" class="ui-btn ui-btn--primary" :disabled="loading" @click="load">
            {{ t('purchases.hub.refresh') }}
          </button>
        </div>
      </div>

      <div class="hub-strip">
        <KpiCard
          v-for="card in primaryCards"
          :key="card.key"
          :label="t(`purchases.hub.kpi.${card.label}`)"
          :value="display(card.key)"
          :icon="card.icon"
          :accent="card.accent"
          :icon-bg="card.iconBg"
        />
      </div>

      <DataTableShell
        :title="t('purchases.hub.topSuppliers')"
        :loading="loading"
        :empty="!loading && !(data.top_suppliers || []).length"
        :empty-title="t('org.empty')"
        empty-icon="suppliers"
        :loading-label="t('common.loading')"
      >
        <table class="ui-table">
          <thead>
            <tr>
              <th>{{ t('purchases.hub.supplier') }}</th>
              <th class="num">{{ t('purchases.hub.orderCount') }}</th>
              <th class="num">{{ t('purchases.hub.amount') }}</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="row in data.top_suppliers || []" :key="row.supplier_id">
              <td class="font-medium">{{ row.name || '—' }}</td>
              <td class="num">{{ row.orders }}</td>
              <td class="num font-medium">{{ formatMoney(row.amount) }}</td>
            </tr>
          </tbody>
        </table>
      </DataTableShell>
    </div>
  </PurchasingLayout>
</template>
