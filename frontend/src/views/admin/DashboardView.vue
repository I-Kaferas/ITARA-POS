<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import { RouterLink } from 'vue-router'
import PageFrame from '../../components/layout/PageFrame.vue'
import AppIcon from '../../components/ui/AppIcon.vue'
import LoadingBlock from '../../components/ui/LoadingBlock.vue'
import { api, type ApiItemResponse } from '../../api/client'
import { moduleEnabled, type ModuleWidget } from '../../modules/registry'
import { useAuthStore } from '../../stores/auth'
import { useBackofficeStore } from '../../stores/backoffice'
import { useContextStore } from '../../stores/context'
import type { DashboardStats, InventoryAlert, PosOverview } from '../../types'
import { realtimeTopics, useRealtimeSync } from '../../composables/useRealtimeSync'
import { formatMoney } from '../../utils/format'

const { t, locale } = useI18n()
const store = useBackofficeStore()
const auth = useAuthStore()
const context = useContextStore()

const loading = ref(true)
const overview = ref<PosOverview | null>(null)
const widgets = ref<ModuleWidget[]>([])
const posOn = computed(() => moduleEnabled(auth.user?.modules, 'pos'))
const inventoryOn = computed(() => moduleEnabled(auth.user?.modules, 'inventory'))

const firstName = computed(() => auth.user?.name?.split(' ')[0] ?? '')
const storeId = computed(() => context.currentStoreId)

const greeting = computed(() => {
  if (!firstName.value) return t('dashboard.welcome')
  const hour = new Date().getHours()
  const key = hour < 12 ? 'dashboard.morning' : hour < 18 ? 'dashboard.afternoon' : 'dashboard.evening'
  return t(key, { name: firstName.value })
})

const openShifts = ref(0)
const alertCount = ref(0)
const openAlerts = ref<InventoryAlert[]>([])

const peak = computed(() => {
  const active = (overview.value?.sales_by_hour ?? []).filter(h => h.revenue > 0)
  if (!active.length) return null
  return active.reduce((best, hour) => (hour.revenue > best.revenue ? hour : best))
})

const spotlight = computed(() => overview.value?.best_selling_products?.[0] ?? null)
const topProducts = computed(() => (overview.value?.best_selling_products ?? []).slice(0, 4))
const nowClock = computed(() =>
  new Intl.DateTimeFormat(locale.value || undefined, { hour: '2-digit', minute: '2-digit' }).format(new Date()),
)
const todayLabel = computed(() =>
  new Intl.DateTimeFormat(locale.value || undefined, { weekday: 'short', month: 'short', day: 'numeric' }).format(new Date()),
)
const hourSlots = computed(() => {
  const byHour = new Map((overview.value?.sales_by_hour ?? []).map(row => [row.hour, row]))
  const rows = Array.from({ length: 14 }, (_, index) => {
    const hour = index + 8
    const hit = byHour.get(hour)
    return { hour, revenue: hit?.revenue ?? 0 }
  })
  const max = Math.max(0, ...rows.map(row => row.revenue))
  return rows.map(row => ({
    ...row,
    label: String(row.hour),
    pct: max > 0 ? Math.round((row.revenue / max) * 100) : 0,
    peak: max > 0 && row.revenue === max,
    empty: row.revenue <= 0,
    showLabel: row.hour % 2 === 0,
  }))
})
const payments = computed(() => (overview.value?.payment_methods ?? []).slice(0, 4))
const recentOrders = computed(() => (overview.value?.recent_orders ?? []).slice(0, 4))
const sellerMax = computed(() => Math.max(1, ...topProducts.value.map(item => item.revenue)))
const spotlightShare = computed(() => {
  const revenue = overview.value?.kpis.revenue ?? 0
  const part = spotlight.value?.revenue ?? 0
  if (!revenue || !part) return 0
  return Math.round((part / revenue) * 100)
})

