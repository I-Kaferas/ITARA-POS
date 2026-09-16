<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { watchLiveSearch } from '../../../composables/useLiveSearch'
import { useI18n } from 'vue-i18n'
import ReportsLayout from '../../../components/reports/ReportsLayout.vue'
import FieldLabel from '../../../components/ui/FieldLabel.vue'
import { useBackofficeStore } from '../../../stores/backoffice'
import { useContextStore } from '../../../stores/context'
import type { SalesReport } from '../../../types'
import { formatDate, formatMoney } from '../../../utils/format'

const { t } = useI18n()
const store = useBackofficeStore()
const context = useContextStore()

const report = ref<SalesReport | null>(null)
const byStore = ref<{ store_id: string; store_name: string; sales_count: number; revenue: number }[]>([])
const from = ref('')
const to = ref('')
const storeId = ref(context.currentStoreId ?? '')
const loading = ref(false)

async function load() {
  loading.value = true
  try {
    const res = await store.loadSalesReport({
      store_id: storeId.value || undefined,
      from: from.value || undefined,
      to: to.value || undefined,
    })
    report.value = res.data
    byStore.value = res.meta.by_store ?? []
  } finally {
    loading.value = false
  }
}

async function exportCsv() {
  await store.exportSalesReport({
    store_id: storeId.value || undefined,
    from: from.value || undefined,
    to: to.value || undefined,
  })
}

function applyPeriod(period: 'day' | 'week' | 'month' | 'year') {
  const now = new Date()
  const start = new Date(now)
  if (period === 'week') start.setDate(now.getDate() - ((now.getDay() + 6) % 7))
  if (period === 'month') start.setDate(1)
  if (period === 'year') start.setMonth(0, 1)
  const local = (date: Date) => {
    const month = String(date.getMonth() + 1).padStart(2, '0')
    const day = String(date.getDate()).padStart(2, '0')
    return `${date.getFullYear()}-${month}-${day}`
  }
  from.value = local(start)
  to.value = local(now)
}

onMounted(load)
watchLiveSearch([storeId, from, to], load, 0)
</script>

