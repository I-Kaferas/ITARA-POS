<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import { RouterLink } from 'vue-router'
import PageFrame from '../../components/layout/PageFrame.vue'
import AppIcon from '../../components/ui/AppIcon.vue'
import KpiCard from '../../components/ui/KpiCard.vue'
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

const hourSpark = computed(() => {
  const decoration = [18, 28, 22, 40, 55, 48, 62, 35, 44, 30, 52, 38, 46, 24]
  const hours = (overview.value?.sales_by_hour ?? []).filter(h => h.hour >= 8 && h.hour <= 21)
  const max = Math.max(0, ...hours.map(h => h.revenue))
  if (!hours.length || max <= 0) return decoration
  return hours.map(h => Math.round((h.revenue / max) * 100))
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
const serviceHours = computed(() => {
  const hourNow = new Date().getHours()
  return Array.from({ length: 14 }, (_, index) => {
    const hour = index + 8
    return { hour, label: String(hour), now: hour === hourNow, past: hour < hourNow }
  })
})
const spotlightShare = computed(() => {
  const revenue = overview.value?.kpis.revenue ?? 0
  const part = spotlight.value?.revenue ?? 0
  if (!revenue || !part) return 0
  return Math.round((part / revenue) * 100)
})

const tones = ['green', 'amber', 'violet', 'blue'] as const

const stats = computed(() => [
  ...(posOn.value ? [{
    key: 'revenue',
    label: t('pointOfSale.overview.todayRevenue'),
    value: formatMoney(overview.value?.kpis.revenue ?? 0),
    icon: 'receipt',
    tone: 'green',
    accent: 'var(--color-success)',
    iconBg: 'var(--color-success-bg)',
    delta: t('dashboard.avgTicket', { amount: formatMoney(overview.value?.kpis.average_ticket ?? 0) }),
    deltaTone: 'up' as const,
  },
  {
    key: 'sales',
    label: t('pointOfSale.overview.todaySales'),
    value: overview.value?.kpis.sales_count ?? 0,
    icon: 'sales',
    tone: 'amber',
    accent: 'var(--color-warning)',
    iconBg: 'var(--color-warning-bg)',
    delta: peak.value ? t('dashboard.peakHour', { hour: peak.value.label }) : t('dashboard.quiet'),
    deltaTone: peak.value ? 'up' as const : 'flat' as const,
  },
  {
    key: 'shifts',
    label: t('pointOfSale.overview.openShifts'),
    value: openShifts.value,
    icon: 'shift',
    tone: 'violet',
    accent: 'var(--color-brand-600)',
    iconBg: 'var(--color-brand-50)',
    delta: openShifts.value > 0 ? t('dashboard.shiftsLive') : t('dashboard.shiftsIdle'),
    deltaTone: openShifts.value > 0 ? 'up' as const : 'flat' as const,
  }] : []),
  ...(inventoryOn.value ? [{
    key: 'alerts',
    label: t('dashboard.stockAlerts'),
    value: alertCount.value,
    icon: 'bell',
    tone: 'blue',
    accent: 'var(--color-info)',
    iconBg: 'var(--color-info-bg)',
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

function monogram(name: string) {
  return name
    .trim()
    .split(/\s+/)
    .slice(0, 2)
    .map(part => part[0]?.toUpperCase() ?? '')
    .join('') || '•'
}

function productLink(productId?: string | null) {
  return productId ? `/admin/products/${productId}` : '/admin/pos/orders'
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

    <div class="dash">
      <header class="greet">
        <h2 class="greet__title">{{ greeting }}</h2>
        <p class="greet__prompt">{{ t('dashboard.prompt') }}</p>
      </header>

      <section v-if="widgets.length" class="module-widgets" :aria-label="t('modules.widgetsTitle')">
        <RouterLink v-for="widget in widgets" :key="widget.code" :to="widget.to" class="module-widget">
          <AppIcon :name="widget.icon" :size="18" />
          <span>{{ t(widget.label_key) }}</span>
        </RouterLink>
      </section>

      <section
        v-if="loading || stats.length"
        class="dash-kpis hub-strip"
        :aria-label="t('dashboard.todayActivity')"
      >
        <LoadingBlock v-if="loading" variant="cards" :rows="4" :label="t('common.loading')" />
        <template v-else>
          <KpiCard
            v-for="card in stats"
            :key="card.key"
            :label="card.label"
            :value="card.value"
            :icon="card.icon"
            :accent="card.accent"
            :icon-bg="card.iconBg"
            :delta="card.delta"
            :delta-tone="card.deltaTone"
          />
        </template>
      </section>

      <div class="stage">
        <article v-if="posOn" class="hero" :class="{ 'hero--quiet': !spotlight }">
          <div class="hero__copy">
            <p class="hero__kicker">{{ t('dashboard.spotlight') }}</p>
            <h3 class="hero__title">{{ spotlight?.product_name ?? t('dashboard.spotlightEmpty') }}</h3>
            <p class="hero__text">
              {{
                spotlight
                  ? t('dashboard.spotlightHint', {
                      qty: spotlight.quantity,
                      amount: formatMoney(spotlight.revenue),
                    })
                  : t('dashboard.spotlightEmptyHint')
              }}
            </p>
            <div v-if="spotlight" class="hero__meta">
              <span class="hero__chip">
                <AppIcon name="products" :size="14" />
                {{ t('dashboard.soldCount', { count: spotlight.quantity }) }}
              </span>
              <span class="hero__chip">
                <AppIcon name="receipt" :size="14" />
                {{ formatMoney(spotlight.revenue) }}
              </span>
              <span v-if="spotlightShare" class="hero__chip">
                <AppIcon name="sparkles" :size="14" />
                {{ t('dashboard.shareOfToday', { percent: spotlightShare }) }}
              </span>
            </div>
            <RouterLink v-if="spotlight" class="hero__link" to="/admin/pos/orders">
              {{ t('dashboard.viewSales') }}
              <AppIcon name="chevron-right" :size="14" />
            </RouterLink>
          </div>
          <div class="hero__visual" :aria-hidden="spotlight ? true : undefined">
            <template v-if="spotlight">
              <span class="hero__mark">{{ monogram(spotlight.product_name) }}</span>
              <div class="hero__bars">
                <span
                  v-for="(n, i) in hourSpark"
                  :key="i"
                  :style="{ height: `${Math.max(18, Math.min(100, n))}%`, animationDelay: `${i * 40}ms` }"
                />
              </div>
            </template>
            <div v-else class="hero__clock">
              <AppIcon name="clock" :size="18" />
              <strong>{{ nowClock }}</strong>
              <small>{{ t('dashboard.spotlightNow') }}</small>
            </div>
          </div>
          <ol
            v-if="!spotlight"
            class="hero__hours"
            :aria-label="t('dashboard.serviceHours', { time: nowClock })"
          >
            <li
              v-for="slot in serviceHours"
              :key="slot.hour"
              :class="{ 'is-now': slot.now, 'is-past': slot.past }"
            >
              <span class="hero__hour-bar" />
              <span class="hero__hour-label">{{ slot.label }}</span>
            </li>
          </ol>
        </article>

        <section class="ui-card">
          <div class="ui-card__header">
            <h3 class="ui-card__title">{{ t('dashboard.areas') }}</h3>
            <RouterLink class="dash-link" to="/admin/pos/overview">{{ t('dashboard.viewAll') }}</RouterLink>
          </div>
          <div class="ui-card__body area-list">
            <RouterLink v-for="area in areas" :key="area.to" :to="area.to" class="area" :class="`tone-${area.tone}`">
              <span class="area__icon">
                <AppIcon :name="area.icon" :size="16" />
              </span>
              <span class="min-w-0">
                <span class="area__label">{{ area.label }}</span>
                <span class="area__count">{{ area.count }}</span>
              </span>
            </RouterLink>
          </div>
        </section>
      </div>

      <div class="stage">
        <section v-if="posOn" class="ui-card">
          <div class="ui-card__header">
            <h3 class="ui-card__title">{{ t('dashboard.topForYou') }}</h3>
            <RouterLink class="dash-link" to="/admin/pos/orders">{{ t('dashboard.viewAll') }}</RouterLink>
          </div>
          <div class="ui-card__body">
            <div v-if="topProducts.length" class="picks">
              <RouterLink
                v-for="(item, index) in topProducts"
                :key="item.product_id ?? item.product_sku ?? index"
                :to="productLink(item.product_id)"
                class="pick"
                :class="`tone-${tones[index % tones.length]}`"
              >
                <span class="pick__art">
                  <span class="pick__rank">{{ index + 1 }}</span>
                  {{ monogram(item.product_name) }}
                </span>
                <span class="pick__body">
                  <span class="pick__name">{{ item.product_name }}</span>
                  <span class="pick__meta">{{ t('dashboard.soldCount', { count: item.quantity }) }}</span>
                  <span class="pick__price">{{ formatMoney(item.revenue) }}</span>
                </span>
              </RouterLink>
            </div>
            <p v-else class="empty-copy">{{ t('dashboard.noTop') }}</p>
          </div>
        </section>

        <section class="ui-card">
          <div class="ui-card__header">
            <div>
              <h3 class="ui-card__title">{{ openAlerts.length ? t('dashboard.watchlist') : t('dashboard.gettingStarted') }}</h3>
              <p v-if="!openAlerts.length" class="text-caption">
                {{ completedSteps }}/{{ checklist.length }} {{ t('dashboard.stepsDone') }}
              </p>
            </div>
            <RouterLink
              class="dash-link"
              :to="openAlerts.length && inventoryOn ? '/admin/inventory/alerts' : '/admin/organization/company'"
            >
              {{ t('dashboard.viewAll') }}
            </RouterLink>
          </div>
          <div class="ui-card__body watch-list">
            <template v-if="inventoryOn && openAlerts.length">
              <RouterLink
                v-for="alert in openAlerts.slice(0, 6)"
                :key="alert.id"
                to="/admin/inventory/alerts"
                class="watch"
              >
                <span class="watch__box" aria-hidden="true" />
                <span class="min-w-0">
                  <span class="watch__name">{{ alert.product?.name ?? alert.message }}</span>
                  <span v-if="alert.product?.sku" class="watch__sku">{{ alert.product.sku }}</span>
                </span>
                <span v-if="alert.quantity_on_hand != null" class="watch__qty">
                  {{ t('dashboard.onHand', { count: alert.quantity_on_hand }) }}
                </span>
              </RouterLink>
              <div v-if="!setupDone" class="setup-note">
                <div class="ui-progress">
                  <div class="ui-progress__bar" :style="{ width: `${(completedSteps / checklist.length) * 100}%` }" />
                </div>
                <span>{{ completedSteps }}/{{ checklist.length }} {{ t('dashboard.stepsDone') }}</span>
              </div>
            </template>
            <template v-else>
              <div v-for="(item, i) in checklist" :key="i" class="watch">
                <span class="watch__box" :class="{ 'watch__box--done': item.done }" aria-hidden="true">
                  <AppIcon v-if="item.done" name="check" :size="12" />
                </span>
                <span class="watch__name" :class="{ 'watch__name--done': item.done }">{{ item.label }}</span>
              </div>
            </template>
          </div>
        </section>
      </div>
    </div>
  </PageFrame>
</template>

<style scoped>
.module-widgets {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(min(100%, 12rem), 1fr));
  gap: 0.6rem;
}
.module-widget {
  display: flex;
  align-items: center;
  gap: 0.55rem;
  white-space: nowrap;
  padding: 0.75rem 0.85rem;
  border-radius: 0.8rem;
  background: var(--color-surface, white);
  color: var(--color-text);
  text-decoration: none;
  border: 1px solid var(--color-border, rgba(0, 0, 0, 0.08));
}
.dash {
  display: flex;
  flex-direction: column;
  gap: var(--space-6);
}

.greet__title {
  margin: 0;
  font-family: var(--font-display);
  font-size: clamp(1.5rem, 2vw, 1.85rem);
  font-weight: 650;
  letter-spacing: -0.03em;
  line-height: 1.15;
  color: var(--color-text-primary);
}

.greet__prompt {
  margin: 6px 0 0;
  font-size: var(--text-sm);
  color: var(--color-text-muted);
}

.dash-kpis.hub-strip {
  margin-bottom: 0;
}

.dash-kpis :deep(.ui-skeleton-block) {
  grid-column: 1 / -1;
}

.area__icon {
  display: grid;
  place-items: center;
  flex-shrink: 0;
  border-radius: 12px;
  background: var(--tone-bg);
  color: var(--tone);
}

.area__label,
.area__count,
.pick__name,
.pick__meta,
.pick__price,
.watch__name,
.watch__sku {
  margin: 0;
}

.stage {
  display: grid;
  grid-template-columns: minmax(0, 1.65fr) minmax(0, 0.85fr);
  gap: var(--space-4);
  align-items: stretch;
}

.hero {
  position: relative;
  overflow: hidden;
  display: grid;
  grid-template-columns: minmax(0, 1.15fr) minmax(0, 0.85fr);
  min-height: 280px;
  border-radius: 16px;
  background: var(--color-surface);
  border: 1px solid var(--color-border);
  box-shadow: var(--shadow-xs);
  color: var(--color-text-primary);
}

.hero__copy {
  position: relative;
  z-index: 1;
  display: flex;
  flex-direction: column;
  align-items: flex-start;
  gap: 12px;
  padding: 24px 26px;
}

.hero__kicker {
  margin: 0;
  font-size: 11px;
  font-weight: 700;
  letter-spacing: 0.14em;
  text-transform: uppercase;
  color: var(--color-text-muted);
}

.hero__title {
  margin: 0;
  max-width: 16ch;
  font-size: clamp(1.45rem, 2vw, 1.85rem);
  font-weight: 650;
  letter-spacing: -0.03em;
  line-height: 1.15;
}

.hero__text {
  margin: 0;
  max-width: 36ch;
  font-size: var(--text-sm);
  line-height: 1.45;
  color: var(--color-text-secondary);
}

.hero__meta {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
}

.hero__chip {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  padding: 5px 10px;
  border-radius: 999px;
  background: var(--color-canvas);
  color: var(--color-text-secondary);
  font-size: 12px;
  font-weight: 600;
}

.hero__link {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  margin-top: auto;
  color: var(--color-ink-brand, var(--color-brand-600));
  font-size: var(--text-sm);
  font-weight: 650;
  text-decoration: none;
  border-bottom: 1px solid color-mix(in srgb, currentColor 35%, transparent);
  padding-bottom: 1px;
}

.hero__link:hover {
  border-bottom-color: currentColor;
}

.hero--quiet {
  grid-template-columns: minmax(0, 1fr) auto;
  grid-template-rows: auto minmax(108px, 1fr);
}

.hero--quiet .hero__copy {
  grid-column: 1;
  grid-row: 1;
  padding-bottom: 8px;
}

.hero--quiet .hero__visual {
  grid-column: 2;
  grid-row: 1;
  min-height: 0;
  display: flex;
  align-items: flex-start;
  justify-content: flex-end;
  padding: 22px 22px 0 0;
}

.hero__clock {
  display: grid;
  grid-template-columns: auto auto;
  grid-template-rows: auto auto;
  column-gap: 8px;
  align-items: center;
  padding: 14px 16px 12px;
  border-radius: 16px;
  background: var(--color-canvas);
  border: 1px solid var(--color-border);
  color: var(--color-text-primary);
}

.hero__clock svg {
  grid-row: 1 / span 2;
  align-self: center;
  color: var(--color-text-muted);
}

.hero__clock strong {
  font-size: 1.55rem;
  font-weight: 650;
  letter-spacing: -0.04em;
  font-variant-numeric: tabular-nums;
  line-height: 1;
}

.hero__clock small {
  grid-column: 2;
  font-size: 11px;
  font-weight: 650;
  letter-spacing: 0.12em;
  text-transform: uppercase;
  color: var(--color-text-muted);
}

.hero__hours {
  grid-column: 1 / -1;
  grid-row: 2;
  display: flex;
  align-items: stretch;
  gap: 6px;
  height: 100%;
  margin: 0;
  padding: 8px 22px 16px;
  list-style: none;
}

.hero__hours li {
  flex: 1;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: flex-end;
  gap: 8px;
  min-width: 0;
  min-height: 0;
}

.hero__hour-bar {
  width: 100%;
  max-width: 18px;
  height: 7px;
  border-radius: 999px;
  background: var(--color-border);
}

.hero__hours .is-past .hero__hour-bar {
  height: 32%;
  border-radius: 6px 6px 3px 3px;
  background: color-mix(in srgb, var(--color-brand-400) 35%, var(--color-border));
}

.hero__hours .is-now .hero__hour-bar {
  height: 82%;
  max-width: 22px;
  border-radius: 8px 8px 3px 3px;
  background: var(--color-accent);
}

.hero__hour-label {
  font-size: 10px;
  font-weight: 650;
  letter-spacing: 0.02em;
  color: var(--color-text-muted);
  font-variant-numeric: tabular-nums;
}

.hero__hours .is-now .hero__hour-label {
  color: var(--color-text-primary);
}

.hero__visual {
  position: relative;
  min-height: 200px;
}

.hero__mark {
  position: absolute;
  top: 28px;
  right: 28px;
  display: grid;
  place-items: center;
  width: 112px;
  height: 112px;
  border-radius: 28px;
  background: var(--color-canvas);
  border: 1px solid var(--color-border);
  font-size: 2.4rem;
  font-weight: 700;
  letter-spacing: -0.04em;
  color: var(--color-ink-brand, var(--color-brand-600));
}

.hero__bars {
  position: absolute;
  left: 18px;
  right: 22px;
  bottom: 18px;
  display: flex;
  align-items: flex-end;
  gap: 5px;
  height: 72px;
}

.hero__bars span {
  flex: 1;
  border-radius: 5px 5px 2px 2px;
  background: color-mix(in srgb, var(--color-brand-600) 55%, var(--color-border));
  transform-origin: bottom;
  animation: bar-rise 700ms var(--ease-out) both;
}

.dash-link {
  color: var(--color-success);
  font-size: 13px;
  font-weight: 650;
  text-decoration: none;
}

.dash-link:hover {
  text-decoration: underline;
}

.area-list,
.watch-list {
  display: flex;
  flex-direction: column;
  padding-top: 8px;
  padding-bottom: 8px;
}

.area,
.watch {
  display: flex;
  align-items: center;
  gap: 12px;
  min-height: 52px;
  padding: 8px 0;
  border-bottom: 1px solid var(--color-border);
  color: inherit;
  text-decoration: none;
}

.area:last-child,
.watch:last-child {
  border-bottom: 0;
}

.area__icon {
  width: 36px;
  height: 36px;
  border-radius: 10px;
}

.area__label,
.watch__name {
  display: block;
  font-size: var(--text-sm);
  font-weight: 600;
  color: var(--color-text-primary);
}

.area__count,
.watch__sku {
  display: block;
  margin-top: 1px;
  font-size: 12px;
  color: var(--color-text-muted);
}

.area:hover .area__label,
.pick:hover .pick__name,
.watch:hover .watch__name {
  color: var(--color-ink-brand, var(--color-brand-600));}

.picks {
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  gap: 12px;
}

.pick {
  display: flex;
  flex-direction: column;
  min-width: 0;
  overflow: hidden;
  border: 1px solid var(--color-border);
  border-radius: 14px;
  background: var(--color-surface);
  color: inherit;
  text-decoration: none;
  transition: transform var(--motion-fast) var(--ease-out), box-shadow var(--motion-fast) var(--ease-out);
}

.pick:hover {
  transform: translateY(-2px);
  box-shadow: var(--shadow-md);
}

.pick__art {
  position: relative;
  display: grid;
  place-items: center;
  height: 96px;
  background: var(--tone-bg);
  color: var(--tone);
  font-size: 1.7rem;
  font-weight: 700;
  letter-spacing: -0.04em;
}

.pick__rank {
  position: absolute;
  top: 8px;
  left: 8px;
  display: grid;
  place-items: center;
  width: 22px;
  height: 22px;
  border-radius: 999px;
  background: var(--color-surface);
  color: var(--color-text-secondary);
  font-size: 11px;
  font-weight: 700;
}

.pick__body {
  display: flex;
  flex-direction: column;
  gap: 2px;
  padding: 10px 12px 12px;
}

.pick__name {
  overflow: hidden;
  font-size: 13.5px;
  font-weight: 650;
  line-height: 1.3;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.pick__meta {
  font-size: 12px;
  color: var(--color-text-muted);
}

.pick__price {
  margin-top: 4px;
  font-size: 13px;
  font-weight: 650;
  color: var(--tone);
}

.watch__box {
  display: grid;
  place-items: center;
  width: 18px;
  height: 18px;
  flex-shrink: 0;
  border: 1.5px solid var(--color-border-strong);
  border-radius: 5px;
  color: var(--color-success);
}

.watch__box--done {
  border-color: var(--color-success);
  background: var(--color-success-bg);
}

.watch__name--done {
  color: var(--color-text-muted);
  text-decoration: line-through;
}

.watch__qty {
  margin-left: auto;
  flex-shrink: 0;
  font-size: 12px;
  font-weight: 650;
  color: var(--color-text-secondary);
  font-variant-numeric: tabular-nums;
}

.setup-note {
  display: flex;
  align-items: center;
  gap: 12px;
  margin-top: 8px;
  padding-top: 12px;
  border-top: 1px solid var(--color-border);
  font-size: 12px;
  color: var(--color-text-muted);
}

.setup-note .ui-progress {
  flex: 1;
}

.empty-copy {
  margin: 0;
  color: var(--color-text-muted);
  font-size: var(--text-sm);
}

.tone-green {
  --tone: var(--color-success);
  --tone-bg: var(--color-success-bg);
}
.tone-amber {
  --tone: var(--color-warning);
  --tone-bg: var(--color-warning-bg);
}
.tone-violet {
  --tone: var(--color-brand-600);
  --tone-bg: var(--color-brand-50);
}
.tone-blue {
  --tone: var(--color-info);
  --tone-bg: var(--color-info-bg);
}

@keyframes bar-rise {
  from { transform: scaleY(0.35); opacity: 0.35; }
  to { transform: scaleY(1); opacity: 1; }
}

@media (max-width: 1180px) {
  .picks {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }
}

@media (max-width: 980px) {
  .stage,
  .hero {
    grid-template-columns: 1fr;
  }

  .hero__visual {
    min-height: 148px;
  }

  .hero--quiet {
    grid-template-rows: auto auto minmax(120px, 1fr);
  }

  .hero--quiet .hero__visual {
    grid-column: 1;
    grid-row: 2;
    min-height: 0;
    justify-content: flex-start;
    padding: 0 22px 4px;
  }

  .hero__hours {
    grid-row: 3;
  }

  .hero__clock {
    grid-template-columns: auto auto auto;
    grid-template-rows: auto;
    align-items: center;
  }

  .hero__clock svg {
    grid-row: auto;
  }

  .hero__clock small {
    grid-column: auto;
  }

  .hero__mark {
    inset: 8px 12px 64px;
    font-size: 3rem;
  }
}

@media (max-width: 640px) {
  .picks {
    grid-template-columns: 1fr;
  }
}
</style>
