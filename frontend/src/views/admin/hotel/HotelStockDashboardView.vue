<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import { RouterLink } from 'vue-router'
import { extractApiErrorMessage } from '../../../api/client'
import AppIcon from '../../../components/ui/AppIcon.vue'
import KpiCard from '../../../components/ui/KpiCard.vue'
import LoadingBlock from '../../../components/ui/LoadingBlock.vue'
import { useBackofficeStore } from '../../../stores/backoffice'
import { useContextStore } from '../../../stores/context'
import type { InventoryReport } from '../../../types'
import { getAppCurrency } from '../../../utils/currency'
import { formatDate } from '../../../utils/format'
import { formatMoney } from '../../../utils/money'
import HotelChrome from './HotelChrome.vue'

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

const hotelName = computed(() =>
  context.currentStore?.branch?.company?.name
  || context.currentStore?.name
  || t('nav.hotel'),
)

const todayLabel = computed(() =>
  new Intl.DateTimeFormat(locale.value, { dateStyle: 'medium' }).format(new Date()),
)

const catalogueCount = computed(() => store.stats?.products ?? inventory.value?.total_articles ?? 0)
const productsInStock = computed(() => inventory.value?.skus_in_stock ?? 0)
const stockValue = computed(() => inventory.value?.estimated_value ?? 0)
const lowCount = computed(() => (inventory.value?.low_stock_count ?? 0) + (inventory.value?.out_of_stock_count ?? 0))
const salesDelta = computed(() => deltaPct(monthSales.value, prevSales.value))

const status = computed(() => {
  const report = inventory.value
  const healthy = report?.healthy_count ?? 0
  const low = report?.low_stock_count ?? 0
  const out = report?.out_of_stock_count ?? 0
  const over = report?.overstock_count ?? 0
  const total = Math.max(1, healthy + low + out + over)
  return {
    total: healthy + low + out + over,
    healthy,
    low,
    out,
    over,
    healthPct: Math.round((healthy / total) * 100),
    slices: [
      { key: 'healthy', width: `${(healthy / total) * 100}%`, color: 'var(--color-success)' },
      { key: 'low', width: `${(low / total) * 100}%`, color: 'var(--color-warning)' },
      { key: 'out', width: `${(out / total) * 100}%`, color: 'var(--color-danger)' },
      { key: 'over', width: `${(over / total) * 100}%`, color: 'var(--color-info)' },
    ],
  }
})

const alerts = computed(() => (inventory.value?.low_stock ?? []).slice(0, 10).map(row => {
  const qty = Number(row.quantity_on_hand) || 0
  const threshold = Number(row.threshold) || 0
  const pct = qty <= 0 ? 0 : Math.min(100, Math.round((qty / Math.max(threshold, 1)) * 100))
  return {
    id: row.product_id,
    name: row.name || '—',
    sku: row.sku || '—',
    place: row.warehouse || '—',
    qty,
    out: qty <= 0,
    pct,
  }
}))

const movements = computed(() => (inventory.value?.movements ?? []).slice(0, 8))

const trendChart = computed(() => {
  const max = niceMax(Math.max(0, ...trend.value.map(row => row.revenue / 100)))
  return {
    ticks: [max, max * 0.75, max * 0.5, max * 0.25, 0],
    rows: trend.value.map(row => ({
      ...row,
      pct: max ? (row.revenue / 100) / max : 0,
    })),
  }
})

const links = [
  { to: '/admin/inventory/stock', label: t('hotel.stock.links.products'), icon: 'products' },
  { to: '/admin/catalog/categories', label: t('hotel.stock.links.categories'), icon: 'layers' },
  { to: '/admin/inventory/transfers', label: t('hotel.stock.links.transfers'), icon: 'transfer' },
  { to: '/admin/inventory/counts', label: t('hotel.stock.links.counts'), icon: 'check' },
  { to: '/admin/inventory/issues', label: t('hotel.stock.links.exits'), icon: 'upload' },
  { to: '/admin/suppliers', label: t('hotel.stock.links.suppliers'), icon: 'suppliers' },
  { to: '/admin/organization/warehouses', label: t('hotel.stock.links.warehouses'), icon: 'inventory' },
  { to: '/admin/reports/inventory', label: t('hotel.stock.links.reports'), icon: 'dashboard' },
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
  const currency = getAppCurrency()
  const abs = Math.abs(value)
  if (abs >= 1_000_000) return `${(value / 1_000_000).toFixed(1)}M ${currency}`
  if (abs >= 1_000) return `${(value / 1_000).toFixed(1)}k ${currency}`
  return formatMoney(cents)
}

