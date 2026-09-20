<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import ReportsLayout from '../../../components/reports/ReportsLayout.vue'
import AppIcon from '../../../components/ui/AppIcon.vue'
import FieldLabel from '../../../components/ui/FieldLabel.vue'
import { useBackofficeStore } from '../../../stores/backoffice'
import type { PurchasesReport } from '../../../types'
import { formatDate, formatMoney } from '../../../utils/format'

type PurchasesTab = 'overview' | 'suppliers' | 'receipts'
type ReceiptViewMode = 'condensed' | 'detailed'

const { t, locale } = useI18n()
const store = useBackofficeStore()

const report = ref<PurchasesReport | null>(null)
const from = ref('')
const to = ref('')
const loading = ref(false)
const activeTab = ref<PurchasesTab>('overview')
const receiptViewMode = ref<ReceiptViewMode>('condensed')
const receiptSearch = ref('')

const tabs: { id: PurchasesTab; labelKey: string; icon: string }[] = [
  { id: 'overview', labelKey: 'reports.purchaseAnalytics.tabs.overview', icon: 'dashboard' },
  { id: 'suppliers', labelKey: 'reports.purchaseAnalytics.tabs.suppliers', icon: 'suppliers' },
  { id: 'receipts', labelKey: 'reports.purchaseAnalytics.tabs.receipts', icon: 'inventory' },
]

const donutColors = ['#0f766e', '#2563eb', '#d97706', '#dc2626', '#7c3aed', '#0e7490', '#64748b']
const qtyColors: Record<string, string> = {
  ordered: '#2563eb',
  received: '#0ea5e9',
  accepted: '#059669',
  rejected: '#dc2626',
  quarantine: '#d97706',
}

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
    report.value = await store.loadPurchasesReport({
      from: from.value || undefined,
      to: to.value || undefined,
    })
  } finally {
    loading.value = false
  }
}

async function exportExcel() {
  await store.exportPurchasesReport({
    from: from.value || undefined,
    to: to.value || undefined,
  })
}

function exportPdf() {
  window.print()
}

const monthsSpan = computed(() => report.value?.months_span ?? 12)
const totalSpend = computed(() => report.value?.total_spend ?? 0)
const monthlySpend = computed(() => report.value?.monthly_spend ?? [])
const spendMax = computed(() => Math.max(1, ...monthlySpend.value.map(r => r.spend)))
const ordersMax = computed(() => Math.max(1, ...monthlySpend.value.map(r => r.orders_count)))

const orderStatus = computed(() => report.value?.order_status ?? [])
const orderDonut = computed(() => donutBackground(orderStatus.value.map(r => ({ count: r.count }))))

const topCategories = computed(() => report.value?.top_categories ?? [])
const categoryMax = computed(() => Math.max(1, ...topCategories.value.map(r => r.spend)))

const bySupplier = computed(() => report.value?.by_supplier ?? [])
const topSuppliers = computed(() => bySupplier.value.slice(0, 5))
const supplierMax = computed(() => Math.max(1, ...topSuppliers.value.map(r => r.spend)))
const concentration = computed(() => report.value?.supplier_concentration ?? {
  top_count: 5,
  share: 0,
  spend: 0,
})

const receipts = computed(() => report.value?.receipts ?? [])
const receiptSummary = computed(() => report.value?.receipt_summary ?? {
  total_receipts: 0,
  qty_ordered: 0,
  qty_received: 0,
  qty_accepted: 0,
  qty_rejected: 0,
  qty_quarantine: 0,
  quantity_breakdown: [],
  receipt_status: [],
  inspection_results: [],
})
const receiptStatusDonut = computed(() =>
  donutBackground(receiptSummary.value.receipt_status.map(r => ({ count: r.count }))),
)
const quantityBreakdown = computed(() => receiptSummary.value.quantity_breakdown)
const quantityMax = computed(() => Math.max(1, ...quantityBreakdown.value.map(r => r.qty)))