const stats = computed(() => [
  ...(posOn.value ? [{
    key: 'revenue',
    label: t('pointOfSale.overview.todayRevenue'),
    value: formatMoney(overview.value?.kpis.revenue ?? 0),
    icon: 'receipt',
    tone: 'green',
    delta: t('dashboard.avgTicket', { amount: formatMoney(overview.value?.kpis.average_ticket ?? 0) }),
    deltaTone: 'up' as const,
  },
  {
    key: 'sales',
    label: t('pointOfSale.overview.todaySales'),
    value: overview.value?.kpis.sales_count ?? 0,
    icon: 'sales',
    tone: 'amber',
    delta: peak.value ? t('dashboard.peakHour', { hour: peak.value.label }) : t('dashboard.quiet'),
    deltaTone: peak.value ? 'up' as const : 'flat' as const,
  },
  {
    key: 'shifts',
    label: t('pointOfSale.overview.openShifts'),
    value: openShifts.value,
    icon: 'shift',
    tone: 'violet',
    delta: openShifts.value > 0 ? t('dashboard.shiftsLive') : t('dashboard.shiftsIdle'),
    deltaTone: openShifts.value > 0 ? 'up' as const : 'flat' as const,
  }] : []),
  ...(inventoryOn.value ? [{
    key: 'alerts',
    label: t('dashboard.stockAlerts'),
    value: alertCount.value,
    icon: 'bell',
    tone: 'blue',
    delta: alertCount.value > 0 ? t('dashboard.alertsOpen') : t('dashboard.alertsClear'),
    deltaTone: alertCount.value > 0 ? 'down' as const : 'up' as const,
  }] : []),
])

const areas = computed(() => [
  { to: '/admin/pos/orders', icon: 'sales', tone: 'green', label: t('pointOfSale.overview.todaySales'), count: overview.value?.kpis.sales_count ?? 0, module: 'pos' },
  { to: '/admin/products', icon: 'products', tone: 'amber', label: t('nav.products'), count: store.stats?.products ?? 0 },
  { to: '/admin/inventory/alerts', icon: 'bell', tone: 'violet', label: t('dashboard.stockAlerts'), count: alertCount.value, module: 'inventory' },
  { to: '/admin/pos/shifts', icon: 'shift', tone: 'blue', label: t('pointOfSale.overview.openShifts'), count: openShifts.value, module: 'pos' },
  { to: '/admin/catalog/catalogs', icon: 'catalog', tone: 'green', label: t('nav.catalogs'), count: store.stats?.catalogs ?? 0 },
  { to: '/admin/stores', icon: 'stores', tone: 'amber', label: t('nav.stores'), count: store.stats?.stores ?? 0 },
].filter(area => moduleEnabled(auth.user?.modules, 'module' in area ? area.module : undefined)))

const checklist = computed(() => [
  { done: (store.stats?.companies ?? 0) > 0, label: t('dashboard.checklist.company') },
  { done: (store.stats?.catalogs ?? 0) > 0, label: t('dashboard.checklist.catalog') },
  { done: (store.stats?.products ?? 0) > 0, label: t('dashboard.checklist.products') },
  { done: (store.stats?.store_imports ?? 0) > 0, label: t('dashboard.checklist.import') },
])

const completedSteps = computed(() => checklist.value.filter(c => c.done).length)
const setupDone = computed(() => completedSteps.value === checklist.value.length)
const contextPanel = computed<'alerts' | 'setup' | 'orders'>(() => {
  if (inventoryOn.value && openAlerts.value.length) return 'alerts'
  if (!setupDone.value || !posOn.value) return 'setup'
  return 'orders'
})

function productLink(productId?: string | null) {
  return productId ? `/admin/products/${productId}` : '/admin/pos/orders'
}

function orderWhen(value?: string | null) {
  if (!value) return ''
  return new Intl.DateTimeFormat(locale.value || undefined, { hour: '2-digit', minute: '2-digit' }).format(new Date(value))
}

async function loadWidgets() {
  try {
    const response = await api.get<{ data: { widgets: ModuleWidget[] }[] }>('/modules')
    widgets.value = response.data.flatMap(item => item.widgets)
  } catch {
    widgets.value = []
  }
}