function compactAxis(value: number) {
  const abs = Math.abs(value)
  if (abs >= 1_000_000) return `${(value / 1_000_000).toFixed(1)}M`
  if (abs >= 1_000) return `${(value / 1_000).toFixed(1)}k`
  return new Intl.NumberFormat(locale.value, { maximumFractionDigits: 0 }).format(value)
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
  return `${sign}${value}`
}
</script>

<template>
  <HotelChrome scroll-body :title="t('hotel.stock.title')" :subtitle="subtitle">
    <div class="sd">
      <div class="sd__toolbar">
        <p class="text-caption">{{ todayLabel }}</p>
        <button type="button" class="btn-secondary" :disabled="loading" @click="load">
          <AppIcon name="recycle" :size="15" />
          {{ t('common.refresh') }}
        </button>
      </div>

      <p v-if="error" class="sd__error">{{ error }}</p>
      <LoadingBlock v-else-if="loading && !inventory" variant="cards" :rows="6" :label="t('common.loading')" />

      <template v-else>
        <section class="sd-kpis stagger-in">
          <KpiCard :label="t('hotel.stock.productsInStock')" :value="productsInStock" icon="products" />
          <KpiCard :label="t('hotel.stock.catalogueItems')" :value="catalogueCount" icon="layers" />
          <KpiCard
            :label="t('hotel.stock.stockValue')"
            :value="compactMoney(stockValue)"
            icon="receipt"
            accent="var(--color-info)"
            icon-bg="var(--color-info-bg)"
          />
          <KpiCard
            :label="t('hotel.stock.lowStockAlerts')"
            :value="lowCount"
            icon="bell"
            accent="var(--color-warning)"
            icon-bg="var(--color-warning-bg)"
          />
          <KpiCard
            :label="t('hotel.stock.monthlySales')"
            :value="formatMoney(monthSales)"
            icon="sales"
            :delta="`${formatPct(salesDelta)} ${t('hotel.stock.vsLastMonth')}`"
            :delta-tone="deltaTone(salesDelta)"
          />
          <KpiCard :label="t('hotel.stock.activeOrders')" :value="openOrders" icon="inventory" />
        </section>

        <div class="sd-grid">
          <section class="ui-card">
            <header class="ui-card__header">
              <div>
                <h3 class="ui-card__title">{{ t('hotel.stock.revenueTrend') }}</h3>
                <p class="text-caption">{{ t('hotel.stock.last12Months') }}</p>
              </div>
            </header>
            <div class="ui-card__body">
              <div class="chart" role="img" :aria-label="t('hotel.stock.revenueTrend')">
                <div class="chart__y">
                  <span v-for="(tick, index) in trendChart.ticks" :key="index">{{ compactAxis(tick) }} {{ currency }}</span>
                </div>
                <div class="chart__plot">
                  <div class="chart__grid" aria-hidden="true" />
                  <div v-for="bar in trendChart.rows" :key="bar.key" class="chart__col">
                    <div class="chart__track">
                      <span class="chart__bar" :style="{ '--bar': bar.pct }" />
                    </div>
                    <span class="chart__label">{{ bar.label }}</span>
                  </div>
                </div>
              </div>
            </div>
          </section>

          <section class="ui-card">
            <header class="ui-card__header">
              <h3 class="ui-card__title">{{ t('hotel.stock.stockStatus') }}</h3>
              <RouterLink to="/admin/inventory/stock" class="sd-link">
                {{ t('hotel.stock.viewAll') }}
                <AppIcon name="chevron-right" :size="14" />
              </RouterLink>
            </header>
            <div class="ui-card__body">
              <p class="status__total"><strong>{{ status.total }}</strong> {{ t('hotel.stock.totalProducts') }}</p>
              <div class="avail__bar" aria-hidden="true">
                <span v-for="slice in status.slices" :key="slice.key" :style="{ width: slice.width, background: slice.color }" />
              </div>
              <ul class="status__list">
                <li><span class="dot dot--ok" />{{ t('hotel.stock.inStock') }}<strong>{{ status.healthy }}</strong></li>
                <li><span class="dot dot--low" />{{ t('hotel.stock.lowStock') }}<strong>{{ status.low }}</strong></li>
                <li><span class="dot dot--out" />{{ t('hotel.stock.outOfStock') }}<strong>{{ status.out }}</strong></li>
                <li v-if="status.over"><span class="dot dot--over" />{{ t('hotel.stock.overstock') }}<strong>{{ status.over }}</strong></li>
              </ul>
              <p class="status__health">{{ t('hotel.stock.stockHealth') }} · {{ t('hotel.stock.healthy', { pct: status.healthPct }) }}</p>
            </div>
          </section>
        </div>

        <div class="sd-grid">
          <section class="ui-card">
            <header class="ui-card__header">
              <div>
                <h3 class="ui-card__title">{{ t('hotel.stock.alertsTitle') }}</h3>
                <p class="text-caption">{{ t('hotel.stock.alertCount', { count: alerts.length }) }}</p>
              </div>
            </header>
            <div class="ui-card__body">
              <p v-if="!alerts.length" class="sd-empty">{{ t('hotel.stock.emptyAlerts') }}</p>
              <ul v-else class="alert-list">
                <li v-for="item in alerts" :key="item.id">
                  <div class="alert-list__copy">
                    <strong>{{ item.name }}</strong>
                    <span>{{ item.sku }} · {{ item.place }}</span>
                    <span class="alert-list__track"><span :style="{ transform: `scaleX(${item.pct / 100})` }" /></span>
                  </div>
                  <div class="alert-list__qty">
                    <strong>{{ item.qty }}</strong>
                    <em :class="{ 'is-out': item.out }">{{ item.out ? t('hotel.stock.outOfStock') : t('hotel.stock.lowStock') }}</em>
                    <span>{{ item.pct }}%</span>
                  </div>
                </li>
              </ul>
              <RouterLink to="/admin/inventory/alerts" class="sd-link sd-link--block">{{ t('hotel.stock.viewAllAlerts') }}</RouterLink>
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
              <p v-if="!movements.length" class="sd-empty">{{ t('hotel.stock.emptyMovements') }}</p>
              <ul v-else class="move-list">
                <li v-for="(row, index) in movements" :key="`${row.sku}-${index}`">
                  <div>
                    <strong>{{ row.name || '—' }}</strong>
                    <span>{{ movementLabel(row.type) }} · {{ row.sku || '—' }}</span>
                  </div>
                  <div class="move-list__side">
                    <strong :class="Number(row.quantity) > 0 ? 'is-in' : Number(row.quantity) < 0 ? 'is-out' : ''">{{ qtyLabel(row.quantity) }}</strong>
                    <span>{{ formatDate(row.occurred_at) }}</span>
                  </div>
                </li>
              </ul>
              <RouterLink to="/admin/inventory/adjustments" class="sd-link sd-link--block">{{ t('hotel.stock.viewAllMovements') }}</RouterLink>
            </div>
          </section>
        </div>

        <section>
          <h3 class="text-section-title">{{ t('hotel.stock.quickNav') }}</h3>
          <div class="sd-links stagger-in">
            <RouterLink v-for="link in links" :key="link.to" :to="link.to" class="action-tile">
              <span class="action-tile__icon">
                <AppIcon :name="link.icon" :size="16" />
              </span>
              <span class="action-tile__title">{{ link.label }}</span>
            </RouterLink>
          </div>
        </section>
      </template>
    </div>
  </HotelChrome>