const filteredReceipts = computed(() => {
  const q = receiptSearch.value.trim().toLowerCase()
  if (!q) return receipts.value
  return receipts.value.filter((row) => {
    const haystack = [
      row.receipt_number,
      row.order_number,
      row.supplier,
      row.warehouse,
      row.status,
    ].filter(Boolean).join(' ').toLowerCase()
    return haystack.includes(q)
  })
})

function qtyLabel(key: string) {
  const path = `reports.purchaseAnalytics.qtyLabels.${key}`
  const translated = t(path)
  return translated === path ? key : translated
}

function inspectionLabel(value?: string | null) {
  if (!value) return '—'
  const path = `reports.purchaseAnalytics.inspection.${value}`
  const translated = t(path)
  return translated === path ? value : translated
}

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

const statusLabel = (key: string) => {
  const path = `reports.purchaseAnalytics.status.${key}`
  const translated = t(path)
  return translated === path ? key : translated
}

const categoryLabel = (label: string | null | undefined) => label || t('reports.uncategorized')
const supplierLabel = (label: string | null | undefined) => label || t('reports.purchaseAnalytics.unknownSupplier')

const shortMonth = (label: string) => {
  const [year, month] = label.split('-')
  if (!year || !month) return label
  try {
    return new Date(Number(year), Number(month) - 1, 1).toLocaleDateString(locale.value, { month: 'short' })
  } catch {
    return label
  }
}

onMounted(() => {
  initDates()
  load()
})
</script>

