<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import ReportsLayout from '../../../components/reports/ReportsLayout.vue'
import AppIcon from '../../../components/ui/AppIcon.vue'
import FieldLabel from '../../../components/ui/FieldLabel.vue'
import { useBackofficeStore } from '../../../stores/backoffice'
import { useContextStore } from '../../../stores/context'
import type { RevenueReport } from '../../../types'
import { formatMoney, toDateTimeLocal } from '../../../utils/format'

type ProductTab = 'all' | 'sales' | 'accompaniments'

const { t, locale } = useI18n()
const store = useBackofficeStore()
const context = useContextStore()

const report = ref<RevenueReport | null>(null)
const from = ref('')
const to = ref('')
const storeId = ref('')
const loading = ref(false)
const productTab = ref<ProductTab>('all')
const search = ref('')

const donutColors = ['#059669', '#2563eb', '#d97706', '#dc2626', '#7c3aed', '#0e7490', '#64748b', '#be185d', '#0f766e']

function initDates() {
  const now = new Date()
  const start = new Date(now.getFullYear(), now.getMonth(), 1, 0, 0, 0)
  from.value = toDateTimeLocal(start).slice(0, 16)
  to.value = toDateTimeLocal(now).slice(0, 16)
}

async function load() {
  loading.value = true
  try {
    report.value = await store.loadRevenueReport({
      store_id: storeId.value || undefined,
      from: from.value || undefined,
      to: to.value || undefined,
    })
  } finally {
    loading.value = false
  }
}

async function exportExcel() {
  await store.exportRevenueReport({
    store_id: storeId.value || undefined,
    from: from.value || undefined,
    to: to.value || undefined,
  })
}

const storeLabel = computed(() => {
  if (!storeId.value) return t('org.allStores')
  return context.activeStores.find(s => s.id === storeId.value)?.name ?? t('org.allStores')
})

const periodLabel = computed(() => {
  const start = report.value?.from || from.value
  const end = report.value?.to || to.value
  if (!start && !end) return '—'
  return `${formatPeriod(start)} ${t('reports.revenueReport.toConnector')} ${formatPeriod(end)}`
})

function formatPeriod(value?: string | null) {
  if (!value) return '—'
  const normalized = value.includes('T') ? value : value.replace(' ', 'T')
  try {
    return new Date(normalized).toLocaleString(locale.value, {
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
      hour: '2-digit',
      minute: '2-digit',
      second: '2-digit',
      hour12: false,
    })
  } catch {
    return value
  }
}

const daily = computed(() => report.value?.by_day ?? [])
const dailyMax = computed(() => Math.max(1, ...daily.value.map(r => r.revenue)))

const categories = computed(() => {
  const rows = [...(report.value?.by_category ?? [])]
  if (rows.length <= 8) return rows
  const top = rows.slice(0, 8)
  const rest = rows.slice(8)
  const otherRevenue = rest.reduce((sum, r) => sum + r.revenue, 0)
  const otherQty = rest.reduce((sum, r) => sum + r.quantity, 0)
  const total = rows.reduce((sum, r) => sum + r.revenue, 0) || 1
  top.push({
    label: t('reports.revenueReport.others'),
    quantity: otherQty,
    revenue: otherRevenue,
    share: Math.round((otherRevenue / total) * 1000) / 10,
  })
  return top
})

function donutBackground(rows: { revenue: number }[]) {
  const total = rows.reduce((sum, row) => sum + row.revenue, 0) || 1
  let cursor = 0
  const stops = rows.map((row, i) => {
    const start = (cursor / total) * 100
    cursor += row.revenue
    const end = (cursor / total) * 100
    return `${donutColors[i % donutColors.length]} ${start}% ${end}%`
  })
  return `conic-gradient(${stops.join(', ')})`
}

const categoryDonut = computed(() => donutBackground(categories.value))

const filteredProducts = computed(() => {
  let rows = report.value?.by_product ?? []
  if (productTab.value === 'sales') rows = rows.filter(r => !r.is_accompaniment)
  if (productTab.value === 'accompaniments') rows = rows.filter(r => r.is_accompaniment)
  const q = search.value.trim().toLowerCase()
  if (q) {
    rows = rows.filter(r =>
      (r.label || '').toLowerCase().includes(q)
      || (r.sku || '').toLowerCase().includes(q)
      || (r.category || '').toLowerCase().includes(q),
    )
  }
  return rows
})