</template>

<style scoped>
.sd {
  display: flex;
  flex-direction: column;
  gap: var(--section-gap);
}

.sd__toolbar {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: var(--space-3);
}

.sd__error,
.sd-empty {
  margin: 0;
  color: var(--color-text-muted);
  font-size: var(--text-sm);
}

.sd__error { color: var(--color-danger); }

.sd-kpis {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: var(--card-gap);
}

.sd-grid {
  display: grid;
  grid-template-columns: 1.3fr 0.9fr;
  gap: var(--card-gap);
  align-items: start;
}

.sd-link {
  display: inline-flex;
  align-items: center;
  gap: var(--space-1);
  color: var(--color-ink-brand, var(--color-brand-700));
  font-size: var(--text-sm);
  font-weight: 600;
  text-decoration: none;
  transition: color var(--motion-fast) var(--ease-in-out);}

.sd-link:hover { color: var(--color-ink-brand, var(--color-brand-800));}
.sd-link--block { margin-top: var(--space-4); }

.status__total,
.status__health {
  margin: 0 0 var(--space-3);
  color: var(--color-text-secondary);
  font-size: var(--text-sm);
}

.status__total strong {
  font-size: var(--text-2xl);
  color: var(--color-text-primary);
}

.status__health { margin: var(--space-4) 0 0; }

