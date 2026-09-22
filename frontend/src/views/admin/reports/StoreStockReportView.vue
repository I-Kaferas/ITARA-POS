<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import ReportsLayout from '../../../components/reports/ReportsLayout.vue'
import AppIcon from '../../../components/ui/AppIcon.vue'
import FieldLabel from '../../../components/ui/FieldLabel.vue'
import { useBackofficeStore } from '../../../stores/backoffice'
import { useContextStore } from '../../../stores/context'
import type { StoreStockReport } from '../../../types'
import { formatDate, formatDateTime, formatMoney } from '../../../utils/format'

type StockTab = 'summary' | 'stock' | 'movements' | 'alerts' | 'performance' | 'comparison' | 'recommendations'
type Frequency = 'daily' | 'weekly' | 'monthly' | 'custom'
type Recipient = 'store_manager' | 'director' | 'accounting'

const { t } = useI18n()
const store = useBackofficeStore()
const context = useContextStore()

const report = ref<StoreStockReport | null>(null)
const storeId = ref(context.currentStoreId ?? '')
const from = ref('')
const to = ref('')
const idleDays = ref(30)
const frequency = ref<Frequency>('monthly')
const recipient = ref<Recipient>('store_manager')
const loading = ref(false)
const activeTab = ref<StockTab>('summary')

const tabs: { id: StockTab; labelKey: string; icon: string }[] = [
  { id: 'summary', labelKey: 'reports.storeStock.tabs.summary', icon: 'dashboard' },
  { id: 'stock', labelKey: 'reports.storeStock.tabs.stock', icon: 'inventory' },
  { id: 'movements', labelKey: 'reports.storeStock.tabs.movements', icon: 'transfer' },
  { id: 'alerts', labelKey: 'reports.storeStock.tabs.alerts', icon: 'alert' },
  { id: 'performance', labelKey: 'reports.storeStock.tabs.performance', icon: 'sparkles' },
  { id: 'comparison', labelKey: 'reports.storeStock.tabs.comparison', icon: 'stores' },
  { id: 'recommendations', labelKey: 'reports.storeStock.tabs.recommendations', icon: 'products' },
]

const healthColors: Record<string, string> = {
  healthy: '#059669',
  low: '#d97706',
  out: '#dc2626',
  over: '#2563eb',
}

function localDate(date: Date) {
  const month = String(date.getMonth() + 1).padStart(2, '0')
  const day = String(date.getDate()).padStart(2, '0')
  return `${date.getFullYear()}-${month}-${day}`
}

function applyFrequency(next: Frequency) {
  frequency.value = next
  const now = new Date()
  if (next === 'daily') {
    from.value = localDate(now)
    to.value = localDate(now)
    return
  }
  if (next === 'weekly') {
    const start = new Date(now)
    start.setDate(now.getDate() - 6)
    from.value = localDate(start)
    to.value = localDate(now)
    return
  }
  if (next === 'monthly') {
    from.value = localDate(new Date(now.getFullYear(), now.getMonth(), 1))
    to.value = localDate(now)
  }
}

const queryParams = computed(() => ({
  store_id: storeId.value || undefined,
  from: from.value || undefined,
  to: to.value || undefined,
  idle_days: String(idleDays.value || 30),
}))

async function load() {
  loading.value = true
  try {
    report.value = await store.loadStoreStockReport(queryParams.value)
  } finally {
    loading.value = false
  }
}

async function exportExcel() {
  await store.exportStoreStockReport(queryParams.value)
}

function exportPdf() {
  window.print()
}

watch(frequency, (value) => {
  if (value !== 'custom') applyFrequency(value)
})

const headerStore = computed(() => {
  if (report.value?.store?.name) return report.value.store
  const selected = context.activeStores.find(s => s.id === storeId.value)
  return {
    name: selected?.name ?? null,
    code: selected?.code ?? null,
    address: null,
    manager: null,
  }
})

const summary = computed(() => report.value?.summary)
const stockHealth = computed(() => report.value?.stock_health ?? [])
const healthTotal = computed(() => Math.max(1, stockHealth.value.reduce((sum, row) => sum + row.count, 0)))
const healthDonut = computed(() => {
  let cursor = 0
  const stops = stockHealth.value.map((row) => {
    const start = (cursor / healthTotal.value) * 100
    cursor += row.count
    const end = (cursor / healthTotal.value) * 100
    return `${healthColors[row.label] ?? '#64748b'} ${start}% ${end}%`
  })
  return `conic-gradient(${stops.join(', ')})`
})
const dominantHealth = computed(() => [...stockHealth.value].sort((a, b) => b.count - a.count)[0] ?? null)
const byCategory = computed(() => report.value?.by_category ?? [])
const categoryMax = computed(() => Math.max(1, ...byCategory.value.map(r => r.value)))
const topSold = computed(() => report.value?.performance.top_sold ?? [])
const topSoldMax = computed(() => Math.max(1, ...topSold.value.map(r => r.quantity)))
const comparisonStores = computed(() => report.value?.comparison.stores ?? [])
const comparisonMax = computed(() => Math.max(1, ...comparisonStores.value.map(r => r.turnover_rate)))

const variationClass = computed(() => {
  const value = summary.value?.variation_value ?? 0
  if (value > 0) return 'is-up'
  if (value < 0) return 'is-down'
  return ''
})

function statusLabel(key: string) {
  const path = `reports.storeStock.status.${key}`
  const translated = t(path)
  return translated === path ? key : translated
}