async function loadDashboard(silent?: boolean) {
  if (silent !== true) loading.value = true
  try {
    const params = new URLSearchParams()
    if (storeId.value) params.set('store_id', storeId.value)
    if (posOn.value) params.set('sales', '1')
    if (inventoryOn.value) params.set('inventory', '1')
    const suffix = params.toString() ? `?${params}` : ''
    const [home] = await Promise.all([
      api.get<ApiItemResponse<{
        stats: DashboardStats
        overview: PosOverview | null
        open_shifts: number
        open_alerts: number
        alerts: InventoryAlert[]
      }>>(`/dashboard/home${suffix}`),
      loadWidgets(),
    ])
    store.stats = home.data.stats
    overview.value = posOn.value ? home.data.overview : null
    openShifts.value = home.data.open_shifts
    alertCount.value = home.data.open_alerts
    openAlerts.value = home.data.alerts ?? []
  } finally {
    loading.value = false
  }
}

onMounted(() => loadDashboard())
useRealtimeSync(realtimeTopics.dashboard, () => loadDashboard(true))
watch(storeId, () => loadDashboard())
</script>

<template>
  <PageFrame>
    <template #title>{{ t('nav.dashboard') }}</template>
    <template #subtitle>{{ t('dashboard.subtitle') }}</template>

    <div class="db-root">
      <header class="db-head">
        <div class="db-brand">
          <span class="db-mark" aria-hidden="true">
            <AppIcon name="dashboard" :size="22" />
          </span>
          <div>
            <p v-if="context.currentStore?.name" class="db-where">{{ context.currentStore.name }}</p>
            <h2>{{ greeting }}</h2>
            <p>{{ t('dashboard.prompt') }}</p>
          </div>
        </div>
        <div class="db-meta">
          <RouterLink v-if="posOn" class="db-go" to="/admin/pos/terminal">
            <AppIcon name="device-pos" :size="16" />
            {{ t('dashboard.openPos') }}
          </RouterLink>
          <div class="db-clock">
            <AppIcon name="clock" :size="16" />
            <div>
              <strong>{{ nowClock }}</strong>
              <small>{{ todayLabel }}</small>
            </div>
          </div>
        </div>
      </header>

      <nav v-if="widgets.length" class="db-mods" :aria-label="t('modules.widgetsTitle')">
        <RouterLink v-for="widget in widgets" :key="widget.code" :to="widget.to">
          <AppIcon :name="widget.icon" :size="16" />
          <span>{{ t(widget.label_key) }}</span>
        </RouterLink>
      </nav>

      <section
        v-if="loading || stats.length"
        class="db-kpis"
        :aria-label="t('dashboard.todayActivity')"
      >
        <LoadingBlock v-if="loading" variant="cards" :rows="4" :label="t('common.loading')" />
        <article v-for="card in stats" v-else :key="card.key">
          <span class="db-kpi-icon" :class="`is-${card.tone}`" aria-hidden="true">
            <AppIcon :name="card.icon" :size="16" />
          </span>
          <div>
            <span>{{ card.label }}</span>
            <strong>{{ card.value }}</strong>
            <p :class="`is-${card.deltaTone}`">{{ card.delta }}</p>
          </div>
        </article>
      </section>

      <div class="db-board">
        <article v-if="posOn" class="db-panel db-activity">
          <header class="db-panel__head">
            <div>
              <h3>{{ t('pointOfSale.overview.salesByHour') }}</h3>
              <p>{{ peak ? t('dashboard.peakHour', { hour: peak.label }) : t('dashboard.quiet') }}</p>
            </div>
            <RouterLink to="/admin/pos/orders">{{ t('dashboard.viewSales') }}</RouterLink>
          </header>
          <div class="db-chart" role="img" :aria-label="t('pointOfSale.overview.salesByHour')">
            <div v-for="slot in hourSlots" :key="slot.hour" class="db-chart__col">
              <div class="db-chart__track">
                <span
                  :class="{ 'is-peak': slot.peak, 'is-empty': slot.empty }"
                  :style="slot.empty ? undefined : { height: `${Math.max(slot.pct, 8)}%` }"
                />
              </div>
              <small :class="{ 'is-on': slot.showLabel }">{{ slot.showLabel ? slot.label : '' }}</small>
            </div>
          </div>
          <RouterLink v-if="spotlight" class="db-focus" :to="productLink(spotlight.product_id)">
            <span class="db-focus__mark" aria-hidden="true">1</span>
            <span class="db-focus__copy">
              <strong>{{ spotlight.product_name }}</strong>
              <small>
                {{ t('dashboard.spotlightHint', { qty: spotlight.quantity, amount: formatMoney(spotlight.revenue) }) }}
              </small>
            </span>
            <em v-if="spotlightShare">{{ t('dashboard.shareOfToday', { percent: spotlightShare }) }}</em>
          </RouterLink>
          <p v-else class="db-quiet">
            <strong>{{ t('dashboard.spotlightEmpty') }}</strong>
            {{ t('dashboard.spotlightEmptyHint') }}
          </p>
        </article>

        <section class="db-panel">
          <header class="db-panel__head">
            <h3>{{ t('dashboard.areas') }}</h3>
            <RouterLink :to="posOn ? '/admin/pos/overview' : '/admin/products'">{{ t('dashboard.viewAll') }}</RouterLink>
          </header>
          <div class="db-tiles">
            <RouterLink v-for="area in areas" :key="area.to" :to="area.to" class="db-tile">
              <span class="db-tile__icon" aria-hidden="true">
                <AppIcon :name="area.icon" :size="16" />
              </span>
              <span class="db-tile__label">{{ area.label }}</span>
              <strong>{{ area.count }}</strong>
            </RouterLink>
          </div>
        </section>
      </div>

      <div class="db-lower" :class="{ 'is-solo': !posOn }">
        <section v-if="posOn" class="db-panel">
          <header class="db-panel__head">
            <h3>{{ t('dashboard.topForYou') }}</h3>
            <RouterLink to="/admin/pos/orders">{{ t('dashboard.viewAll') }}</RouterLink>
          </header>
          <div v-if="topProducts.length" class="db-stack">
            <RouterLink
              v-for="(item, index) in topProducts"
              :key="item.product_id ?? item.product_sku ?? index"
              :to="productLink(item.product_id)"
              class="db-seller"
            >
              <span class="db-rank">{{ index + 1 }}</span>
              <span class="db-seller__body">
                <span class="db-seller__top">
                  <span class="db-row__label">{{ item.product_name }}</span>
                  <strong>{{ formatMoney(item.revenue) }}</strong>
                </span>
                <span class="db-meter" aria-hidden="true">
                  <span :style="{ width: `${Math.max(8, Math.round((item.revenue / sellerMax) * 100))}%` }" />
                </span>
                <small>{{ t('dashboard.soldCount', { count: item.quantity }) }}</small>
              </span>
            </RouterLink>
          </div>
          <p v-else class="db-empty">{{ t('dashboard.noTop') }}</p>
        </section>

        <section v-if="posOn" class="db-panel">
          <header class="db-panel__head">
            <h3>{{ t('pointOfSale.overview.paymentMethods') }}</h3>
          </header>
          <div v-if="payments.length" class="db-stack">
            <div v-for="row in payments" :key="row.payment_method" class="db-pay">
              <span class="db-seller__top">
                <span class="db-row__label">{{ row.label }}</span>
                <strong>{{ formatMoney(row.amount) }}</strong>
              </span>
              <span class="db-meter" aria-hidden="true">
                <span class="is-pay" :style="{ width: `${Math.max(row.share, 6)}%` }" />
              </span>
              <small>{{ row.share }}% · {{ row.count }} {{ t('pointOfSale.overview.transactions') }}</small>
            </div>
          </div>
          <p v-else class="db-empty">{{ t('pointOfSale.overview.noPayments') }}</p>
        </section>

        <section class="db-panel">
          <header class="db-panel__head">
            <div>
              <h3>
                {{
                  contextPanel === 'alerts'
                    ? t('dashboard.watchlist')
                    : contextPanel === 'orders'
                      ? t('pointOfSale.overview.recentOrders')
                      : t('dashboard.gettingStarted')
                }}
              </h3>
              <p v-if="contextPanel === 'setup'">{{ completedSteps }}/{{ checklist.length }} {{ t('dashboard.stepsDone') }}</p>
            </div>
            <RouterLink
              :to="contextPanel === 'alerts' ? '/admin/inventory/alerts' : contextPanel === 'orders' ? '/admin/pos/orders' : '/admin/organization/company'"
            >
              {{ t('dashboard.viewAll') }}
            </RouterLink>
          </header>

          <div v-if="contextPanel === 'alerts'" class="db-list">
            <RouterLink
              v-for="alert in openAlerts.slice(0, 5)"
              :key="alert.id"
              to="/admin/inventory/alerts"
              class="db-row"
            >
              <span class="db-alert-dot" aria-hidden="true" />
              <span class="db-row__copy">
                <span class="db-row__label">{{ alert.product?.name ?? alert.message }}</span>
                <small v-if="alert.product?.sku">{{ alert.product.sku }}</small>
              </span>
              <strong v-if="alert.quantity_on_hand != null">
                {{ t('dashboard.onHand', { count: alert.quantity_on_hand }) }}
              </strong>
            </RouterLink>
            <div v-if="!setupDone" class="db-setup">
              <div class="ui-progress">
                <div class="ui-progress__bar" :style="{ width: `${(completedSteps / checklist.length) * 100}%` }" />
              </div>
              <span>{{ completedSteps }}/{{ checklist.length }} {{ t('dashboard.stepsDone') }}</span>
            </div>
          </div>

          <div v-else-if="contextPanel === 'orders'" class="db-list">
            <RouterLink
              v-for="order in recentOrders"
              :key="order.id"
              to="/admin/pos/orders"
              class="db-row"
            >
              <span class="db-row__copy">
                <span class="db-row__label">{{ order.reference }}</span>
                <small>{{ [order.customer?.name, orderWhen(order.completed_at || order.created_at)].filter(Boolean).join(' · ') }}</small>
              </span>
              <strong>{{ formatMoney(order.total) }}</strong>
            </RouterLink>
            <p v-if="!recentOrders.length" class="db-empty">{{ t('pointOfSale.overview.noRecentOrders') }}</p>
          </div>

          <div v-else class="db-list">
            <div v-for="(item, i) in checklist" :key="i" class="db-row">
              <span class="db-box" :class="{ 'is-done': item.done }" aria-hidden="true">
                <AppIcon v-if="item.done" name="check" :size="12" />
              </span>
              <span class="db-row__label" :class="{ 'is-done': item.done }">{{ item.label }}</span>
            </div>
          </div>
        </section>
      </div>
    </div>
  </PageFrame>
