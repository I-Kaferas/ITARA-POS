<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import { RouterLink } from 'vue-router'
import ReportsLayout from '../../../components/reports/ReportsLayout.vue'
import AppIcon from '../../../components/ui/AppIcon.vue'
import { useBackofficeStore } from '../../../stores/backoffice'
import type { FinancialReport, InventoryReport, SalesReport } from '../../../types'
import { formatMoney } from '../../../utils/format'

const { t, locale } = useI18n()
const store = useBackofficeStore()

const loading = ref(false)
const sales = ref<SalesReport | null>(null)
const prevRevenue = ref(0)
const inventory = ref<InventoryReport | null>(null)
const financial = ref<FinancialReport | null>(null)
const monthPurchases = ref(0)
const supplierCount = ref(0)
const activeCustomers = ref(0)
const trend = ref<{ label: string; revenue: number }[]>([])

const links = [
  {
    to: '/admin/reports/sales',
    titleKey: 'reports.explore.sales.title',
    descKey: 'reports.explore.sales.desc',
    icon: 'sales',
    color: '#059669',
  },
  {
    to: '/admin/reports/inventory',
    titleKey: 'reports.explore.inventory.title',
    descKey: 'reports.explore.inventory.desc',
    icon: 'inventory',
    color: '#0f766e',
  },
  {
    to: '/admin/reports/store-stock',
    titleKey: 'reports.explore.storeStock.title',
    descKey: 'reports.explore.storeStock.desc',
    icon: 'stores',
    color: '#0e7490',
  },
  {
    to: '/admin/reports/financial',
    titleKey: 'reports.explore.financial.title',
    descKey: 'reports.explore.financial.desc',
    icon: 'coins',
    color: '#b45309',
  },
  {
    to: '/admin/reports/purchases',
    titleKey: 'reports.explore.purchases.title',
    descKey: 'reports.explore.purchases.desc',
    icon: 'purchases',
    color: '#2563eb',
  },
  {
    to: '/admin/reports/forecasts',
    titleKey: 'reports.explore.forecasts.title',
    descKey: 'reports.explore.forecasts.desc',
    icon: 'sparkles',
    color: '#7c3aed',
  },
  {
    to: '/admin/reports/revenue',
    titleKey: 'reports.explore.revenue.title',
    descKey: 'reports.explore.revenue.desc',
    icon: 'receipt',
    color: '#c2410c',
  },
  {
    to: '/admin/reports/condensed',
    titleKey: 'reports.explore.condensed.title',
    descKey: 'reports.explore.condensed.desc',
    icon: 'layers',
    color: '#0e7490',
  },
  {
    to: '/admin/reports/daily',
    titleKey: 'reports.explore.daily.title',
    descKey: 'reports.explore.daily.desc',
    icon: 'calendar',
    color: '#d97706',
  },
  {
    to: '/admin/reports/user-performance',
    titleKey: 'reports.explore.userPerformance.title',
    descKey: 'reports.explore.userPerformance.desc',
    icon: 'account',
    color: '#dc2626',
  },
] as const

function localDate(date: Date) {
  const month = String(date.getMonth() + 1).padStart(2, '0')
  const day = String(date.getDate()).padStart(2, '0')
  return `${date.getFullYear()}-${month}-${day}`
}

function monthBounds(offset = 0) {
  const now = new Date()
  const start = new Date(now.getFullYear(), now.getMonth() + offset, 1)
  const end = new Date(now.getFullYear(), now.getMonth() + offset + 1, 0)
  return { from: localDate(start), to: localDate(end) }
}

function last12MonthsBounds() {
  const now = new Date()
  const start = new Date(now.getFullYear(), now.getMonth() - 11, 1)
  return { from: localDate(start), to: localDate(now) }
}

const monthlyRevenue = computed(() => sales.value?.revenue ?? 0)
const revenueDelta = computed(() => {
  if (!prevRevenue.value) return monthlyRevenue.value ? 100 : 0
  return Math.round(((monthlyRevenue.value - prevRevenue.value) / prevRevenue.value) * 1000) / 10
})
const revenueDeltaLabel = computed(() => {
  const sign = revenueDelta.value > 0 ? '+' : ''
  return `${sign}${revenueDelta.value}%`
})
const lowStockCount = computed(() => inventory.value?.low_stock_count ?? inventory.value?.open_alerts ?? 0)
const outOfStockCount = computed(() =>
  inventory.value?.out_of_stock_count
  ?? (inventory.value?.low_stock ?? []).filter(row => row.quantity_on_hand <= 0).length,
)
const topProducts = computed(() => (sales.value?.by_product ?? []).slice(0, 6))
const trendMax = computed(() => Math.max(1, ...trend.value.map(row => row.revenue)))
const debts = computed(() =>
  store.payablesSummary?.total_debt
  ?? financial.value?.debts
  ?? 0,
)
const receivables = computed(() => financial.value?.credit ?? sales.value?.outstanding_amount ?? 0)
const grossProfit = computed(() => financial.value?.gross_margin ?? 0)
const stockValue = computed(() => inventory.value?.estimated_value ?? 0)
const productCount = computed(() => store.stats?.products ?? 0)

