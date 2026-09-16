<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { watchLiveSearch } from '../../../composables/useLiveSearch'
import { useI18n } from 'vue-i18n'
import ReportsLayout from '../../../components/reports/ReportsLayout.vue'
import FieldLabel from '../../../components/ui/FieldLabel.vue'
import { useBackofficeStore } from '../../../stores/backoffice'
import type { FinancialReport } from '../../../types'
import { formatMoney } from '../../../utils/format'

const { t } = useI18n()
const store = useBackofficeStore()

const report = ref<FinancialReport | null>(null)
const from = ref('')
const to = ref('')
const loading = ref(false)

async function load() {
  loading.value = true
  try {
    report.value = await store.loadFinancialReport(from.value || undefined, to.value || undefined)
  } finally {
    loading.value = false
  }
}

onMounted(load)
watchLiveSearch([from, to], load, 0)
</script>

<template>
  <ReportsLayout>
    <div class="mb-4 flex flex-wrap items-end gap-3">
      <div>
        <FieldLabel icon="calendar">{{ t('reports.from') }}</FieldLabel>
        <input v-model="from" type="date" class="field" />
      </div>
      <div>
        <FieldLabel icon="calendar">{{ t('reports.to') }}</FieldLabel>
        <input v-model="to" type="date" class="field" />
      </div>
    </div>

    <div v-if="report" class="mb-6 grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
      <div class="stat"><p class="label">{{ t('reports.revenue') }}</p><p class="value">{{ formatMoney(report.revenue) }}</p></div>
      <div class="stat"><p class="label">{{ t('reports.cogs') }}</p><p class="value">{{ formatMoney(report.cogs) }}</p></div>
      <div class="stat"><p class="label">{{ t('reports.expenses') }}</p><p class="value">{{ formatMoney(report.expenses ?? 0) }}</p></div>
      <div class="stat"><p class="label">{{ t('reports.margin') }}</p><p class="value">{{ formatMoney(report.gross_margin) }}</p></div>
      <div class="stat"><p class="label">{{ t('reports.profit') }}</p><p class="value">{{ formatMoney(report.profit ?? 0) }}</p></div>
      <div class="stat"><p class="label">{{ t('reports.credit') }}</p><p class="value">{{ formatMoney(report.credit ?? 0) }}</p></div>
      <div class="stat"><p class="label">{{ t('reports.debts') }}</p><p class="value">{{ formatMoney(report.debts ?? 0) }}</p></div>
    </div>

    <div class="overflow-hidden rounded-xl bg-white shadow-sm ring-1 ring-slate-200">
      <div class="border-b px-4 py-3 text-sm font-semibold">{{ t('reports.byAccount') }}</div>
      <table class="min-w-full divide-y text-sm">
        <thead class="bg-slate-50"><tr>
          <th class="px-4 py-2 text-left">{{ t('accounting.account') }}</th>
          <th class="px-4 py-2 text-right">{{ t('payables.debit') }}</th>
          <th class="px-4 py-2 text-right">{{ t('payables.creditCol') }}</th>
          <th class="px-4 py-2 text-right">Net</th>
        </tr></thead>
        <tbody class="divide-y">
          <tr v-for="row in report?.by_account ?? []" :key="row.account_code ?? 'none'">
            <td class="px-4 py-2 font-mono">{{ row.account_code ?? '—' }}</td>
            <td class="px-4 py-2 text-right">{{ formatMoney(row.total_debit) }}</td>
            <td class="px-4 py-2 text-right">{{ formatMoney(row.total_credit) }}</td>
            <td class="px-4 py-2 text-right font-medium">{{ formatMoney(row.net) }}</td>
          </tr>
        </tbody>
      </table>
    </div>
  </ReportsLayout>
</template>

<style scoped>
.field { border-radius: 0.5rem; border: 1px solid #cbd5e1; padding: 0.5rem 0.75rem; }
.btn-secondary { border-radius: 0.5rem; border: 1px solid #cbd5e1; padding: 0.5rem 1rem; }
.stat { border-radius: 0.75rem; background: white; padding: 1rem; box-shadow: 0 1px 2px rgb(0 0 0 / 0.05); }
.label { margin: 0; font-size: 0.75rem; color: #64748b; }
.value { margin: 0.25rem 0 0; font-size: 1.25rem; font-weight: 700; }
</style>
