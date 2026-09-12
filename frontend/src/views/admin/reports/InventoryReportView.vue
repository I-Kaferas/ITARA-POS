<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import ReportsLayout from '../../../components/reports/ReportsLayout.vue'
import { useBackofficeStore } from '../../../stores/backoffice'
import type { InventoryReport, Warehouse } from '../../../types'
import { formatMoney } from '../../../utils/format'

const { t } = useI18n()
const store = useBackofficeStore()

const report = ref<InventoryReport | null>(null)
const warehouses = ref<Warehouse[]>([])
const warehouseId = ref('')
const loading = ref(false)

async function load() {
  loading.value = true
  try {
    report.value = await store.loadInventoryReport(warehouseId.value || undefined)
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
        <label class="mb-1 block text-xs font-medium text-slate-500">{{ t('inventory.warehouse') }}</label>
        <select v-model="warehouseId" class="field">
          <option value="">{{ t('org.allStores') }}</option>
          <option v-for="w in warehouses" :key="w.id" :value="w.id">{{ w.name }}</option>
        </select>
      </div>
      <button class="btn-secondary" :disabled="loading" @click="load">{{ t('common.search') }}</button>
      <button class="btn-primary" @click="exportCsv">{{ t('reports.export') }}</button>
    </div>

    <div v-if="report" class="mb-6 grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
      <div class="stat"><p class="label">SKU</p><p class="value">{{ report.skus_in_stock }}</p></div>
      <div class="stat"><p class="label">{{ t('inventory.onHand') }}</p><p class="value">{{ report.total_units }}</p></div>
      <div class="stat"><p class="label">{{ t('reports.stockValue') }}</p><p class="value">{{ formatMoney(report.estimated_value) }}</p></div>
      <div class="stat"><p class="label">{{ t('inventory.tabs.alerts') }}</p><p class="value">{{ report.open_alerts }}</p></div>
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