async function load() {
  loading.value = true
  try {
    const current = monthBounds(0)
    const previous = monthBounds(-1)
    const year = last12MonthsBounds()

    const [salesRes, prevSalesRes, yearSalesRes, inventoryRes, financialRes, purchaseOverview] = await Promise.all([
      store.loadSalesReport({ from: current.from, to: current.to }),
      store.loadSalesReport({ from: previous.from, to: previous.to }),
      store.loadSalesReport({ from: year.from, to: year.to }),
      store.loadInventoryReport(),
      store.loadFinancialReport(current.from, current.to),
      store.loadPurchaseOverview({ from: current.from, to: current.to }).catch(() => ({ month_purchases: 0 })),
      store.loadStats().catch(() => undefined),
      store.loadPayablesSummary().catch(() => undefined),
      store.loadSuppliers().catch(() => undefined),
      store.loadCustomers().catch(() => undefined),
    ])

    sales.value = salesRes.data
    prevRevenue.value = prevSalesRes.data.revenue ?? 0
    inventory.value = inventoryRes
    financial.value = financialRes
    monthPurchases.value = Number(purchaseOverview?.month_purchases ?? purchaseOverview?.purchases_total ?? 0)
    supplierCount.value = store.suppliers.length
    activeCustomers.value = store.customers.filter(c => c.is_active !== false).length

    const byMonth = yearSalesRes.data.by_month ?? []
    if (byMonth.length) {
      trend.value = byMonth.slice(-12).map(row => ({ label: row.label, revenue: row.revenue }))
    } else {
      trend.value = buildEmptyTrend()
    }
  } finally {
    loading.value = false
  }
}

function buildEmptyTrend() {
  const rows: { label: string; revenue: number }[] = []
  const now = new Date()
  for (let i = 11; i >= 0; i -= 1) {
    const date = new Date(now.getFullYear(), now.getMonth() - i, 1)
    rows.push({
      label: date.toLocaleDateString(locale.value, { month: 'short', year: '2-digit' }),
      revenue: 0,
    })
  }
  return rows
}

function shortMonth(label: string) {
  if (/^\d{4}-\d{2}/.test(label)) {
    const date = new Date(`${label.slice(0, 7)}-01T00:00:00`)
    return date.toLocaleDateString(locale.value, { month: 'short' })
  }
  return label.slice(0, 3)
}

onMounted(load)
</script>

