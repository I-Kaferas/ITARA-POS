<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import ReportsLayout from '../../../components/reports/ReportsLayout.vue'
import AppIcon from '../../../components/ui/AppIcon.vue'
import FieldLabel from '../../../components/ui/FieldLabel.vue'
import { useBackofficeStore } from '../../../stores/backoffice'
import { useContextStore } from '../../../stores/context'
import type { SalesReport } from '../../../types'
import { formatDate, formatMoney } from '../../../utils/format'

type SalesTab = 'overview' | 'trends' | 'products' | 'customers'

const { t, locale } = useI18n()
const store = useBackofficeStore()
const context = useContextStore()

const report = ref<SalesReport | null>(null)
const from = ref('')
const to = ref('')
const storeId = ref(context.currentStoreId ?? '')
const loading = ref(false)
const activeTab = ref<SalesTab>('overview')

const tabs: { id: SalesTab; labelKey: string; icon: string }[] = [
  { id: 'overview', labelKey: 'reports.salesAnalytics.tabs.overview', icon: 'dashboard' },
  { id: 'trends', labelKey: 'reports.salesAnalytics.tabs.trends', icon: 'sparkles' },
  { id: 'products', labelKey: 'reports.salesAnalytics.tabs.products', icon: 'products' },
  { id: 'customers', labelKey: 'reports.salesAnalytics.tabs.customers', icon: 'customers' },
]

function localDate(date: Date) {
  const month = String(date.getMonth() + 1).padStart(2, '0')
  const day = String(date.getDate()).padStart(2, '0')
  return `${date.getFullYear()}-${month}-${day}`
}

function initDates() {
  const now = new Date()
  const start = new Date(now.getFullYear(), now.getMonth() - 11, 1)
  from.value = localDate(start)
  to.value = localDate(now)
}

async function load() {
  loading.value = true
  try {
    const res = await store.loadSalesReport({
      store_id: storeId.value || undefined,
      from: from.value || undefined,
      to: to.value || undefined,
    })
    report.value = res.data
  } finally {
    loading.value = false
  }
}

async function exportExcel() {
  await store.exportSalesReport({
    store_id: storeId.value || undefined,
    from: from.value || undefined,
    to: to.value || undefined,
  })
}

function exportPdf() {
  window.print()
}

const aov = computed(() => report.value?.average_order_value ?? (
  report.value && report.value.sales_count > 0
    ? Math.round(report.value.revenue / report.value.sales_count)
    : 0
))

const quoteConversion = computed(() => report.value?.quote_conversion ?? { converted: 0, total: 0, rate: 0 })

const monthlyRevenue = computed(() => report.value?.monthly_revenue ?? [])
const monthlyMax = computed(() => Math.max(1, ...monthlyRevenue.value.map(r => r.revenue)))

const invoiceStatus = computed(() => report.value?.invoice_status ?? [])
const orderStatus = computed(() => report.value?.order_status ?? [])
const returnsByType = computed(() => report.value?.returns_by_type ?? [])
const delivery = computed(() => report.value?.delivery ?? [])

const returnsMax = computed(() => Math.max(1, ...returnsByType.value.map(r => r.amount)))

const dailyTrend = computed(() => report.value?.by_day ?? [])
const dailyTrendMax = computed(() => Math.max(1, ...dailyTrend.value.map(r => r.revenue)))

const weeklyRevenue = computed(() => report.value?.by_week ?? [])
const weeklyMax = computed(() => Math.max(1, ...weeklyRevenue.value.map(r => r.revenue)))

const weekdaySales = computed(() => report.value?.by_weekday ?? [])
const weekdayMax = computed(() => Math.max(1, ...weekdaySales.value.map(r => r.sales_count)))

const aovTrend = computed(() => {
  if (report.value?.aov_by_day?.length) return report.value.aov_by_day
  return dailyTrend.value.map(row => ({
    day: row.day,
    sales_count: row.sales_count,
    revenue: row.revenue,
    aov: row.sales_count > 0 ? Math.round(row.revenue / row.sales_count) : 0,
  }))
})
const aovTrendMax = computed(() => Math.max(1, ...aovTrend.value.map(r => r.aov)))

function weekdayName(weekday: number) {
  return t(`reports.salesAnalytics.weekdays.${weekday}`)
}

function shortDay(day: string) {
  try {
    return new Date(`${day}T12:00:00`).toLocaleDateString(locale.value, { day: '2-digit', month: 'short' })
  } catch {
    return day
  }
}

