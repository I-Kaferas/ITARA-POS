<script setup lang="ts">
import CountUp from '../../../components/motion/CountUp.vue'
import { computed, onMounted, ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import PageFrame from '../../../components/layout/PageFrame.vue'
import AppIcon from '../../../components/ui/AppIcon.vue'
import { intlLocale } from '../../../i18n/locales'
import { useBackofficeStore } from '../../../stores/backoffice'
import { formatMoney } from '../../../utils/format'
import { periodRange } from '../../../utils/listFilters'

type Bucket = { key: string; total: number; count: number }
type Report = {
  total: number
  count: number
  average: number
  active_categories: number
  monthly: Bucket[]
  yearly: Bucket[]
  by_category: Bucket[]
  by_fund: Bucket[]
}

const { t } = useI18n()
const store = useBackofficeStore()
const period = ref('year')
const tab = ref<'monthly' | 'annual' | 'category' | 'fund'>('monthly')
const report = ref<Report | null>(null)
const loading = ref(false)

const tabs = [
  { id: 'monthly' as const, icon: 'calendar', label: 'expenses.analysis.monthly' },
  { id: 'annual' as const, icon: 'layers', label: 'expenses.analysis.annual' },
  { id: 'category' as const, icon: 'tag', label: 'expenses.analysis.byCategory' },
  { id: 'fund' as const, icon: 'coins', label: 'expenses.analysis.byFund' },
]

const trendTitle = computed(() => ({
  monthly: t('expenses.analysis.trendMonthly'),
  annual: t('expenses.analysis.trendAnnual'),
  category: t('expenses.analysis.trendCategory'),
  fund: t('expenses.analysis.trendFund'),
}[tab.value]))

const detailTitle = computed(() => ({
  monthly: t('expenses.analysis.detailMonthly'),
  annual: t('expenses.analysis.detailAnnual'),
  category: t('expenses.analysis.detailCategory'),
  fund: t('expenses.analysis.detailFund'),
}[tab.value]))

const rows = computed(() => {
  const data = report.value
  if (!data || data.count === 0) return []
  if (tab.value === 'monthly') return fillMonths(data.monthly)
  if (tab.value === 'annual') return data.yearly
  if (tab.value === 'category') return data.by_category
  return data.by_fund
})

const maxTotal = computed(() => Math.max(1, ...rows.value.map(row => row.total)))

function fillMonths(buckets: Bucket[]): Bucket[] {
  const range = periodRange(period.value)
  const keys = buckets.map(row => row.key).filter(key => /^\d{4}-\d{2}$/.test(key)).sort()
  if (!keys.length) return buckets
  const start = range.from?.slice(0, 7) ?? keys[0]
  const end = range.to?.slice(0, 7) ?? keys[keys.length - 1]
  const byKey = new Map(buckets.map(row => [row.key, row]))
  const cursor = new Date(`${start}-01T00:00:00`)
  const last = new Date(`${end}-01T00:00:00`)
  const filled: Bucket[] = []
  while (cursor <= last) {
    const key = `${cursor.getFullYear()}-${String(cursor.getMonth() + 1).padStart(2, '0')}`
    filled.push(byKey.get(key) ?? { key, total: 0, count: 0 })
    cursor.setMonth(cursor.getMonth() + 1)
  }
  return filled.length ? filled : buckets
}

function labelFor(row: Bucket): string {
  if (tab.value === 'monthly' && /^\d{4}-\d{2}$/.test(row.key)) {
    const [year, month] = row.key.split('-').map(Number)
    return new Intl.DateTimeFormat(intlLocale(), { month: 'long', year: 'numeric' }).format(new Date(year, month - 1, 1))
  }
  if (row.key === 'none') return t('expenses.analysis.noFund')
  if (row.key === 'other') return t('expenses.analysis.other')
  return row.key
}

async function load() {
  loading.value = true
  try {
    const range = periodRange(period.value)
    report.value = await store.loadExpenseReport(tab.value, range) as Report
  } finally {
    loading.value = false
  }
}

function exportPdf() {
  window.print()
}

watch(period, load)
onMounted(load)
</script>

<template>
  <PageFrame>
    <template #title>{{ t('expenses.analysis.title') }}</template>
    <template #subtitle>{{ t('expenses.analysis.subtitle') }}</template>

    <section class="exp-report">
      <div class="exp-report__head">
        <label class="exp-report__period">
          <span>{{ t('expenses.analysis.period') }}</span>
          <select v-model="period" class="field">
            <option value="year">{{ t('expenses.analysis.thisYear') }}</option>
            <option value="quarter">{{ t('expenses.analysis.thisQuarter') }}</option>
            <option value="month">{{ t('expenses.analysis.thisMonth') }}</option>
            <option value="all">{{ t('expenses.analysis.all') }}</option>
          </select>
        </label>
        <button type="button" class="btn-secondary" @click="exportPdf">
          <AppIcon name="device-printer" :size="16" />
          {{ t('expenses.analysis.exportPdf') }}
        </button>
      </div>

      <div class="exp-report__kpis">
        <article class="exp-kpi">
          <p class="exp-kpi__kicker">{{ t('expenses.analysis.operations', { count: report?.count ?? 0 }) }}</p>
          <p class="exp-kpi__value"><CountUp :value="Number(report?.total ?? 0)" format="money" /></p>
          <p class="exp-kpi__label">{{ t('expenses.analysis.total') }}</p>
        </article>
        <article class="exp-kpi">
          <p class="exp-kpi__kicker">{{ t('expenses.analysis.perOperation') }}</p>
          <p class="exp-kpi__value"><CountUp :value="Number(report?.average ?? 0)" format="money" /></p>
          <p class="exp-kpi__label">{{ t('expenses.analysis.average') }}</p>
        </article>
        <article class="exp-kpi">
          <p class="exp-kpi__kicker">{{ t('expenses.analysis.withExpenses') }}</p>
          <p class="exp-kpi__value"><CountUp :value="Number(report?.active_categories ?? 0)" /></p>
          <p class="exp-kpi__label">{{ t('expenses.analysis.activeCategories') }}</p>
        </article>
      </div>

      <div class="exp-report__tabs" role="tablist">
        <button
          v-for="item in tabs"
          :key="item.id"
          type="button"
          role="tab"
          class="exp-report__tab"
          :class="{ 'is-active': tab === item.id }"
          :aria-selected="tab === item.id"
          @click="tab = item.id"
        >
          <AppIcon :name="item.icon" :size="15" />
          {{ t(item.label) }}
        </button>
      </div>

      <article class="exp-panel">
        <h2>{{ trendTitle }}</h2>
        <p v-if="loading" class="exp-empty">{{ t('common.loading') }}</p>
        <p v-else-if="!rows.length" class="exp-empty">{{ t('expenses.analysis.emptyTrend') }}</p>
        <ul v-else class="exp-bars">
          <li v-for="row in rows" :key="row.key">
            <span>{{ labelFor(row) }}</span>
            <span class="exp-bars__track">
              <span class="exp-bars__fill" :style="{ width: `${Math.round((row.total / maxTotal) * 100)}%` }" />
            </span>
            <strong>{{ formatMoney(row.total) }}</strong>
          </li>
        </ul>
      </article>

      <article class="exp-panel">
        <h2>{{ detailTitle }}</h2>
        <p v-if="!loading && !rows.length" class="exp-empty">{{ t('expenses.analysis.emptyDetail') }}</p>
        <table v-else-if="rows.length" class="exp-table">
          <thead>
            <tr>
              <th>{{ detailTitle }}</th>
              <th>{{ t('expenses.analysis.operationsCol') }}</th>
              <th>{{ t('expenses.analysis.amountCol') }}</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="row in rows" :key="row.key">
              <td>{{ labelFor(row) }}</td>
              <td>{{ row.count }}</td>
              <td>{{ formatMoney(row.total) }}</td>
            </tr>
          </tbody>
        </table>
      </article>
    </section>
  </PageFrame>
</template>

<style scoped>
.exp-report { display: flex; flex-direction: column; gap: 1rem; }
.exp-report__head { display: flex; align-items: flex-end; justify-content: space-between; gap: 1rem; }
.exp-report__period { display: flex; flex-direction: column; gap: 0.35rem; min-width: 14rem; font-size: 0.8rem; color: var(--color-ink-muted, #64748b); }
.exp-report__kpis { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 0.75rem; }
.exp-kpi { padding: 1rem 1.1rem; border-radius: var(--radius-lg, 0.9rem); background: var(--color-surface, #fff); border: 1px solid var(--color-border, #e2e8f0); }
.exp-kpi__kicker, .exp-kpi__label { margin: 0; font-size: 0.78rem; color: var(--color-ink-muted, #64748b); }
.exp-kpi__value { margin: 0.35rem 0 0.15rem; font-size: 1.45rem; font-weight: 650; letter-spacing: -0.02em; }
.exp-report__tabs { display: flex; flex-wrap: wrap; gap: 0.4rem; }
.exp-report__tab { display: inline-flex; align-items: center; gap: 0.4rem; }
.exp-panel { padding: 1rem 1.1rem; border-radius: var(--radius-lg, 0.9rem); background: var(--color-surface, #fff); border: 1px solid var(--color-border, #e2e8f0); }
.exp-panel h2 { margin: 0 0 0.85rem; font-size: 0.95rem; font-weight: 650; }
.exp-empty { margin: 0; padding: 1.5rem 0; text-align: center; color: var(--color-ink-muted, #64748b); font-size: 0.9rem; }
.exp-bars { list-style: none; margin: 0; padding: 0; display: flex; flex-direction: column; gap: 0.55rem; }
.exp-bars li { display: grid; grid-template-columns: minmax(7rem, 11rem) 1fr auto; gap: 0.75rem; align-items: center; font-size: 0.85rem; }
.exp-bars__track { height: 0.55rem; border-radius: 999px; background: color-mix(in srgb, var(--color-brand-700, #12243c) 12%, transparent); overflow: hidden; }
.exp-bars__fill { display: block; height: 100%; border-radius: inherit; background: var(--color-brand-700, #12243c); min-width: 2px; }
.exp-table { width: 100%; border-collapse: collapse; font-size: 0.9rem; }
.exp-table th, .exp-table td { padding: 0.65rem 0.4rem; text-align: left; border-bottom: 1px solid var(--color-border, #e2e8f0); }
.exp-table th { font-size: 0.75rem; font-weight: 600; color: var(--color-ink-muted, #64748b); }
.exp-table td:last-child, .exp-table th:last-child { text-align: right; }
@media (max-width: 800px) {
  .exp-report__kpis, .exp-bars li { grid-template-columns: 1fr; }
  .exp-report__head { align-items: stretch; flex-direction: column; }
}
@media print {
  .exp-report__head button, .exp-report__tabs { display: none; }
}
</style>