<template>
  <ReportsLayout>
    <div class="analytics">
      <div class="analytics__toolbar">
        <button type="button" class="btn-refresh" :disabled="loading" @click="load">
          <AppIcon name="import" :size="16" />
          {{ t('common.refresh') }}
        </button>
      </div>

      <div v-if="lowStockCount > 0" class="analytics__alert">
        <AppIcon name="alert" :size="18" />
        <span>{{ t('reports.analytics.lowStockAlert', { count: lowStockCount }) }}</span>
        <RouterLink to="/admin/reports/inventory" class="analytics__alert-link">
          {{ t('reports.analytics.viewReports') }}
        </RouterLink>
      </div>

      <div class="analytics__kpis">
        <article class="kpi">
          <p class="kpi__label">{{ t('reports.analytics.monthlyRevenue') }}</p>
          <p class="kpi__value">{{ formatMoney(monthlyRevenue) }}</p>
          <p class="kpi__meta" :class="revenueDelta >= 0 ? 'is-up' : 'is-down'">
            {{ revenueDeltaLabel }} {{ t('reports.analytics.vsLastMonth') }}
          </p>
        </article>
        <article class="kpi">
          <p class="kpi__label">{{ t('reports.analytics.grossProfit') }}</p>
          <p class="kpi__value">{{ formatMoney(grossProfit) }}</p>
        </article>
        <article class="kpi">
          <p class="kpi__label">{{ t('reports.analytics.receivables') }}</p>
          <p class="kpi__value">{{ formatMoney(receivables) }}</p>
        </article>
        <article class="kpi">
          <p class="kpi__label">{{ t('reports.analytics.stockValue') }}</p>
          <p class="kpi__value">{{ formatMoney(stockValue) }}</p>
        </article>
        <article class="kpi">
          <p class="kpi__label">{{ t('reports.analytics.activeCustomers') }}</p>
          <p class="kpi__value">{{ activeCustomers }}</p>
        </article>
        <article class="kpi">
          <p class="kpi__label">{{ t('reports.analytics.totalProducts') }}</p>
          <p class="kpi__value">{{ productCount }}</p>
        </article>
      </div>

      <div class="analytics__mid">
        <section class="panel">
          <header class="panel__header">
            <h3 class="panel__title">{{ t('reports.analytics.revenueTrend') }}</h3>
          </header>
          <div class="trend">
            <div
              v-for="(row, index) in trend"
              :key="`${row.label}-${index}`"
              class="trend__col"
              :title="`${row.label}: ${formatMoney(row.revenue)}`"
            >
              <div class="trend__bar-wrap">
                <div
                  class="trend__bar"
                  :style="{ height: `${Math.max(4, (row.revenue / trendMax) * 100)}%` }"
                />
              </div>
              <span class="trend__label">{{ shortMonth(row.label) }}</span>
            </div>
          </div>
        </section>

        <section class="panel">
          <header class="panel__header">
            <h3 class="panel__title">{{ t('reports.analytics.topProducts') }}</h3>
          </header>
          <div v-if="topProducts.length" class="top-list">
            <div v-for="(item, index) in topProducts" :key="`${item.label}-${index}`" class="top-list__row">
              <span class="top-list__rank">{{ index + 1 }}</span>
              <div class="top-list__info">
                <p class="top-list__name">{{ item.label }}</p>
                <p class="top-list__meta">{{ item.quantity }} · {{ formatMoney(item.revenue) }}</p>
              </div>
            </div>
          </div>
          <p v-else class="panel__empty">{{ t('reports.analytics.noSalesThisMonth') }}</p>
        </section>
      </div>

      <div class="analytics__secondary">
        <article class="kpi kpi--compact">
          <p class="kpi__label">{{ t('reports.analytics.purchasesThisMonth') }}</p>
          <p class="kpi__value">{{ formatMoney(monthPurchases) }}</p>
        </article>
        <article class="kpi kpi--compact">
          <p class="kpi__label">{{ t('reports.analytics.supplierDebts') }}</p>
          <p class="kpi__value">{{ formatMoney(debts) }}</p>
        </article>
        <article class="kpi kpi--compact">
          <p class="kpi__label">{{ t('reports.analytics.outOfStock') }}</p>
          <p class="kpi__value">{{ outOfStockCount }}</p>
        </article>
        <article class="kpi kpi--compact">
          <p class="kpi__label">{{ t('reports.analytics.suppliers') }}</p>
          <p class="kpi__value">{{ supplierCount }}</p>
        </article>
      </div>

      <section class="explore">
        <header class="explore__header">
          <h3 class="explore__title">{{ t('reports.analytics.exploreTitle') }}</h3>
        </header>
        <div class="explore__grid">
          <article
            v-for="link in links"
            :key="`${link.to}-${link.titleKey}`"
            class="explore-card"
            :style="{ '--card-color': link.color }"
          >
            <div class="explore-card__icon">
              <AppIcon :name="link.icon" :size="20" />
            </div>
            <h4 class="explore-card__title">{{ t(link.titleKey) }}</h4>
            <p class="explore-card__desc">{{ t(link.descKey) }}</p>
            <RouterLink :to="link.to" class="explore-card__cta">
              {{ t('reports.analytics.viewReports') }}
              <AppIcon name="chevron-right" :size="14" />
            </RouterLink>
          </article>
        </div>
      </section>
    </div>
  </ReportsLayout>
</template>

<style scoped>
.analytics {
  display: flex;
  flex-direction: column;
  gap: 1.25rem;
}

.analytics__toolbar {
  display: flex;
  justify-content: flex-end;
}

.btn-refresh {
  display: inline-flex;
  align-items: center;
  gap: 0.45rem;
  border: 1px solid #cbd5e1;
  border-radius: 0.55rem;
  background: white;
  color: #334155;
  padding: 0.45rem 0.85rem;
  font-size: 0.875rem;
  font-weight: 500;
  cursor: pointer;
}

.btn-refresh:disabled {
  opacity: 0.6;
  cursor: wait;
}

.analytics__alert {
  display: flex;
  align-items: center;
  gap: 0.65rem;
  flex-wrap: wrap;
  padding: 0.75rem 1rem;
  border-radius: 0.75rem;
  border: 1px solid #fcd34d;
  background: #fffbeb;
  color: #92400e;
  font-size: 0.9rem;
}