const totals = computed(() => {
  const rows = filteredProducts.value
  return {
    quantity: rows.reduce((s, r) => s + r.quantity, 0),
    revenue: rows.reduce((s, r) => s + r.revenue, 0),
    gross_profit: rows.reduce((s, r) => s + r.gross_profit, 0),
    tax_total: rows.reduce((s, r) => s + r.tax_total, 0),
  }
})

function moneyOrDash(value: number | null | undefined) {
  if (value === null || value === undefined) return '—'
  return formatMoney(value)
}

function axisLabel(value: number) {
  const major = value / 100
  if (major >= 1_000_000) return `${Math.round(major / 100_000) / 10}M`
  if (major >= 1000) return `${Math.round(major / 100) / 10}K`
  return String(Math.round(major))
}

const axisTicks = computed(() => {
  const max = dailyMax.value
  return [0, 0.25, 0.5, 0.75, 1].map(ratio => axisLabel(Math.round(max * ratio)))
})

onMounted(() => {
  initDates()
  load()
})
</script>

<template>
  <ReportsLayout>
    <div class="rev">
      <div class="rev__toolbar">
        <button type="button" class="btn-secondary" :disabled="loading" @click="load">
          <AppIcon name="import" :size="15" />
          {{ t('common.refresh') }}
        </button>
        <div class="rev__filters">
          <div>
            <FieldLabel icon="calendar">{{ t('reports.revenueReport.from') }}</FieldLabel>
            <input v-model="from" type="datetime-local" class="field" />
          </div>
          <div>
            <FieldLabel icon="calendar">{{ t('reports.revenueReport.to') }}</FieldLabel>
            <input v-model="to" type="datetime-local" class="field" />
          </div>
          <div>
            <FieldLabel icon="stores">{{ t('nav.stores') }}</FieldLabel>
            <select v-model="storeId" class="field">
              <option value="">{{ t('org.allStores') }}</option>
              <option v-for="s in context.activeStores" :key="s.id" :value="s.id">{{ s.name }}</option>
            </select>
          </div>
          <button type="button" class="btn-primary" :disabled="loading" @click="load">
            {{ t('reports.revenueReport.generate') }}
          </button>
        </div>
      </div>

      <p v-if="report" class="rev__meta">
        {{ t('reports.revenueReport.period') }}: {{ periodLabel }}
        · {{ storeLabel }}
        · {{ t('reports.revenueReport.productsSold') }}: {{ report.products_count }}
      </p>

      <div v-if="report" class="rev__kpis">
        <div class="kpi kpi--hero">
          <p class="kpi__label">{{ t('reports.revenueReport.grandTotal') }}</p>
          <p class="kpi__value">{{ formatMoney(report.total) }}</p>
        </div>
        <div class="kpi">
          <p class="kpi__label">{{ t('print.subtotal') }}</p>
          <p class="kpi__value">{{ formatMoney(report.subtotal) }}</p>
        </div>
        <div class="kpi">
          <p class="kpi__label">{{ t('reports.analytics.grossProfit') }}</p>
          <p class="kpi__value">{{ formatMoney(report.gross_profit) }}</p>
          <p class="kpi__meta">{{ report.margin_pct }}% {{ t('reports.revenueReport.margin') }}</p>
        </div>
        <div class="kpi">
          <p class="kpi__label">{{ t('reports.revenueReport.totalTax') }}</p>
          <p class="kpi__value">{{ formatMoney(report.tax_total) }}</p>
        </div>
        <div class="kpi">
          <p class="kpi__label">{{ t('reports.revenueReport.totalDiscount') }}</p>
          <p class="kpi__value">{{ formatMoney(report.discount_total) }}</p>
        </div>
        <div class="kpi">
          <p class="kpi__label">{{ t('reports.revenueReport.totalInvoices') }}</p>
          <p class="kpi__value">{{ report.invoices_count }}</p>
        </div>
        <div class="kpi">
          <p class="kpi__label">{{ t('reports.revenueReport.houseOffer') }}</p>
          <p class="kpi__value">{{ formatMoney(report.house_offer) }}</p>
        </div>
      </div>

      <div v-if="report" class="rev__charts">
        <section class="panel">
          <h3 class="panel__title">{{ t('reports.revenueReport.dailyRevenue') }}</h3>
          <div v-if="daily.length" class="bars">
            <div class="bars__axis">
              <span v-for="tick in [...axisTicks].reverse()" :key="tick">{{ tick }}</span>
            </div>
            <div class="bars__plot">
              <div v-for="row in daily" :key="row.day" class="bars__col">
                <div
                  class="bars__bar"
                  :style="{ height: `${Math.max(4, (row.revenue / dailyMax) * 100)}%` }"
                  :title="`${row.day}: ${formatMoney(row.revenue)}`"
                />
                <span class="bars__label">{{ row.day }}</span>
              </div>
            </div>
          </div>
          <p v-else class="empty">{{ t('common.noResults') }}</p>
        </section>

        <section class="panel">
          <h3 class="panel__title">{{ t('reports.salesAnalytics.revenueByCategory') }}</h3>
          <div v-if="categories.length" class="donut-wrap">
            <div class="donut" :style="{ background: categoryDonut }" />
            <ul class="legend">
              <li v-for="(row, i) in categories" :key="`${row.label}-${i}`">
                <span class="legend__swatch" :style="{ background: donutColors[i % donutColors.length] }" />
                <span class="legend__text">
                  {{ row.label || t('reports.uncategorized') }} ({{ row.share }}%)
                </span>
              </li>
            </ul>
          </div>
          <p v-else class="empty">{{ t('common.noResults') }}</p>
        </section>
      </div>

      <section v-if="report" class="panel panel--table">
        <div class="table-head">
          <div>
            <h3 class="panel__title">
              {{ t('reports.revenueReport.productsSold') }} ({{ report.products_count }})
            </h3>
            <div class="seg">
              <button
                type="button"
                class="seg__btn"
                :class="{ 'is-active': productTab === 'all' }"
                @click="productTab = 'all'"
              >
                {{ t('reports.revenueReport.tabAll') }}
                <strong>{{ report.products_count }}</strong>
              </button>
              <button
                type="button"
                class="seg__btn"
                :class="{ 'is-active': productTab === 'sales' }"
                @click="productTab = 'sales'"
              >
                {{ t('reports.revenueReport.tabSales') }}
                <strong>{{ report.sales_products_count }}</strong>
              </button>
              <button
                type="button"
                class="seg__btn"
                :class="{ 'is-active': productTab === 'accompaniments' }"
                @click="productTab = 'accompaniments'"
              >
                {{ t('reports.revenueReport.tabAccompaniments') }}
                <strong>{{ report.accompaniments_count }}</strong>
              </button>
            </div>
          </div>
          <div class="table-actions">
            <button type="button" class="btn-secondary" @click="exportExcel">
              <AppIcon name="import" :size="15" />
              {{ t('reports.salesAnalytics.exportExcel') }}
            </button>
            <input
              v-model="search"
              type="search"
              class="field field--search"
              :placeholder="t('reports.revenueReport.searchProducts')"
            >
          </div>
        </div>

        <div class="table-scroll">
          <table>
            <thead>
              <tr>
                <th>#</th>
                <th>{{ t('reports.salesAnalytics.product') }}</th>
                <th>{{ t('reports.salesAnalytics.category') }}</th>
                <th class="num">{{ t('reports.salesAnalytics.qtySold') }}</th>
                <th class="num">{{ t('reports.revenueReport.costPrice') }}</th>
                <th class="num">{{ t('reports.revenueReport.salePrice') }}</th>
                <th class="num">{{ t('print.total') }}</th>
                <th class="num">{{ t('reports.analytics.grossProfit') }}</th>
                <th class="num">{{ t('reports.revenueReport.marginPct') }}</th>
                <th class="num">{{ t('reports.revenueReport.totalTax') }}</th>
                <th class="num">{{ t('reports.salesAnalytics.invoices') }}</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="(row, index) in filteredProducts" :key="`${row.sku}-${row.label}-${index}`">
                <td>{{ index + 1 }}</td>
                <td>
                  <div class="product-cell">
                    <strong>{{ row.label }}</strong>
                    <span v-if="row.sku" class="sku">{{ row.sku }}</span>
                  </div>
                </td>
                <td>{{ row.category || t('reports.uncategorized') }}</td>
                <td class="num">{{ row.quantity }}</td>
                <td class="num">{{ moneyOrDash(row.cost_price) }}</td>
                <td class="num">{{ formatMoney(row.unit_price) }}</td>
                <td class="num">{{ formatMoney(row.revenue) }}</td>
                <td class="num">{{ formatMoney(row.gross_profit) }}</td>
                <td class="num">{{ row.margin_pct }}%</td>
                <td class="num">{{ row.tax_total ? formatMoney(row.tax_total) : '—' }}</td>
                <td class="num">{{ row.invoices }}</td>
              </tr>
              <tr v-if="!filteredProducts.length">
                <td colspan="11" class="empty">{{ t('common.noResults') }}</td>
              </tr>
            </tbody>
            <tfoot v-if="filteredProducts.length">
              <tr>
                <td colspan="3">{{ t('print.total') }}</td>
                <td class="num">{{ totals.quantity }}</td>
                <td class="num">—</td>
                <td class="num">—</td>
                <td class="num">{{ formatMoney(totals.revenue) }}</td>
                <td class="num">{{ formatMoney(totals.gross_profit) }}</td>
                <td class="num">—</td>
                <td class="num">{{ formatMoney(totals.tax_total) }}</td>
                <td class="num">—</td>
              </tr>
            </tfoot>
          </table>
        </div>
      </section>

      <p v-if="loading && !report" class="empty">{{ t('common.loading') }}</p>
    </div>
  </ReportsLayout>