function linePoints(values: number[], max: number, width = 100, height = 100) {
  if (!values.length) return ''
  return values
    .map((value, index) => {
      const x = values.length === 1 ? width / 2 : (index / (values.length - 1)) * width
      const y = height - (Math.max(0, value) / max) * height
      return `${x},${y}`
    })
    .join(' ')
}

const dailyLinePoints = computed(() =>
  linePoints(dailyTrend.value.map(r => r.revenue), dailyTrendMax.value),
)
const aovLinePoints = computed(() =>
  linePoints(aovTrend.value.map(r => r.aov), aovTrendMax.value),
)

const categoryRows = computed(() => report.value?.by_category ?? [])
const categoryRevenueMax = computed(() => Math.max(1, ...categoryRows.value.map(r => r.revenue)))
const categoryDonut = computed(() => donutBackground(categoryRows.value.map(r => ({ count: r.revenue }))))
const topProducts = computed(() => report.value?.by_product ?? [])

const categoryLabel = (label: string | null | undefined) => label || t('reports.uncategorized')
const locationLabel = (label: string | null | undefined) => label || t('reports.salesAnalytics.unknownLocation')

const customerSummary = computed(() => report.value?.customer_summary ?? {
  customers: 0,
  revenue: 0,
  unpaid: 0,
  avg_revenue: 0,
})
const topCustomers = computed(() => report.value?.by_customer ?? [])
const categoryForCustomers = computed(() => report.value?.by_category ?? [])
const categoryCustomerDonut = computed(() => donutBackground(categoryForCustomers.value.map(r => ({ count: r.revenue }))))
const categoryCustomerMax = computed(() => Math.max(1, ...categoryForCustomers.value.map(r => r.revenue)))

const statusLabel = (key: string) => {
  const path = `reports.salesAnalytics.status.${key}`
  const translated = t(path)
  return translated === path ? key : translated
}

const returnLabel = (key: string) => {
  const path = `reports.salesAnalytics.returnTypes.${key}`
  const translated = t(path)
  return translated === path ? (key || t('reports.salesAnalytics.returnTypes.other')) : translated
}

const shortMonth = (label: string) => {
  const [year, month] = label.split('-')
  if (!year || !month) return label
  try {
    return new Date(Number(year), Number(month) - 1, 1).toLocaleDateString(locale.value, { month: 'short' })
  } catch {
    return label
  }
}

const donutColors = ['#059669', '#2563eb', '#d97706', '#dc2626', '#7c3aed', '#0e7490', '#64748b']

function donutBackground(rows: { count: number }[]) {
  const total = rows.reduce((sum, row) => sum + row.count, 0) || 1
  let cursor = 0
  const stops = rows.map((row, i) => {
    const start = (cursor / total) * 100
    cursor += row.count
    const end = (cursor / total) * 100
    return `${donutColors[i % donutColors.length]} ${start}% ${end}%`
  })
  return `conic-gradient(${stops.join(', ')})`
}

const invoiceDonut = computed(() => donutBackground(invoiceStatus.value))
const orderDonut = computed(() => donutBackground(orderStatus.value))

onMounted(() => {
  initDates()
  load()
})
</script>