</template>

<style scoped>
.db-root {
  --db-bg: var(--color-canvas);
  --db-card: var(--color-surface);
  --db-line: var(--color-border);
  --db-title: var(--color-text-primary);
  --db-text: var(--color-text);
  --db-muted: var(--color-text-muted);
  --db-primary: var(--color-brand-600);
  --db-done: var(--color-success);
  --db-down: var(--color-danger);
  --db-warn: var(--color-warning);
  --db-info: var(--color-info);
  box-sizing: border-box;
  display: flex;
  flex-direction: column;
  align-self: stretch;
  width: 100%;
  padding: 22px 24px 28px;
  background: var(--db-bg);
  color: var(--db-text);
}

:global([data-theme='dark']) .db-root {
  --db-bg: #070b16;
  --db-card: #151c2c;
  --db-line: #2a3448;
  --db-title: #f4f7ff;
  --db-text: #e8eefc;
  --db-muted: #9aa6bf;
  --db-primary: #7c5cff;
  --db-done: #3ddc97;
  --db-down: #ffb4b4;
  --db-warn: #f5a524;
  --db-info: #7eb6ff;
}

.db-root h2,
.db-root h3,
.db-root h4,
.db-root p {
  margin: 0;
}

.db-root h2 {
  color: var(--db-title);
  font-size: 1.45rem;
  font-weight: 800;
  letter-spacing: -0.03em;
  line-height: 1.15;
}