<template>
  <ReportsLayout>
    <div class="purchases">
      <div class="purchases__chrome">
        <nav class="purchases__tabs" role="tablist" :aria-label="t('reports.explore.purchases.title')">
          <button
            v-for="tab in tabs"
            :key="tab.id"
            type="button"
            role="tab"
            class="purchases__tab"
            :class="{ 'is-active': activeTab === tab.id }"
            :aria-selected="activeTab === tab.id"
            @click="activeTab = tab.id"
          >
            <span class="purchases__tab-icon" aria-hidden="true">
              <AppIcon :name="tab.icon" :size="15" />
            </span>
            <span class="purchases__tab-label">{{ t(tab.labelKey) }}</span>
          </button>
        </nav>

        <div class="purchases__actions">
          <button type="button" class="btn-secondary" @click="exportPdf">
            <AppIcon name="receipt" :size="15" />
            <span>{{ t('reports.purchaseAnalytics.exportPdf') }}</span>
          </button>
          <button type="button" class="btn-secondary" @click="exportExcel">
            <AppIcon name="import" :size="15" />
            <span>{{ t('reports.purchaseAnalytics.exportExcel') }}</span>
          </button>
          <button type="button" class="btn-secondary" :disabled="loading" @click="load">
            <AppIcon name="import" :size="15" />
            <span>{{ t('common.refresh') }}</span>
          </button>
        </div>
      </div>

      <div class="purchases__filters">
        <div>
          <FieldLabel icon="calendar">{{ t('reports.purchaseAnalytics.from') }}</FieldLabel>
          <input v-model="from" type="date" class="field" />
        </div>
        <div>
          <FieldLabel icon="calendar">{{ t('reports.purchaseAnalytics.to') }}</FieldLabel>
          <input v-model="to" type="date" class="field" />
        </div>
        <button type="button" class="btn-primary" :disabled="loading" @click="load">
          {{ t('reports.purchaseAnalytics.apply') }}
        </button>
      </div>

      <template v-if="activeTab === 'overview'">
        <div class="purchases__kpis">
          <article class="kpi">
            <p class="kpi__label">{{ t('reports.purchaseAnalytics.totalSpendMonths', { months: monthsSpan }) }}</p>
            <p class="kpi__value">{{ formatMoney(totalSpend) }}</p>
          </article>
        </div>

        <section class="panel">
          <header class="panel__header">
            <h3 class="panel__title">{{ t('reports.purchaseAnalytics.monthlySpend') }}</h3>
            <div class="legend">
              <span class="legend__item"><i class="dot dot--orders" />{{ t('reports.purchaseAnalytics.orders') }}</span>
              <span class="legend__item"><i class="dot dot--spend" />{{ t('reports.purchaseAnalytics.spend') }}</span>
            </div>
          </header>
          <div v-if="monthlySpend.length" class="combo">
            <div
              v-for="row in monthlySpend"
              :key="row.label"
              class="combo__col"
              :title="`${row.label}: ${row.orders_count} / ${formatMoney(row.spend)}`"
            >
              <div class="combo__bars">
                <div
                  class="combo__bar combo__bar--orders"
                  :style="{ height: `${Math.max(4, (row.orders_count / ordersMax) * 100)}%` }"
                />
                <div
                  class="combo__bar combo__bar--spend"
                  :style="{ height: `${Math.max(4, (row.spend / spendMax) * 100)}%` }"
                />
              </div>
              <span class="combo__label">{{ shortMonth(row.label) }}</span>
            </div>
          </div>
          <p v-else class="panel__empty">{{ t('org.empty') }}</p>
        </section>

        <div class="purchases__grid">
          <section class="panel">
            <header class="panel__header">
              <h3 class="panel__title">{{ t('reports.purchaseAnalytics.orderStatus') }}</h3>
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
              <h3 class="panel__title">{{ t('reports.purchaseAnalytics.topCategories') }}</h3>
            </header>
            <div v-if="topCategories.length" class="bar-list">
              <div v-for="(row, index) in topCategories" :key="`cat-${row.label || index}`" class="bar-list__row">
                <div class="bar-list__meta">
                  <span>{{ categoryLabel(row.label) }}</span>
                  <strong>{{ row.share }}% · {{ formatMoney(row.spend) }}</strong>
                </div>
                <div class="bar-list__track">
                  <div class="bar-list__fill" :style="{ width: `${(row.spend / categoryMax) * 100}%` }" />
                </div>
              </div>
            </div>
            <p v-else class="panel__empty">{{ t('org.empty') }}</p>
          </section>
        </div>
      </template>

      <template v-else-if="activeTab === 'suppliers'">
        <section class="panel panel--soft">
          <header class="panel__header">
            <h3 class="panel__title">{{ t('reports.purchaseAnalytics.supplierConcentration') }}</h3>
          </header>
          <p class="concentration">
            {{ t('reports.purchaseAnalytics.concentrationHint', {
              count: concentration.top_count,
              share: concentration.share,
            }) }}
          </p>
          <div class="concentration__track">
            <div class="concentration__fill" :style="{ width: `${Math.min(100, concentration.share)}%` }" />
          </div>
        </section>

        <section class="panel">
          <header class="panel__header">
            <h3 class="panel__title">{{ t('reports.purchaseAnalytics.topSuppliersBySpend') }}</h3>
          </header>
          <div v-if="topSuppliers.length" class="bar-list">
            <div v-for="(row, index) in topSuppliers" :key="`top-${row.label || index}`" class="bar-list__row">
              <div class="bar-list__meta">
                <span>{{ supplierLabel(row.label) }}</span>
                <strong>{{ row.share }}% · {{ formatMoney(row.spend) }}</strong>
              </div>
              <div class="bar-list__track">
                <div class="bar-list__fill bar-list__fill--teal" :style="{ width: `${(row.spend / supplierMax) * 100}%` }" />
              </div>
            </div>
          </div>
          <p v-else class="panel__empty">{{ t('org.empty') }}</p>
        </section>

        <section class="panel panel--table">
          <header class="panel__header">
            <h3 class="panel__title">{{ t('reports.purchaseAnalytics.supplierPerformance') }}</h3>
          </header>
          <table v-if="bySupplier.length" class="table">
            <thead>
              <tr>
                <th>#</th>
                <th>{{ t('reports.purchaseAnalytics.supplier') }}</th>
                <th>{{ t('reports.purchaseAnalytics.location') }}</th>
                <th class="text-right">{{ t('reports.purchaseAnalytics.orders') }}</th>
                <th class="text-right">{{ t('reports.purchaseAnalytics.avgOrder') }}</th>
                <th class="text-right">{{ t('reports.purchaseAnalytics.totalSpendMonths', { months: monthsSpan }) }}</th>
                <th class="text-right">{{ t('reports.purchaseAnalytics.lastOrder') }}</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="(row, index) in bySupplier" :key="`perf-${row.label || index}`">
                <td>{{ index + 1 }}</td>
                <td>
                  <div class="product">
                    <strong>{{ supplierLabel(row.label) }}</strong>
                    <span v-if="row.code" class="mono">{{ row.code }}</span>
                  </div>
                </td>
                <td>{{ row.location || '—' }}</td>
                <td class="text-right">{{ row.orders_count }}</td>
                <td class="text-right">{{ formatMoney(row.avg_order) }}</td>
                <td class="text-right">{{ formatMoney(row.spend) }}</td>
                <td class="text-right">{{ row.last_order ? formatDate(row.last_order) : '—' }}</td>
              </tr>
            </tbody>
          </table>
          <p v-else class="panel__empty">{{ t('org.empty') }}</p>
        </section>
      </template>

      <template v-else>
        <div class="purchases__kpis purchases__kpis--4">
          <article class="kpi">
            <p class="kpi__label">{{ t('reports.purchaseAnalytics.totalReceipts') }}</p>
            <p class="kpi__value">{{ receiptSummary.total_receipts }}</p>
          </article>
          <article class="kpi">
            <p class="kpi__label">{{ t('reports.purchaseAnalytics.qtyOrdered') }}</p>
            <p class="kpi__value">{{ receiptSummary.qty_ordered }}</p>
          </article>
          <article class="kpi">
            <p class="kpi__label">{{ t('reports.purchaseAnalytics.qtyAccepted') }}</p>
            <p class="kpi__value kpi__value--ok">{{ receiptSummary.qty_accepted }}</p>
          </article>
          <article class="kpi">
            <p class="kpi__label">{{ t('reports.purchaseAnalytics.qtyRejected') }}</p>
            <p class="kpi__value kpi__value--danger">{{ receiptSummary.qty_rejected }}</p>
          </article>
        </div>

        <div class="purchases__grid purchases__grid--3">
          <section class="panel">
            <header class="panel__header">
              <h3 class="panel__title">{{ t('reports.purchaseAnalytics.quantitySummary') }}</h3>
            </header>
            <div v-if="quantityBreakdown.length" class="bar-list">
              <div v-for="row in quantityBreakdown" :key="row.label" class="bar-list__row">
                <div class="bar-list__meta">
                  <span>{{ qtyLabel(row.label) }}</span>
                  <strong>{{ row.qty }} ({{ Number(row.share).toFixed(1) }}%)</strong>
                </div>
                <div class="bar-list__track">
                  <div
                    class="bar-list__fill"
                    :style="{
                      width: `${(row.qty / quantityMax) * 100}%`,
                      background: qtyColors[row.label] || '#64748b',
                    }"
                  />
                </div>
              </div>
            </div>
            <p v-else class="panel__empty">{{ t('org.empty') }}</p>
          </section>

          <section class="panel">
            <header class="panel__header">
              <h3 class="panel__title">{{ t('reports.purchaseAnalytics.receiptStatus') }}</h3>
            </header>
            <div v-if="receiptSummary.receipt_status.length" class="donut-wrap">
              <div class="donut" :style="{ background: receiptStatusDonut }" />
              <ul class="donut-legend">
                <li v-for="(row, i) in receiptSummary.receipt_status" :key="row.label">
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
              <h3 class="panel__title">{{ t('reports.purchaseAnalytics.inspectionResults') }}</h3>
            </header>
            <div v-if="receiptSummary.inspection_results.length" class="bar-list">
              <div v-for="row in receiptSummary.inspection_results" :key="row.label" class="bar-list__row">
                <div class="bar-list__meta">
                  <span>{{ inspectionLabel(row.label) }}</span>
                  <strong>{{ row.count }}</strong>
                </div>
              </div>
            </div>
            <p v-else class="panel__empty">{{ t('reports.purchaseAnalytics.noInspections') }}</p>
          </section>
        </div>

        <section class="panel panel--table">
          <header class="panel__header panel__header--stack">
            <div class="panel__heading">
              <h3 class="panel__title">
                {{ t('reports.purchaseAnalytics.receiptDetails', { count: filteredReceipts.length }) }}
              </h3>
            </div>
            <div class="receipt-toolbar">
              <div class="segmented" role="group">
                <button
                  type="button"
                  class="segmented__btn"
                  :class="{ 'is-active': receiptViewMode === 'condensed' }"
                  @click="receiptViewMode = 'condensed'"
                >
                  {{ t('reports.purchaseAnalytics.viewCondensed') }}
                </button>
                <button
                  type="button"
                  class="segmented__btn"
                  :class="{ 'is-active': receiptViewMode === 'detailed' }"
                  @click="receiptViewMode = 'detailed'"
                >
                  {{ t('reports.purchaseAnalytics.viewDetailed') }}
                </button>
              </div>
              <button type="button" class="btn-secondary" @click="exportPdf">
                <AppIcon name="receipt" :size="15" />
                PDF
              </button>
              <button type="button" class="btn-secondary" @click="exportExcel">
                <AppIcon name="import" :size="15" />
                Excel
              </button>
              <input
                v-model="receiptSearch"
                type="search"
                class="field field--search"
                :placeholder="t('reports.purchaseAnalytics.receiptSearch')"
              />
            </div>
          </header>

          <table v-if="filteredReceipts.length" class="table">
            <thead>
              <tr>
                <th>{{ t('reports.purchaseAnalytics.goodsReceipt') }}</th>
                <th>{{ t('reports.purchaseAnalytics.purchaseOrder') }}</th>
                <th>{{ t('reports.purchaseAnalytics.supplier') }}</th>
                <th>{{ t('reports.purchaseAnalytics.date') }}</th>
                <th class="text-right">{{ t('reports.purchaseAnalytics.orderedShort') }}</th>
                <th class="text-right">{{ t('reports.purchaseAnalytics.receivedShort') }}</th>
                <th class="text-right">{{ t('reports.purchaseAnalytics.acceptedShort') }}</th>
                <th class="text-right">{{ t('reports.purchaseAnalytics.rejectedShort') }}</th>
                <th>{{ t('reports.purchaseAnalytics.statusCol') }}</th>
                <th>{{ t('reports.purchaseAnalytics.inspectionCol') }}</th>
                <th v-if="receiptViewMode === 'detailed'" class="text-right">{{ t('reports.purchaseAnalytics.amount') }}</th>
                <th v-if="receiptViewMode === 'detailed'">{{ t('inventory.warehouse') }}</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="row in filteredReceipts" :key="row.id">
                <td class="mono">{{ row.receipt_number }}</td>
                <td>{{ row.order_number || '—' }}</td>
                <td>{{ row.supplier || '—' }}</td>
                <td>{{ row.received_at ? formatDate(row.received_at) : '—' }}</td>
                <td class="text-right">{{ row.qty_ordered }}</td>
                <td class="text-right">{{ row.qty_received }}</td>
                <td class="text-right">{{ row.qty_accepted }}</td>
                <td class="text-right">{{ row.qty_rejected }}</td>
                <td>{{ statusLabel(row.status) }}</td>
                <td>{{ inspectionLabel(row.inspection) }}</td>
                <td v-if="receiptViewMode === 'detailed'" class="text-right">{{ formatMoney(row.amount) }}</td>
                <td v-if="receiptViewMode === 'detailed'">{{ row.warehouse || '—' }}</td>
              </tr>
            </tbody>
          </table>
          <p v-else class="panel__empty">{{ t('reports.purchaseAnalytics.noReceipts') }}</p>
        </section>
      </template>
    </div>
  </ReportsLayout>