</template>

<style scoped>
.rev {
  display: flex;
  flex-direction: column;
  gap: 1rem;
}

.rev__toolbar {
  display: flex;
  flex-wrap: wrap;
  align-items: flex-end;
  gap: 0.75rem 1rem;
}

.rev__filters {
  display: flex;
  flex-wrap: wrap;
  align-items: flex-end;
  gap: 0.75rem;
  flex: 1;
}

.rev__meta {
  margin: 0;
  font-size: 0.875rem;
  color: #475569;
}

.rev__kpis {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(150px, 1fr));
  gap: 0.75rem;
}

.kpi {
  border: 1px solid #e2e8f0;
  border-radius: 0.85rem;
  background: white;
  padding: 0.95rem 1rem;
}

.kpi--hero {
  border-color: #99f6e4;
  background: linear-gradient(180deg, #f0fdfa 0%, #fff 100%);
}

.kpi__label {
  margin: 0;
  font-size: 0.72rem;
  font-weight: 600;
  letter-spacing: 0.02em;
  text-transform: uppercase;
  color: #64748b;
}

.kpi__value {
  margin: 0.4rem 0 0;
  font-size: 1.2rem;
  font-weight: 700;
  color: #0f172a;
}

.kpi__meta {
  margin: 0.25rem 0 0;
  font-size: 0.8rem;
  color: #0f766e;
  font-weight: 600;
}

.rev__charts {
  display: grid;
  grid-template-columns: 1.2fr 1fr;
  gap: 0.85rem;
}

@media (max-width: 960px) {
  .rev__charts {
    grid-template-columns: 1fr;
  }
}

.panel {
  border: 1px solid #e2e8f0;
  border-radius: 0.85rem;
  background: white;
  padding: 1rem 1.1rem 1.15rem;
}

.panel--table {
  padding-bottom: 0.5rem;
}

.panel__title {
  margin: 0 0 0.85rem;
  font-size: 0.95rem;
  font-weight: 700;
  color: #0f172a;
}

.bars {
  display: grid;
  grid-template-columns: 2.5rem 1fr;
  gap: 0.5rem;
  min-height: 220px;
}

.bars__axis {
  display: flex;
  flex-direction: column;
  justify-content: space-between;
  font-size: 0.68rem;
  color: #94a3b8;
  text-align: right;
  padding-bottom: 1.6rem;
}

.bars__plot {
  display: flex;
  align-items: flex-end;
  gap: 0.45rem;
  border-left: 1px solid #e2e8f0;
  border-bottom: 1px solid #e2e8f0;
  padding: 0.25rem 0.35rem 0;
  min-height: 200px;
  overflow-x: auto;
}

.bars__col {
  flex: 1 0 2.4rem;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: flex-end;
  height: 180px;
  gap: 0.35rem;
}

.bars__bar {
  width: 70%;
  max-width: 2rem;
  border-radius: 0.35rem 0.35rem 0 0;
  background: linear-gradient(180deg, #14b8a6 0%, #0f766e 100%);
}

.bars__label {
  font-size: 0.62rem;
  color: #64748b;
  writing-mode: horizontal-tb;
  white-space: nowrap;
  transform: rotate(-35deg);
  transform-origin: top left;
  margin-left: 0.4rem;
  height: 1.4rem;
}

.donut-wrap {
  display: grid;
  grid-template-columns: 8rem 1fr;
  gap: 1rem;
  align-items: center;
}

.donut {
  width: 8rem;
  height: 8rem;
  border-radius: 999px;
  mask: radial-gradient(circle, transparent 48%, #000 50%);
  -webkit-mask: radial-gradient(circle, transparent 48%, #000 50%);
}

.legend {
  list-style: none;
  margin: 0;
  padding: 0;
  display: flex;
  flex-direction: column;
  gap: 0.4rem;
}

.legend li {
  display: flex;
  align-items: flex-start;
  gap: 0.45rem;
  font-size: 0.8rem;
  color: #334155;
}

.legend__swatch {
  width: 0.7rem;
  height: 0.7rem;
  border-radius: 0.2rem;
  margin-top: 0.15rem;
  flex-shrink: 0;
}

.table-head {
  display: flex;
  flex-wrap: wrap;
  justify-content: space-between;
  gap: 0.85rem;
  margin-bottom: 0.85rem;
}

.table-actions {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 0.55rem;
}

.seg {
  display: inline-flex;
  flex-wrap: wrap;
  gap: 0.35rem;
  margin-top: 0.55rem;
}

.seg__btn {
  display: inline-flex;
  align-items: center;
  gap: 0.4rem;
  border: 1px solid #e2e8f0;
  background: #f8fafc;
  color: #64748b;
  border-radius: 999px;
  padding: 0.35rem 0.75rem;
  font-size: 0.8rem;
  font-weight: 600;
  cursor: pointer;
}

.seg__btn strong {
  color: #0f172a;
}

.seg__btn.is-active {
  background: #ecfdf5;
  border-color: #99f6e4;
  color: #0f766e;
}

.table-scroll {
  overflow: auto;
}

table {
  width: 100%;
  border-collapse: collapse;
  font-size: 0.84rem;
}

th,
td {
  padding: 0.65rem 0.7rem;
  border-top: 1px solid #e2e8f0;
  text-align: left;
  vertical-align: top;
}

th {
  background: #f8fafc;
  color: #64748b;
  font-size: 0.72rem;
  text-transform: uppercase;
  letter-spacing: 0.03em;
  white-space: nowrap;
}

.num {
  text-align: right;
  font-variant-numeric: tabular-nums;
  white-space: nowrap;
}

.product-cell {
  display: flex;
  flex-direction: column;
  gap: 0.15rem;
}

.sku {
  font-size: 0.75rem;
  color: #94a3b8;
  font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
}

tfoot td {
  font-weight: 700;
  background: #f8fafc;
}

.field {
  border-radius: 0.5rem;
  border: 1px solid #cbd5e1;
  padding: 0.5rem 0.75rem;
  min-width: 11rem;
  background: white;
}

.field--search {
  min-width: 14rem;
}

.btn-primary,
.btn-secondary {
  display: inline-flex;
  align-items: center;
  gap: 0.4rem;
  border-radius: 0.55rem;
  padding: 0.5rem 0.9rem;
  font-size: 0.875rem;
  font-weight: 500;
  cursor: pointer;
  height: 2.45rem;
}

.btn-primary {
  border: none;
  color: white;
  background: var(--color-brand-600, #0f766e);
}

.btn-secondary {
  border: 1px solid #cbd5e1;
  background: white;
  color: #334155;
}

.btn-primary:disabled,
.btn-secondary:disabled {
  opacity: 0.6;
  cursor: wait;
}

.empty {
  margin: 0;
  padding: 1.25rem 0.5rem;
  text-align: center;
  color: #94a3b8;
  font-size: 0.875rem;
}
</style>