<template>
  <ReportsLayout>
    <div class="sales">
      <div class="sales__chrome">
        <nav class="sales__tabs" role="tablist" :aria-label="t('reports.explore.sales.title')">
          <button
            v-for="tab in tabs"
            :key="tab.id"
            type="button"
            role="tab"
            class="sales__tab"
            :class="{ 'is-active': activeTab === tab.id }"
            :aria-selected="activeTab === tab.id"
            @click="activeTab = tab.id"
          >
            <span class="sales__tab-icon" aria-hidden="true">
              <AppIcon :name="tab.icon" :size="15" />
            </span>
            <span class="sales__tab-label">{{ t(tab.labelKey) }}</span>
          </button>
        </nav>

        <div class="sales__actions">
          <button type="button" class="btn-secondary" @click="exportPdf">
            <AppIcon name="receipt" :size="15" />
            <span>{{ t('reports.salesAnalytics.exportPdf') }}</span>
          </button>
          <button type="button" class="btn-secondary" @click="exportExcel">
            <AppIcon name="import" :size="15" />
            <span>{{ t('reports.salesAnalytics.exportExcel') }}</span>
          </button>
          <button type="button" class="btn-secondary" :disabled="loading" @click="load">
            <AppIcon name="import" :size="15" />
            <span>{{ t('common.refresh') }}</span>
          </button>
        </div>
      </div>

      <div class="sales__filters">
        <div>
          <FieldLabel icon="stores">{{ t('nav.stores') }}</FieldLabel>
          <select v-model="storeId" class="field">
            <option value="">{{ t('org.allStores') }}</option>
            <option v-for="s in context.activeStores" :key="s.id" :value="s.id">{{ s.name }}</option>
          </select>
        </div>
        <div>
          <FieldLabel icon="calendar">{{ t('reports.salesAnalytics.from') }}</FieldLabel>
          <input v-model="from" type="date" class="field" />
        </div>
        <div>
          <FieldLabel icon="calendar">{{ t('reports.salesAnalytics.to') }}</FieldLabel>
          <input v-model="to" type="date" class="field" />
        </div>
        <button type="button" class="btn-primary" :disabled="loading" @click="load">
          {{ t('reports.salesAnalytics.apply') }}
        </button>
      </div>

      <template v-if="activeTab === 'overview'">
        <div class="sales__kpis">
          <article class="kpi">
            <p class="kpi__label">{{ t('reports.salesAnalytics.aov') }}</p>
            <p class="kpi__value">{{ formatMoney(aov) }}</p>
          </article>
          <article class="kpi">
            <p class="kpi__label">{{ t('reports.salesAnalytics.quoteConversion') }}</p>
            <p class="kpi__value">{{ quoteConversion.rate }}%</p>
            <p class="kpi__meta">{{ t('reports.salesAnalytics.ofCount', { converted: quoteConversion.converted, total: quoteConversion.total }) }}</p>
          </article>
          <article class="kpi">
            <p class="kpi__label">{{ t('reports.salesAnalytics.totalRevenue') }}</p>
            <p class="kpi__value">{{ formatMoney(report?.revenue ?? 0) }}</p>
          </article>
          <article class="kpi">
            <p class="kpi__label">{{ t('reports.salesAnalytics.unpaid') }}</p>
            <p class="kpi__value">{{ formatMoney(report?.outstanding_amount ?? 0) }}</p>
          </article>
        </div>

        <section class="panel">
          <header class="panel__header">
            <h3 class="panel__title">{{ t('reports.salesAnalytics.monthlyRevenue') }}</h3>
            <div class="legend">
              <span class="legend__item"><i class="dot dot--collected" />{{ t('reports.salesAnalytics.collected') }}</span>
              <span class="legend__item"><i class="dot dot--unpaid" />{{ t('reports.salesAnalytics.unpaid') }}</span>
              <span class="legend__item"><i class="dot dot--revenue" />{{ t('reports.salesAnalytics.revenue') }}</span>
            </div>
          </header>
          <div v-if="monthlyRevenue.length" class="stacked">
            <div
              v-for="row in monthlyRevenue"
              :key="row.label"
              class="stacked__col"
              :title="`${row.label}: ${formatMoney(row.revenue)}`"
            >
              <div class="stacked__bars">
                <div class="stacked__track">
                  <div
                    class="stacked__seg stacked__seg--collected"
                    :style="{ height: `${(row.collected / monthlyMax) * 100}%` }"
                  />
                  <div
                    class="stacked__seg stacked__seg--unpaid"
                    :style="{ height: `${(row.unpaid / monthlyMax) * 100}%` }"
                  />
                </div>
                <div
                  class="stacked__line"
                  :style="{ bottom: `${(row.revenue / monthlyMax) * 100}%` }"
                />
              </div>
              <span class="stacked__label">{{ shortMonth(row.label) }}</span>
            </div>
          </div>
          <p v-else class="panel__empty">{{ t('org.empty') }}</p>
        </section>

        <div class="sales__grid">
          <section class="panel">
            <header class="panel__header">
              <h3 class="panel__title">{{ t('reports.salesAnalytics.invoiceStatus') }}</h3>
            </header>
            <div v-if="invoiceStatus.length" class="donut-wrap">
              <div class="donut" :style="{ background: invoiceDonut }" />
              <ul class="donut-legend">
                <li v-for="(row, i) in invoiceStatus" :key="row.label">
                  <i class="dot" :style="{ background: donutColors[i % donutColors.length] }" />
                  <span>{{ statusLabel(row.label) }}</span>
                  <strong>{{ row.count }}</strong>
                </li>
              </ul>
            </div>
            <p v-else class="panel__empty">{{ t('org.empty') }}</p>
          </section>

          <section class="panel">
            <header class="panel__header">
              <h3 class="panel__title">{{ t('reports.salesAnalytics.orderStatus') }}</h3>
            </header>
            <div v-if="orderStatus.length" class="donut-wrap">
              <div class="donut" :style="{ background: orderDonut }" />
              <ul class="donut-legend">
                <li v-for="(row, i) in orderStatus" :key="row.label">
                  <i class="dot" :style="{ background: donutColors[i % donutColors.length] }" />
                  <span>{{ statusLabel(row.label) }}</span>
                  <strong>{{ row.count }}</strong>
                </li>
              </ul>
            </div>
            <p v-else class="panel__empty">{{ t('org.empty') }}</p>
          </section>

          <section class="panel">
            <header class="panel__header">
              <h3 class="panel__title">{{ t('reports.salesAnalytics.delivery') }}</h3>
            </header>
            <p v-if="!delivery.length" class="panel__empty">{{ t('reports.salesAnalytics.noDelivery') }}</p>
            <ul v-else class="simple-list">
              <li v-for="row in delivery" :key="row.label">
                <span>{{ statusLabel(row.label) }}</span>
                <strong>{{ row.count }}</strong>
              </li>
            </ul>
          </section>

          <section class="panel">
            <header class="panel__header">
              <h3 class="panel__title">{{ t('reports.salesAnalytics.returnsByType') }}</h3>
            </header>
            <div v-if="returnsByType.length" class="bar-list">
              <div v-for="row in returnsByType" :key="row.label" class="bar-list__row">
                <div class="bar-list__meta">
                  <span>{{ returnLabel(row.label) }}</span>
                  <strong>{{ formatMoney(row.amount) }}</strong>
                </div>
                <div class="bar-list__track">
                  <div class="bar-list__fill" :style="{ width: `${(row.amount / returnsMax) * 100}%` }" />
                </div>
              </div>
            </div>
            <p v-else class="panel__empty">{{ t('reports.salesAnalytics.noReturns') }}</p>
          </section>
        </div>
      </template>

      <template v-else-if="activeTab === 'trends'">
        <div class="sales__grid sales__grid--2">
          <section class="panel">
            <header class="panel__header">
              <h3 class="panel__title">{{ t('reports.salesAnalytics.dailySalesTrend') }}</h3>
            </header>
            <div v-if="dailyTrend.length" class="line-chart">
              <svg viewBox="0 0 100 100" preserveAspectRatio="none" class="line-chart__svg">
                <polyline
                  fill="none"
                  stroke="#059669"
                  stroke-width="2"
                  vector-effect="non-scaling-stroke"
                  :points="dailyLinePoints"
                />
              </svg>
              <div class="line-chart__labels">
                <span
                  v-for="(row, index) in dailyTrend.filter((_, i) => i === 0 || i === dailyTrend.length - 1 || i % Math.ceil(dailyTrend.length / 6) === 0)"
                  :key="`${row.day}-${index}`"
                >
                  {{ shortDay(row.day) }}
                </span>
              </div>
              <p class="line-chart__hint">
                {{ formatMoney(dailyTrend[dailyTrend.length - 1]?.revenue ?? 0) }}
              </p>
            </div>
            <p v-else class="panel__empty">{{ t('org.empty') }}</p>
          </section>

          <section class="panel">
            <header class="panel__header">
              <h3 class="panel__title">{{ t('reports.salesAnalytics.weeklyRevenue') }}</h3>
            </header>
            <div v-if="weeklyRevenue.length" class="trend trend--compact">
              <div
                v-for="row in weeklyRevenue"
                :key="row.label"
                class="trend__col"
                :title="`${row.label}: ${formatMoney(row.revenue)}`"
              >
                <div class="trend__bar-wrap">
                  <div class="trend__bar" :style="{ height: `${Math.max(4, (row.revenue / weeklyMax) * 100)}%` }" />
                </div>
                <span class="trend__label">{{ row.label.replace(/^\d{4}-W/, 'S') }}</span>
              </div>
            </div>
            <p v-else class="panel__empty">{{ t('org.empty') }}</p>
          </section>

          <section class="panel">
            <header class="panel__header">
              <h3 class="panel__title">{{ t('reports.salesAnalytics.salesByWeekday') }}</h3>
            </header>
            <div v-if="weekdaySales.some(r => r.sales_count > 0)" class="trend trend--compact">
              <div
                v-for="row in weekdaySales"
                :key="row.weekday"
                class="trend__col"
                :title="`${weekdayName(row.weekday)}: ${row.sales_count}`"
              >
                <div class="trend__bar-wrap">
                  <div
                    class="trend__bar trend__bar--blue"
                    :style="{ height: `${Math.max(4, (row.sales_count / weekdayMax) * 100)}%` }"
                  />
                </div>
                <span class="trend__label">{{ weekdayName(row.weekday) }}</span>
              </div>
            </div>
            <p v-else class="panel__empty">{{ t('org.empty') }}</p>
          </section>

          <section class="panel">
            <header class="panel__header">
              <h3 class="panel__title">{{ t('reports.salesAnalytics.aovTrend') }}</h3>
            </header>
            <div v-if="aovTrend.length" class="line-chart">
              <svg viewBox="0 0 100 100" preserveAspectRatio="none" class="line-chart__svg">
                <polyline
                  fill="none"
                  stroke="#2563eb"
                  stroke-width="2"
                  vector-effect="non-scaling-stroke"
                  :points="aovLinePoints"
                />
              </svg>
              <div class="line-chart__labels">
                <span
                  v-for="(row, index) in aovTrend.filter((_, i) => i === 0 || i === aovTrend.length - 1 || i % Math.ceil(aovTrend.length / 6) === 0)"
                  :key="`aov-${row.day}-${index}`"
                >
                  {{ shortDay(row.day) }}
                </span>
              </div>
              <p class="line-chart__hint">
                {{ formatMoney(aovTrend[aovTrend.length - 1]?.aov ?? 0) }}
              </p>
            </div>
            <p v-else class="panel__empty">{{ t('org.empty') }}</p>
          </section>
        </div>
      </template>

      <template v-else-if="activeTab === 'products'">
        <div class="sales__grid sales__grid--2">
          <section class="panel">
            <header class="panel__header">
              <h3 class="panel__title">{{ t('reports.salesAnalytics.revenueByCategory') }}</h3>
            </header>
            <div v-if="categoryRows.length" class="donut-wrap">
              <div class="donut" :style="{ background: categoryDonut }" />
              <ul class="donut-legend">
                <li v-for="(row, i) in categoryRows" :key="`rev-${row.label || i}`">
                  <i class="dot" :style="{ background: donutColors[i % donutColors.length] }" />
                  <span>{{ categoryLabel(row.label) }}</span>
                  <strong>{{ formatMoney(row.revenue) }}</strong>
                </li>
              </ul>
            </div>
            <p v-else class="panel__empty">{{ t('org.empty') }}</p>
          </section>

          <section class="panel">
            <header class="panel__header">
              <h3 class="panel__title">{{ t('reports.salesAnalytics.categoryPerformance') }}</h3>
            </header>
            <div v-if="categoryRows.length" class="bar-list">
              <div v-for="(row, index) in categoryRows" :key="`perf-${row.label || index}`" class="bar-list__row">
                <div class="bar-list__meta">
                  <span>{{ categoryLabel(row.label) }}</span>
                  <strong>{{ row.share ?? 0 }}% · {{ formatMoney(row.revenue) }}</strong>
                </div>
                <div class="bar-list__track">
                  <div
                    class="bar-list__fill bar-list__fill--teal"
                    :style="{ width: `${(row.revenue / categoryRevenueMax) * 100}%` }"
                  />
                </div>
                <p class="bar-list__sub">
                  {{ t('reports.salesAnalytics.qtySold') }}: {{ row.quantity }}
                  · {{ t('reports.salesAnalytics.orders') }}: {{ row.orders ?? 0 }}
                </p>
              </div>
            </div>
            <p v-else class="panel__empty">{{ t('org.empty') }}</p>
          </section>
        </div>

        <section class="panel panel--table">
          <header class="panel__header">
            <h3 class="panel__title">{{ t('reports.salesAnalytics.topProductsByRevenue') }}</h3>
          </header>
          <table v-if="topProducts.length" class="table">
            <thead>
              <tr>
                <th>#</th>
                <th>{{ t('reports.salesAnalytics.product') }}</th>
                <th>{{ t('reports.salesAnalytics.category') }}</th>
                <th class="text-right">{{ t('reports.salesAnalytics.qtySold') }}</th>
                <th class="text-right">{{ t('reports.salesAnalytics.avgPrice') }}</th>
                <th class="text-right">{{ t('reports.salesAnalytics.revenueCol') }}</th>
                <th class="text-right">{{ t('reports.salesAnalytics.orders') }}</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="(row, index) in topProducts" :key="row.sku || row.label">
                <td>{{ index + 1 }}</td>
                <td>{{ row.label }}</td>
                <td>{{ categoryLabel(row.category) }}</td>
                <td class="text-right">{{ row.quantity }}</td>
                <td class="text-right">{{ formatMoney(row.avg_price ?? 0) }}</td>
                <td class="text-right">{{ formatMoney(row.revenue) }}</td>
                <td class="text-right">{{ row.orders ?? 0 }}</td>
              </tr>
            </tbody>
          </table>
          <p v-else class="panel__empty">{{ t('org.empty') }}</p>
        </section>
      </template>

      <template v-else>
        <div class="sales__kpis">
          <article class="kpi">
            <p class="kpi__label">{{ t('reports.salesAnalytics.clientsCount') }}</p>
            <p class="kpi__value">{{ customerSummary.customers }}</p>
          </article>
          <article class="kpi">
            <p class="kpi__label">{{ t('reports.salesAnalytics.clientsRevenue') }}</p>
            <p class="kpi__value">{{ formatMoney(customerSummary.revenue) }}</p>
          </article>
          <article class="kpi">
            <p class="kpi__label">{{ t('reports.salesAnalytics.unpaid') }}</p>
            <p class="kpi__value">{{ formatMoney(customerSummary.unpaid) }}</p>
          </article>
          <article class="kpi">
            <p class="kpi__label">{{ t('reports.salesAnalytics.avgClientRevenue') }}</p>
            <p class="kpi__value">{{ formatMoney(customerSummary.avg_revenue) }}</p>
          </article>
        </div>

        <div class="sales__grid sales__grid--2">
          <section class="panel">
            <header class="panel__header">
              <h3 class="panel__title">{{ t('reports.salesAnalytics.revenueByCategory') }}</h3>
            </header>
            <div v-if="categoryForCustomers.length" class="donut-wrap">
              <div class="donut" :style="{ background: categoryCustomerDonut }" />
              <ul class="donut-legend">
                <li v-for="(row, i) in categoryForCustomers" :key="`cust-cat-${row.label || i}`">
                  <i class="dot" :style="{ background: donutColors[i % donutColors.length] }" />
                  <span>{{ categoryLabel(row.label) }}</span>
                  <strong>{{ formatMoney(row.revenue) }}</strong>
                </li>
              </ul>
            </div>
            <p v-else class="panel__empty">{{ t('org.empty') }}</p>
          </section>

          <section class="panel">
            <header class="panel__header">
              <h3 class="panel__title">{{ t('reports.salesAnalytics.revenueByCategory') }}</h3>
            </header>
            <div v-if="categoryForCustomers.length" class="bar-list">
              <div
                v-for="(row, index) in categoryForCustomers"
                :key="`cust-cat-bar-${row.label || index}`"
                class="bar-list__row"
              >
                <div class="bar-list__meta">
                  <span>{{ categoryLabel(row.label) }}</span>
                  <strong>{{ row.share ?? 0 }}% · {{ formatMoney(row.revenue) }}</strong>
                </div>
                <div class="bar-list__track">
                  <div
                    class="bar-list__fill bar-list__fill--teal"
                    :style="{ width: `${(row.revenue / categoryCustomerMax) * 100}%` }"
                  />
                </div>
              </div>
            </div>
            <p v-else class="panel__empty">{{ t('org.empty') }}</p>
          </section>
        </div>

        <section class="panel panel--table">
          <header class="panel__header">
            <h3 class="panel__title">{{ t('reports.salesAnalytics.topClientsByRevenue') }}</h3>
          </header>
          <table v-if="topCustomers.length" class="table">
            <thead>
              <tr>
                <th>#</th>
                <th>{{ t('reports.salesAnalytics.client') }}</th>
                <th>{{ t('reports.salesAnalytics.location') }}</th>
                <th class="text-right">{{ t('reports.salesAnalytics.invoices') }}</th>
                <th class="text-right">{{ t('reports.salesAnalytics.revenueCol') }}</th>
                <th class="text-right">{{ t('reports.salesAnalytics.unpaid') }}</th>
                <th class="text-right">{{ t('reports.salesAnalytics.lastPurchase') }}</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="(row, index) in topCustomers" :key="row.label || index">
                <td>{{ index + 1 }}</td>
                <td>{{ row.label || t('reports.salesAnalytics.walkIn') }}</td>
                <td>{{ locationLabel(row.location) }}</td>
                <td class="text-right">{{ row.invoices ?? row.sales_count }}</td>
                <td class="text-right">{{ formatMoney(row.revenue) }}</td>
                <td class="text-right">{{ formatMoney(row.unpaid ?? 0) }}</td>
                <td class="text-right">{{ row.last_purchase ? formatDate(row.last_purchase) : '—' }}</td>
              </tr>
            </tbody>
          </table>
          <p v-else class="panel__empty">{{ t('org.empty') }}</p>
        </section>
      </template>
    </div>
  </ReportsLayout>
