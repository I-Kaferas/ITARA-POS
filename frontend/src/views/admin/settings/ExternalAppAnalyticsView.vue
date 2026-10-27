<script setup lang="ts">
import CountUp from '../../../components/motion/CountUp.vue'
import { computed, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import PageFrame from '../../../components/layout/PageFrame.vue'
import AppIcon from '../../../components/ui/AppIcon.vue'
import { intlLocale } from '../../../i18n/locales'
import { useContextStore } from '../../../stores/context'
import {
  cloneMobileOrders,
  type MobileOrder,
  type OrderType,
  type PaymentStatus,
} from '../customer-hub/mobileOrdersData'

type PeriodDays = 7 | 30 | 90

const periods: PeriodDays[] = [7, 30, 90]

const { t, locale } = useI18n()
const context = useContextStore()
const days = ref<PeriodDays>(30)
const refreshing = ref(false)
const orders = ref<MobileOrder[]>(cloneMobileOrders())

function money(amount: number) {
  const formatted = new Intl.NumberFormat(intlLocale(locale.value), {
    maximumFractionDigits: 0,
  }).format(amount)
  const code = (context.currencyCode || 'BIF').toUpperCase()
  return code === 'BIF' ? `${formatted} FBu` : `${formatted} ${code}`
}

function signedPercent(value: number) {
  const rounded = Math.round(value)
  if (rounded > 0) return `+${rounded}%`
  if (rounded === 0) return '+0%'
  return `${rounded}%`
}

function change(current: number, previous: number) {
  if (previous === 0) return current === 0 ? 0 : 100
  return ((current - previous) / previous) * 100
}

function dayKey(date: Date) {
  const month = String(date.getMonth() + 1).padStart(2, '0')
  const day = String(date.getDate()).padStart(2, '0')
  return `${date.getFullYear()}-${month}-${day}`
}

function windowFor(offsetDays: number) {
  const to = new Date()
  to.setHours(23, 59, 59, 999)
  to.setDate(to.getDate() - offsetDays)
  const from = new Date(to)
  from.setHours(0, 0, 0, 0)
  from.setDate(from.getDate() - (days.value - 1))
  return { from, to }
}

function inWindow(order: MobileOrder, from: Date, to: Date) {
  const at = new Date(order.at).getTime()
  return at >= from.getTime() && at <= to.getTime()
}

function activeOrders(offsetDays: number) {
  const { from, to } = windowFor(offsetDays)
  return orders.value.filter(order => order.status !== 'cancelled' && inWindow(order, from, to))
}

function revenueOf(list: MobileOrder[]) {
  return list.reduce((sum, order) => sum + order.amount, 0)
}

function customersOf(list: MobileOrder[]) {
  return new Set(list.map(order => order.phone.trim() || order.customer.trim())).size
}

const current = computed(() => activeOrders(0))
const previous = computed(() => activeOrders(days.value))

const revenue = computed(() => revenueOf(current.value))
const previousRevenue = computed(() => revenueOf(previous.value))
const orderCount = computed(() => current.value.length)
const previousOrderCount = computed(() => previous.value.length)
const uniqueCustomers = computed(() => customersOf(current.value))
const averageBasket = computed(() => (orderCount.value ? Math.round(revenue.value / orderCount.value) : 0))
const uniqueShare = computed(() => (orderCount.value ? Math.round((uniqueCustomers.value / orderCount.value) * 100) : 0))

const revenueDelta = computed(() => change(revenue.value, previousRevenue.value))
const orderDelta = computed(() => change(orderCount.value, previousOrderCount.value))

function locationLabel(order: MobileOrder) {
  if (order.address?.trim()) return order.address.trim()
  if (order.table?.trim()) return t('mobileOrdersPage.table', { name: order.table })
  return ''
}

function ranked(entries: Map<string, number>) {
  const total = [...entries.values()].reduce((sum, count) => sum + count, 0)
  return [...entries.entries()]
    .map(([label, count]) => ({
      label,
      count,
      share: total ? Math.round((count / total) * 100) : 0,
    }))
    .sort((a, b) => b.count - a.count || a.label.localeCompare(b.label))
}

const locations = computed(() => {
  const counts = new Map<string, number>()
  for (const order of current.value) {
    const label = locationLabel(order)
    if (!label) continue
    counts.set(label, (counts.get(label) ?? 0) + 1)
  }
  return ranked(counts)
})

const orderTypes = computed(() => {
  const counts = new Map<string, number>()
  const labelFor: Record<OrderType, string> = {
    dine_in: t('mobileOrdersPage.dineIn'),
    takeaway: t('mobileOrdersPage.takeaway'),
    delivery: t('mobileOrdersPage.delivery'),
  }
  for (const order of current.value) {
    const label = labelFor[order.type]
    counts.set(label, (counts.get(label) ?? 0) + 1)
  }
  return ranked(counts)
})

const payments = computed(() => {
  const counts = new Map<string, number>()
  const labelFor: Record<PaymentStatus, string> = {
    paid: t('mobileOrdersPage.paid'),
    unpaid: t('mobileOrdersPage.unpaid'),
    partial: t('mobileOrdersPage.partial'),
  }
  for (const order of current.value) {
    const label = labelFor[order.payment]
    counts.set(label, (counts.get(label) ?? 0) + 1)
  }
  return ranked(counts)
})

const trendStep = computed(() => (days.value <= 7 ? 1 : days.value <= 30 ? 5 : 10))

function showTrendLabel(index: number, total: number) {
  return index === 0 || index === total - 1 || index % trendStep.value === 0
}

const trend = computed(() => {
  const { from, to } = windowFor(0)
  const buckets = new Map<string, number>()
  const cursor = new Date(from)
  while (cursor <= to) {
    buckets.set(dayKey(cursor), 0)
    cursor.setDate(cursor.getDate() + 1)
  }
  for (const order of current.value) {
    const key = dayKey(new Date(order.at))
    if (!buckets.has(key)) continue
    buckets.set(key, (buckets.get(key) ?? 0) + order.amount)
  }
  const rows = [...buckets.entries()].map(([key, amount]) => ({
    key,
    amount,
    label: new Intl.DateTimeFormat(intlLocale(locale.value), { day: '2-digit', month: 'short' }).format(new Date(`${key}T12:00:00`)),
  }))
  const peak = Math.max(...rows.map(row => row.amount), 0)
  return { rows, peak, hasSeries: peak > 0 }
})

function refresh() {
  if (refreshing.value) return
  refreshing.value = true
  window.setTimeout(() => {
    orders.value = cloneMobileOrders()
    refreshing.value = false
  }, 280)
}
</script>

<template>
  <PageFrame>
    <div class="xa-root" :aria-busy="refreshing">
      <header class="xa-head">
        <div class="xa-brand">
          <span class="xa-mark" aria-hidden="true">
            <svg viewBox="0 0 24 24" width="22" height="22" fill="none" stroke="currentColor" stroke-width="2">
              <path d="M4 19V5" stroke-linecap="round" />
              <path d="M4 19h16" stroke-linecap="round" />
              <path d="M8 15l3.2-3.2 2.3 2.2L19 8" stroke-linecap="round" stroke-linejoin="round" />
            </svg>
          </span>
          <div>
            <h1>{{ t('externalAnalytics.title') }}</h1>
            <p>{{ t('externalAnalytics.subtitle') }}</p>
          </div>
        </div>
        <div class="xa-actions">
          <div class="xa-periods" role="tablist" :aria-label="t('externalAnalytics.period30')">
            <button
              v-for="option in periods"
              :key="option"
              type="button"
              role="tab"
              :aria-selected="days === option"
              :class="{ 'is-on': days === option }"
              @click="days = option"
            >
              {{ t(`externalAnalytics.period${option}`) }}
            </button>
          </div>
          <button type="button" class="xa-btn" :disabled="refreshing" @click="refresh">
            <AppIcon name="refresh" :size="16" />
            {{ t('externalAnalytics.refresh') }}
          </button>
        </div>
      </header>

      <section class="xa-kpis">
        <article class="xa-kpi">
          <span class="xa-kpi__icon xa-kpi__icon--revenue" aria-hidden="true">
            <svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" stroke-width="2">
              <path d="M12 3v18M7 8.5c0-1.8 2.2-3 5-3s5 1.2 5 3-2.2 2.5-5 2.5-5 .8-5 2.5 2.2 3 5 3 5-1.2 5-3" stroke-linecap="round" />
            </svg>
          </span>
          <div>
            <span>{{ t('externalAnalytics.revenue') }}</span>
            <strong><CountUp :value="Number(revenue ?? 0)" format="money" /></strong>
            <p :class="revenueDelta > 0 ? 'is-up' : revenueDelta < 0 ? 'is-down' : ''">
              <b>{{ signedPercent(revenueDelta) }}</b>
              {{ t('externalAnalytics.vsPrevious') }}
            </p>
          </div>
        </article>
        <article class="xa-kpi">
          <span class="xa-kpi__icon xa-kpi__icon--orders" aria-hidden="true">
            <svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" stroke-width="2">
              <path d="M6 7h12l-1 12H7L6 7z" stroke-linejoin="round" />
              <path d="M9 7V5a3 3 0 0 1 6 0v2" stroke-linecap="round" />
            </svg>
          </span>
          <div>
            <span>{{ t('externalAnalytics.totalOrders') }}</span>
            <strong><CountUp :value="Number(orderCount ?? 0)" /></strong>
            <p :class="orderDelta > 0 ? 'is-up' : orderDelta < 0 ? 'is-down' : ''">
              <b>{{ signedPercent(orderDelta) }}</b>
              {{ t('externalAnalytics.vsPrevious') }}
            </p>
          </div>
        </article>
        <article class="xa-kpi">
          <span class="xa-kpi__icon xa-kpi__icon--customers" aria-hidden="true">
            <svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" stroke-width="2">
              <circle cx="9" cy="9" r="3" />
              <path d="M4.5 18.5a5 5 0 0 1 9 0" stroke-linecap="round" />
              <circle cx="17" cy="10" r="2.2" />
              <path d="M16 18.5c.3-1.6 1.5-2.8 3.2-3.2" stroke-linecap="round" />
            </svg>
          </span>
          <div>
            <span>{{ t('externalAnalytics.uniqueCustomers') }}</span>
            <strong><CountUp :value="Number(uniqueCustomers ?? 0)" /></strong>
            <p>{{ t('externalAnalytics.uniqueShare', { pct: uniqueShare }) }}</p>
          </div>
        </article>
        <article class="xa-kpi">
          <span class="xa-kpi__icon xa-kpi__icon--basket" aria-hidden="true">
            <svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" stroke-width="2">
              <path d="M4 8h16l-1.4 10.2a2 2 0 0 1-2 1.8H7.4a2 2 0 0 1-2-1.8L4 8z" stroke-linejoin="round" />
              <path d="M8 8l1.5-3h5L16 8" stroke-linecap="round" stroke-linejoin="round" />
            </svg>
          </span>
          <div>
            <span>{{ t('externalAnalytics.averageBasket') }}</span>
            <strong><CountUp :value="Number(averageBasket ?? 0)" format="money" /></strong>
            <p>{{ t('externalAnalytics.averageHint') }}</p>
          </div>
        </article>
      </section>

      <div class="xa-layout">
        <section class="xa-panel xa-panel--trend" aria-labelledby="analytics-trend">
          <header class="xa-panel__head">
            <h2 id="analytics-trend">{{ t('externalAnalytics.dailyTrend') }}</h2>
            <span>{{ t(`externalAnalytics.period${days}`) }}</span>
          </header>
          <div class="xa-trend" role="img" :aria-label="t('externalAnalytics.dailyTrend')">
            <div v-for="(row, index) in trend.rows" :key="row.key" class="xa-trend__col">
              <div class="xa-trend__bar-wrap">
                <span
                  class="xa-trend__bar"
                  :class="{ 'is-empty': !row.amount, 'is-peak': trend.hasSeries && row.amount === trend.peak }"
                  :style="{ height: trend.peak ? `${Math.max(8, Math.round((row.amount / trend.peak) * 100))}%` : '8%' }"
                  :title="`${row.label} · ${money(row.amount)}`"
                />
              </div>
              <span v-if="showTrendLabel(index, trend.rows.length)" class="xa-trend__label">{{ row.label }}</span>
              <span v-else class="xa-trend__label xa-trend__label--blank" aria-hidden="true" />
            </div>
          </div>
          <p v-if="!trend.hasSeries" class="xa-note">{{ t('externalAnalytics.noTrend') }}</p>
        </section>

        <div class="xa-split">
          <section class="xa-panel" aria-labelledby="analytics-locations">
            <header class="xa-panel__head">
              <h2 id="analytics-locations">{{ t('externalAnalytics.topLocations') }}</h2>
            </header>
            <ul v-if="locations.length" class="xa-ranks">
              <li v-for="row in locations" :key="row.label">
                <div class="xa-ranks__top">
                  <span>{{ row.label }}</span>
                  <span>{{ t('externalAnalytics.ordersCount', { n: row.count }) }} · {{ row.share }}%</span>
                </div>
                <div class="xa-ranks__track" aria-hidden="true">
                  <span class="xa-ranks__fill xa-ranks__fill--locations" :style="{ width: `${row.share}%` }" />
                </div>
              </li>
            </ul>
            <p v-else class="xa-empty">{{ t('externalAnalytics.noLocations') }}</p>
          </section>

          <section class="xa-panel" aria-labelledby="analytics-types">
            <header class="xa-panel__head">
              <h2 id="analytics-types">{{ t('externalAnalytics.orderTypes') }}</h2>
            </header>
            <ul v-if="orderTypes.length" class="xa-ranks">
              <li v-for="row in orderTypes" :key="row.label">
                <div class="xa-ranks__top">
                  <span>{{ row.label }}</span>
                  <span>{{ t('externalAnalytics.ordersCount', { n: row.count }) }} · {{ row.share }}%</span>
                </div>
                <div class="xa-ranks__track" aria-hidden="true">
                  <span class="xa-ranks__fill xa-ranks__fill--types" :style="{ width: `${row.share}%` }" />
                </div>
              </li>
            </ul>
            <p v-else class="xa-empty">{{ t('externalAnalytics.noOrders') }}</p>
          </section>

          <section class="xa-panel" aria-labelledby="analytics-payments">
            <header class="xa-panel__head">
              <h2 id="analytics-payments">{{ t('externalAnalytics.paymentMethods') }}</h2>
            </header>
            <ul v-if="payments.length" class="xa-ranks">
              <li v-for="row in payments" :key="row.label">
                <div class="xa-ranks__top">
                  <span>{{ row.label }}</span>
                  <span>{{ t('externalAnalytics.ordersCount', { n: row.count }) }} · {{ row.share }}%</span>
                </div>
                <div class="xa-ranks__track" aria-hidden="true">
                  <span class="xa-ranks__fill xa-ranks__fill--payments" :style="{ width: `${row.share}%` }" />
                </div>
              </li>
            </ul>
            <p v-else class="xa-empty">{{ t('externalAnalytics.noPayments') }}</p>
          </section>
        </div>
      </div>
    </div>
  </PageFrame>
</template>

<style scoped>
.xa-root {
  --xa-bg: var(--color-canvas);
  --xa-card: var(--color-surface);
  --xa-line: var(--color-border);
  --xa-title: var(--color-text-primary);
  --xa-text: var(--color-text);
  --xa-muted: var(--color-text-muted);
  --xa-primary: var(--color-brand-600);
  --xa-up: var(--color-success);
  --xa-down: var(--color-danger);
  --xa-locations: var(--color-brand-600);
  --xa-types: var(--color-success);
  --xa-payments: #9a6412;
  box-sizing: border-box;
  display: flex;
  flex-direction: column;
  flex: 1 1 auto;
  align-self: stretch;
  width: 100%;
  min-height: 100%;
  padding: 22px 24px 24px;
  background: var(--xa-bg);
  color: var(--xa-text);
}

:global([data-theme='dark']) .xa-root {
  --xa-bg: #070b16;
  --xa-card: #151c2c;
  --xa-line: #2a3448;
  --xa-title: #f4f7ff;
  --xa-text: #e8eefc;
  --xa-muted: #9aa6bf;
  --xa-primary: #7c5cff;
  --xa-up: #3ddc97;
  --xa-down: #ffb4b4;
  --xa-locations: #b9a6ff;
  --xa-types: #3ddc97;
  --xa-payments: #f5a524;
}

.xa-root h1 {
  margin: 0;
  color: var(--xa-title);
  font-size: 1.45rem;
  font-weight: 800;
  letter-spacing: -0.03em;
  line-height: 1.15;
}

.xa-root p {
  margin: 0;
}

.xa-head {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  justify-content: space-between;
  gap: 16px;
}

.xa-brand {
  display: flex;
  align-items: center;
  gap: 12px;
  min-width: 0;
}

.xa-brand > div {
  min-width: 0;
}

.xa-brand p {
  margin-top: 2px;
  color: var(--xa-muted);
  font-size: 13px;
}

.xa-mark {
  display: grid;
  place-items: center;
  width: 46px;
  height: 46px;
  flex: 0 0 auto;
  border-radius: 14px;
  background: var(--xa-primary);
  color: #fff;
}

.xa-actions {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 8px;
}

.xa-periods {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
  padding: 4px;
  border: 1px solid var(--xa-line);
  border-radius: 14px;
  background: var(--xa-card);
}

.xa-periods button {
  height: 34px;
  padding: 0 12px;
  border: 0;
  border-radius: 10px;
  background: transparent;
  color: var(--xa-muted);
  font-size: 13px;
  font-weight: 700;
  cursor: pointer;
}

.xa-periods button.is-on {
  background: var(--xa-primary);
  color: #fff;
}

.xa-btn {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  height: 42px;
  padding: 0 14px;
  border-radius: 12px;
  border: 1px solid var(--xa-line);
  background: var(--xa-card);
  color: var(--xa-text);
  font-size: 13px;
  font-weight: 700;
  cursor: pointer;
}

.xa-btn:disabled {
  opacity: 0.45;
  cursor: not-allowed;
}

.xa-kpis {
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  gap: 12px;
  margin-top: 18px;
}

.xa-kpi {
  display: flex;
  align-items: flex-start;
  gap: 12px;
  min-width: 0;
  padding: 16px;
  border-radius: 16px;
  background: var(--xa-card);
  border: 1px solid var(--xa-line);
}

.xa-kpi__icon {
  display: grid;
  place-items: center;
  width: 36px;
  height: 36px;
  border-radius: 10px;
  flex: 0 0 auto;
}

.xa-kpi__icon--revenue { background: color-mix(in srgb, var(--xa-primary) 16%, transparent); color: var(--xa-primary); }
.xa-kpi__icon--orders { background: color-mix(in srgb, var(--xa-types) 16%, transparent); color: var(--xa-types); }
.xa-kpi__icon--customers { background: color-mix(in srgb, var(--xa-payments) 16%, transparent); color: var(--xa-payments); }
.xa-kpi__icon--basket { background: color-mix(in srgb, var(--xa-locations) 16%, transparent); color: var(--xa-locations); }

.xa-kpi div {
  min-width: 0;
}

.xa-kpi > div > span {
  display: block;
  color: var(--xa-muted);
  font-size: 12px;
  font-weight: 650;
}

.xa-kpi strong {
  display: block;
  margin-top: 4px;
  color: var(--xa-title);
  font-size: 1.45rem;
  font-weight: 800;
  letter-spacing: -0.03em;
  line-height: 1.1;
  font-variant-numeric: tabular-nums;
}

.xa-kpi p {
  margin-top: 6px;
  color: var(--xa-muted);
  font-size: 12px;
  line-height: 1.35;
}

.xa-kpi b {
  margin-right: 4px;
  font-variant-numeric: tabular-nums;
}

.xa-kpi p.is-up b { color: var(--xa-up); }
.xa-kpi p.is-down b { color: var(--xa-down); }

.xa-layout {
  display: grid;
  grid-template-rows: minmax(280px, 1.2fr) minmax(220px, 0.9fr);
  gap: 12px;
  flex: 1 1 auto;
  min-height: 0;
  margin-top: 16px;
}

.xa-split {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 12px;
  min-height: 0;
}

.xa-panel {
  display: flex;
  flex-direction: column;
  min-width: 0;
  min-height: 0;
  padding: 16px 16px 14px;
  border-radius: 18px;
  background: var(--xa-card);
  border: 1px solid var(--xa-line);
}

.xa-panel__head {
  display: flex;
  align-items: baseline;
  justify-content: space-between;
  gap: 12px;
}

.xa-panel h2 {
  margin: 0;
  color: var(--xa-title);
  font-size: 15px;
  font-weight: 800;
  letter-spacing: -0.02em;
}

.xa-panel__head span {
  color: var(--xa-muted);
  font-size: 12px;
  font-weight: 650;
}

.xa-root .xa-note,
.xa-root .xa-empty {
  margin: 10px 0 0;
  color: var(--xa-muted);
  font-size: 13px;
}

.xa-root .xa-empty {
  display: grid;
  flex: 1;
  place-items: center;
  margin: 0;
  padding: 24px 8px;
  text-align: center;
}

.xa-trend {
  display: flex;
  align-items: flex-end;
  gap: 3px;
  flex: 1;
  min-height: 160px;
  margin-top: 14px;
  padding-top: 8px;
  border-bottom: 1px solid var(--xa-line);
}

.xa-trend__col {
  display: flex;
  flex: 1 1 0;
  flex-direction: column;
  align-items: center;
  height: 100%;
  min-width: 0;
  gap: 6px;
}

.xa-trend__bar-wrap {
  display: flex;
  flex: 1;
  align-items: flex-end;
  width: 100%;
  min-height: 0;
}

.xa-trend__bar {
  width: 68%;
  margin-inline: auto;
  border-radius: 5px 5px 2px 2px;
  background: var(--xa-primary);
  min-height: 4px;
}

.xa-trend__bar.is-peak {
  background: var(--xa-types);
}

.xa-trend__bar.is-empty {
  background: var(--xa-line);
}

.xa-trend__label {
  max-width: 100%;
  overflow: hidden;
  color: var(--xa-muted);
  font-size: 10px;
  line-height: 1;
  white-space: nowrap;
}

.xa-trend__label--blank {
  height: 10px;
}

.xa-ranks {
  display: flex;
  flex-direction: column;
  gap: 12px;
  margin: 14px 0 0;
  padding: 0;
  list-style: none;
  overflow: auto;
}

.xa-ranks__top {
  display: flex;
  justify-content: space-between;
  gap: 12px;
  color: var(--xa-title);
  font-size: 13px;
  font-weight: 650;
}

.xa-ranks__top span:last-child {
  color: var(--xa-muted);
  font-weight: 600;
  font-variant-numeric: tabular-nums;
  white-space: nowrap;
}

.xa-ranks__track {
  height: 6px;
  margin-top: 6px;
  border-radius: 999px;
  background: color-mix(in srgb, var(--xa-line) 80%, transparent);
  overflow: hidden;
}

.xa-ranks__fill {
  display: block;
  height: 100%;
  border-radius: inherit;
}

.xa-ranks__fill--locations { background: var(--xa-locations); }
.xa-ranks__fill--types { background: var(--xa-types); }
.xa-ranks__fill--payments { background: var(--xa-payments); }

@media (max-width: 1100px) {
  .xa-kpis,
  .xa-split {
    grid-template-columns: 1fr 1fr;
  }

  .xa-split .xa-panel:last-child {
    grid-column: 1 / -1;
  }
}

@media (max-width: 720px) {
  .xa-kpis,
  .xa-split {
    grid-template-columns: 1fr;
  }

  .xa-layout {
    grid-template-rows: auto auto;
  }

  .xa-split .xa-panel:last-child {
    grid-column: auto;
  }
}
</style>