function movementLabel(type: string) {
  const map: Record<string, string> = {
    INITIAL_STOCK: 'initial',
    OPENING: 'opening',
    PURCHASE: 'purchase',
    SALE: 'sale',
    SALE_RETURN: 'saleReturn',
    PURCHASE_RETURN: 'purchaseReturn',
    TRANSFER_IN: 'transferIn',
    TRANSFER_OUT: 'transferOut',
    ADJUSTMENT_IN: 'adjustmentIn',
    ADJUSTMENT_OUT: 'adjustmentOut',
    DAMAGE: 'damage',
    LOSS: 'loss',
    EXPIRED: 'expired',
  }
  const key = map[type.toUpperCase()] ?? type
  const path = `inventory.types.${key}`
  const translated = t(path)
  return translated === path ? type : translated
}

function safeMoney(amount?: number | null) {
  return formatMoney(Number.isFinite(amount as number) ? Number(amount) : 0)
}

function signedPct(value?: number | null) {
  const n = Number(value ?? 0)
  const sign = n > 0 ? '+' : ''
  return `${sign}${n.toFixed(1)}%`
}

onMounted(async () => {
  applyFrequency('monthly')
  if (!context.stores.length) await context.loadStores().catch(() => undefined)
  if (!storeId.value && context.currentStoreId) storeId.value = context.currentStoreId
  await load()
})
</script>