</template>

<style scoped>
.sales {
  display: flex;
  flex-direction: column;
  gap: 1.1rem;
}

.sales__chrome {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  justify-content: space-between;
  gap: 0.85rem;
}

.sales__actions,
.sales__filters {
  display: flex;
  flex-wrap: wrap;
  gap: 0.65rem;
  align-items: flex-end;
}

.sales__tabs {
  display: inline-flex;
  flex-wrap: nowrap;
  align-items: center;
  gap: 0.2rem;
  padding: 0.28rem;
  border: 1px solid #e2e8f0;
  border-radius: 0.95rem;
  background: #f8fafc;
  box-shadow: inset 0 1px 0 rgba(255, 255, 255, 0.8);
  overflow-x: auto;
  max-width: 100%;
  scrollbar-width: none;
}

.sales__tabs::-webkit-scrollbar {
  display: none;
}

.sales__tab {
  position: relative;
  display: inline-flex;
  align-items: center;
  gap: 0.45rem;
  border: 1px solid transparent;
  background: transparent;
  color: #64748b;
  font-size: 0.875rem;
  font-weight: 600;
  line-height: 1;
  padding: 0.62rem 0.95rem;
  border-radius: 0.72rem;
  white-space: nowrap;
  cursor: pointer;
  transition:
    color 0.18s ease,
    background 0.18s ease,
    border-color 0.18s ease,
    box-shadow 0.18s ease,
    transform 0.18s ease;
}

