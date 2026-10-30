<script setup lang="ts">
import CountUp from '../../../components/motion/CountUp.vue'
import { computed, onMounted, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import { RouterLink } from 'vue-router'
import { extractApiErrorMessage } from '../../../api/client'
import AppIcon from '../../../components/ui/AppIcon.vue'
import LoadingBlock from '../../../components/ui/LoadingBlock.vue'
import { useBackofficeStore } from '../../../stores/backoffice'
import { useContextStore } from '../../../stores/context'
import type { InventoryReport } from '../../../types'
import { getAppCurrency } from '../../../utils/currency'
import { formatDate } from '../../../utils/format'
import { formatMoney } from '../../../utils/money'
import HotelChrome from './HotelChrome.vue'

const props = withDefaults(defineProps<{ variant?: 'page' | 'home' }>(), { variant: 'page' })

const { t, locale } = useI18n()
const store = useBackofficeStore()
const context = useContextStore()

const loading = ref(true)
const error = ref('')
const inventory = ref<InventoryReport | null>(null)
const monthSales = ref(0)
const prevSales = ref(0)
const openOrders = ref(0)
const trend = ref<{ key: string; label: string; revenue: number }[]>([])

const RING_RADIUS = 52
const RING = 2 * Math.PI * RING_RADIUS
const STORE_COLORS = ['#f5a524', '#818cf8', '#2dd4bf', '#f472b6', '#94a3b8']

const hotelName = computed(() =>
  context.currentStore?.branch?.company?.name
  || context.currentStore?.name
  || t('nav.hotel'),
)

const todayLabel = computed(() =>
  new Intl.DateTimeFormat(locale.value, { dateStyle: 'full' }).format(new Date()),
)

const catalogueCount = computed(() => store.stats?.products ?? inventory.value?.total_articles ?? 0)
const productsInStock = computed(() => inventory.value?.skus_in_stock ?? 0)
const stockValue = computed(() => inventory.value?.estimated_value ?? 0)
const totalUnits = computed(() => inventory.value?.total_units ?? 0)
const availableUnits = computed(() => inventory.value?.total_available ?? 0)
const outCount = computed(() => inventory.value?.out_of_stock_count ?? 0)
const lowCount = computed(() => (inventory.value?.low_stock_count ?? 0) + outCount.value)
const salesDelta = computed(() => deltaPct(monthSales.value, prevSales.value))
const storeCount = computed(() => inventory.value?.by_warehouse?.length ?? 0)

const kpis = computed(() => [
  {
    key: 'products',
    to: '/admin/inventory/stock',
    label: t('hotel.stock.productsInStock'),
    icon: 'products',
    tone: 'violet',
    value: productsInStock.value,
    format: 'integer' as const,
    sub: t('hotel.stock.ofCatalogue', { count: catalogueCount.value }),
  },
  {
    key: 'alerts',
    to: '/admin/inventory/alerts',
    label: t('hotel.stock.lowStockAlerts'),
    icon: 'bell',
    tone: lowCount.value ? 'danger' : 'green',
    value: lowCount.value,
    format: 'integer' as const,
    sub: t('hotel.stock.openAlerts', { count: outCount.value }),
  },
  {
    key: 'sales',
    to: '/admin/reports/sales',
    label: t('hotel.stock.monthlySales'),
    icon: 'sales',
    tone: 'teal',
    value: monthSales.value,
    format: 'money' as const,
    delta: salesDelta.value,
  },
  {
    key: 'orders',
    to: '/admin/purchases/orders',
    label: t('hotel.stock.activeOrders'),
    icon: 'purchases',
    tone: 'blue',
    value: openOrders.value,
    format: 'integer' as const,
    sub: t('hotel.stock.pendingOrders'),
  },
])

const status = computed(() => {
  const report = inventory.value
  const rows = [
    { key: 'healthy', label: t('hotel.stock.inStock'), count: report?.healthy_count ?? 0, color: 'var(--color-success)' },
    { key: 'low', label: t('hotel.stock.lowStock'), count: report?.low_stock_count ?? 0, color: 'var(--color-warning)' },
    { key: 'out', label: t('hotel.stock.outOfStock'), count: report?.out_of_stock_count ?? 0, color: 'var(--color-danger)' },
    { key: 'over', label: t('hotel.stock.overstock'), count: report?.overstock_count ?? 0, color: 'var(--color-info)' },
  ]
  const total = rows.reduce((sum, row) => sum + row.count, 0)
  const safe = Math.max(1, total)
  const visible = rows.filter(row => row.count > 0)
  const gap = visible.length > 1 ? 3 : 0
  let offset = 0
  const segments = visible.map(row => {
    const length = (row.count / safe) * RING
    const segment = {
      key: row.key,
      color: row.color,
      dash: `${Math.max(length - gap, 0.01)} ${RING}`,
      offset: -offset,
    }
    offset += length
    return segment
  })
  const healthy = rows[0].count
  const attention = rows[1].count + rows[2].count
  return {
    total,
    rows: rows.map(row => ({ ...row, pct: Math.round((row.count / safe) * 100) })),
    segments,
    healthPct: Math.round((healthy / safe) * 100),
    attention,
    critical: rows[2].count > 0,
  }
})

const storeSplit = computed(() => {
  const rows = (inventory.value?.by_warehouse ?? [])
    .map(row => ({ label: row.label, value: Number(row.value) || 0 }))
    .filter(row => row.value > 0)
  const total = rows.reduce((sum, row) => sum + row.value, 0)
  if (!total) return []
  const list = rows.slice(0, 4)
  const rest = rows.slice(4)
  if (rest.length) {
    list.push({ label: `+${rest.length}`, value: rest.reduce((sum, row) => sum + row.value, 0) })
  }
  return list.map((row, index) => ({
    ...row,
    pct: (row.value / total) * 100,
    color: STORE_COLORS[index % STORE_COLORS.length],
  }))
})

const categories = computed(() => {
  const all = (inventory.value?.by_category ?? []).map(row => ({
    label: row.label && row.label !== '—' ? row.label : t('reports.uncategorized'),
    value: Number(row.value) || 0,
    quantity: Number(row.quantity) || 0,
  }))
  const total = all.reduce((sum, row) => sum + row.value, 0)
  const rows = all.filter(row => row.value > 0).slice(0, 6)
  const max = Math.max(1, ...rows.map(row => row.value))
  return rows.map(row => ({
    ...row,
    pct: (row.value / max) * 100,
    share: total ? Math.round((row.value / total) * 100) : 0,
  }))
})

const alerts = computed(() => (inventory.value?.low_stock ?? []).slice(0, 6).map((row, index) => {
  const qty = Number(row.quantity_on_hand) || 0
  const threshold = Number(row.threshold) || 0
  const pct = qty <= 0 ? 0 : Math.min(100, Math.round((qty / Math.max(threshold, 1)) * 100))
  return {
    key: `${row.product_id}-${row.warehouse ?? index}`,
    name: row.name || '—',
    sku: row.sku || '—',
    place: row.warehouse || '—',
    qty,
    threshold,
    out: qty <= 0,
    pct,
  }
}))

const movements = computed(() => (inventory.value?.movements ?? []).slice(0, 6).map((row, index) => {
  const qty = Number(row.quantity) || 0
  return {
    key: `${row.sku}-${row.occurred_at}-${index}`,
    name: row.name || '—',
    type: movementLabel(row.type),
    place: row.warehouse || row.sku || '—',
    qty,
    direction: qty > 0 ? 'in' : qty < 0 ? 'out' : 'flat',
    date: formatDate(row.occurred_at),
  }
}))

const trendChart = computed(() => {
  const max = niceMax(Math.max(0, ...trend.value.map(row => row.revenue / 100)))
  const total = trend.value.reduce((sum, row) => sum + row.revenue, 0)
  return {
    ticks: [max, max * 0.75, max * 0.5, max * 0.25, 0],
    total,
    average: trend.value.length ? total / trend.value.length : 0,
    rows: trend.value.map((row, index) => ({
      ...row,
      pct: max ? (row.revenue / 100) / max : 0,
      current: index === trend.value.length - 1,
    })),
  }
})

const links = [
  { to: '/admin/inventory/stock', label: t('hotel.stock.links.products'), icon: 'products', tone: 'violet' },
  { to: '/admin/catalog/categories', label: t('hotel.stock.links.categories'), icon: 'layers', tone: 'amber' },
  { to: '/admin/inventory/transfers', label: t('hotel.stock.links.transfers'), icon: 'transfer', tone: 'blue' },
  { to: '/admin/inventory/counts', label: t('hotel.stock.links.counts'), icon: 'check', tone: 'green' },
  { to: '/admin/inventory/issues', label: t('hotel.stock.links.exits'), icon: 'upload', tone: 'coral' },
  { to: '/admin/suppliers', label: t('hotel.stock.links.suppliers'), icon: 'suppliers', tone: 'teal' },
  { to: '/admin/organization/stores', label: t('hotel.stock.links.warehouses'), icon: 'stores', tone: 'pink' },
  { to: '/admin/reports/inventory', label: t('hotel.stock.links.reports'), icon: 'dashboard', tone: 'navy' },
]

const subtitle = computed(() => `${hotelName.value} — ${t('hotel.stock.subtitle')}`)
const currency = computed(() => getAppCurrency())

async function load() {
  loading.value = true
  error.value = ''
  try {
    const current = monthBounds(0)
    const previous = monthBounds(-1)
    const year = last12Months()
    const [inventoryRes, salesRes, prevRes, yearRes, purchase] = await Promise.all([
      store.loadInventoryReport(),
      store.loadSalesReport({ from: current.from, to: current.to }),
      store.loadSalesReport({ from: previous.from, to: previous.to }),
      store.loadSalesReport({ from: year.from, to: year.to }),
      store.loadPurchaseOverview().catch(() => ({})),
      store.loadStats().catch(() => undefined),
    ])
    inventory.value = inventoryRes
    monthSales.value = salesRes.data.revenue ?? 0
    prevSales.value = prevRes.data.revenue ?? 0
    openOrders.value = Number((purchase as Record<string, unknown>).open_orders ?? 0)
    trend.value = fillTrend(yearRes.data.by_month ?? [])
  } catch (err) {
    error.value = extractApiErrorMessage(err)
  } finally {
    loading.value = false
  }
}

onMounted(load)

function localDate(date: Date) {
  const month = String(date.getMonth() + 1).padStart(2, '0')
  const day = String(date.getDate()).padStart(2, '0')
  return `${date.getFullYear()}-${month}-${day}`
}

function monthBounds(offset: number) {
  const now = new Date()
  const start = new Date(now.getFullYear(), now.getMonth() + offset, 1)
  const end = new Date(now.getFullYear(), now.getMonth() + offset + 1, 0)
  return { from: localDate(start), to: localDate(end) }
}

function last12Months() {
  const now = new Date()
  const start = new Date(now.getFullYear(), now.getMonth() - 11, 1)
  return { from: localDate(start), to: localDate(now) }
}

function fillTrend(rows: { label: string; revenue: number }[]) {
  const byKey = new Map(rows.map(row => [row.label.slice(0, 7), row.revenue]))
  const points = []
  const now = new Date()
  for (let i = 11; i >= 0; i -= 1) {
    const date = new Date(now.getFullYear(), now.getMonth() - i, 1)
    const key = `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}`
    points.push({
      key,
      label: date.toLocaleDateString(locale.value, { month: 'short' }),
      revenue: byKey.get(key) ?? rows.find(row => row.label.startsWith(key))?.revenue ?? 0,
    })
  }
  return points
}

function deltaPct(current: number, previous: number) {
  if (!previous) return current ? null : 0
  return Math.round(((current - previous) / previous) * 1000) / 10
}

function formatPct(value: number | null) {
  if (value == null) return '—'
  const body = new Intl.NumberFormat(locale.value, { maximumFractionDigits: 1 }).format(Math.abs(value))
  if (value > 0) return `+${body}%`
  if (value < 0) return `−${body}%`
  return `${body}%`
}

function deltaTone(value: number | null) {
  if (value == null || value === 0) return 'flat'
  return value > 0 ? 'up' : 'down'
}

function compactMoney(cents: number) {
  const value = (Number(cents) || 0) / 100
  const abs = Math.abs(value)
  if (abs >= 1_000_000) return `${(value / 1_000_000).toFixed(1)}M ${currency.value}`
  if (abs >= 1_000) return `${(value / 1_000).toFixed(1)}k ${currency.value}`
  return formatMoney(cents)
}

function compactAxis(value: number) {
  const abs = Math.abs(value)
  if (abs >= 1_000_000) return `${(value / 1_000_000).toFixed(1)}M`
  if (abs >= 1_000) return `${(value / 1_000).toFixed(1)}k`
  return new Intl.NumberFormat(locale.value, { maximumFractionDigits: 0 }).format(value)
}

function formatCount(value: number) {
  return new Intl.NumberFormat(locale.value).format(value)
}

function niceMax(value: number) {
  if (value <= 0) return 4
  const steps = 4
  const raw = value / steps
  const mag = 10 ** Math.floor(Math.log10(raw))
  const unit = [1, 2, 2.5, 5, 10].map(n => n * mag).find(n => n >= raw) ?? mag * 10
  return unit * steps
}

function movementLabel(type: string) {
  const map: Record<string, string> = {
    INITIAL_STOCK: 'initial',
    OPENING: 'opening',
    PURCHASE: 'purchase',
    SALE: 'sale',
    TRANSFER_IN: 'transferIn',
    TRANSFER_OUT: 'transferOut',
    ADJUSTMENT_IN: 'adjustmentIn',
    ADJUSTMENT_OUT: 'adjustmentOut',
  }
  const key = map[type.toUpperCase()] ?? type
  const path = `inventory.types.${key}`
  const translated = t(path)
  return translated === path ? type : translated
}

function qtyLabel(quantity: number) {
  const value = Number(quantity) || 0
  const sign = value > 0 ? '+' : ''
  return `${sign}${formatCount(value)}`
}
</script>

<template>
  <component
    :is="props.variant === 'home' ? 'div' : HotelChrome"
    v-bind="props.variant === 'home'
      ? { class: 'sd-home' }
      : { scrollBody: true, title: t('hotel.stock.title'), subtitle }"
  >
    <header v-if="props.variant === 'home'" class="sd-hero">
      <div class="sd-hero__id">
        <span class="sd-hero__mark" aria-hidden="true">
          <AppIcon name="inventory" :size="18" />
        </span>
        <div>
          <h2>{{ t('hotel.stock.title') }}</h2>
          <p>{{ t('hotel.stock.subtitle') }}</p>
        </div>
      </div>
      <button type="button" class="sd-hero__refresh" :disabled="loading" @click="load">
        <AppIcon name="recycle" :size="15" />
        {{ t('common.refresh') }}
      </button>
    </header>

    <div class="sd">
      <div v-if="props.variant !== 'home'" class="sd__toolbar">
        <p class="sd__date">
          <AppIcon name="calendar" :size="15" />
          {{ todayLabel }}
        </p>
        <div class="sd__actions">
          <button type="button" class="btn-secondary" :disabled="loading" @click="load">
            <AppIcon name="recycle" :size="15" />
            {{ t('common.refresh') }}
          </button>
          <RouterLink class="btn-primary" to="/admin/inventory/stock">
            <AppIcon name="inventory" :size="15" />
            {{ t('hotel.stock.openInventory') }}
          </RouterLink>
        </div>
      </div>

      <p v-if="error" class="sd__error" role="alert">
        <AppIcon name="alert" :size="16" />
        {{ error }}
      </p>
      <LoadingBlock v-else-if="loading && !inventory" variant="cards" :rows="6" :label="t('common.loading')" />

      <template v-else>
        <div class="sd-overview">
          <section class="sd-value" :aria-label="t('hotel.stock.stockValue')">
            <div class="sd-value__head">
              <span class="sd-value__icon" aria-hidden="true">
                <AppIcon name="coins" :size="18" />
              </span>
              <p class="sd-value__eyebrow">{{ t('hotel.stock.stockValue') }}</p>
            </div>
            <p class="sd-value__amount">
              <CountUp :value="stockValue" format="money" />
            </p>

            <dl class="sd-value__facts">
              <div>
                <dt>{{ t('hotel.stock.unitsOnHand') }}</dt>
                <dd><CountUp :value="totalUnits" /></dd>
              </div>
              <div>
                <dt>{{ t('hotel.stock.unitsAvailable') }}</dt>
                <dd><CountUp :value="availableUnits" /></dd>
              </div>
              <div>
                <dt>{{ t('hotel.stock.stores') }}</dt>
                <dd><CountUp :value="storeCount" /></dd>
              </div>
            </dl>

            <div v-if="storeSplit.length" class="sd-value__split">
              <p class="sd-value__label">{{ t('hotel.stock.valueByStore') }}</p>
              <div class="sd-value__bar" aria-hidden="true">
                <span
                  v-for="slice in storeSplit"
                  :key="slice.label"
                  :style="{ flexGrow: slice.pct, background: slice.color }"
                />
              </div>
              <ul class="sd-value__legend">
                <li v-for="slice in storeSplit" :key="slice.label">
                  <i :style="{ background: slice.color }" aria-hidden="true" />
                  <span>{{ slice.label }}</span>
                  <strong>{{ compactMoney(slice.value) }}</strong>
                </li>
              </ul>
            </div>
          </section>

          <section class="ui-card sd-health">
            <header class="ui-card__header">
              <div>
                <h3 class="ui-card__title">{{ t('hotel.stock.stockStatus') }}</h3>
                <p class="text-caption">
                  <CountUp :value="status.total" /> {{ t('hotel.stock.totalProducts').toLowerCase() }}
                </p>
              </div>
              <RouterLink to="/admin/inventory/stock" class="sd-link">
                {{ t('hotel.stock.viewAll') }}
                <AppIcon name="chevron-right" :size="14" />
              </RouterLink>
            </header>
            <div class="ui-card__body sd-health__body">
              <div class="sd-ring" role="img" :aria-label="`${t('hotel.stock.stockHealth')} · ${t('hotel.stock.healthy', { pct: status.healthPct })}`">
                <svg viewBox="0 0 128 128" aria-hidden="true">
                  <circle class="sd-ring__track" cx="64" cy="64" :r="RING_RADIUS" />
                  <circle
                    v-for="segment in status.segments"
                    :key="segment.key"
                    class="sd-ring__segment"
                    cx="64"
                    cy="64"
                    :r="RING_RADIUS"
                    :stroke="segment.color"
                    :stroke-dasharray="segment.dash"
                    :stroke-dashoffset="segment.offset"
                  />
                </svg>
                <div class="sd-ring__center">
                  <strong><CountUp :value="status.healthPct" suffix="%" /></strong>
                  <span>{{ t('hotel.stock.stockHealth') }}</span>
                </div>
              </div>

              <ul class="sd-status">
                <li v-for="row in status.rows" :key="row.key">
                  <span class="sd-status__dot" :style="{ background: row.color }" aria-hidden="true" />
                  <span class="sd-status__label">{{ row.label }}</span>
                  <strong><CountUp :value="row.count" /></strong>
                  <span class="sd-status__pct">{{ row.pct }}%</span>
                </li>
              </ul>
            </div>
            <RouterLink
              v-if="status.attention"
              to="/admin/inventory/alerts"
              class="sd-callout"
              :class="status.critical ? 'sd-callout--danger' : 'sd-callout--warning'"
            >
              <AppIcon name="alert" :size="16" />
              <span>{{ t('hotel.stock.needsAttention', { count: status.attention }) }}</span>
              <AppIcon name="chevron-right" :size="14" />
            </RouterLink>
            <p v-else class="sd-callout sd-callout--ok">
              <AppIcon name="check" :size="16" />
              <span>{{ t('hotel.stock.allHealthy') }}</span>
            </p>
          </section>
        </div>

        <section class="sd-kpis stagger-in">
          <RouterLink
            v-for="kpi in kpis"
            :key="kpi.key"
            :to="kpi.to"
            class="sd-kpi"
            :class="`sd-kpi--${kpi.tone}`"
          >
            <span class="sd-kpi__icon" aria-hidden="true">
              <AppIcon :name="kpi.icon" :size="18" />
            </span>
            <span class="sd-kpi__copy">
              <span class="sd-kpi__label">{{ kpi.label }}</span>
              <strong class="sd-kpi__value">
                <CountUp :value="kpi.value" :format="kpi.format" />
              </strong>
              <span v-if="kpi.key === 'sales'" class="sd-kpi__delta" :class="`sd-kpi__delta--${deltaTone(kpi.delta ?? null)}`">
                {{ formatPct(kpi.delta ?? null) }}
                <span>{{ t('hotel.stock.vsLastMonth') }}</span>
              </span>
              <span v-else class="sd-kpi__sub">{{ kpi.sub }}</span>
            </span>
          </RouterLink>
        </section>

        <div class="sd-grid">
          <section class="ui-card">
            <header class="ui-card__header">
              <div>
                <h3 class="ui-card__title">{{ t('hotel.stock.revenueTrend') }}</h3>
                <p class="text-caption">{{ t('hotel.stock.last12Months') }}</p>
              </div>
              <dl class="sd-trend-stats">
                <div>
                  <dt>{{ t('hotel.stock.total12Months') }}</dt>
                  <dd>{{ compactMoney(trendChart.total) }}</dd>
                </div>
                <div>
                  <dt>{{ t('hotel.stock.monthlyAverage') }}</dt>
                  <dd>{{ compactMoney(trendChart.average) }}</dd>
                </div>
              </dl>
            </header>
            <div class="ui-card__body">
              <div class="chart" role="img" :aria-label="t('hotel.stock.revenueTrend')">
                <div class="chart__y" aria-hidden="true">
                  <span v-for="(tick, index) in trendChart.ticks" :key="index">{{ compactAxis(tick) }}</span>
                </div>
                <div class="chart__plot">
                  <div class="chart__grid" aria-hidden="true">
                    <span v-for="index in 5" :key="index" />
                  </div>
                  <div
                    v-for="bar in trendChart.rows"
                    :key="bar.key"
                    class="chart__col"
                    :class="{ 'is-current': bar.current }"
                    :title="`${bar.label} · ${formatMoney(bar.revenue)}`"
                  >
                    <div class="chart__track">
                      <span class="chart__tip" :style="{ bottom: `${bar.pct * 100}%` }">{{ compactMoney(bar.revenue) }}</span>
                      <span class="chart__bar" :style="{ '--bar': bar.pct }" />
                    </div>
                    <span class="chart__label">{{ bar.label }}</span>
                  </div>
                </div>
              </div>
              <p class="chart__unit">{{ currency }}</p>
            </div>
          </section>

          <section class="ui-card">
            <header class="ui-card__header">
              <div>
                <h3 class="ui-card__title">{{ t('hotel.stock.valueByCategory') }}</h3>
                <p class="text-caption">{{ t('hotel.stock.topCategories') }}</p>
              </div>
              <RouterLink to="/admin/reports/inventory" class="sd-link">
                {{ t('hotel.stock.viewAll') }}
                <AppIcon name="chevron-right" :size="14" />
              </RouterLink>
            </header>
            <div class="ui-card__body">
              <p v-if="!categories.length" class="sd-empty">
                <AppIcon name="layers" :size="20" />
                {{ t('hotel.stock.emptyCategories') }}
              </p>
              <ul v-else class="cat-list">
                <li v-for="row in categories" :key="row.label">
                  <div class="cat-list__row">
                    <span class="cat-list__name">{{ row.label }}</span>
                    <strong>{{ compactMoney(row.value) }}</strong>
                  </div>
                  <span class="cat-list__track" aria-hidden="true">
                    <span :style="{ transform: `scaleX(${row.pct / 100})` }" />
                  </span>
                  <span class="cat-list__meta">
                    {{ formatCount(row.quantity) }} {{ t('hotel.stock.unitsOnHand').toLowerCase() }} · {{ row.share }}%
                  </span>
                </li>
              </ul>
            </div>
          </section>
        </div>

        <div class="sd-grid sd-grid--even">
          <section class="ui-card">
            <header class="ui-card__header">
              <div>
                <h3 class="ui-card__title">{{ t('hotel.stock.alertsTitle') }}</h3>
                <p class="text-caption">{{ t('hotel.stock.alertCount', { count: lowCount }) }}</p>
              </div>
              <RouterLink to="/admin/inventory/alerts" class="sd-link">
                {{ t('hotel.stock.viewAll') }}
                <AppIcon name="chevron-right" :size="14" />
              </RouterLink>
            </header>
            <div class="ui-card__body">
              <p v-if="!alerts.length" class="sd-empty">
                <AppIcon name="check" :size="20" />
                {{ t('hotel.stock.emptyAlerts') }}
              </p>
              <ul v-else class="row-list">
                <li v-for="item in alerts" :key="item.key">
                  <span class="row-list__icon" :class="item.out ? 'is-danger' : 'is-warning'" aria-hidden="true">
                    <AppIcon name="alert" :size="16" />
                  </span>
                  <div class="row-list__copy">
                    <strong>{{ item.name }}</strong>
                    <span>{{ item.sku }} · {{ item.place }}</span>
                    <span class="row-list__meter" aria-hidden="true">
                      <span :class="item.out ? 'is-danger' : 'is-warning'" :style="{ transform: `scaleX(${item.pct / 100})` }" />
                    </span>
                  </div>
                  <div class="row-list__side">
                    <strong>
                      {{ formatCount(item.qty) }}<small v-if="item.threshold"> / {{ formatCount(item.threshold) }}</small>
                    </strong>
                    <span class="chip" :class="item.out ? 'chip--danger' : 'chip--warning'">
                      {{ item.out ? t('hotel.stock.outOfStock') : t('hotel.stock.lowStock') }}
                    </span>
                  </div>
                </li>
              </ul>
            </div>
          </section>

          <section class="ui-card">
            <header class="ui-card__header">
              <h3 class="ui-card__title">{{ t('hotel.stock.recentMovements') }}</h3>
              <RouterLink to="/admin/inventory/adjustments" class="sd-link">
                {{ t('hotel.stock.viewAll') }}
                <AppIcon name="chevron-right" :size="14" />
              </RouterLink>
            </header>
            <div class="ui-card__body">
              <p v-if="!movements.length" class="sd-empty">
                <AppIcon name="transfer" :size="20" />
                {{ t('hotel.stock.emptyMovements') }}
              </p>
              <ul v-else class="row-list">
                <li v-for="row in movements" :key="row.key">
                  <span class="row-list__icon" :class="`is-${row.direction}`" aria-hidden="true">
                    <AppIcon :name="row.direction === 'in' ? 'import' : row.direction === 'out' ? 'upload' : 'adjust'" :size="16" />
                  </span>
                  <div class="row-list__copy">
                    <strong>{{ row.name }}</strong>
                    <span>{{ row.type }} · {{ row.place }}</span>
                  </div>
                  <div class="row-list__side">
                    <strong class="row-list__qty" :class="`is-${row.direction}`">{{ qtyLabel(row.qty) }}</strong>
                    <span>{{ row.date }}</span>
                  </div>
                </li>
              </ul>
            </div>
          </section>
        </div>

        <section class="sd-nav">
          <h3 class="text-section-title">{{ t('hotel.stock.quickNav') }}</h3>
          <div class="sd-links stagger-in">
            <RouterLink
              v-for="link in links"
              :key="link.to"
              :to="link.to"
              class="sd-tile"
              :class="`sd-tile--${link.tone}`"
            >
              <span class="sd-tile__icon" aria-hidden="true">
                <AppIcon :name="link.icon" :size="18" />
              </span>
              <span class="sd-tile__title">{{ link.label }}</span>
              <AppIcon class="sd-tile__arrow" name="chevron-right" :size="16" />
            </RouterLink>
          </div>
        </section>
      </template>
    </div>
  </component>
</template>

<style scoped>
.sd {
  --sd-violet: #6366f1;
  --sd-amber: #ea8a12;
  --sd-coral: #f0643f;
  --sd-pink: #e8478f;
  --sd-green: #10a36b;
  --sd-blue: #2f6fed;
  --sd-teal: #0f9f8f;
  --sd-navy: var(--color-brand-600);
  --sd-danger: var(--color-danger);

  display: flex;
  flex-direction: column;
  gap: var(--section-gap);
}

/* ─── Home variant header ─────────────────────────────────────────── */
.sd-hero,
.sd-hero__id {
  display: flex;
  align-items: center;
  gap: 0.85rem;
}

.sd-hero {
  flex-wrap: wrap;
  justify-content: space-between;
  gap: var(--space-4);
  margin-bottom: var(--space-6);
  animation: bright-slide-up var(--motion-slow) var(--ease-out) backwards;
}

.sd-hero__mark {
  display: grid;
  flex-shrink: 0;
  place-items: center;
  width: 48px;
  height: 48px;
  border-radius: var(--radius-lg);
  background: linear-gradient(135deg, var(--color-brand-50), var(--color-brand-100));
  color: var(--color-brand-700);
  box-shadow: inset 0 0 0 1px var(--color-brand-100);
}

.sd-hero h2 {
  margin: 0;
  color: var(--color-text-primary);
  font-family: var(--font-display);
  font-size: clamp(1.375rem, 1.1rem + 1vw, 1.75rem);
  font-weight: 700;
  letter-spacing: -0.025em;
  line-height: 1.2;
}

.sd-hero p {
  max-width: 65ch;
  margin: var(--space-1) 0 0;
  color: var(--color-text-muted);
  font-size: var(--text-base);
  line-height: 1.6;
}

.sd-hero__refresh {
  display: inline-flex;
  align-items: center;
  gap: var(--space-2);
  min-height: var(--touch-min);
  padding: 0 var(--space-4);
  border: 1px solid var(--color-border-strong);
  border-radius: var(--radius-md);
  background: var(--color-surface);
  color: var(--color-text-secondary);
  font-size: var(--text-sm);
  font-weight: 600;
  box-shadow: var(--shadow-xs);
  cursor: pointer;
  transition:
    background-color var(--motion-fast) var(--ease-out),
    border-color var(--motion-fast) var(--ease-out),
    color var(--motion-fast) var(--ease-out),
    transform var(--motion-normal) var(--ease-out);
}

.sd-hero__refresh:hover:not(:disabled) {
  border-color: var(--color-brand-300);
  background: var(--color-brand-50);
  color: var(--color-ink-brand);
  transform: var(--lift);
}

.sd-hero__refresh:focus-visible {
  outline: 2px solid var(--color-brand-600);
  outline-offset: 2px;
  box-shadow: 0 0 0 4px var(--color-focus-ring);
}

/* ─── Toolbar ─────────────────────────────────────────────────────── */
.sd__toolbar {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  justify-content: space-between;
  gap: var(--space-3);
}

.sd__date {
  display: inline-flex;
  align-items: center;
  gap: var(--space-2);
  margin: 0;
  color: var(--color-text-muted);
  font-size: var(--text-sm);
  font-weight: 500;
  text-transform: capitalize;
}

.sd__actions {
  display: flex;
  flex-wrap: wrap;
  gap: var(--space-2);
}

.sd__error {
  display: flex;
  align-items: center;
  gap: var(--space-2);
  margin: 0;
  padding: var(--space-3) var(--space-4);
  border: 1px solid color-mix(in srgb, var(--color-danger) 25%, transparent);
  border-radius: var(--radius-md);
  background: var(--color-danger-bg);
  color: var(--color-danger);
  font-size: var(--text-sm);
  font-weight: 500;
}

.sd-empty {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: var(--space-2);
  margin: 0;
  padding: var(--space-8) var(--space-4);
  color: var(--color-text-muted);
  font-size: var(--text-sm);
  text-align: center;
}

.sd-empty :deep(svg) {
  color: var(--color-text-faint);
}

.sd-link {
  display: inline-flex;
  flex-shrink: 0;
  align-items: center;
  gap: var(--space-1);
  color: var(--color-ink-brand, var(--color-brand-700));
  font-size: var(--text-sm);
  font-weight: 600;
  text-decoration: none;
  transition: color var(--motion-fast) var(--ease-in-out);
}

.sd-link:hover {
  color: var(--color-ink-brand, var(--color-brand-800));
  text-decoration: underline;
  text-underline-offset: 3px;
}

/* ─── Overview: value hero + health ───────────────────────────────── */
.sd-overview {
  display: grid;
  grid-template-columns: minmax(0, 1.25fr) minmax(0, 1fr);
  gap: var(--card-gap);
  align-items: stretch;
}

.sd-value {
  position: relative;
  display: flex;
  flex-direction: column;
  gap: var(--space-5);
  min-width: 0;
  padding: var(--space-6);
  overflow: hidden;
  border-radius: 24px;
  background: var(--color-brand-500);
  color: #fff;
  box-shadow: var(--shadow-md);
  animation: bright-slide-up var(--motion-slow) var(--ease-out) backwards;
}

.sd-value__head {
  display: flex;
  align-items: center;
  gap: var(--space-3);
}

.sd-value__icon {
  display: grid;
  place-items: center;
  width: 40px;
  height: 40px;
  border-radius: var(--radius-md);
  background: rgba(255, 255, 255, 0.12);
  color: #f5c46b;
  box-shadow: inset 0 0 0 1px rgba(255, 255, 255, 0.14);
}

.sd-value__eyebrow,
.sd-value__label {
  margin: 0;
  color: rgba(255, 255, 255, 0.78);
  font-size: var(--text-sm);
  font-weight: 600;
}

.sd-value__amount {
  margin: calc(var(--space-2) * -1) 0 0;
  font-family: var(--font-display);
  font-size: clamp(1.875rem, 1.3rem + 2vw, 2.625rem);
  font-weight: 700;
  letter-spacing: -0.03em;
  line-height: 1.1;
  font-variant-numeric: tabular-nums;
}

.sd-value__facts {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: var(--space-3);
  margin: 0;
}

.sd-value__facts div {
  padding: var(--space-3);
  border-radius: var(--radius-md);
  background: rgba(255, 255, 255, 0.08);
  box-shadow: inset 0 0 0 1px rgba(255, 255, 255, 0.1);
}

.sd-value__facts dt {
  color: rgba(255, 255, 255, 0.7);
  font-size: var(--text-2xs);
  font-weight: 600;
  letter-spacing: 0.02em;
  text-transform: uppercase;
}

.sd-value__facts dd {
  margin: var(--space-1) 0 0;
  font-size: var(--text-md);
  font-weight: 700;
  font-variant-numeric: tabular-nums;
}

.sd-value__split {
  display: flex;
  flex-direction: column;
  gap: var(--space-3);
  margin-top: auto;
}

.sd-value__bar {
  display: flex;
  gap: 3px;
  height: 10px;
  overflow: hidden;
  border-radius: 999px;
  background: rgba(255, 255, 255, 0.1);
}

.sd-value__bar span {
  flex-basis: 0;
  min-width: 4px;
  border-radius: 999px;
}

.sd-value__legend {
  display: flex;
  flex-wrap: wrap;
  gap: var(--space-2) var(--space-5);
  margin: 0;
  padding: 0;
  list-style: none;
  font-size: var(--text-xs);
}

.sd-value__legend li {
  display: inline-flex;
  align-items: center;
  gap: var(--space-2);
  min-width: 0;
  color: rgba(255, 255, 255, 0.8);
}

.sd-value__legend i {
  flex-shrink: 0;
  width: 8px;
  height: 8px;
  border-radius: 999px;
}

.sd-value__legend span {
  overflow: hidden;
  max-width: 14ch;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.sd-value__legend strong {
  color: #fff;
  font-variant-numeric: tabular-nums;
}

.sd-health {
  display: flex;
  flex-direction: column;
  min-width: 0;
}

.sd-health__body {
  display: grid;
  grid-template-columns: 148px minmax(0, 1fr);
  gap: var(--space-6);
  align-items: center;
  flex: 1;
}

.sd-ring {
  position: relative;
  width: 148px;
  aspect-ratio: 1;
}

.sd-ring svg {
  width: 100%;
  height: 100%;
  transform: rotate(-90deg);
}

.sd-ring circle {
  fill: none;
  stroke-width: 14;
}

.sd-ring__track {
  stroke: var(--color-surface-muted, var(--color-table-header));
}

.sd-ring__segment {
  stroke-linecap: butt;
  transition: stroke-dasharray var(--motion-slow) var(--ease-out), stroke-dashoffset var(--motion-slow) var(--ease-out);
}

.sd-ring__center {
  position: absolute;
  inset: 0;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  text-align: center;
}

.sd-ring__center strong {
  color: var(--color-text-primary);
  font-family: var(--font-display);
  font-size: 1.75rem;
  font-weight: 700;
  letter-spacing: -0.02em;
  line-height: 1;
}

.sd-ring__center > span {
  max-width: 10ch;
  margin-top: var(--space-1);
  color: var(--color-text-muted);
  font-size: var(--text-2xs);
  font-weight: 600;
  line-height: 1.3;
}

.sd-status {
  display: flex;
  flex-direction: column;
  margin: 0;
  padding: 0;
  list-style: none;
}

.sd-status li {
  display: grid;
  grid-template-columns: auto minmax(0, 1fr) auto 3.25rem;
  gap: var(--space-3);
  align-items: center;
  min-height: 42px;
  font-size: var(--text-sm);
}

.sd-status li + li {
  border-top: 1px solid var(--color-table-border, var(--color-border));
}

.sd-status__dot {
  width: 10px;
  height: 10px;
  border-radius: 3px;
}

.sd-status__label {
  overflow: hidden;
  color: var(--color-text-secondary);
  text-overflow: ellipsis;
  white-space: nowrap;
}

.sd-status strong {
  color: var(--color-text-primary);
  font-variant-numeric: tabular-nums;
}

.sd-status__pct {
  color: var(--color-text-faint);
  font-size: var(--text-xs);
  font-variant-numeric: tabular-nums;
  text-align: right;
}

.sd-callout {
  display: flex;
  align-items: center;
  gap: var(--space-2);
  margin: 0 var(--space-5) var(--space-5);
  padding: var(--space-3) var(--space-4);
  border-radius: var(--radius-md);
  font-size: var(--text-sm);
  font-weight: 600;
  text-decoration: none;
}

.sd-callout span {
  flex: 1;
}

.sd-callout--danger {
  background: var(--color-danger-bg);
  color: var(--color-danger);
}

.sd-callout--warning {
  background: var(--color-warning-bg);
  color: var(--color-warning);
}

.sd-callout--ok {
  background: var(--color-success-bg);
  color: var(--color-success);
}

a.sd-callout {
  transition: filter var(--motion-fast) var(--ease-out);
}

a.sd-callout:hover {
  filter: brightness(0.97);
}

/* ─── KPI strip ───────────────────────────────────────────────────── */
.sd-kpis {
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  gap: var(--card-gap);
}

.sd-kpi {
  --tone: var(--sd-navy);
  display: flex;
  align-items: flex-start;
  gap: var(--space-4);
  min-width: 0;
  padding: var(--space-5);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-xl);
  background: var(--color-surface);
  background-image: var(--gradient-card);
  box-shadow: var(--shadow-sm);
  color: inherit;
  text-decoration: none;
  transition:
    box-shadow var(--motion-normal) var(--ease-out),
    border-color var(--motion-normal) var(--ease-out),
    transform var(--motion-normal) var(--ease-out);
}

.sd-kpi:hover {
  border-color: color-mix(in srgb, var(--tone) 35%, var(--color-border));
  box-shadow: var(--shadow-md);
  transform: var(--lift);
}

.sd-kpi:focus-visible,
.sd-tile:focus-visible,
.sd-callout:focus-visible {
  outline: 2px solid var(--color-brand-600);
  outline-offset: 2px;
}

.sd-kpi--violet { --tone: var(--sd-violet); }
.sd-kpi--danger { --tone: var(--sd-danger); }
.sd-kpi--green { --tone: var(--sd-green); }
.sd-kpi--teal { --tone: var(--sd-teal); }
.sd-kpi--blue { --tone: var(--sd-blue); }

.sd-kpi__icon {
  display: grid;
  flex-shrink: 0;
  place-items: center;
  width: 42px;
  height: 42px;
  border-radius: var(--radius-md);
  background: var(--tone);
  color: #fff;
  box-shadow: 0 6px 14px -6px color-mix(in srgb, var(--tone) 70%, transparent);
}

.sd-kpi__copy {
  display: flex;
  flex-direction: column;
  gap: 2px;
  min-width: 0;
}

.sd-kpi__label {
  color: var(--color-text-muted);
  font-size: var(--text-xs);
  font-weight: 600;
}

.sd-kpi__value {
  overflow: hidden;
  color: var(--color-text-primary);
  font-family: var(--font-display);
  font-size: 1.5rem;
  font-weight: 700;
  letter-spacing: -0.02em;
  line-height: 1.25;
  text-overflow: ellipsis;
  white-space: nowrap;
  font-variant-numeric: tabular-nums;
}

.sd-kpi__sub,
.sd-kpi__delta span {
  color: var(--color-text-faint);
  font-size: var(--text-2xs);
  font-weight: 500;
}

.sd-kpi__delta {
  display: inline-flex;
  flex-wrap: wrap;
  align-items: baseline;
  gap: var(--space-1);
  font-size: var(--text-2xs);
  font-weight: 700;
}

.sd-kpi__delta--up { color: var(--color-success); }
.sd-kpi__delta--down { color: var(--color-danger); }
.sd-kpi__delta--flat { color: var(--color-text-muted); }

/* ─── Grids ───────────────────────────────────────────────────────── */
.sd-grid {
  display: grid;
  grid-template-columns: minmax(0, 1.5fr) minmax(0, 1fr);
  gap: var(--card-gap);
  align-items: stretch;
}

.sd-grid--even {
  grid-template-columns: repeat(2, minmax(0, 1fr));
}

.sd-grid > .ui-card {
  min-width: 0;
}

/* ─── Revenue chart ───────────────────────────────────────────────── */
.sd-trend-stats {
  display: flex;
  gap: var(--space-5);
  margin: 0;
  text-align: right;
}

.sd-trend-stats dt {
  color: var(--color-text-faint);
  font-size: var(--text-2xs);
  font-weight: 600;
}

.sd-trend-stats dd {
  margin: 2px 0 0;
  color: var(--color-text-primary);
  font-size: var(--text-sm);
  font-weight: 700;
  font-variant-numeric: tabular-nums;
}

.chart {
  --chart-h: 200px;
  display: grid;
  grid-template-columns: 3rem minmax(0, 1fr);
  gap: var(--space-3);
  align-items: start;
  padding-top: var(--space-6);
}

.chart__y {
  display: flex;
  flex-direction: column;
  justify-content: space-between;
  height: var(--chart-h);
  margin-top: -0.45em;
  margin-bottom: 0.45em;
  color: var(--color-text-faint);
  font-size: 11px;
  font-weight: 600;
  text-align: right;
  font-variant-numeric: tabular-nums;
}

.chart__plot {
  position: relative;
  display: grid;
  grid-auto-flow: column;
  grid-auto-columns: minmax(0, 1fr);
  gap: clamp(4px, 1vw, 10px);
  align-items: end;
}

.chart__grid {
  position: absolute;
  inset: 0 0 auto;
  display: flex;
  flex-direction: column;
  justify-content: space-between;
  height: var(--chart-h);
  pointer-events: none;
}

.chart__grid span {
  height: 1px;
  background: var(--color-table-border, var(--color-border));
}

.chart__grid span:last-child {
  background: var(--color-border-strong);
}

.chart__col {
  position: relative;
  z-index: 1;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: var(--space-2);
  min-width: 0;
}

.chart__track {
  position: relative;
  display: flex;
  align-items: flex-end;
  justify-content: center;
  width: 100%;
  height: var(--chart-h);
}

.chart__bar {
  display: block;
  width: min(100%, 36px);
  height: 100%;
  border-radius: 8px 8px 3px 3px;
  background: color-mix(in srgb, var(--color-brand-600) 40%, transparent);
  transform: scaleY(var(--bar, 0));
  transform-origin: bottom;
  transition: background var(--motion-fast) var(--ease-out);
  animation: bar-in var(--motion-chart, 600ms) var(--ease-out) both;
}

.chart__col:hover .chart__bar {
  background: var(--color-brand-600);
}

.chart__col.is-current .chart__bar {
  background: var(--color-accent, #f5a524);
}

.chart__tip {
  position: absolute;
  left: 50%;
  z-index: 2;
  padding: 3px 8px;
  border-radius: 6px;
  background: var(--color-text-primary);
  color: var(--color-surface);
  font-size: 11px;
  font-weight: 700;
  white-space: nowrap;
  opacity: 0;
  pointer-events: none;
  transform: translate(-50%, -4px);
  transition: opacity var(--motion-fast) var(--ease-out), transform var(--motion-fast) var(--ease-out);
}

.chart__col:hover .chart__tip {
  opacity: 1;
  transform: translate(-50%, -10px);
}

.chart__label {
  color: var(--color-text-faint);
  font-size: 11px;
  font-weight: 600;
  text-transform: capitalize;
}

.chart__col.is-current .chart__label {
  color: var(--color-text-primary);
}

.chart__unit {
  margin: var(--space-2) 0 0;
  color: var(--color-text-faint);
  font-size: 11px;
  font-weight: 600;
}

.chart__col:nth-child(2) .chart__bar { animation-delay: 30ms; }
.chart__col:nth-child(3) .chart__bar { animation-delay: 50ms; }
.chart__col:nth-child(4) .chart__bar { animation-delay: 70ms; }
.chart__col:nth-child(5) .chart__bar { animation-delay: 90ms; }
.chart__col:nth-child(6) .chart__bar { animation-delay: 110ms; }
.chart__col:nth-child(7) .chart__bar { animation-delay: 130ms; }
.chart__col:nth-child(8) .chart__bar { animation-delay: 150ms; }
.chart__col:nth-child(9) .chart__bar { animation-delay: 170ms; }
.chart__col:nth-child(10) .chart__bar { animation-delay: 190ms; }
.chart__col:nth-child(11) .chart__bar { animation-delay: 210ms; }
.chart__col:nth-child(12) .chart__bar { animation-delay: 230ms; }
.chart__col:nth-child(13) .chart__bar { animation-delay: 250ms; }

@keyframes bar-in {
  from { transform: scaleY(0); }
}

/* ─── Category bars ───────────────────────────────────────────────── */
.cat-list {
  display: flex;
  flex-direction: column;
  gap: var(--space-4);
  margin: 0;
  padding: 0;
  list-style: none;
}

.cat-list li {
  display: flex;
  flex-direction: column;
  gap: 6px;
}

.cat-list__row {
  display: flex;
  align-items: baseline;
  justify-content: space-between;
  gap: var(--space-3);
  font-size: var(--text-sm);
}

.cat-list__name {
  overflow: hidden;
  color: var(--color-text-secondary);
  font-weight: 600;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.cat-list__row strong {
  flex-shrink: 0;
  color: var(--color-text-primary);
  font-variant-numeric: tabular-nums;
}

.cat-list__track {
  display: block;
  height: 8px;
  overflow: hidden;
  border-radius: 999px;
  background: var(--color-surface-muted, var(--color-table-header));
}

.cat-list__track span {
  display: block;
  width: 100%;
  height: 100%;
  border-radius: inherit;
  background: linear-gradient(90deg, var(--sd-violet), #8b8ef8);
  transform-origin: left;
  transition: transform var(--motion-slow) var(--ease-out);
}

.cat-list li:nth-child(2) .cat-list__track span { background: linear-gradient(90deg, var(--sd-teal), #3cc4b5); }
.cat-list li:nth-child(3) .cat-list__track span { background: linear-gradient(90deg, var(--sd-amber), #f5b04f); }
.cat-list li:nth-child(4) .cat-list__track span { background: linear-gradient(90deg, var(--sd-pink), #f17bb0); }
.cat-list li:nth-child(5) .cat-list__track span { background: linear-gradient(90deg, var(--sd-blue), #6b97f3); }
.cat-list li:nth-child(6) .cat-list__track span { background: linear-gradient(90deg, var(--sd-coral), #f58f72); }

.cat-list__meta {
  color: var(--color-text-faint);
  font-size: var(--text-2xs);
  font-variant-numeric: tabular-nums;
}

/* ─── Alert + movement rows ───────────────────────────────────────── */
.row-list {
  display: flex;
  flex-direction: column;
  margin: calc(var(--space-2) * -1) 0;
  padding: 0;
  list-style: none;
}

.row-list li {
  display: grid;
  grid-template-columns: auto minmax(0, 1fr) auto;
  gap: var(--space-3);
  align-items: center;
  padding: var(--space-3) 0;
}

.row-list li + li {
  border-top: 1px solid var(--color-table-border, var(--color-border));
}

.row-list__icon {
  display: grid;
  place-items: center;
  width: 36px;
  height: 36px;
  border-radius: var(--radius-md);
  background: var(--color-surface-muted, var(--color-table-header));
  color: var(--color-text-muted);
}

.row-list__icon.is-danger,
.row-list__icon.is-out {
  background: var(--color-danger-bg);
  color: var(--color-danger);
}

.row-list__icon.is-warning {
  background: var(--color-warning-bg);
  color: var(--color-warning);
}

.row-list__icon.is-in {
  background: var(--color-success-bg);
  color: var(--color-success);
}

.row-list__copy {
  display: flex;
  flex-direction: column;
  gap: 2px;
  min-width: 0;
}

.row-list__copy strong {
  overflow: hidden;
  color: var(--color-text-primary);
  font-size: var(--text-sm);
  text-overflow: ellipsis;
  white-space: nowrap;
}

.row-list__copy > span:not(.row-list__meter),
.row-list__side > span:not(.chip) {
  overflow: hidden;
  color: var(--color-text-faint);
  font-size: var(--text-2xs);
  text-overflow: ellipsis;
  white-space: nowrap;
}

.row-list__meter {
  display: block;
  max-width: 220px;
  height: 4px;
  margin-top: var(--space-1);
  overflow: hidden;
  border-radius: 999px;
  background: var(--color-surface-muted, var(--color-table-header));
}

.row-list__meter span {
  display: block;
  width: 100%;
  height: 100%;
  border-radius: inherit;
  transform-origin: left;
  transition: transform var(--motion-slow) var(--ease-out);
}

.row-list__meter .is-danger { background: var(--color-danger); }
.row-list__meter .is-warning { background: var(--color-warning); }

.row-list__side {
  display: flex;
  flex-direction: column;
  align-items: flex-end;
  gap: var(--space-1);
  text-align: right;
}

.row-list__side strong {
  color: var(--color-text-primary);
  font-size: var(--text-sm);
  font-variant-numeric: tabular-nums;
}

.row-list__side small {
  color: var(--color-text-faint);
  font-size: var(--text-2xs);
  font-weight: 500;
}

.row-list__qty.is-in { color: var(--color-success); }
.row-list__qty.is-out { color: var(--color-danger); }

.chip {
  display: inline-flex;
  align-items: center;
  padding: 1px var(--space-2);
  border-radius: 999px;
  font-size: var(--text-2xs);
  font-weight: 600;
  white-space: nowrap;
}

.chip--danger {
  background: var(--color-danger-bg);
  color: var(--color-danger);
}

.chip--warning {
  background: var(--color-warning-bg);
  color: var(--color-warning);
}

/* ─── Quick navigation ────────────────────────────────────────────── */
.sd-nav .text-section-title {
  margin: 0 0 var(--space-3);
}

.sd-links {
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  gap: var(--space-3);
}

.sd-tile {
  --tone: var(--sd-navy);
  display: flex;
  align-items: center;
  gap: var(--space-3);
  min-width: 0;
  padding: var(--space-3) var(--space-4);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-lg);
  background: var(--color-surface);
  box-shadow: var(--shadow-xs);
  color: var(--color-text-primary);
  text-decoration: none;
  transition:
    border-color var(--motion-fast) var(--ease-out),
    box-shadow var(--motion-normal) var(--ease-out),
    transform var(--motion-normal) var(--ease-out);
}

.sd-tile:hover {
  border-color: color-mix(in srgb, var(--tone) 40%, var(--color-border));
  box-shadow: var(--shadow-sm);
  transform: var(--lift);
}

.sd-tile--violet { --tone: var(--sd-violet); }
.sd-tile--amber { --tone: var(--sd-amber); }
.sd-tile--blue { --tone: var(--sd-blue); }
.sd-tile--green { --tone: var(--sd-green); }
.sd-tile--coral { --tone: var(--sd-coral); }
.sd-tile--teal { --tone: var(--sd-teal); }
.sd-tile--pink { --tone: var(--sd-pink); }
.sd-tile--navy { --tone: var(--sd-navy); }

.sd-tile__icon {
  display: grid;
  flex-shrink: 0;
  place-items: center;
  width: 38px;
  height: 38px;
  border-radius: var(--radius-md);
  background: color-mix(in srgb, var(--tone) 12%, transparent);
  color: var(--tone);
}

.sd-tile__title {
  flex: 1;
  overflow: hidden;
  font-size: var(--text-sm);
  font-weight: 600;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.sd-tile__arrow {
  flex-shrink: 0;
  color: var(--color-text-faint);
  transition: transform var(--motion-fast) var(--ease-out), color var(--motion-fast) var(--ease-out);
}

.sd-tile:hover .sd-tile__arrow {
  color: var(--tone);
  transform: translateX(2px);
}

/* ─── Dark theme tweaks ───────────────────────────────────────────── */
:global([data-theme="dark"]) .sd-kpi,
:global([data-theme="dark"]) .sd-tile {
  background-image: none;
}

:global([data-theme="dark"]) .sd-tile__icon {
  background: color-mix(in srgb, var(--tone) 22%, transparent);
  color: color-mix(in srgb, var(--tone) 70%, #fff);
}

/* ─── Responsive ──────────────────────────────────────────────────── */
@media (max-width: 1280px) {
  .sd-overview {
    grid-template-columns: 1fr;
  }
}

@media (max-width: 1100px) {
  .sd-kpis,
  .sd-links {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }

  .sd-grid,
  .sd-grid--even {
    grid-template-columns: 1fr;
  }
}

@media (max-width: 640px) {
  .sd-kpis,
  .sd-links,
  .sd-value__facts {
    grid-template-columns: 1fr;
  }

  .sd-health__body {
    grid-template-columns: 1fr;
    justify-items: center;
  }

  .sd-status {
    width: 100%;
  }

  .sd-trend-stats {
    display: none;
  }

  .sd-value {
    padding: var(--space-5);
  }
}

@media (prefers-reduced-motion: reduce) {
  .sd-hero,
  .sd-value,
  .chart__bar {
    animation: none;
  }

  .sd-hero__refresh:hover:not(:disabled),
  .sd-kpi:hover,
  .sd-tile:hover {
    transform: none;
  }
}
</style>