.db-head {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  justify-content: space-between;
  gap: 16px;
}

.db-brand {
  display: flex;
  align-items: center;
  gap: 12px;
  min-width: 0;
}

.db-brand > div {
  min-width: 0;
}

.db-where {
  color: var(--db-muted);
  font-size: 11px;
  font-weight: 750;
  letter-spacing: 0.12em;
  text-transform: uppercase;
}

.db-brand p:last-child {
  margin-top: 2px;
  color: var(--db-muted);
  font-size: 13px;
}

.db-mark {
  display: grid;
  place-items: center;
  width: 46px;
  height: 46px;
  flex: 0 0 auto;
  border-radius: 14px;
  background: var(--db-primary);
  color: #fff;
}

.db-meta {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 8px;
}

.db-go {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  height: 42px;
  padding: 0 14px;
  border-radius: 12px;
  background: var(--db-primary);
  color: #fff;
  font-size: 13px;
  font-weight: 750;
  text-decoration: none;
}

.db-go:hover {
  filter: brightness(1.08);
}

.db-clock {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  height: 42px;
  padding: 0 14px;
  border: 1px solid var(--db-line);
  border-radius: 12px;
  background: var(--db-card);
  color: var(--db-title);
}

.db-clock strong {
  display: block;
  font-size: 1.05rem;
  font-weight: 800;
  font-variant-numeric: tabular-nums;
  letter-spacing: -0.03em;
  line-height: 1.1;
}