<template>
  <ReportsLayout>
    <div class="mb-4 flex flex-wrap items-end gap-3">
      <div>
        <FieldLabel icon="stores">{{ t('nav.stores') }}</FieldLabel>
        <select v-model="storeId" class="field">
          <option value="">{{ t('org.allStores') }}</option>
          <option v-for="s in context.activeStores" :key="s.id" :value="s.id">{{ s.name }}</option>
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
      <button class="btn-secondary" @click="applyPeriod('day')">{{ t('reports.periods.day') }}</button>
      <button class="btn-secondary" @click="applyPeriod('week')">{{ t('reports.periods.week') }}</button>
      <button class="btn-secondary" @click="applyPeriod('month')">{{ t('reports.periods.month') }}</button>
      <button class="btn-secondary" @click="applyPeriod('year')">{{ t('reports.periods.year') }}</button>
      <button class="btn-primary" @click="exportCsv">{{ t('reports.export') }}</button>
    </div>

    <div v-if="report" class="mb-6 grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
      <div class="stat"><p class="label">{{ t('reports.salesCount') }}</p><p class="value">{{ report.sales_count }}</p></div>
      <div class="stat"><p class="label">{{ t('reports.revenue') }}</p><p class="value">{{ formatMoney(report.revenue) }}</p></div>
      <div class="stat"><p class="label">{{ t('reports.tax') }}</p><p class="value">{{ formatMoney(report.tax_total) }}</p></div>
      <div class="stat"><p class="label">{{ t('reports.returns') }}</p><p class="value">{{ formatMoney(report.returns_total) }}</p></div>
    </div>

    <div class="grid gap-4 lg:grid-cols-2">
      <div class="overflow-hidden rounded-xl bg-white shadow-sm ring-1 ring-slate-200">
        <div class="border-b px-4 py-3 text-sm font-semibold">{{ t('reports.byDay') }}</div>
        <table class="min-w-full divide-y text-sm">
          <thead class="bg-slate-50"><tr>
            <th class="px-4 py-2 text-left">{{ t('inventory.date') }}</th>
            <th class="px-4 py-2 text-right">{{ t('reports.salesCount') }}</th>
            <th class="px-4 py-2 text-right">{{ t('reports.revenue') }}</th>
          </tr></thead>
          <tbody class="divide-y">
            <tr v-for="row in report?.by_day ?? []" :key="row.day">
              <td class="px-4 py-2">{{ formatDate(row.day) }}</td>
              <td class="px-4 py-2 text-right">{{ row.sales_count }}</td>
              <td class="px-4 py-2 text-right">{{ formatMoney(row.revenue) }}</td>
            </tr>
          </tbody>
        </table>
        <p v-if="!report?.by_day?.length" class="px-4 py-6 text-center text-slate-500">{{ t('org.empty') }}</p>
      </div>

      <div class="overflow-hidden rounded-xl bg-white shadow-sm ring-1 ring-slate-200">
        <div class="border-b px-4 py-3 text-sm font-semibold">{{ t('reports.byStore') }}</div>
        <table class="min-w-full divide-y text-sm">
          <thead class="bg-slate-50"><tr>
            <th class="px-4 py-2 text-left">{{ t('nav.stores') }}</th>
            <th class="px-4 py-2 text-right">{{ t('reports.salesCount') }}</th>
            <th class="px-4 py-2 text-right">{{ t('reports.revenue') }}</th>
          </tr></thead>
          <tbody class="divide-y">
            <tr v-for="row in byStore" :key="row.store_id">
              <td class="px-4 py-2">{{ row.store_name }}</td>
              <td class="px-4 py-2 text-right">{{ row.sales_count }}</td>
              <td class="px-4 py-2 text-right">{{ formatMoney(row.revenue) }}</td>
            </tr>
          </tbody>
        </table>
      </div>

      <div class="overflow-hidden rounded-xl bg-white shadow-sm ring-1 ring-slate-200">
        <div class="border-b px-4 py-3 text-sm font-semibold">{{ t('reports.byWeek') }}</div>
        <table class="min-w-full divide-y text-sm">
          <tbody class="divide-y">
            <tr v-for="row in report?.by_week ?? []" :key="`w-${row.label}`">
              <td class="px-4 py-2">{{ row.label }}</td>
              <td class="px-4 py-2 text-right">{{ row.sales_count }}</td>
              <td class="px-4 py-2 text-right">{{ formatMoney(row.revenue) }}</td>
            </tr>
          </tbody>
        </table>
        <p v-if="!report?.by_week?.length" class="px-4 py-6 text-center text-slate-500">{{ t('org.empty') }}</p>
      </div>

      <div class="overflow-hidden rounded-xl bg-white shadow-sm ring-1 ring-slate-200">
        <div class="border-b px-4 py-3 text-sm font-semibold">{{ t('reports.byMonth') }}</div>
        <table class="min-w-full divide-y text-sm">
          <tbody class="divide-y">
            <tr v-for="row in report?.by_month ?? []" :key="`m-${row.label}`">
              <td class="px-4 py-2">{{ row.label }}</td>
              <td class="px-4 py-2 text-right">{{ row.sales_count }}</td>
              <td class="px-4 py-2 text-right">{{ formatMoney(row.revenue) }}</td>
            </tr>
          </tbody>
        </table>
        <p v-if="!report?.by_month?.length" class="px-4 py-6 text-center text-slate-500">{{ t('org.empty') }}</p>
      </div>

      <div class="overflow-hidden rounded-xl bg-white shadow-sm ring-1 ring-slate-200">
        <div class="border-b px-4 py-3 text-sm font-semibold">{{ t('reports.byYear') }}</div>
        <table class="min-w-full divide-y text-sm">
          <tbody class="divide-y">
            <tr v-for="row in report?.by_year ?? []" :key="`y-${row.label}`">
              <td class="px-4 py-2">{{ row.label }}</td>
              <td class="px-4 py-2 text-right">{{ row.sales_count }}</td>
              <td class="px-4 py-2 text-right">{{ formatMoney(row.revenue) }}</td>
            </tr>
          </tbody>
        </table>
        <p v-if="!report?.by_year?.length" class="px-4 py-6 text-center text-slate-500">{{ t('org.empty') }}</p>
      </div>

      <div class="overflow-hidden rounded-xl bg-white shadow-sm ring-1 ring-slate-200">
        <div class="border-b px-4 py-3 text-sm font-semibold">{{ t('reports.byProduct') }}</div>
        <table class="min-w-full divide-y text-sm">
          <tbody class="divide-y">
            <tr v-for="row in report?.by_product ?? []" :key="row.sku || row.label">
              <td class="px-4 py-2">{{ row.label }}</td>
              <td class="px-4 py-2 text-right">{{ row.quantity }}</td>
              <td class="px-4 py-2 text-right">{{ formatMoney(row.revenue) }}</td>
            </tr>
          </tbody>
        </table>
        <p v-if="!report?.by_product?.length" class="px-4 py-6 text-center text-slate-500">{{ t('org.empty') }}</p>
      </div>

      <div class="overflow-hidden rounded-xl bg-white shadow-sm ring-1 ring-slate-200">
        <div class="border-b px-4 py-3 text-sm font-semibold">{{ t('reports.byCategory') }}</div>
        <table class="min-w-full divide-y text-sm">
          <tbody class="divide-y">
            <tr v-for="(row, index) in report?.by_category ?? []" :key="row.label || index">
              <td class="px-4 py-2">{{ row.label || t('reports.uncategorized') }}</td>
              <td class="px-4 py-2 text-right">{{ row.quantity }}</td>
              <td class="px-4 py-2 text-right">{{ formatMoney(row.revenue) }}</td>
            </tr>
          </tbody>
        </table>
        <p v-if="!report?.by_category?.length" class="px-4 py-6 text-center text-slate-500">{{ t('org.empty') }}</p>
      </div>

      <div class="overflow-hidden rounded-xl bg-white shadow-sm ring-1 ring-slate-200">
        <div class="border-b px-4 py-3 text-sm font-semibold">{{ t('reports.byCashier') }}</div>
        <table class="min-w-full divide-y text-sm">
          <tbody class="divide-y">
            <tr v-for="(row, index) in report?.by_cashier ?? []" :key="row.label || index">
              <td class="px-4 py-2">{{ row.label || t('reports.unknownCashier') }}</td>
              <td class="px-4 py-2 text-right">{{ row.sales_count }}</td>
              <td class="px-4 py-2 text-right">{{ formatMoney(row.revenue) }}</td>
            </tr>
          </tbody>
        </table>
        <p v-if="!report?.by_cashier?.length" class="px-4 py-6 text-center text-slate-500">{{ t('org.empty') }}</p>
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
