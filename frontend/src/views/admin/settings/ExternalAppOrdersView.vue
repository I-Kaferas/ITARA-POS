<script setup lang="ts">
import { computed, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import PageFrame from '../../../components/layout/PageFrame.vue'
import AppIcon from '../../../components/ui/AppIcon.vue'
import Badge from '../../../components/ui/Badge.vue'
import { intlLocale } from '../../../i18n/locales'
import { useContextStore } from '../../../stores/context'
import ListPager from '../../../components/ui/ListPager.vue'
import { useClientPager } from '../../../composables/useClientPager'

type OrderType = 'delivery' | 'dine_in' | 'takeaway'
type OrderStatus = 'pending' | 'validated' | 'preparing' | 'out_for_delivery' | 'delivered' | 'cancelled'
type OrderSource = 'android' | 'ios' | 'web'

interface ExternalOrder {
  id: string
  reference: string
  customer: string
  phone: string
  store: string
  source: OrderSource
  type: OrderType
  deliveryLabel: string
  amount: number
  status: OrderStatus
  at: string
  proximityKm: number | null
  qrConfirmed: boolean
}

const { t, locale } = useI18n()
const context = useContextStore()

const orders = ref<ExternalOrder[]>([])
const query = ref('')
const typeFilter = ref<OrderType | ''>('')
const statusFilter = ref<OrderStatus | ''>('')
const sourceFilter = ref<OrderSource | ''>('')
const filtersOpen = ref(true)
const refreshing = ref(false)
const exporting = ref(false)
const loaded = ref(true)

const typeTabs = computed(() => [
  { key: '' as const, label: t('externalAppOrdersPage.all'), value: orders.value.length },
  {
    key: 'delivery' as const,
    label: t('externalAppOrdersPage.delivery'),
    value: orders.value.filter(o => o.type === 'delivery').length,
  },
  {
    key: 'dine_in' as const,
    label: t('externalAppOrdersPage.dineIn'),
    value: orders.value.filter(o => o.type === 'dine_in').length,
  },
])

const filtered = computed(() => {
  const q = query.value.trim().toLowerCase()
  return orders.value.filter(order => {
    if (typeFilter.value && order.type !== typeFilter.value) return false
    if (statusFilter.value && order.status !== statusFilter.value) return false
    if (sourceFilter.value && order.source !== sourceFilter.value) return false
    if (!q) return true
    return (
      order.reference.toLowerCase().includes(q)
      || order.customer.toLowerCase().includes(q)
      || order.phone.toLowerCase().includes(q)
      || order.store.toLowerCase().includes(q)
    )
  })
})
const { page, lastPage, total, perPage, paged, setPage } = useClientPager(filtered)

const totalOnPeriod = computed(() => filtered.value.length)

const completedCount = computed(() =>
  filtered.value.filter(o => o.status === 'delivered' || o.qrConfirmed).length,
)

const completionRate = computed(() => {
  if (!filtered.value.length) return 0
  return (completedCount.value / filtered.value.length) * 100
})

const statusTone: Record<OrderStatus, 'info' | 'warning' | 'success' | 'danger' | 'neutral'> = {
  pending: 'warning',
  validated: 'info',
  preparing: 'info',
  out_for_delivery: 'warning',
  delivered: 'success',
  cancelled: 'danger',
}

function money(amount: number) {
  const formatted = new Intl.NumberFormat(intlLocale(locale.value)).format(amount)
  return `${formatted} ${context.currencyCode || 'BIF'}`
}

function when(value: string) {
  const date = new Date(value)
  const loc = intlLocale(locale.value)
  return new Intl.DateTimeFormat(loc, {
    day: '2-digit',
    month: 'short',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  }).format(date)
}

function typeLabel(type: OrderType) {
  if (type === 'dine_in') return t('externalAppOrdersPage.dineIn')
  if (type === 'delivery') return t('externalAppOrdersPage.delivery')
  return t('externalAppOrdersPage.takeaway')
}

function sourceLabel(source: OrderSource) {
  return t(`externalAppOrdersPage.source.${source}`)
}

function statusLabel(status: OrderStatus) {
  return t(`externalAppOrdersPage.status.${status}`)
}

function proximityLabel(km: number | null) {
  if (km === null) return '—'
  return t('externalAppOrdersPage.proximityKm', { km: km.toFixed(1) })
}

function selectType(key: OrderType | '') {
  typeFilter.value = typeFilter.value === key ? '' : key
}

function refresh() {
  if (refreshing.value) return
  refreshing.value = true
  query.value = ''
  typeFilter.value = ''
  statusFilter.value = ''
  sourceFilter.value = ''
  window.setTimeout(() => {
    orders.value = []
    loaded.value = true
    refreshing.value = false
  }, 280)
}

function exportCsv() {
  if (exporting.value) return
  exporting.value = true
  const headers = [
    t('externalAppOrdersPage.col.reference'),
    t('externalAppOrdersPage.col.customer'),
    t('externalAppOrdersPage.col.store'),
    t('externalAppOrdersPage.col.source'),
    t('externalAppOrdersPage.col.type'),
    t('externalAppOrdersPage.col.delivery'),
    t('externalAppOrdersPage.col.amount'),
    t('externalAppOrdersPage.col.status'),
    t('externalAppOrdersPage.col.date'),
    t('externalAppOrdersPage.col.proximity'),
  ]
  const rows = filtered.value.map(o => [
    o.reference,
    o.customer,
    o.store,
    sourceLabel(o.source),
    typeLabel(o.type),
    o.deliveryLabel,
    String(o.amount),
    statusLabel(o.status),
    o.at,
    proximityLabel(o.proximityKm),
  ])
  const csv = [headers, ...rows]
    .map(line => line.map(cell => `"${String(cell).replaceAll('"', '""')}"`).join(','))
    .join('\n')
  const blob = new Blob([csv], { type: 'text/csv;charset=utf-8' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = `commandes-app-externe-${new Date().toISOString().slice(0, 10)}.csv`
  a.click()
  URL.revokeObjectURL(url)
  window.setTimeout(() => {
    exporting.value = false
  }, 200)
}
</script>

<template>
  <PageFrame>
    <div class="xo-root" :aria-busy="refreshing">
      <header class="xo-head">
        <div class="xo-brand">
          <span class="xo-mark" aria-hidden="true">
            <svg viewBox="0 0 24 24" width="22" height="22" fill="none" stroke="currentColor" stroke-width="2">
              <path d="M6 7h12l-1 12H7L6 7z" stroke-linejoin="round" />
              <path d="M9 7V5a3 3 0 0 1 6 0v2" stroke-linecap="round" />
            </svg>
          </span>
          <div>
            <h1>{{ t('externalAppOrdersPage.title') }}</h1>
            <p>{{ t('externalAppOrdersPage.subtitle') }}</p>
          </div>
        </div>
        <div class="xo-actions">
          <button type="button" class="xo-btn" :disabled="refreshing" @click="refresh">
            <AppIcon name="refresh" :size="16" />
            {{ t('externalAppOrdersPage.refresh') }}
          </button>
          <button type="button" class="xo-btn xo-btn--primary" :disabled="exporting" @click="exportCsv">
            <AppIcon name="download" :size="16" />
            {{ t('externalAppOrdersPage.export') }}
          </button>
        </div>
      </header>

      <section class="xo-kpis" :aria-label="t('externalAppOrdersPage.kpis')">
        <article>
          <span class="xo-kpi-icon" aria-hidden="true">
            <svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" stroke-width="2">
              <path d="M6 7h12l-1 12H7L6 7z" stroke-linejoin="round" />
              <path d="M9 7V5a3 3 0 0 1 6 0v2" stroke-linecap="round" />
            </svg>
          </span>
          <div>
            <span>{{ t('externalAppOrdersPage.totalOrders') }}</span>
            <strong>{{ totalOnPeriod }}</strong>
            <p>{{ t('externalAppOrdersPage.filteredPeriod', { n: totalOnPeriod }) }}</p>
          </div>
        </article>
        <article>
          <span class="xo-kpi-icon xo-kpi-icon--done" aria-hidden="true">
            <svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" stroke-width="2">
              <path d="M5 12.5l4.2 4.2L19 7" stroke-linecap="round" stroke-linejoin="round" />
            </svg>
          </span>
          <div>
            <span>{{ t('externalAppOrdersPage.completionRate') }}</span>
            <strong>{{ completionRate.toFixed(1) }}%</strong>
            <p>{{ t('externalAppOrdersPage.completedCount', { n: completedCount }) }}</p>
          </div>
        </article>
      </section>

      <div class="xo-bar">
      <section class="ext__tabs" role="tablist" :aria-label="t('externalAppOrdersPage.typeFilter')">
        <button
          v-for="tab in typeTabs"
          :key="tab.key || 'all'"
          type="button"
          role="tab"
          class="ext__tab"
          :class="{ 'is-on': typeFilter === tab.key }"
          :aria-selected="typeFilter === tab.key"
          @click="selectType(tab.key)"
        >
          <span class="ext__tab-label">{{ tab.label }}</span>
          <span class="ext__tab-count">{{ tab.value }}</span>
        </button>
      </section>

      <div class="ext__filters-bar">
        <label class="ext__search">
          <span class="sr-only">{{ t('externalAppOrdersPage.search') }}</span>
          <AppIcon name="search" :size="15" class="ext__search-icon" />
          <input
            v-model="query"
            class="field ext__search-input"
            type="search"
            :placeholder="t('externalAppOrdersPage.search')"
          />
        </label>
        <button
          type="button"
          class="xo-btn"
          :class="{ 'is-on': filtersOpen }"
          :aria-expanded="filtersOpen"
          @click="filtersOpen = !filtersOpen"
        >
          <AppIcon name="filter" :size="16" />
          {{ t('externalAppOrdersPage.filters') }}
        </button>
      </div>
      </div>

      <div class="fold-panel" :class="{ 'is-open': filtersOpen }">
      <div class="fold-panel__body ext__filters" :inert="!filtersOpen">
        <label>
          <span>{{ t('externalAppOrdersPage.col.status') }}</span>
          <select v-model="statusFilter" class="field">
            <option value="">{{ t('externalAppOrdersPage.allStatuses') }}</option>
            <option value="pending">{{ t('externalAppOrdersPage.status.pending') }}</option>
            <option value="validated">{{ t('externalAppOrdersPage.status.validated') }}</option>
            <option value="preparing">{{ t('externalAppOrdersPage.status.preparing') }}</option>
            <option value="out_for_delivery">{{ t('externalAppOrdersPage.status.out_for_delivery') }}</option>
            <option value="delivered">{{ t('externalAppOrdersPage.status.delivered') }}</option>
            <option value="cancelled">{{ t('externalAppOrdersPage.status.cancelled') }}</option>
          </select>
        </label>
        <label>
          <span>{{ t('externalAppOrdersPage.col.source') }}</span>
          <select v-model="sourceFilter" class="field">
            <option value="">{{ t('externalAppOrdersPage.allSources') }}</option>
            <option value="android">{{ t('externalAppOrdersPage.source.android') }}</option>
            <option value="ios">{{ t('externalAppOrdersPage.source.ios') }}</option>
            <option value="web">{{ t('externalAppOrdersPage.source.web') }}</option>
          </select>
        </label>
      </div>
      </div>

      <div class="xo-table">
        <table class="ui-table">
          <thead>
            <tr>
              <th>{{ t('externalAppOrdersPage.col.reference') }}</th>
              <th>{{ t('externalAppOrdersPage.col.customer') }}</th>
              <th>{{ t('externalAppOrdersPage.col.store') }}</th>
              <th>{{ t('externalAppOrdersPage.col.source') }}</th>
              <th>{{ t('externalAppOrdersPage.col.type') }}</th>
              <th>{{ t('externalAppOrdersPage.col.delivery') }}</th>
              <th>{{ t('externalAppOrdersPage.col.amount') }}</th>
              <th>{{ t('externalAppOrdersPage.col.status') }}</th>
              <th>{{ t('externalAppOrdersPage.col.date') }}</th>
              <th>{{ t('externalAppOrdersPage.col.proximity') }}</th>
              <th>{{ t('externalAppOrdersPage.col.actions') }}</th>
            </tr>
          </thead>
          <tbody>
            <tr v-if="loaded && !filtered.length">
              <td class="ext__empty" colspan="11">{{ t('externalAppOrdersPage.empty') }}</td>
            </tr>
            <tr v-for="order in paged" :key="order.id">
              <td class="ext__ref">{{ order.reference }}</td>
              <td>
                <p class="ext__name">{{ order.customer }}</p>
                <p class="ext__meta">{{ order.phone }}</p>
              </td>
              <td>{{ order.store }}</td>
              <td>{{ sourceLabel(order.source) }}</td>
              <td>{{ typeLabel(order.type) }}</td>
              <td>{{ order.deliveryLabel || '—' }}</td>
              <td class="ext__amount">{{ money(order.amount) }}</td>
              <td>
                <Badge :variant="statusTone[order.status]">{{ statusLabel(order.status) }}</Badge>
                <p v-if="order.qrConfirmed" class="ext__meta ext__qr">
                  {{ t('externalAppOrdersPage.qrConfirmed') }}
                </p>
              </td>
              <td class="ext__when">{{ when(order.at) }}</td>
              <td>{{ proximityLabel(order.proximityKm) }}</td>
              <td>
                <button type="button" class="btn-secondary ext__view" disabled>
                  <AppIcon name="eye" :size="16" />
                  {{ t('externalAppOrdersPage.view') }}
                </button>
              </td>
            </tr>
          </tbody>
        </table>
        <ListPager :page="page" :last-page="lastPage" :total="total" :per-page="perPage" @change="setPage" />
      </div>
    </div>
  </PageFrame>
</template>

<style scoped>
.xo-root {
  --xo-bg: var(--color-canvas);
  --xo-card: var(--color-surface);
  --xo-line: var(--color-border);
  --xo-title: var(--color-text-primary);
  --xo-text: var(--color-text);
  --xo-muted: var(--color-text-muted);
  --xo-primary: var(--color-brand-600);
  --xo-done: var(--color-success);
  box-sizing: border-box;
  display: flex;
  flex-direction: column;
  flex: 1 1 auto;
  align-self: stretch;
  width: 100%;
  min-height: 100%;
  padding: 22px 24px 24px;
  background: var(--xo-bg);
  color: var(--xo-text);
}

:global([data-theme='dark']) .xo-root {
  --xo-bg: #070b16;
  --xo-card: #151c2c;
  --xo-line: #2a3448;
  --xo-title: #f4f7ff;
  --xo-text: #e8eefc;
  --xo-muted: #9aa6bf;
  --xo-primary: var(--color-brand-600);
  --xo-done: #3ddc97;
}

.xo-root h1 {
  margin: 0;
  color: var(--xo-title);
  font-size: 1.45rem;
  font-weight: 800;
  letter-spacing: -0.03em;
  line-height: 1.15;
}

.xo-head {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  justify-content: space-between;
  gap: 16px;
}

.xo-brand {
  display: flex;
  align-items: center;
  gap: 12px;
  min-width: 0;
}

.xo-brand > div {
  min-width: 0;
}

.xo-brand p {
  margin: 2px 0 0;
  color: var(--xo-muted);
  font-size: 13px;
}

.xo-mark {
  display: grid;
  place-items: center;
  width: 46px;
  height: 46px;
  flex: 0 0 auto;
  border-radius: 14px;
  background: var(--xo-primary);
  color: #fff;
}

.xo-actions,
.ext__filters-bar {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 8px;
}

.xo-btn {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  height: 42px;
  padding: 0 14px;
  border-radius: 12px;
  border: 1px solid var(--xo-line);
  background: var(--xo-card);
  color: var(--xo-text);
  font-size: 13px;
  font-weight: 700;
  cursor: pointer;
}

.xo-btn:hover {
  border-color: color-mix(in srgb, var(--xo-primary) 40%, var(--xo-line));
}

.xo-btn:disabled {
  opacity: 0.45;
  cursor: not-allowed;
}

.xo-btn--primary,
.xo-btn.is-on {
  border-color: transparent;
  background: var(--xo-primary);
  color: #fff;
}

.xo-kpis {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 12px;
  margin-top: 18px;
}

.xo-kpis article {
  display: flex;
  align-items: flex-start;
  gap: 12px;
  min-width: 0;
  padding: 16px;
  border-radius: 16px;
  background: var(--xo-card);
  border: 1px solid var(--xo-line);
}

.xo-kpi-icon {
  display: grid;
  place-items: center;
  width: 36px;
  height: 36px;
  border-radius: 10px;
  flex: 0 0 auto;
  background: color-mix(in srgb, var(--xo-primary) 16%, transparent);
  color: var(--xo-primary);
}

.xo-kpi-icon--done {
  background: color-mix(in srgb, var(--xo-done) 16%, transparent);
  color: var(--xo-done);
}

.xo-kpis article > div {
  min-width: 0;
}

.xo-kpis article span {
  display: block;
  color: var(--xo-muted);
  font-size: 12px;
  font-weight: 650;
}

.xo-kpis strong {
  display: block;
  margin-top: 4px;
  color: var(--xo-title);
  font-size: 1.45rem;
  font-weight: 800;
  letter-spacing: -0.03em;
  line-height: 1.1;
  font-variant-numeric: tabular-nums;
}

.xo-kpis p {
  margin: 6px 0 0;
  color: var(--xo-muted);
  font-size: 12px;
  line-height: 1.35;
}

.xo-bar {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  margin-top: 16px;
}

.ext__tabs {
  display: inline-flex;
  flex-wrap: wrap;
  gap: 6px;
  padding: 4px;
  border: 1px solid var(--xo-line);
  border-radius: 14px;
  background: var(--xo-card);
  width: fit-content;
  max-width: 100%;
}

.ext__tab {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  height: 34px;
  padding: 0 12px;
  border: 0;
  border-radius: 10px;
  background: transparent;
  color: var(--xo-muted);
  font-size: 13px;
  font-weight: 700;
  cursor: pointer;
}

.ext__tab:hover {
  color: var(--xo-title);
}

.ext__tab.is-on {
  background: var(--xo-primary);
  color: #fff;
}

.ext__tab-count {
  min-width: 1.35rem;
  padding: 0.05rem 0.4rem;
  border-radius: 999px;
  background: color-mix(in srgb, currentColor 14%, transparent);
  font-variant-numeric: tabular-nums;
  font-size: 12px;
  text-align: center;
}

.ext__tab.is-on .ext__tab-count {
  background: rgba(255, 255, 255, 0.18);
}

.ext__filters-bar {
  flex: 1 1 280px;
  justify-content: flex-end;
}

.ext__search {
  position: relative;
  flex: 1 1 220px;
  max-width: 360px;
  min-width: min(100%, 12rem);
}

.ext__search-icon {
  position: absolute;
  left: 0.75rem;
  top: 50%;
  transform: translateY(-50%);
  color: var(--xo-muted);
  pointer-events: none;
}

.ext__search-input {
  width: 100%;
  height: 42px;
  padding-left: 2.2rem;
  border: 1px solid var(--xo-line);
  border-radius: 12px;
  background: var(--xo-card);
  color: var(--xo-text);
}

.ext__filters {
  display: flex;
  flex-wrap: wrap;
  gap: 12px;
  margin-top: 12px;
  padding: 14px;
  border: 1px solid var(--xo-line);
  border-radius: 16px;
  background: var(--xo-card);
}

.ext__filters label {
  display: flex;
  flex-direction: column;
  gap: 6px;
  min-width: min(100%, 14rem);
  flex: 1;
  font-size: 12px;
  font-weight: 650;
  color: var(--xo-muted);
}

.ext__filters .field {
  height: 40px;
  border-radius: 10px;
  border: 1px solid var(--xo-line);
  background: var(--xo-bg);
  color: var(--xo-text);
}

.xo-table {
  display: flex;
  flex: 1 1 auto;
  flex-direction: column;
  min-height: 280px;
  margin-top: 16px;
  overflow: auto;
  border: 1px solid var(--xo-line);
  border-radius: 18px;
  background: var(--xo-card);
}

.xo-table :deep(.ui-table) {
  height: 100%;
  min-width: 960px;
}

.xo-table :deep(.ui-table thead th) {
  background: var(--xo-card);
  color: var(--xo-muted);
}

.xo-table :deep(.ui-table td) {
  border-bottom-color: var(--xo-line);
  color: var(--xo-text);
}

.xo-table :deep(.ui-table td:first-child) {
  color: var(--xo-title);
}

.xo-table :deep(.ui-table tbody tr:hover) {
  background: color-mix(in srgb, var(--xo-primary) 7%, transparent);
}

.ext__empty {
  height: 100% !important;
  padding: 3rem 1rem !important;
  text-align: center;
  color: var(--xo-muted) !important;
  font-weight: 600 !important;
}

.ext__ref {
  font-weight: 650;
  font-variant-numeric: tabular-nums;
  white-space: nowrap;
}

.ext__name {
  margin: 0;
  font-weight: 650;
  color: var(--xo-title);
}

.ext__meta {
  margin: 0.15rem 0 0;
  font-size: 12px;
  color: var(--xo-muted);
}

.ext__qr {
  display: inline-flex;
  align-items: center;
  gap: 0.25rem;
  margin-top: 0.35rem;
  color: var(--xo-done);
}

.ext__amount,
.ext__when {
  white-space: nowrap;
  font-variant-numeric: tabular-nums;
}

.ext__view {
  white-space: nowrap;
  height: 34px;
  padding: 0 10px;
  border-radius: 10px;
}

@media (max-width: 860px) {
  .xo-kpis,
  .xo-bar {
    display: grid;
    grid-template-columns: 1fr;
  }

  .ext__filters-bar,
  .ext__search {
    max-width: none;
    width: 100%;
  }

  .ext__tabs {
    width: 100%;
  }

  .ext__tab {
    flex: 1;
    justify-content: center;
  }
}
</style>