.sales__tab:hover {
  color: #0f172a;
  background: rgba(255, 255, 255, 0.7);
}

.sales__tab-icon {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 1.35rem;
  height: 1.35rem;
  border-radius: 0.45rem;
  background: rgba(148, 163, 184, 0.16);
  color: inherit;
  transition: background 0.18s ease, color 0.18s ease;
}

.sales__tab.is-active {
  color: #0f766e;
  background: white;
  border-color: #ccfbf1;
  box-shadow:
    0 1px 2px rgba(15, 23, 42, 0.06),
    0 4px 12px rgba(15, 118, 110, 0.08);
}

.sales__tab.is-active .sales__tab-icon {
  background: #ecfdf5;
  color: #0f766e;
}

.sales__tab.is-active::after {
  content: '';
  position: absolute;
  left: 0.9rem;
  right: 0.9rem;
  bottom: 0.2rem;
  height: 2px;
  border-radius: 999px;
  background: #0f766e;
  opacity: 0.85;
}

@media (max-width: 720px) {
  .sales__chrome {
    flex-direction: column;
    align-items: stretch;
  }

  .sales__tabs {
    width: 100%;
  }

  .sales__actions {
    justify-content: flex-start;
  }

  .sales__actions .btn-secondary span {
    display: none;
  }
}