.avail__bar {
  display: flex;
  height: 10px;
  overflow: hidden;
  border-radius: 999px;
  background: var(--color-table-header);
}

.status__list,
.alert-list,
.move-list {
  list-style: none;
  margin: var(--space-3) 0 0;
  padding: 0;
}

.status__list li,
.move-list li,
.alert-list li {
  display: flex;
  align-items: center;
  gap: var(--space-3);
  min-height: 44px;
  border-top: 1px solid var(--color-border);
}

.status__list strong,
.move-list__side {
  margin-left: auto;
  text-align: right;
  font-variant-numeric: tabular-nums;
}

.dot {
  width: 8px;
  height: 8px;
  border-radius: 999px;
}

.dot--ok { background: var(--color-success); }
.dot--low { background: var(--color-warning); }
.dot--out { background: var(--color-danger); }
.dot--over { background: var(--color-info); }

.alert-list__copy,
.move-list li > div {
  display: flex;
  flex-direction: column;
  gap: 2px;
  min-width: 0;
  flex: 1;
}

.alert-list__copy strong,
.move-list strong {
  color: var(--color-text-primary);
  font-size: var(--text-sm);
}

.alert-list__copy span,
.move-list span,
.alert-list__qty em {
  color: var(--color-text-muted);
  font-size: var(--text-xs);
  font-style: normal;
}

.alert-list__track {
  display: block;
  height: 4px;
  margin-top: var(--space-1);
  border-radius: 999px;
  background: var(--color-table-header);
  overflow: hidden;
}

.alert-list__track span {
  display: block;
  width: 100%;
  height: 100%;
  background: var(--color-danger);
  transform-origin: left;
  transition: transform var(--motion-slow) var(--ease-out);
}

.alert-list__qty {
  display: flex;
  flex-direction: column;
  align-items: flex-end;
  font-variant-numeric: tabular-nums;
}

.alert-list__qty .is-out { color: var(--color-danger); }

.alert-list__qty .is-out {
  color: var(--color-danger);
  background: var(--color-danger-bg);
  padding: 2px var(--space-2);
  border-radius: 999px;
  font-weight: 600;
}

.move-list__side strong.is-in { color: var(--color-success); }
.move-list__side strong.is-out { color: var(--color-danger); }

.chart {
  display: grid;
  grid-template-columns: 5.5rem 1fr;
  gap: var(--space-3);
  align-items: start;
}

.chart__y {
  display: flex;
  flex-direction: column;
  justify-content: space-between;
  height: 140px;
  color: var(--color-text-muted);
  font-size: 11px;
  font-weight: 600;
  text-align: right;
  font-variant-numeric: tabular-nums;
}

.chart__plot {
  position: relative;
  display: grid;
  grid-auto-flow: column;
  grid-auto-columns: 1fr;
  gap: 4px;
  align-items: end;
}

.chart__grid {
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  height: 140px;
  background: repeating-linear-gradient(
    to top,
    transparent 0,
    transparent calc(25% - 1px),
    var(--color-border) calc(25% - 1px),
    var(--color-border) 25%
  );
  pointer-events: none;
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
  display: flex;
  align-items: flex-end;
  width: 100%;
  height: 140px;
}

.chart__bar {
  display: block;
  width: 100%;
  height: 100%;
  border-radius: 4px 4px 0 0;
  background: linear-gradient(180deg, var(--color-brand-400), var(--color-brand-700));
  transform: scaleY(var(--bar, 0));
  transform-origin: bottom;
  animation: bar-in var(--motion-slow) var(--ease-out) backwards;
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

.chart__label {
  color: var(--color-text-muted);
  font-size: 11px;
  font-weight: 600;
}

.sd-links {
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  gap: var(--card-gap);
}

.action-tile__icon {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: var(--control-md);
  height: var(--control-md);
  border-radius: var(--radius-md);
  background: var(--color-brand-50);
  color: var(--color-ink-brand, var(--color-brand-700));}

.action-tile__title {
  font-size: var(--text-sm);
  font-weight: 600;
  color: var(--color-text-primary);
}

@media (max-width: 1100px) {
  .sd-kpis,
  .sd-links { grid-template-columns: 1fr 1fr; }
  .sd-grid { grid-template-columns: 1fr; }
}

@media (max-width: 640px) {
  .sd-kpis,
  .sd-links { grid-template-columns: 1fr; }
}
</style>
