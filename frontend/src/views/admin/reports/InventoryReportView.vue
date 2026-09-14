<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import ReportsLayout from '../../../components/reports/ReportsLayout.vue'
import FieldLabel from '../../../components/ui/FieldLabel.vue'
import { useBackofficeStore } from '../../../stores/backoffice'
import type { InventoryReport, Warehouse } from '../../../types'
import { formatDate, formatMoney } from '../../../utils/format'

const { t } = useI18n()
const store = useBackofficeStore()

const report = ref<InventoryReport | null>(null)
const warehouses = ref<Warehouse[]>([])
const warehouseId = ref('')
const from = ref('')
const to = ref('')
const loading = ref(false)

async function load() {
  loading.value = true
  try {
    report.value = await store.loadInventoryReport({
      warehouse_id: warehouseId.value || undefined,
      from: from.value || undefined,
      to: to.value || undefined,
    })
  } finally {
    loading.value = false
  }
}

async function exportCsv() {
  await store.exportInventoryReport(warehouseId.value || undefined)
}

onMounted(async () => {
  warehouses.value = await store.loadAllWarehouses()
  await load()
})
</script>

<template>
  <ReportsLayout>
    <div class="mb-4 flex flex-wrap items-end gap-3">
      <div>
        <FieldLabel icon="inventory">{{ t('inventory.warehouse') }}</FieldLabel>
        <select v-model="warehouseId" class="field">
          <option value="">{{ t('org.allStores') }}</option>
          <option v-for="w in warehouses" :key="w.id" :value="w.id">{{ w.name }}</option>
        </select>
      </div>
      <div>
        <FieldLabel icon="calendar">{{ t('reports.from') }}</FieldLabel>
        <input v-model="from" type="date" class="field" />
      </div>
      <div>
        <FieldLabel icon="calendar">{{ t('reports.to') }}</FieldLabel>
        <input v-model="to" type="date" class="field" />
      </div>
      <button class="btn-secondary" :disabled="loading" @click="load">{{ t('common.search') }}</button>
      <button class="btn-primary" @click="exportCsv">{{ t('reports.export') }}</button>
    </div>

    <div v-if="report" class="mb-6 grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
      <div class="stat"><p class="label">SKU</p><p class="value">{{ report.skus_in_stock }}</p></div>
      <div class="stat"><p class="label">{{ t('inventory.onHand') }}</p><p class="value">{{ report.total_units }}</p></div>
      <div class="stat"><p class="label">{{ t('reports.stockValue') }}</p><p class="value">{{ formatMoney(report.estimated_value) }}</p></div>
      <div class="stat"><p class="label">{{ t('reports.lowStock') }}</p><p class="value">{{ report.low_stock_count ?? report.open_alerts }}</p></div>
      <div class="stat"><p class="label">{{ t('reports.losses') }}</p><p class="value">{{ formatMoney(report.losses_value ?? 0) }}</p></div>
    </div>

    <div class="overflow-hidden rounded-xl bg-white shadow-sm ring-1 ring-slate-200">
      <div class="border-b px-4 py-3 text-sm font-semibold">{{ t('reports.topStock') }}</div>
      <table class="min-w-full divide-y text-sm">
        <thead class="bg-slate-50"><tr>
          <th class="px-4 py-2 text-left">SKU</th>
          <th class="px-4 py-2 text-left">{{ t('products.name') }}</th>
          <th class="px-4 py-2 text-left">{{ t('inventory.warehouse') }}</th>
          <th class="px-4 py-2 text-right">{{ t('inventory.onHand') }}</th>
        </tr></thead>
        <tbody class="divide-y">
          <tr v-for="row in report?.top_items ?? []" :key="`${row.product_id}-${row.warehouse}`">
            <td class="px-4 py-2 font-mono">{{ row.sku }}</td>
            <td class="px-4 py-2">{{ row.name }}</td>
            <td class="px-4 py-2">{{ row.warehouse }}</td>
            <td class="px-4 py-2 text-right">{{ row.quantity_on_hand }}</td>
          </tr>
        </tbody>
      </table>
    </div>

    <div class="mt-4 grid gap-4 lg:grid-cols-2">
      <div class="overflow-hidden rounded-xl bg-white shadow-sm ring-1 ring-slate-200">
        <div class="border-b px-4 py-3 text-sm font-semibold">{{ t('reports.lowStock') }}</div>
        <table class="min-w-full divide-y text-sm">
          <tbody class="divide-y">
            <tr v-for="row in report?.low_stock ?? []" :key="`${row.product_id}-${row.warehouse}`">
              <td class="px-4 py-2">{{ row.name }}</td>
              <td class="px-4 py-2 text-right">{{ row.quantity_on_hand }} / {{ row.threshold }}</td>
            </tr>
          </tbody>
        </table>
        <p v-if="!report?.low_stock?.length" class="px-4 py-6 text-center text-slate-500">{{ t('org.empty') }}</p>
      </div>
      <div class="overflow-hidden rounded-xl bg-white shadow-sm ring-1 ring-slate-200">
        <div class="border-b px-4 py-3 text-sm font-semibold">{{ t('reports.movements') }}</div>
        <table class="min-w-full divide-y text-sm">
          <tbody class="divide-y">
            <tr v-for="(row, index) in report?.movements ?? []" :key="`${row.occurred_at}-${index}`">
              <td class="px-4 py-2">{{ row.name }} · {{ row.type }}</td>
              <td class="px-4 py-2 text-right">{{ row.quantity }}</td>
            </tr>
          </tbody>
        </table>
        <p v-if="!report?.movements?.length" class="px-4 py-6 text-center text-slate-500">{{ t('org.empty') }}</p>
      </div>
      <div class="overflow-hidden rounded-xl bg-white shadow-sm ring-1 ring-slate-200">
        <div class="border-b px-4 py-3 text-sm font-semibold">{{ t('reports.losses') }}</div>
        <table class="min-w-full divide-y text-sm">
          <tbody class="divide-y">
            <tr v-for="(row, index) in report?.losses ?? []" :key="`loss-${row.occurred_at}-${index}`">
              <td class="px-4 py-2">{{ row.name }} · {{ row.type }}</td>
              <td class="px-4 py-2 text-right">{{ formatMoney(row.amount) }}</td>
            </tr>
          </tbody>
        </table>
        <p v-if="!report?.losses?.length" class="px-4 py-6 text-center text-slate-500">{{ t('org.empty') }}</p>
      </div>
      <div class="overflow-hidden rounded-xl bg-white shadow-sm ring-1 ring-slate-200">
        <div class="border-b px-4 py-3 text-sm font-semibold">{{ t('reports.expiration') }}</div>
        <table class="min-w-full divide-y text-sm">
          <tbody class="divide-y">
            <tr v-for="(row, index) in report?.expiration ?? []" :key="`${row.batch}-${index}`">
              <td class="px-4 py-2">{{ row.name }} <span v-if="row.batch" class="text-slate-500">{{ row.batch }}</span></td>
              <td class="px-4 py-2 text-right" :class="row.expired ? 'text-red-600' : ''">{{ row.expires_at ? formatDate(row.expires_at) : '—' }}</td>
            </tr>
          </tbody>
        </table>
        <p v-if="!report?.expiration?.length" class="px-4 py-6 text-center text-slate-500">{{ t('org.empty') }}</p>
      </div>
    </div>
  </ReportsLayout>
</template>

<style scoped>
.field { border-radius: 0.5rem; border: 1px solid #cbd5e1; padding: 0.5rem 0.75rem; }
.btn-primary { border-radius: 0.5rem; padding: 0.5rem 1rem; font-weight: 500; color: white; background-color: var(--color-brand-600); }
.btn-secondary { border-radius: 0.5rem; border: 1px solid #cbd5e1; padding: 0.5rem 1rem; }
.stat { border-radius: 0.75rem; background: white; padding: 1rem; box-shadow: 0 1px 2px rgb(0 0 0 / 0.05); }
.label { margin: 0; font-size: 0.75rem; color: #64748b; }
.value { margin: 0.25rem 0 0; font-size: 1.25rem; font-weight: 700; }
</style>