.btn-secondary {
  display: inline-flex;
  align-items: center;
  gap: 0.4rem;
  border-radius: 0.55rem;
  padding: 0.5rem 0.9rem;
  font-size: 0.875rem;
  font-weight: 500;
  cursor: pointer;
}



.btn-secondary {
  border: 1px solid #cbd5e1;
  background: white;
  color: #334155;
}



.sales__kpis {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(170px, 1fr));
  gap: 0.85rem;
}

.kpi {
  border: 1px solid #e2e8f0;
  border-radius: 0.85rem;
  background: white;
  padding: 1rem 1.05rem;
}

.kpi__label {
  margin: 0;
  font-size: 0.75rem;
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
}

.kpi__meta {
  margin: 0.3rem 0 0;
  font-size: 0.8rem;
  color: #94a3b8;
}

.sales__grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 0.85rem;
}

.sales__grid--2 {
  grid-template-columns: repeat(2, minmax(0, 1fr));
}

@media (max-width: 900px) {
  .sales__grid,
  .sales__grid--2 {
    grid-template-columns: 1fr;
  }
}

.panel {
  border: 1px solid #e2e8f0;
  border-radius: 0.85rem;
  background: white;
  padding: 1rem 1.1rem 1.15rem;
  min-height: 220px;
}