.analytics__alert-link {
  margin-left: auto;
  color: #b45309;
  font-weight: 600;
  text-decoration: none;
}

.analytics__kpis,
.analytics__secondary {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(160px, 1fr));
  gap: 0.85rem;
}

.kpi {
  border: 1px solid #e2e8f0;
  border-radius: 0.85rem;
  background: white;
  padding: 1rem 1.05rem;
}

.kpi--compact {
  padding: 0.85rem 1rem;
}

.kpi__label {
  margin: 0;
  font-size: 0.78rem;
  font-weight: 600;
  letter-spacing: 0.02em;
  text-transform: uppercase;
  color: #64748b;
}

.kpi__value {
  margin: 0.45rem 0 0;
  font-size: 1.35rem;
  font-weight: 700;
  color: #0f172a;
  line-height: 1.2;
}

.kpi__meta {
  margin: 0.35rem 0 0;
  font-size: 0.8rem;
  font-weight: 600;
}

.kpi__meta.is-up { color: #059669; }
.kpi__meta.is-down { color: #dc2626; }

.analytics__mid {
  display: grid;
  grid-template-columns: minmax(0, 1.4fr) minmax(0, 1fr);
  gap: 0.85rem;
}

@media (max-width: 900px) {
  .analytics__mid {
    grid-template-columns: 1fr;
  }
}

.panel {
  border: 1px solid #e2e8f0;
  border-radius: 0.85rem;
  background: white;
  padding: 1rem 1.1rem 1.15rem;
  min-height: 240px;
}

.panel__header {
  margin-bottom: 0.85rem;
}

.panel__title {
  margin: 0;
  font-size: 0.95rem;
  font-weight: 700;
  color: #0f172a;
}

.panel__empty {
  margin: 2rem 0 0;
  text-align: center;
  color: #94a3b8;
  font-size: 0.9rem;
}

.trend {
  display: grid;
  grid-template-columns: repeat(12, minmax(0, 1fr));
  align-items: end;
  gap: 0.35rem;
  height: 160px;
}

.trend__col {
  display: flex;
  flex-direction: column;
  align-items: center;
  height: 100%;
  gap: 0.35rem;
}

.trend__bar-wrap {
  flex: 1;
  width: 100%;
  display: flex;
  align-items: flex-end;
  justify-content: center;
}

.trend__bar {
  width: 70%;
  max-width: 1.4rem;
  border-radius: 0.35rem 0.35rem 0.15rem 0.15rem;
  background: #0f766e;
  min-height: 4px;
}

.trend__label {
  font-size: 0.65rem;
  color: #94a3b8;
  text-transform: uppercase;
}

.top-list {
  display: flex;
  flex-direction: column;
  gap: 0.55rem;
}

.top-list__row {
  display: flex;
  align-items: center;
  gap: 0.7rem;
}

.top-list__rank {
  width: 1.6rem;
  height: 1.6rem;
  border-radius: 999px;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  background: #f1f5f9;
  color: #475569;
  font-size: 0.75rem;
  font-weight: 700;
}

.top-list__name {
  margin: 0;
  font-size: 0.9rem;
  font-weight: 600;
  color: #0f172a;
}

.top-list__meta {
  margin: 0.1rem 0 0;
  font-size: 0.78rem;
  color: #64748b;
}

.explore__header {
  margin-bottom: 0.85rem;
}

.explore__title {
  margin: 0;
  font-size: 1.05rem;
  font-weight: 700;
  color: #0f172a;
}

.explore__grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(240px, 1fr));
  gap: 0.85rem;
}

.explore-card {
  display: flex;
  flex-direction: column;
  gap: 0.55rem;
  border: 1px solid var(--color-border);
  border-radius: var(--radius-lg);
  background: var(--color-surface);
  padding: 1.05rem 1.1rem 1.15rem;
}

.explore-card__icon {
  width: 2.35rem;
  height: 2.35rem;
  border-radius: var(--radius-md);
  display: inline-flex;
  align-items: center;
  justify-content: center;
  color: var(--color-brand-700);
  background: var(--color-brand-50);
}

.explore-card__title {
  margin: 0;
  font-size: 0.95rem;
  font-weight: 700;
  color: #0f172a;
}

.explore-card__desc {
  margin: 0;
  flex: 1;
  font-size: 0.82rem;
  line-height: 1.45;
  color: #64748b;
}

.explore-card__cta {
  display: inline-flex;
  align-items: center;
  gap: 0.25rem;
  margin-top: 0.25rem;
  color: var(--color-brand-700);
  font-size: 0.85rem;
  font-weight: 650;
  text-decoration: none;
}
</style>