</template>

<style scoped>
.purchases {
  display: flex;
  flex-direction: column;
  gap: 1.1rem;
}

.purchases__chrome {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 0.85rem;
  flex-wrap: wrap;
}

.purchases__actions,
.purchases__filters {
  display: flex;
  flex-wrap: wrap;
  gap: 0.65rem;
  align-items: flex-end;
}

.purchases__tabs {
  display: inline-flex;
  gap: 0.25rem;
  padding: 0.28rem;
  border-radius: 0.95rem;
  background: #f8fafc;
  box-shadow: inset 0 1px 0 rgba(255, 255, 255, 0.8);
  overflow-x: auto;
  max-width: 100%;
  scrollbar-width: none;
}

.purchases__tabs::-webkit-scrollbar {
  display: none;
}

.purchases__tab {
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
}

.purchases__tab:hover {
  color: #0f172a;
  background: rgba(255, 255, 255, 0.7);
}

.purchases__tab-icon {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 1.35rem;
  height: 1.35rem;
  border-radius: 0.45rem;
  background: rgba(148, 163, 184, 0.16);
  color: inherit;
}

.purchases__tab.is-active {
  color: #0f766e;
  background: white;
  border-color: #ccfbf1;
  box-shadow:
    0 1px 2px rgba(15, 23, 42, 0.06),
    0 4px 12px rgba(15, 118, 110, 0.08);
}