.panel--table {
  overflow: auto;
}

.panel__header {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  justify-content: space-between;
  gap: 0.5rem;
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

.legend {
  display: flex;
  flex-wrap: wrap;
  gap: 0.75rem;
  font-size: 0.78rem;
  color: #64748b;
}

.legend__item {
  display: inline-flex;
  align-items: center;
  gap: 0.35rem;
}

.dot {
  display: inline-block;
  width: 0.55rem;
  height: 0.55rem;
  border-radius: 999px;
}

.dot--collected { background: #059669; }
.dot--unpaid { background: #f59e0b; }
.dot--revenue { background: #2563eb; }

.stacked {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(2.2rem, 1fr));
  align-items: end;
  gap: 0.4rem;
  height: 180px;
}

.stacked__col {
  display: flex;
  flex-direction: column;
  align-items: center;
  height: 100%;
  gap: 0.35rem;
}

.stacked__bars {
  position: relative;
  flex: 1;
  width: 100%;
  display: flex;
  align-items: flex-end;
  justify-content: center;
}

.stacked__track {
  width: 70%;
  max-width: 1.5rem;
  height: 100%;
  display: flex;
  flex-direction: column-reverse;
  border-radius: 0.3rem 0.3rem 0.1rem 0.1rem;
  overflow: hidden;
  background: #f8fafc;
}

.stacked__seg { width: 100%; min-height: 0; }
.stacked__seg--collected { background: #059669; }
.stacked__seg--unpaid { background: #f59e0b; }

.stacked__line {
  position: absolute;
  left: 10%;
  right: 10%;
  height: 2px;
  background: #2563eb;
}

.stacked__label {
  font-size: 0.65rem;
  color: #94a3b8;
  text-transform: uppercase;
}

.donut-wrap {
  display: flex;
  align-items: center;
  gap: 1rem;
  flex-wrap: wrap;
}

.donut {
  width: 7.5rem;
  height: 7.5rem;
  border-radius: 999px;
  mask: radial-gradient(circle at center, transparent 48%, black 49%);
  -webkit-mask: radial-gradient(circle at center, transparent 48%, black 49%);
}

.donut-legend {
  list-style: none;
  margin: 0;
  padding: 0;
  display: flex;
  flex-direction: column;
  gap: 0.45rem;
  flex: 1;
  min-width: 8rem;
}

.donut-legend li,
.simple-list li {
  display: flex;
  align-items: center;
  gap: 0.45rem;
  font-size: 0.85rem;
  color: #475569;
}

.donut-legend strong,
.simple-list strong {
  margin-left: auto;
  color: #0f172a;
}

.simple-list {
  list-style: none;
  margin: 0;
  padding: 0;
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
}

.bar-list {
  display: flex;
  flex-direction: column;
  gap: 0.7rem;
}

.bar-list__meta {
  display: flex;
  justify-content: space-between;
  gap: 0.5rem;
  font-size: 0.85rem;
  color: #475569;
  margin-bottom: 0.25rem;
}

.bar-list__track {
  height: 0.45rem;
  border-radius: 999px;
  background: #f1f5f9;
  overflow: hidden;
}

.bar-list__fill {
  height: 100%;
  background: #dc2626;
  border-radius: 999px;
}

.bar-list__fill--teal {
  background: #0f766e;
}

.bar-list__sub {
  margin: 0.25rem 0 0;
  font-size: 0.75rem;
  color: #94a3b8;
}

.trend {
  display: grid;
  grid-auto-flow: column;
  grid-auto-columns: minmax(2rem, 1fr);
  align-items: end;
  gap: 0.3rem;
  height: 180px;
  overflow-x: auto;
}

.trend--compact {
  height: 160px;
  grid-auto-columns: minmax(1.8rem, 1fr);
}

.trend__col {
  display: flex;
  flex-direction: column;
  align-items: center;
  height: 100%;
  gap: 0.3rem;
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
  max-width: 1.2rem;
  border-radius: 0.3rem 0.3rem 0.1rem 0.1rem;
  background: #0f766e;
  min-height: 4px;
}

.trend__bar--blue {
  background: #2563eb;
}

.trend__label {
  font-size: 0.6rem;
  color: #94a3b8;
  white-space: nowrap;
}

.line-chart {
  display: flex;
  flex-direction: column;
  gap: 0.55rem;
  min-height: 160px;
}

.line-chart__svg {
  width: 100%;
  height: 140px;
  background: #fff;
  border-bottom: 1px solid #e2e8f0;
}

.line-chart__labels {
  display: flex;
  justify-content: space-between;
  gap: 0.35rem;
  font-size: 0.68rem;
  color: #94a3b8;
}

.line-chart__hint {
  margin: 0;
  font-size: 0.85rem;
  font-weight: 600;
  color: #0f172a;
}

.table {
  width: 100%;
  border-collapse: collapse;
  font-size: 0.875rem;
}

.table th,
.table td {
  padding: 0.55rem 0.35rem;
  border-bottom: 1px solid #f1f5f9;
  text-align: left;
}

.table th {
  color: #64748b;
  font-weight: 600;
  font-size: 0.75rem;
  text-transform: uppercase;
}

.text-right { text-align: right !important; }

@media print {
  .sales__chrome,
  .sales__filters {
    display: none !important;
  }
}
</style>