.db-clock small {
  display: block;
  color: var(--db-muted);
  font-size: 11px;
  font-weight: 650;
}

.db-mods {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
  margin-top: 16px;
}

.db-mods a {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  height: 38px;
  padding: 0 12px;
  border: 1px solid var(--db-line);
  border-radius: 12px;
  background: var(--db-card);
  color: var(--db-text);
  font-size: 13px;
  font-weight: 700;
  text-decoration: none;
}

.db-mods a:hover {
  border-color: color-mix(in srgb, var(--db-primary) 45%, var(--db-line));
  color: var(--db-title);
}

.db-kpis {
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  gap: 12px;
  margin-top: 16px;
}

.db-kpis article {
  display: flex;
  align-items: flex-start;
  gap: 12px;
  min-width: 0;
  padding: 16px;
  border: 1px solid var(--db-line);
  border-radius: 16px;
  background: var(--db-card);
}

.db-kpi-icon {
  display: grid;
  place-items: center;
  width: 36px;
  height: 36px;
  flex: 0 0 auto;
  border-radius: 10px;
  background: color-mix(in srgb, var(--db-primary) 16%, transparent);
  color: var(--db-primary);
}

.db-kpi-icon.is-green {
  background: color-mix(in srgb, var(--db-done) 16%, transparent);
  color: var(--db-done);
}

.db-kpi-icon.is-amber {
  background: color-mix(in srgb, var(--db-warn) 18%, transparent);
  color: var(--db-warn);
}

.db-kpi-icon.is-violet {
  background: color-mix(in srgb, var(--db-primary) 16%, transparent);
  color: var(--db-primary);
}

.db-kpi-icon.is-blue {
  background: color-mix(in srgb, var(--db-info) 16%, transparent);
  color: var(--db-info);
}

.db-kpis article > div {
  min-width: 0;
}

.db-kpis article span {
  display: block;
  color: var(--db-muted);
  font-size: 12px;
  font-weight: 650;
}

.db-kpis strong {
  display: block;
  margin-top: 4px;
  color: var(--db-title);
  font-size: 1.45rem;
  font-weight: 800;
  letter-spacing: -0.03em;
  line-height: 1.1;
  font-variant-numeric: tabular-nums;
}

.db-kpis p {
  margin-top: 6px;
  color: var(--db-muted);
  font-size: 12px;
  line-height: 1.35;
}

.db-kpis p.is-up { color: var(--db-done); }
.db-kpis p.is-down { color: var(--db-down); }

.db-board {
  display: grid;
  grid-template-columns: minmax(0, 1.55fr) minmax(300px, 0.9fr);
  gap: 12px;
  align-items: stretch;
  margin-top: 16px;
}

.db-lower {
  display: grid;
  grid-template-columns: minmax(0, 1.15fr) minmax(0, 0.9fr) minmax(0, 0.95fr);
  gap: 12px;
  margin-top: 12px;
  align-items: start;
}

.db-lower.is-solo {
  grid-template-columns: minmax(0, 420px);
}

.db-panel {
  display: flex;
  flex-direction: column;
  min-width: 0;
  min-height: 0;
  padding: 16px 16px 12px;
  border: 1px solid var(--db-line);
  border-radius: 18px;
  background: var(--db-card);
}