.purchases__tab.is-active .purchases__tab-icon {
  background: #ecfdf5;
  color: #0f766e;
}

.purchases__tab.is-active::after {
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
  .purchases__chrome {
    flex-direction: column;
    align-items: stretch;
  }

  .purchases__actions .btn-secondary span {
    display: none;
  }
}

.field {
  border-radius: 0.5rem;
  border: 1px solid #cbd5e1;
  padding: 0.5rem 0.75rem;
  min-width: 10rem;
  background: white;
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

.purchases__kpis {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(220px, 1fr));
  gap: 0.85rem;
}

.purchases__kpis--4 {
  grid-template-columns: repeat(4, minmax(0, 1fr));
}

@media (max-width: 1100px) {
  .purchases__kpis--4 {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }
}

@media (max-width: 640px) {
  .purchases__kpis--4 {
    grid-template-columns: 1fr;
  }
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

.kpi__value--ok {
  color: #059669;
}

.kpi__value--danger {
  color: #dc2626;
}

.purchases__grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 0.85rem;
}

.purchases__grid--3 {
  grid-template-columns: repeat(3, minmax(0, 1fr));
}

@media (max-width: 1100px) {
  .purchases__grid--3 {
    grid-template-columns: 1fr;
  }
}

@media (max-width: 900px) {
  .purchases__grid {
    grid-template-columns: 1fr;
  }
}