<template>
  <ReportsLayout>
    <div class="ss">
      <div class="ss__chrome">
        <nav class="ss__tabs" role="tablist" :aria-label="t('reports.storeStock.title')">
          <button
            v-for="tab in tabs"
            :key="tab.id"
            type="button"
            role="tab"
            class="ss__tab"
            :class="{ 'is-active': activeTab === tab.id }"
            :aria-selected="activeTab === tab.id"
            @click="activeTab = tab.id"
          >
            <span class="ss__tab-icon" aria-hidden="true">
              <AppIcon :name="tab.icon" :size="15" />
            </span>
            <span class="ss__tab-label">{{ t(tab.labelKey) }}</span>
          </button>
        </nav>
        <div class="ss__actions">
          <button type="button" class="btn-secondary" @click="exportPdf">
            <AppIcon name="receipt" :size="15" />
            <span>{{ t('reports.storeStock.exportPdf') }}</span>
          </button>
          <button type="button" class="btn-secondary" @click="exportExcel">
            <AppIcon name="import" :size="15" />
            <span>{{ t('reports.storeStock.exportExcel') }}</span>
          </button>
          <button type="button" class="btn-secondary" :disabled="loading" @click="load">
            <AppIcon name="import" :size="15" />
            <span>{{ t('common.refresh') }}</span>
          </button>
        </div>
      </div>

      <div class="ss__filters">
        <div>
          <FieldLabel icon="stores">{{ t('reports.storeStock.store') }}</FieldLabel>
          <select v-model="storeId" class="field">
            <option value="">{{ t('org.allStores') }}</option>
            <option v-for="item in context.activeStores" :key="item.id" :value="item.id">
              {{ item.name }} ({{ item.code }})
            </option>
          </select>
        </div>
        <div>
          <FieldLabel icon="calendar">{{ t('reports.storeStock.frequency') }}</FieldLabel>
          <select v-model="frequency" class="field">
            <option value="daily">{{ t('reports.storeStock.frequencies.daily') }}</option>
            <option value="weekly">{{ t('reports.storeStock.frequencies.weekly') }}</option>
            <option value="monthly">{{ t('reports.storeStock.frequencies.monthly') }}</option>
            <option value="custom">{{ t('reports.storeStock.frequencies.custom') }}</option>
          </select>
        </div>
        <div>
          <FieldLabel icon="calendar">{{ t('reports.storeStock.from') }}</FieldLabel>
          <input v-model="from" type="date" class="field" @change="frequency = 'custom'" />
        </div>
        <div>
          <FieldLabel icon="calendar">{{ t('reports.storeStock.to') }}</FieldLabel>
          <input v-model="to" type="date" class="field" @change="frequency = 'custom'" />
        </div>
        <div>
          <FieldLabel icon="clock">{{ t('reports.storeStock.idleDays') }}</FieldLabel>
          <input v-model.number="idleDays" type="number" min="1" class="field field--narrow" />
        </div>
        <div>
          <FieldLabel icon="account">{{ t('reports.storeStock.recipient') }}</FieldLabel>
          <select v-model="recipient" class="field">
            <option value="store_manager">{{ t('reports.storeStock.recipients.store_manager') }}</option>
            <option value="director">{{ t('reports.storeStock.recipients.director') }}</option>
            <option value="accounting">{{ t('reports.storeStock.recipients.accounting') }}</option>
          </select>
        </div>
        <button type="button" class="btn-primary" :disabled="loading" @click="load">
          {{ t('reports.storeStock.apply') }}
        </button>
      </div>

      <section class="header-card">
        <div>
          <p class="header-card__kicker">{{ t('reports.storeStock.systemName') }}</p>
          <h2 class="header-card__title">{{ headerStore.name || t('org.allStores') }}</h2>
          <p class="header-card__meta">
            <span v-if="headerStore.code">{{ t('reports.storeStock.code') }} : {{ headerStore.code }}</span>
            <span v-if="headerStore.address">{{ headerStore.address }}</span>
            <span>{{ t('reports.storeStock.manager') }} : {{ headerStore.manager || '—' }}</span>
          </p>
        </div>
        <div class="header-card__period">
          <p>{{ t('reports.storeStock.periodValue', { from: from ? formatDate(from) : '—', to: to ? formatDate(to) : '—' }) }}</p>
          <p>{{ t('reports.storeStock.generatedAt') }} : {{ report?.generated_at ? formatDateTime(report.generated_at) : '—' }}</p>
          <p>{{ t('reports.storeStock.recipient') }} : {{ t(`reports.storeStock.recipients.${recipient}`) }}</p>
        </div>
      </section>

      <template v-if="activeTab === 'summary'">
        <div class="ss__kpis">
          <article class="kpi">
            <p class="kpi__label">{{ t('reports.storeStock.openingValue') }}</p>
            <p class="kpi__value">{{ safeMoney(summary?.opening_value) }}</p>
          </article>
          <article class="kpi">
            <p class="kpi__label">{{ t('reports.storeStock.closingValue') }}</p>
            <p class="kpi__value">{{ safeMoney(summary?.closing_value) }}</p>
          </article>
          <article class="kpi">
            <p class="kpi__label">{{ t('reports.storeStock.variation') }}</p>
            <p class="kpi__value" :class="variationClass">{{ safeMoney(summary?.variation_value) }}</p>
            <p class="kpi__meta" :class="variationClass">{{ signedPct(summary?.variation_pct) }}</p>
          </article>
          <article class="kpi">
            <p class="kpi__label">{{ t('reports.storeStock.references') }}</p>
            <p class="kpi__value">{{ summary?.skus_in_stock ?? 0 }}</p>
            <p class="kpi__meta">{{ summary?.references_count ?? 0 }} {{ t('reports.storeStock.tracked') }}</p>
          </article>
          <article class="kpi">
            <p class="kpi__label">{{ t('reports.storeStock.stockouts') }}</p>
            <p class="kpi__value kpi__value--danger">{{ summary?.stockouts ?? 0 }}</p>
          </article>
          <article class="kpi">
            <p class="kpi__label">{{ t('reports.storeStock.turnover') }}</p>
            <p class="kpi__value">{{ (summary?.turnover_rate ?? 0).toFixed(2) }}×</p>
          </article>
        </div>

        <div class="ss__grid">
          <section class="panel">
            <header class="panel__header">
              <h3 class="panel__title">{{ t('reports.storeStock.stockHealth') }}</h3>
            </header>
            <div v-if="stockHealth.some(r => r.count > 0)" class="donut-wrap">
              <div class="donut" :style="{ background: healthDonut }">
                <div class="donut__center">
                  <strong v-if="dominantHealth">{{ Math.round((dominantHealth.count / healthTotal) * 100) }}%</strong>
                  <span v-if="dominantHealth">{{ statusLabel(dominantHealth.label) }}</span>
                </div>
              </div>
              <ul class="donut-legend">
                <li v-for="row in stockHealth" :key="row.label">
                  <i class="dot" :style="{ background: healthColors[row.label] || '#64748b' }" />
                  <span>{{ statusLabel(row.label) }}</span>
                  <strong>{{ row.count }}</strong>
                </li>
              </ul>
            </div>
            <p v-else class="panel__empty">{{ t('org.empty') }}</p>
          </section>

          <section class="panel">
            <header class="panel__header">
              <h3 class="panel__title">{{ t('reports.storeStock.valueByCategory') }}</h3>
            </header>
            <div v-if="byCategory.length" class="bar-list">
              <div v-for="row in byCategory" :key="row.label" class="bar-list__row">
                <div class="bar-list__meta">
                  <span>{{ row.label }}</span>
                  <strong>{{ safeMoney(row.value) }}</strong>
                </div>
                <div class="bar-list__track">
                  <div class="bar-list__fill" :style="{ width: `${(row.value / categoryMax) * 100}%` }" />
                </div>
              </div>
            </div>
            <p v-else class="panel__empty">{{ t('org.empty') }}</p>
          </section>
        </div>
      </template>

      <template v-else-if="activeTab === 'stock'">
        <section v-for="group in byCategory" :key="group.label" class="panel panel--table">
          <header class="panel__header">
            <h3 class="panel__title">{{ group.label }}</h3>
            <strong class="panel__meta">{{ safeMoney(group.value) }}</strong>
          </header>
          <table class="table">
            <thead>
              <tr>
                <th>{{ t('reports.storeStock.sku') }}</th>
                <th>{{ t('products.name') }}</th>
                <th>{{ t('reports.storeStock.unit') }}</th>
                <th class="text-right">{{ t('reports.storeStock.openingQty') }}</th>
                <th class="text-right">{{ t('reports.storeStock.inbound') }}</th>
                <th class="text-right">{{ t('reports.storeStock.outbound') }}</th>
                <th class="text-right">{{ t('reports.storeStock.closingQty') }}</th>
                <th class="text-right">{{ t('reports.storeStock.minStock') }}</th>
                <th class="text-right">{{ t('reports.storeStock.maxStock') }}</th>
                <th>{{ t('reports.storeStock.statusCol') }}</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="row in group.items" :key="row.product_id">
                <td class="mono">{{ row.sku || '—' }}</td>
                <td>{{ row.name || '—' }}</td>
                <td>{{ row.unit || '—' }}</td>
                <td class="text-right">{{ row.opening_qty }}</td>
                <td class="text-right">{{ row.inbound_qty }}</td>
                <td class="text-right">{{ row.outbound_qty }}</td>
                <td class="text-right">{{ row.closing_qty }}</td>
                <td class="text-right">{{ row.min_stock }}</td>
                <td class="text-right">{{ row.max_stock }}</td>
                <td>
                  <span class="badge" :class="`badge--${row.status}`">{{ statusLabel(row.status) }}</span>
                </td>
              </tr>
            </tbody>
          </table>
        </section>
        <p v-if="!byCategory.length" class="panel__empty">{{ t('org.empty') }}</p>
      </template>

      <template v-else-if="activeTab === 'movements'">
        <div class="ss__grid">
          <section class="panel panel--table">
            <header class="panel__header">
              <h3 class="panel__title">{{ t('reports.storeStock.inboundList') }}</h3>
            </header>
            <table class="table">
              <thead>
                <tr>
                  <th>{{ t('inventory.date') }}</th>
                  <th>{{ t('products.name') }}</th>
                  <th>{{ t('reports.storeStock.supplier') }}</th>
                  <th class="text-right">{{ t('inventory.qtyShort') }}</th>
                  <th class="text-right">{{ t('reports.storeStock.unitPrice') }}</th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="(row, index) in report?.movements.inbound ?? []" :key="`in-${index}`">
                  <td>{{ row.occurred_at ? formatDate(row.occurred_at) : '—' }}</td>
                  <td>
                    <div class="product">
                      <strong>{{ row.name }}</strong>
                      <span class="mono">{{ row.sku }}</span>
                    </div>
                  </td>
                  <td>{{ row.supplier || movementLabel(row.type) }}</td>
                  <td class="text-right">{{ row.quantity }}</td>
                  <td class="text-right">{{ safeMoney(row.unit_cost) }}</td>
                </tr>
              </tbody>
            </table>
            <p v-if="!report?.movements.inbound.length" class="panel__empty">{{ t('org.empty') }}</p>
          </section>

          <section class="panel panel--table">
            <header class="panel__header">
              <h3 class="panel__title">{{ t('reports.storeStock.outboundList') }}</h3>
            </header>
            <table class="table">
              <thead>
                <tr>
                  <th>{{ t('inventory.date') }}</th>
                  <th>{{ t('products.name') }}</th>
                  <th>{{ t('reports.storeStock.reason') }}</th>
                  <th class="text-right">{{ t('inventory.qtyShort') }}</th>
                  <th class="text-right">{{ t('reports.storeStock.value') }}</th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="(row, index) in report?.movements.outbound ?? []" :key="`out-${index}`">
                  <td>{{ row.occurred_at ? formatDate(row.occurred_at) : '—' }}</td>
                  <td>
                    <div class="product">
                      <strong>{{ row.name }}</strong>
                      <span class="mono">{{ row.sku }}</span>
                    </div>
                  </td>
                  <td>{{ movementLabel(row.reason || row.type) }}</td>
                  <td class="text-right">{{ row.quantity }}</td>
                  <td class="text-right">{{ safeMoney(row.value) }}</td>
                </tr>
              </tbody>
            </table>
            <p v-if="!report?.movements.outbound.length" class="panel__empty">{{ t('org.empty') }}</p>
          </section>
        </div>

        <section class="panel panel--table">
          <header class="panel__header">
            <h3 class="panel__title">{{ t('reports.storeStock.transfers') }}</h3>
          </header>
          <table class="table">
            <thead>
              <tr>
                <th>{{ t('inventory.date') }}</th>
                <th>{{ t('products.name') }}</th>
                <th>{{ t('reports.storeStock.origin') }}</th>
                <th>{{ t('reports.storeStock.destination') }}</th>
                <th class="text-right">{{ t('inventory.qtyShort') }}</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="(row, index) in report?.movements.transfers ?? []" :key="`tr-${index}`">
                <td>{{ row.occurred_at ? formatDate(row.occurred_at) : '—' }}</td>
                <td>{{ row.name }} <span class="mono">{{ row.sku }}</span></td>
                <td>{{ row.origin || '—' }}</td>
                <td>{{ row.destination || '—' }}</td>
                <td class="text-right">{{ row.quantity }}</td>
              </tr>
            </tbody>
          </table>
          <p v-if="!report?.movements.transfers.length" class="panel__empty">{{ t('org.empty') }}</p>
        </section>

        <section class="panel panel--table">
          <header class="panel__header">
            <h3 class="panel__title">{{ t('reports.storeStock.adjustments') }}</h3>
          </header>
          <table class="table">
            <thead>
              <tr>
                <th>{{ t('inventory.date') }}</th>
                <th>{{ t('products.name') }}</th>
                <th>{{ t('inventory.movementType') }}</th>
                <th class="text-right">{{ t('inventory.qtyShort') }}</th>
                <th class="text-right">{{ t('reports.storeStock.value') }}</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="(row, index) in report?.movements.adjustments ?? []" :key="`adj-${index}`">
                <td>{{ row.occurred_at ? formatDate(row.occurred_at) : '—' }}</td>
                <td>{{ row.name }}</td>
                <td>{{ movementLabel(row.type) }}</td>
                <td class="text-right">{{ row.quantity }}</td>
                <td class="text-right">{{ safeMoney(row.value) }}</td>
              </tr>
            </tbody>
          </table>
          <p v-if="!report?.movements.adjustments.length" class="panel__empty">{{ t('org.empty') }}</p>
        </section>
      </template>

      <template v-else-if="activeTab === 'alerts'">
        <div class="ss__grid">
          <section class="panel panel--table">
            <header class="panel__header">
              <h3 class="panel__title">{{ t('reports.storeStock.outOfStock') }}</h3>
            </header>
            <table class="table">
              <tbody>
                <tr v-for="row in report?.alerts.out_of_stock ?? []" :key="`out-${row.product_id}`">
                  <td>{{ row.name }}</td>
                  <td class="mono">{{ row.sku }}</td>
                  <td class="text-right">{{ row.closing_qty }}</td>
                </tr>
              </tbody>
            </table>
            <p v-if="!report?.alerts.out_of_stock.length" class="panel__empty">{{ t('org.empty') }}</p>
          </section>
          <section class="panel panel--table">
            <header class="panel__header">
              <h3 class="panel__title">{{ t('reports.storeStock.belowMin') }}</h3>
            </header>
            <table class="table">
              <tbody>
                <tr v-for="row in report?.alerts.below_min ?? []" :key="`low-${row.product_id}`">
                  <td>{{ row.name }}</td>
                  <td class="text-right">{{ row.closing_qty }} / {{ row.min_stock }}</td>
                </tr>
              </tbody>
            </table>
            <p v-if="!report?.alerts.below_min.length" class="panel__empty">{{ t('org.empty') }}</p>
          </section>
        </div>
        <div class="ss__grid">
          <section class="panel panel--table">
            <header class="panel__header">
              <h3 class="panel__title">{{ t('reports.storeStock.overstock') }}</h3>
            </header>
            <table class="table">
              <tbody>
                <tr v-for="row in report?.alerts.overstock ?? []" :key="`over-${row.product_id}`">
                  <td>{{ row.name }}</td>
                  <td class="text-right">{{ row.closing_qty }} / {{ row.max_stock }}</td>
                </tr>
              </tbody>
            </table>
            <p v-if="!report?.alerts.overstock.length" class="panel__empty">{{ t('org.empty') }}</p>
          </section>
          <section class="panel panel--table">
            <header class="panel__header">
              <h3 class="panel__title">{{ t('reports.storeStock.expiring') }}</h3>
            </header>
            <table class="table">
              <thead>
                <tr>
                  <th>{{ t('products.name') }}</th>
                  <th>{{ t('inventory.batch') }}</th>
                  <th>{{ t('inventory.expires') }}</th>
                  <th class="text-right">{{ t('reports.storeStock.daysLeft') }}</th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="(row, index) in report?.alerts.expiring ?? []" :key="`exp-${index}`">
                  <td>{{ row.name }}</td>
                  <td>{{ row.batch || '—' }}</td>
                  <td :class="{ 'text-danger': row.expired }">{{ row.expires_at ? formatDate(row.expires_at) : '—' }}</td>
                  <td class="text-right" :class="{ 'text-danger': row.expired || (row.days_left != null && row.days_left <= 30) }">
                    {{ row.days_left ?? '—' }}
                  </td>
                </tr>
              </tbody>
            </table>
            <p v-if="!report?.alerts.expiring.length" class="panel__empty">{{ t('org.empty') }}</p>
          </section>
        </div>
        <section class="panel panel--table">
          <header class="panel__header">
            <h3 class="panel__title">{{ t('reports.storeStock.variances') }}</h3>
          </header>
          <table class="table">
            <thead>
              <tr>
                <th>{{ t('products.name') }}</th>
                <th>{{ t('reports.storeStock.countNumber') }}</th>
                <th class="text-right">{{ t('reports.storeStock.systemQty') }}</th>
                <th class="text-right">{{ t('reports.storeStock.countedQty') }}</th>
                <th class="text-right">{{ t('reports.storeStock.variance') }}</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="(row, index) in report?.alerts.count_variances ?? []" :key="`var-${index}`">
                <td>{{ row.name }}</td>
                <td>{{ row.count_number || '—' }}</td>
                <td class="text-right">{{ row.system_qty }}</td>
                <td class="text-right">{{ row.counted_qty }}</td>
                <td class="text-right" :class="{ 'text-danger': row.variance !== 0 }">{{ row.variance }}</td>
              </tr>
            </tbody>
          </table>
          <p v-if="!report?.alerts.count_variances.length" class="panel__empty">{{ t('org.empty') }}</p>
        </section>
      </template>

      <template v-else-if="activeTab === 'performance'">
        <article class="kpi kpi--wide">
          <p class="kpi__label">{{ t('reports.storeStock.serviceRate') }}</p>
          <p class="kpi__value">{{ (report?.performance.service_rate.rate ?? 0).toFixed(1) }}%</p>
          <p class="kpi__meta">
            {{ report?.performance.service_rate.fulfilled ?? 0 }} / {{ report?.performance.service_rate.total ?? 0 }}
          </p>
        </article>
        <div class="ss__grid">
          <section class="panel">
            <header class="panel__header">
              <h3 class="panel__title">{{ t('reports.storeStock.topSold') }}</h3>
            </header>
            <div v-if="topSold.length" class="bar-list">
              <div v-for="(row, index) in topSold" :key="`top-${index}`" class="bar-list__row">
                <div class="bar-list__meta">
                  <span>{{ index + 1 }}. {{ row.name }}</span>
                  <strong>{{ row.quantity }} · {{ safeMoney(row.revenue) }}</strong>
                </div>
                <div class="bar-list__track">
                  <div class="bar-list__fill" :style="{ width: `${(row.quantity / topSoldMax) * 100}%` }" />
                </div>
              </div>
            </div>
            <p v-else class="panel__empty">{{ t('org.empty') }}</p>
          </section>
          <section class="panel panel--table">
            <header class="panel__header">
              <h3 class="panel__title">{{ t('reports.storeStock.leastSold') }}</h3>
            </header>
            <table class="table">
              <tbody>
                <tr v-for="(row, index) in report?.performance.least_sold ?? []" :key="`least-${index}`">
                  <td>{{ row.name }}</td>
                  <td class="text-right">{{ row.quantity }}</td>
                  <td class="text-right">{{ safeMoney(row.revenue) }}</td>
                </tr>
              </tbody>
            </table>
            <p v-if="!report?.performance.least_sold.length" class="panel__empty">{{ t('org.empty') }}</p>
          </section>
        </div>
        <section class="panel panel--table">
          <header class="panel__header">
            <h3 class="panel__title">{{ t('reports.storeStock.noMovement', { days: report?.performance.idle_days ?? idleDays }) }}</h3>
          </header>
          <table class="table">
            <thead>
              <tr>
                <th>{{ t('products.name') }}</th>
                <th class="text-right">{{ t('reports.storeStock.closingQty') }}</th>
                <th class="text-right">{{ t('reports.storeStock.value') }}</th>
                <th>{{ t('reports.storeStock.lastMoved') }}</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="(row, index) in report?.performance.no_movement ?? []" :key="`idle-${index}`">
                <td>{{ row.name }}</td>
                <td class="text-right">{{ row.closing_qty }}</td>
                <td class="text-right">{{ safeMoney(row.closing_value) }}</td>
                <td>{{ row.last_moved_at ? formatDate(row.last_moved_at) : '—' }}</td>
              </tr>
            </tbody>
          </table>
          <p v-if="!report?.performance.no_movement.length" class="panel__empty">{{ t('org.empty') }}</p>
        </section>
      </template>

      <template v-else-if="activeTab === 'comparison'">
        <p v-if="report?.comparison.best_turnover_store" class="banner">
          {{ t('reports.storeStock.bestTurnover', { store: report.comparison.best_turnover_store }) }}
        </p>
        <section class="panel">
          <header class="panel__header">
            <h3 class="panel__title">{{ t('reports.storeStock.comparisonChart') }}</h3>
          </header>
          <div v-if="comparisonStores.length" class="warehouse">
            <div v-for="row in comparisonStores" :key="row.store_id" class="warehouse__col">
              <div class="warehouse__meta">
                <span class="warehouse__name">{{ row.store_name }}</span>
                <strong>{{ row.turnover_rate.toFixed(2) }}×</strong>
                <small>{{ safeMoney(row.closing_value) }}</small>
              </div>
              <div class="warehouse__track">
                <div class="warehouse__fill" :style="{ height: `${Math.max(6, (row.turnover_rate / comparisonMax) * 100)}%` }" />
              </div>
            </div>
          </div>
          <p v-else class="panel__empty">{{ t('org.empty') }}</p>
        </section>
        <section class="panel panel--table">
          <header class="panel__header">
            <h3 class="panel__title">{{ t('reports.storeStock.comparisonTable') }}</h3>
          </header>
          <table class="table">
            <thead>
              <tr>
                <th>{{ t('reports.storeStock.store') }}</th>
                <th class="text-right">{{ t('reports.storeStock.closingValue') }}</th>
                <th class="text-right">{{ t('reports.storeStock.references') }}</th>
                <th class="text-right">{{ t('reports.storeStock.stockouts') }}</th>
                <th class="text-right">{{ t('reports.storeStock.turnover') }}</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="row in comparisonStores" :key="row.store_id">
                <td>{{ row.store_name }} <span class="mono">{{ row.store_code }}</span></td>
                <td class="text-right">{{ safeMoney(row.closing_value) }}</td>
                <td class="text-right">{{ row.skus_in_stock }}</td>
                <td class="text-right">{{ row.stockouts }}</td>
                <td class="text-right">{{ row.turnover_rate.toFixed(2) }}×</td>
              </tr>
            </tbody>
          </table>
        </section>
        <section class="panel panel--table">
          <header class="panel__header">
            <h3 class="panel__title">{{ t('reports.storeStock.transferOpportunities') }}</h3>
          </header>
          <table class="table">
            <thead>
              <tr>
                <th>{{ t('products.name') }}</th>
                <th>{{ t('reports.storeStock.origin') }}</th>
                <th>{{ t('reports.storeStock.destination') }}</th>
                <th class="text-right">{{ t('inventory.qtyShort') }}</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="(row, index) in report?.comparison.transfer_opportunities ?? []" :key="`opp-${index}`">
                <td>{{ row.name }}</td>
                <td>{{ row.from_store }}</td>
                <td>{{ row.to_store }}</td>
                <td class="text-right">{{ row.quantity }}</td>
              </tr>
            </tbody>
          </table>
          <p v-if="!report?.comparison.transfer_opportunities.length" class="panel__empty">{{ t('org.empty') }}</p>
        </section>
      </template>

      <template v-else>
        <section class="panel panel--table">
          <header class="panel__header">
            <h3 class="panel__title">{{ t('reports.storeStock.reorderUrgent') }}</h3>
          </header>
          <table class="table">
            <thead>
              <tr>
                <th>{{ t('products.name') }}</th>
                <th>{{ t('reports.storeStock.statusCol') }}</th>
                <th class="text-right">{{ t('reports.storeStock.closingQty') }}</th>
                <th class="text-right">{{ t('reports.storeStock.suggestedQty') }}</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="(row, index) in report?.recommendations.reorder_urgent ?? []" :key="`reo-${index}`">
                <td>{{ row.name }}</td>
                <td><span class="badge" :class="`badge--${row.status}`">{{ statusLabel(row.status) }}</span></td>
                <td class="text-right">{{ row.closing_qty }}</td>
                <td class="text-right">{{ row.suggested_qty }}</td>
              </tr>
            </tbody>
          </table>
          <p v-if="!report?.recommendations.reorder_urgent.length" class="panel__empty">{{ t('org.empty') }}</p>
        </section>
        <section class="panel panel--table">
          <header class="panel__header">
            <h3 class="panel__title">{{ t('reports.storeStock.transferRecs') }}</h3>
          </header>
          <table class="table">
            <tbody>
              <tr v-for="(row, index) in report?.recommendations.transfer ?? []" :key="`trr-${index}`">
                <td>{{ row.name }}</td>
                <td>{{ row.from_store }} → {{ row.to_store }}</td>
                <td class="text-right">{{ row.quantity }}</td>
              </tr>
            </tbody>
          </table>
          <p v-if="!report?.recommendations.transfer.length" class="panel__empty">{{ t('org.empty') }}</p>
        </section>
        <section class="panel panel--table">
          <header class="panel__header">
            <h3 class="panel__title">{{ t('reports.storeStock.thresholdRecs') }}</h3>
          </header>
          <table class="table">
            <thead>
              <tr>
                <th>{{ t('products.name') }}</th>
                <th class="text-right">{{ t('reports.storeStock.minStock') }}</th>
                <th class="text-right">{{ t('reports.storeStock.suggestedMin') }}</th>
                <th class="text-right">{{ t('reports.storeStock.maxStock') }}</th>
                <th class="text-right">{{ t('reports.storeStock.suggestedMax') }}</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="(row, index) in report?.recommendations.threshold_adjustments ?? []" :key="`th-${index}`">
                <td>{{ row.name }}</td>
                <td class="text-right">{{ row.current_min }}</td>
                <td class="text-right">{{ row.suggested_min }}</td>
                <td class="text-right">{{ row.current_max }}</td>
                <td class="text-right">{{ row.suggested_max }}</td>
              </tr>
            </tbody>
          </table>
          <p v-if="!report?.recommendations.threshold_adjustments.length" class="panel__empty">{{ t('org.empty') }}</p>
        </section>
      </template>
    </div>
  </ReportsLayout>