.db-panel__head {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 12px;
}

.db-panel__head h3 {
  color: var(--db-title);
  font-size: 15px;
  font-weight: 800;
  letter-spacing: -0.02em;
}

.db-panel__head p {
  margin-top: 2px;
  color: var(--db-muted);
  font-size: 12px;
}

.db-panel__head a {
  flex: 0 0 auto;
  color: var(--db-primary);
  font-size: 13px;
  font-weight: 700;
  text-decoration: none;
}

.db-panel__head a:hover {
  text-decoration: underline;
}

.db-activity {
  min-height: 0;
}

.db-chart {
  display: flex;
  align-items: flex-end;
  gap: 4px;
  flex: 1 1 auto;
  height: 196px;
  margin-top: 14px;
}

.db-chart__col {
  display: flex;
  flex: 1 1 0;
  flex-direction: column;
  align-items: center;
  height: 100%;
  min-width: 0;
  gap: 6px;
}

.db-chart__track {
  display: flex;
  flex: 1;
  align-items: flex-end;
  width: 100%;
  min-height: 0;
  border-bottom: 1px solid var(--db-line);
}

.db-chart__track span {
  width: 68%;
  margin-inline: auto;
  min-height: 4px;
  border-radius: 5px 5px 2px 2px;
  background: var(--db-primary);
}

.db-chart__track span.is-peak {
  background: var(--color-accent);
}

.db-chart__track span.is-empty {
  height: 4px;
  background: var(--db-line);
}

.db-chart small {
  height: 12px;
  color: transparent;
  font-size: 10px;
  font-weight: 700;
  font-variant-numeric: tabular-nums;
  line-height: 1;
}

.db-chart small.is-on {
  color: var(--db-muted);
}

.db-focus,
.db-quiet {
  display: flex;
  align-items: center;
  gap: 12px;
  margin-top: 14px;
  padding: 12px;
  border-radius: 14px;
  background: var(--db-bg);
  color: inherit;
  text-decoration: none;
}

.db-focus__mark {
  display: grid;
  place-items: center;
  width: 36px;
  height: 36px;
  flex: 0 0 auto;
  border-radius: 10px;
  background: var(--db-primary);
  color: #fff;
  font-size: 14px;
  font-weight: 800;
}

.db-focus__copy {
  display: flex;
  flex-direction: column;
  min-width: 0;
}