.panel {
  border: 1px solid #e2e8f0;
  border-radius: 0.85rem;
  background: white;
  padding: 1rem 1.1rem 1.15rem;
  min-height: 180px;
}

.panel--soft {
  min-height: auto;
  background: #ffffff;
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

.panel__header--stack {
  align-items: flex-start;
  flex-direction: column;
}

.panel__heading {
  width: 100%;
}

.receipt-toolbar {
  display: flex;
  flex-wrap: wrap;
  gap: 0.55rem;
  align-items: center;
  width: 100%;
}

.segmented {
  display: inline-flex;
  border: 1px solid #cbd5e1;
  border-radius: 0.55rem;
  overflow: hidden;
  background: white;
}

.segmented__btn {
  border: none;
  background: transparent;
  color: #64748b;
  font-size: 0.8rem;
  font-weight: 600;
  padding: 0.45rem 0.75rem;
  cursor: pointer;
}

.segmented__btn.is-active {
  background: #f0fdfa;
  color: #0f766e;
}

.field--search {
  min-width: 16rem;
  flex: 1;
}

.panel__title {
  margin: 0;
  font-size: 0.95rem;
  font-weight: 700;
  color: #0f172a;
}

.panel__meta {
  color: #64748b;
  font-size: 0.9rem;
}

.panel__empty {
  margin: 2rem 0 0;
  text-align: center;
  color: #94a3b8;
  font-size: 0.9rem;
}

.concentration {
  margin: 0 0 0.85rem;
  color: #475569;
  font-size: 0.95rem;
}

.concentration__track {
  height: 0.55rem;
  border-radius: 999px;
  background: #e2e8f0;
  overflow: hidden;
}

.concentration__fill {
  height: 100%;
  border-radius: inherit;
  background: #0f766e;
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

.dot--orders { background: #2563eb; }
.dot--spend { background: #0f766e; }

.combo {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(2.4rem, 1fr));
  gap: 0.45rem;
  align-items: end;
  min-height: 180px;
  padding-top: 0.5rem;
}

.combo__col {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 0.4rem;
  min-width: 0;
}

.combo__bars {
  display: flex;
  align-items: flex-end;
  gap: 0.18rem;
  height: 140px;
  width: 100%;
  justify-content: center;
}

.combo__bar {
  width: 0.55rem;
  border-radius: 0.35rem 0.35rem 0.15rem 0.15rem;
  min-height: 4px;
}

.combo__bar--orders { background: #2563eb; }
.combo__bar--spend { background: #0f766e; }

.combo__label {
  font-size: 0.7rem;
  color: #94a3b8;
  text-transform: capitalize;
}

.donut-wrap {
  display: flex;
  align-items: center;
  gap: 1.1rem;
  flex-wrap: wrap;
}

.donut {
  width: 8.5rem;
  height: 8.5rem;
  border-radius: 999px;
  flex-shrink: 0;
  mask: radial-gradient(circle at center, transparent 48%, #000 49%);
  -webkit-mask: radial-gradient(circle at center, transparent 48%, #000 49%);
}

.donut-legend {
  list-style: none;
  margin: 0;
  padding: 0;
  display: flex;
  flex-direction: column;
  gap: 0.45rem;
  flex: 1;
  min-width: 10rem;
}

.donut-legend li {
  display: grid;
  grid-template-columns: auto 1fr auto;
  gap: 0.5rem;
  align-items: center;
  font-size: 0.85rem;
  color: #475569;
}

.bar-list {
  display: flex;
  flex-direction: column;
  gap: 0.75rem;
}

.bar-list__row {
  display: flex;
  flex-direction: column;
  gap: 0.35rem;
}

.bar-list__meta {
  display: flex;
  justify-content: space-between;
  gap: 0.75rem;
  font-size: 0.85rem;
  color: #334155;
}

.bar-list__track {
  height: 0.45rem;
  border-radius: 999px;
  background: #e2e8f0;
  overflow: hidden;
}

.bar-list__fill {
  height: 100%;
  border-radius: inherit;
  background: #2563eb;
}

.bar-list__fill--teal {
  background: #0f766e;
}

.table {
  width: 100%;
  border-collapse: collapse;
  font-size: 0.875rem;
}

.table th,
.table td {
  padding: 0.7rem 0.55rem;
  border-bottom: 1px solid #e2e8f0;
  text-align: left;
  vertical-align: top;
}

.table th {
  color: #64748b;
  font-weight: 600;
  font-size: 0.75rem;
  text-transform: uppercase;
  letter-spacing: 0.02em;
}

.text-right {
  text-align: right;
}

.product {
  display: flex;
  flex-direction: column;
  gap: 0.15rem;
}

.product strong {
  color: #0f172a;
  font-weight: 600;
}

.mono {
  font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace;
  font-size: 0.75rem;
  color: #94a3b8;
}
</style>