</template>

<style scoped>
.ss { display: flex; flex-direction: column; gap: 1.1rem; }
.ss__chrome, .ss__actions, .ss__filters {
  display: flex; flex-wrap: wrap; gap: 0.65rem; align-items: flex-end;
}
.ss__chrome { justify-content: space-between; align-items: center; }
.ss__tabs {
  display: inline-flex; flex-wrap: nowrap; align-items: center; gap: 0.2rem;
  padding: 0.28rem; border: 1px solid #e2e8f0; border-radius: 0.95rem;
  background: #f8fafc;
  overflow-x: auto; max-width: 100%; scrollbar-width: none;
}
.ss__tabs::-webkit-scrollbar { display: none; }
.ss__tab {
  position: relative; display: inline-flex; align-items: center; gap: 0.45rem;
  border: 1px solid transparent; background: transparent; color: #64748b;
  font-size: 0.875rem; font-weight: 600; line-height: 1; padding: 0.62rem 0.95rem;
  border-radius: 0.72rem; white-space: nowrap; cursor: pointer;
}
.ss__tab:hover { color: #0f172a; background: rgba(255,255,255,0.7); }
.ss__tab-icon {
  display: inline-flex; align-items: center; justify-content: center;
  width: 1.35rem; height: 1.35rem; border-radius: 0.45rem; background: rgba(148,163,184,0.16);
}
.ss__tab.is-active {
  color: #0f766e; background: white; border-color: #ccfbf1;
  box-shadow: 0 1px 2px rgba(15,23,42,0.06), 0 4px 12px rgba(15,118,110,0.08);
}
.ss__tab.is-active .ss__tab-icon { background: #ecfdf5; color: #0f766e; }

.field--narrow { min-width: 6rem; max-width: 7rem; }
.btn-secondary {
  display: inline-flex; align-items: center; gap: 0.4rem; border-radius: 0.55rem;
  padding: 0.5rem 0.9rem; font-size: 0.875rem; font-weight: 500; cursor: pointer;
}

.btn-secondary { border: 1px solid #cbd5e1; background: white; color: #334155; }

.header-card {
  display: flex; flex-wrap: wrap; justify-content: space-between; gap: 1rem;
  border: 1px solid #ccfbf1; border-radius: 0.95rem; background: #f0fdfa; padding: 1.1rem 1.2rem;
}
.header-card__kicker { margin: 0; font-size: 0.72rem; font-weight: 700; letter-spacing: 0.06em; text-transform: uppercase; color: #0f766e; }
.header-card__title { margin: 0.25rem 0 0.4rem; font-size: 1.35rem; color: #0f172a; }
.header-card__meta, .header-card__period { display: flex; flex-direction: column; gap: 0.2rem; color: #475569; font-size: 0.85rem; }
.header-card__period { text-align: right; }
.ss__kpis { display: grid; grid-template-columns: repeat(auto-fill, minmax(150px, 1fr)); gap: 0.85rem; }
.kpi { border: 1px solid #e2e8f0; border-radius: 0.85rem; background: white; padding: 1rem 1.05rem; }
.kpi--wide { max-width: 22rem; }
.kpi__label { margin: 0; font-size: 0.75rem; font-weight: 600; letter-spacing: 0.02em; text-transform: uppercase; color: #64748b; }
.kpi__value { margin: 0.45rem 0 0; font-size: 1.35rem; font-weight: 700; color: #0f172a; }
.kpi__value--danger { color: #dc2626; }
.kpi__meta { margin: 0.3rem 0 0; font-size: 0.8rem; color: #64748b; }
.is-up { color: #059669 !important; }
.is-down { color: #dc2626 !important; }
.ss__grid { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 0.85rem; }
@media (max-width: 900px) { .ss__grid { grid-template-columns: 1fr; } }
.panel { border: 1px solid #e2e8f0; border-radius: 0.85rem; background: white; padding: 1rem 1.1rem 1.15rem; min-height: 160px; }
.panel--table { overflow: auto; }
.panel__header { display: flex; justify-content: space-between; gap: 0.5rem; margin-bottom: 0.85rem; }
.panel__title { margin: 0; font-size: 0.95rem; font-weight: 700; color: #0f172a; }
.panel__meta { font-size: 0.9rem; color: #0f766e; }
.panel__empty { margin: 1.5rem 0 0; text-align: center; color: #94a3b8; font-size: 0.9rem; }
.donut-wrap { display: flex; flex-wrap: wrap; gap: 1.25rem; align-items: center; }
.donut { position: relative; width: 9.5rem; height: 9.5rem; border-radius: 999px; flex-shrink: 0; }
.donut__center {
  position: absolute; inset: 1.55rem; border-radius: 999px; background: white;
  display: flex; flex-direction: column; align-items: center; justify-content: center; text-align: center; gap: 0.15rem;
}
.donut-legend { list-style: none; margin: 0; padding: 0; display: flex; flex-direction: column; gap: 0.45rem; flex: 1; }
.donut-legend li { display: grid; grid-template-columns: auto 1fr auto; gap: 0.5rem; align-items: center; font-size: 0.85rem; color: #475569; }
.dot { display: inline-block; width: 0.55rem; height: 0.55rem; border-radius: 999px; }
.bar-list { display: flex; flex-direction: column; gap: 0.7rem; }
.bar-list__meta { display: flex; justify-content: space-between; gap: 0.75rem; font-size: 0.82rem; color: #475569; margin-bottom: 0.25rem; }
.bar-list__track { height: 0.45rem; border-radius: 999px; background: #f1f5f9; overflow: hidden; }
.bar-list__fill { height: 100%; border-radius: 999px; background: #0f766e; }
.warehouse { display: grid; grid-template-columns: repeat(auto-fit, minmax(7rem, 1fr)); gap: 0.75rem; align-items: end; min-height: 180px; }
.warehouse__col { display: flex; flex-direction: column; gap: 0.55rem; height: 100%; }
.warehouse__meta { display: flex; flex-direction: column; gap: 0.15rem; font-size: 0.78rem; color: #64748b; }
.warehouse__name { font-weight: 600; color: #334155; }
.warehouse__track { flex: 1; min-height: 100px; display: flex; align-items: flex-end; background: #f8fafc; border-radius: 0.5rem; overflow: hidden; }
.warehouse__fill { width: 100%; background: #0f766e; border-radius: 0.5rem 0.5rem 0 0; }
.table { width: 100%; border-collapse: collapse; font-size: 0.85rem; }
.table th, .table td { padding: 0.65rem 0.55rem; border-bottom: 1px solid #f1f5f9; text-align: left; vertical-align: top; }
.table th { font-size: 0.72rem; text-transform: uppercase; letter-spacing: 0.03em; color: #64748b; font-weight: 600; }
.text-right { text-align: right !important; }
.text-danger { color: #dc2626; }
.product { display: flex; flex-direction: column; gap: 0.1rem; }
.mono { font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace; font-size: 0.75rem; color: #94a3b8; }
.badge { display: inline-flex; align-items: center; border-radius: 999px; padding: 0.15rem 0.55rem; font-size: 0.72rem; font-weight: 700; }
.badge--healthy { background: #ecfdf5; color: #047857; }
.badge--low { background: #fffbeb; color: #b45309; }
.badge--out { background: #fef2f2; color: #b91c1c; }
.badge--over { background: #eff6ff; color: #1d4ed8; }
.banner { margin: 0; padding: 0.75rem 1rem; border-radius: 0.75rem; background: #ecfdf5; color: #047857; font-weight: 600; }
@media (max-width: 720px) {
  .ss__chrome { flex-direction: column; align-items: stretch; }
  .ss__tabs { width: 100%; }
  .ss__actions .btn-secondary span { display: none; }
  .header-card__period { text-align: left; }
}
@media print {
  .ss__chrome, .ss__filters { display: none !important; }
}
</style>