.db-focus strong,
.db-quiet strong {
  overflow: hidden;
  color: var(--db-title);
  font-size: 14px;
  font-weight: 750;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.db-focus small,
.db-quiet {
  color: var(--db-muted);
  font-size: 12px;
}

.db-quiet {
  display: block;
}

.db-quiet strong {
  display: block;
  margin-bottom: 2px;
}

.db-focus em {
  margin-left: auto;
  color: var(--db-primary);
  font-size: 12px;
  font-style: normal;
  font-weight: 750;
  white-space: nowrap;
}

.db-focus:hover strong {
  color: var(--db-primary);
}

.db-tiles {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 8px;
  margin-top: 12px;
}

.db-tile {
  display: flex;
  flex-direction: column;
  align-items: flex-start;
  gap: 6px;
  min-width: 0;
  min-height: 88px;
  padding: 12px;
  border-radius: 14px;
  background: var(--db-bg);
  color: inherit;
  text-decoration: none;
}

.db-tile:hover {
  background: color-mix(in srgb, var(--db-primary) 8%, var(--db-bg));
}

.db-tile__icon {
  display: grid;
  place-items: center;
  width: 28px;
  height: 28px;
  border-radius: 8px;
  background: var(--db-card);
  color: var(--db-title);
}

.db-tile__label {
  max-width: 100%;
  color: var(--db-muted);
  font-size: 12px;
  font-weight: 650;
  line-height: 1.3;
}

.db-tile strong {
  color: var(--db-title);
  font-size: 1.25rem;
  font-weight: 800;
  letter-spacing: -0.03em;
  font-variant-numeric: tabular-nums;
  line-height: 1;
}

.db-stack {
  display: flex;
  flex-direction: column;
  gap: 12px;
  margin-top: 14px;
}

.db-seller,
.db-pay {
  display: flex;
  align-items: flex-start;
  gap: 10px;
  color: inherit;
  text-decoration: none;
}

.db-seller__body,
.db-pay {
  display: flex;
  flex: 1;
  flex-direction: column;
  min-width: 0;
  gap: 4px;
}

.db-seller__top {
  display: flex;
  align-items: baseline;
  justify-content: space-between;
  gap: 12px;
}

.db-seller__top strong {
  color: var(--db-title);
  font-size: 13px;
  font-weight: 750;
  font-variant-numeric: tabular-nums;
  white-space: nowrap;
}

.db-seller small,
.db-pay small {
  color: var(--db-muted);
  font-size: 12px;
}

.db-seller:hover .db-row__label {
  color: var(--db-primary);
}

.db-meter {
  display: block;
  height: 6px;
  overflow: hidden;
  border-radius: 999px;
  background: color-mix(in srgb, var(--db-line) 85%, transparent);
}

.db-meter > span {
  display: block;
  height: 100%;
  border-radius: inherit;
  background: var(--db-primary);
}

.db-meter > span.is-pay {
  background: var(--color-accent);
}

.db-alert-dot {
  width: 8px;
  height: 8px;
  flex: 0 0 auto;
  border-radius: 999px;
  background: var(--db-down);
}

.db-list {
  display: flex;
  flex-direction: column;
  min-height: 0;
  margin-top: 8px;
  overflow: auto;
}

.db-row {
  display: flex;
  align-items: center;
  gap: 12px;
  min-height: 48px;
  padding: 8px 2px;
  border-bottom: 1px solid var(--db-line);
  color: inherit;
  text-decoration: none;
}

.db-row:last-child {
  border-bottom: 0;
}

.db-row:hover .db-row__label {
  color: var(--db-primary);
}

.db-row__icon,
.db-rank {
  display: grid;
  place-items: center;
  flex: 0 0 auto;
  border-radius: 10px;
  background: var(--db-bg);
  color: var(--db-title);
}

.db-row__icon {
  width: 36px;
  height: 36px;
}

.db-rank {
  width: 28px;
  height: 28px;
  border-radius: 999px;
  font-size: 12px;
  font-weight: 800;
}

.db-row__copy {
  display: flex;
  flex-direction: column;
  min-width: 0;
}

.db-row__label {
  overflow: hidden;
  color: var(--db-title);
  font-size: 13.5px;
  font-weight: 650;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.db-row__label.is-done {
  color: var(--db-muted);
  text-decoration: line-through;
}

.db-row small {
  overflow: hidden;
  max-width: 28ch;
  color: var(--db-muted);
  font-size: 12px;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.db-row strong {
  margin-left: auto;
  color: var(--db-title);
  font-size: 13px;
  font-weight: 750;
  font-variant-numeric: tabular-nums;
  white-space: nowrap;
}

.db-box {
  display: grid;
  place-items: center;
  width: 18px;
  height: 18px;
  flex: 0 0 auto;
  border: 1.5px solid var(--db-line);
  border-radius: 5px;
  color: #fff;
}

.db-box.is-done {
  border-color: var(--db-done);
  background: var(--db-done);
}

.db-setup {
  display: flex;
  align-items: center;
  gap: 12px;
  margin-top: 8px;
  padding-top: 12px;
  border-top: 1px solid var(--db-line);
  color: var(--db-muted);
  font-size: 12px;
}

.db-setup .ui-progress {
  flex: 1;
}

.db-empty {
  display: grid;
  flex: 1;
  place-items: center;
  margin: 0;
  padding: 24px 8px;
  color: var(--db-muted);
  font-size: 13px;
  text-align: center;
}

@media (max-width: 1100px) {
  .db-kpis,
  .db-lower {
    grid-template-columns: 1fr 1fr;
  }

  .db-board,
  .db-lower.is-solo {
    grid-template-columns: 1fr;
  }

  .db-lower .db-panel:last-child {
    grid-column: 1 / -1;
  }
}

@media (max-width: 720px) {
  .db-root {
    padding: 16px;
  }

  .db-kpis,
  .db-lower,
  .db-tiles {
    grid-template-columns: 1fr;
  }

  .db-chart {
    min-height: 140px;
  }
}
</style>
