<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import PageFrame from '../../../components/layout/PageFrame.vue'
import AppIcon from '../../../components/ui/AppIcon.vue'
import Badge from '../../../components/ui/Badge.vue'
import { intlLocale } from '../../../i18n/locales'
import { useContextStore } from '../../../stores/context'
import {
  cloneCustomerPayments,
  clonePaymentTrend,
  type CustomerHubPayment,
  type PaymentStatus,
  type PaymentTrendPoint,
  type PaymentType,
} from './customerPaymentsData'
import ListPager from '../../../components/ui/ListPager.vue'
import { useClientPager } from '../../../composables/useClientPager'

const statusTone: Record<PaymentStatus, 'success' | 'warning' | 'danger'> = {
  completed: 'success',
  pending: 'warning',
  failed: 'danger',
}

const { t, locale } = useI18n()
const context = useContextStore()

const payments = ref<CustomerHubPayment[]>([])
const trend = ref<PaymentTrendPoint[]>([])
const query = ref('')
const status = ref<PaymentStatus | ''>('')
const type = ref<PaymentType | ''>('')
const refreshing = ref(false)
const loaded = ref(false)

const visible = computed(() => {
  const q = query.value.trim().toLowerCase()
  return payments.value.filter(row => {
    if (status.value && row.status !== status.value) return false
    if (type.value && row.type !== type.value) return false
    if (!q) return true
    return (
      row.reference.toLowerCase().includes(q)
      || row.customer.toLowerCase().includes(q)
      || row.description.toLowerCase().includes(q)
    )
  })
})
const { page, lastPage, total, perPage, paged, setPage } = useClientPager(visible)

const receivedTotal = computed(() =>
  payments.value
    .filter(row => row.status === 'completed' && row.amount > 0)
    .reduce((sum, row) => sum + row.amount, 0),
)

const transactionCount = computed(() => payments.value.length)

const refundsTotal = computed(() =>
  Math.abs(
    payments.value
      .filter(row => row.type === 'refund')
      .reduce((sum, row) => sum + row.amount, 0),
  ),
)

const feesTotal = computed(() =>
  payments.value
    .filter(row => row.status === 'completed')
    .reduce((sum, row) => sum + row.fee, 0),
)

const pendingCount = computed(() =>
  payments.value.filter(row => row.status === 'pending').length,
)

const trendMax = computed(() => Math.max(220_000, ...trend.value.map(p => p.amount), 1))

const yTicks = computed(() => [0, 55_000, 110_000, 165_000, 220_000])

function money(amount: number, withSign = false) {
  const abs = Math.abs(amount)
  const formatted = new Intl.NumberFormat(intlLocale(locale.value)).format(abs)
  const code = context.currencyCode || 'BIF'
  if (!withSign) return `${formatted} ${code}`
  const sign = amount < 0 ? '−' : '+'
  return `${sign}${formatted} ${code}`
}

function compactMoney(amount: number) {
  if (amount >= 1000) {
    const k = amount / 1000
    return `${k % 1 === 0 ? k.toFixed(0) : k.toFixed(0)}K`
  }
  return String(amount)
}

function when(value: string) {
  const date = new Date(value)
  const loc = intlLocale(locale.value)
  const day = new Intl.DateTimeFormat(loc, { day: '2-digit', month: 'long', year: 'numeric' }).format(date)
  const time = new Intl.DateTimeFormat(loc, { hour: '2-digit', minute: '2-digit' }).format(date)
  return `${day}, ${time}`
}

function statusLabel(value: PaymentStatus) {
  if (value === 'completed') return t('customerPaymentsPage.statusCompleted')
  if (value === 'pending') return t('customerPaymentsPage.statusPending')
  return t('customerPaymentsPage.statusFailed')
}

function typeLabel(value: PaymentType) {
  if (value === 'order') return t('customerPaymentsPage.typeOrder')
  if (value === 'tip') return t('customerPaymentsPage.typeTip')
  if (value === 'refund') return t('customerPaymentsPage.typeRefund')
  return t('customerPaymentsPage.typeDirect')
}

function initials(name: string) {
  return name
    .trim()
    .split(/\s+/)
    .slice(0, 2)
    .map(part => part[0]?.toUpperCase() ?? '')
    .join('')
}

function load() {
  payments.value = cloneCustomerPayments()
  trend.value = clonePaymentTrend()
  loaded.value = true
}

function refresh() {
  if (refreshing.value) return
  refreshing.value = true
  query.value = ''
  status.value = ''
  type.value = ''
  window.setTimeout(() => {
    load()
    refreshing.value = false
  }, 280)
}

onMounted(load)
</script>

<template>
  <PageFrame>
    <template #title>{{ t('customerPaymentsPage.title') }}</template>
    <template #subtitle>{{ t('customerPaymentsPage.subtitle') }}</template>

    <div class="pay" :class="{ 'is-refreshing': refreshing }" :aria-busy="refreshing">
      <section class="stage" :aria-label="t('customerPaymentsPage.kpis')">
        <article class="spot">
          <div class="spot__top">
            <p class="spot__kicker">{{ t('customerPaymentsPage.totalReceived') }}</p>
            <button type="button" class="spot__refresh" :disabled="refreshing" @click="refresh">
              <AppIcon name="refresh" :size="15" :class="{ 'is-spin': refreshing }" />
              {{ t('customerPaymentsPage.refresh') }}
            </button>
          </div>
          <p class="spot__amount">{{ money(receivedTotal) }}</p>
          <p class="spot__hint">{{ t('customerPaymentsPage.transactions', { n: transactionCount }) }}</p>
        </article>

        <div class="tiles">
          <article class="tile">
            <p class="tile__value">{{ money(refundsTotal) }}</p>
            <p class="tile__label">{{ t('customerPaymentsPage.refunds') }}</p>
            <p class="tile__hint">{{ t('customerPaymentsPage.refundsHint') }}</p>
          </article>
          <article class="tile">
            <p class="tile__value">{{ money(feesTotal) }}</p>
            <p class="tile__label">{{ t('customerPaymentsPage.fees') }}</p>
            <p class="tile__hint">{{ t('customerPaymentsPage.feesHint') }}</p>
          </article>
          <article class="tile">
            <p class="tile__value">{{ pendingCount }}</p>
            <p class="tile__label">{{ t('customerPaymentsPage.pending') }}</p>
            <p class="tile__hint">{{ t('customerPaymentsPage.pendingHint') }}</p>
          </article>
        </div>
      </section>

      <section class="panel" aria-labelledby="pay-trend">
        <h2 id="pay-trend">{{ t('customerPaymentsPage.trend') }}</h2>
        <div class="chart">
          <div class="chart__y" aria-hidden="true">
            <span v-for="tick in [...yTicks].reverse()" :key="tick">{{ compactMoney(tick) }}</span>
          </div>
          <div class="chart__bars">
            <div
              v-for="point in trend"
              :key="point.date"
              class="chart__col"
              :title="`${point.label}: ${money(point.amount)}`"
            >
              <div class="chart__track">
                <div
                  class="chart__bar"
                  :style="{ height: `${Math.max(8, (point.amount / trendMax) * 100)}%` }"
                />
              </div>
              <span class="chart__x">{{ point.label }}</span>
            </div>
          </div>
        </div>
      </section>

      <section class="panel ledger">
        <div class="filters">
          <label class="search">
            <span class="sr-only">{{ t('customerPaymentsPage.search') }}</span>
            <AppIcon name="search" :size="15" class="search__icon" />
            <input
              v-model="query"
              class="field search__input"
              type="search"
              :placeholder="t('customerPaymentsPage.search')"
            />
          </label>
          <label>
            <span class="sr-only">{{ t('customerPaymentsPage.status') }}</span>
            <select v-model="status" class="field">
              <option value="">{{ t('customerPaymentsPage.allStatuses') }}</option>
              <option value="completed">{{ t('customerPaymentsPage.statusCompleted') }}</option>
              <option value="pending">{{ t('customerPaymentsPage.statusPending') }}</option>
              <option value="failed">{{ t('customerPaymentsPage.statusFailed') }}</option>
            </select>
          </label>
          <label>
            <span class="sr-only">{{ t('customerPaymentsPage.type') }}</span>
            <select v-model="type" class="field">
              <option value="">{{ t('customerPaymentsPage.allTypes') }}</option>
              <option value="order">{{ t('customerPaymentsPage.typeOrder') }}</option>
              <option value="tip">{{ t('customerPaymentsPage.typeTip') }}</option>
              <option value="refund">{{ t('customerPaymentsPage.typeRefund') }}</option>
              <option value="direct">{{ t('customerPaymentsPage.typeDirect') }}</option>
            </select>
          </label>
        </div>

        <p v-if="loaded && !visible.length" class="empty">{{ t('customerPaymentsPage.empty') }}</p>
        <ul v-else class="rows">
          <li v-for="row in paged" :key="row.id" class="row">
            <span class="mark" aria-hidden="true">{{ initials(row.customer) }}</span>
            <div class="who">
              <p class="name">{{ row.customer }}</p>
              <p class="desc">{{ row.description }}</p>
              <p class="ref">{{ row.reference }} · {{ typeLabel(row.type) }}</p>
            </div>
            <Badge :variant="statusTone[row.status]">{{ statusLabel(row.status) }}</Badge>
            <div class="meta">
              <span class="amount" :class="{ 'is-out': row.amount < 0 }">{{ money(row.amount, true) }}</span>
              <span class="when">{{ when(row.at) }}</span>
            </div>
          </li>
        </ul>
        <ListPager
          v-if="visible.length"
          :page="page"
          :last-page="lastPage"
          :total="total"
          :per-page="perPage"
          @change="setPage"
        />
      </section>
    </div>
  </PageFrame>
</template>

<style scoped>
.pay {
  display: flex;
  flex-direction: column;
  gap: 1rem;
  min-width: 0;
}
.pay.is-refreshing { opacity: 0.72; }

.stage {
  display: grid;
  grid-template-columns: minmax(16rem, 22rem) minmax(0, 1fr);
  gap: 0.75rem;
  align-items: stretch;
}
.spot {
  display: flex;
  flex-direction: column;
  justify-content: space-between;
  gap: 0.7rem;
  padding: 0.95rem 1.05rem;
  border: 1px solid var(--color-border);
  border-left: 6px solid var(--color-accent);
  border-radius: 18px;
  background: var(--color-surface);
  box-shadow: var(--shadow-xs);
}
.spot__top { display: flex; align-items: center; justify-content: space-between; gap: 0.75rem; }
.spot__kicker {
  margin: 0;
  font-size: 0.75rem;
  font-weight: 700;
  letter-spacing: 0.08em;
  text-transform: uppercase;
  color: var(--color-text-muted);
}
.spot__refresh {
  display: inline-flex;
  align-items: center;
  gap: 0.35rem;
  height: 2rem;
  padding: 0 0.7rem;
  border: 1px solid var(--color-border);
  border-radius: 999px;
  background: var(--color-surface);
  color: var(--color-text-primary);
  font: inherit;
  font-size: 0.78rem;
  font-weight: 650;
  cursor: pointer;
}
.spot__refresh:disabled { opacity: 0.6; cursor: default; }
.spot__refresh :deep(.is-spin) { animation: pay-spin 0.7s linear infinite; }
.spot__amount {
  margin: 0;
  font-family: var(--font-display);
  font-size: clamp(1.7rem, 2.6vw, 2.15rem);
  font-weight: 680;
  letter-spacing: -0.045em;
  line-height: 1;
}
.spot__hint { margin: 0; color: var(--color-text-secondary); font-size: 0.86rem; }

.tiles {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 0.75rem;
}
.tile {
  display: flex;
  flex-direction: column;
  justify-content: center;
  gap: 0.15rem;
  min-height: 0;
  padding: 0.75rem 0.9rem;
  border: 1px solid var(--color-border);
  border-radius: 14px;
  background: var(--color-surface);
  box-shadow: var(--shadow-xs);
}
.tile__value {
  margin: 0;
  font-family: var(--font-display);
  font-size: 1.15rem;
  font-weight: 700;
  letter-spacing: -0.03em;
  line-height: 1.15;
}
.tile__label { margin: 0.15rem 0 0; font-size: 0.84rem; font-weight: 650; }
.tile__hint { margin: 0; color: var(--color-text-muted); font-size: 0.75rem; }

.panel {
  padding: 0.9rem 1rem 1rem;
  border: 1px solid var(--color-border);
  border-radius: 18px;
  background: var(--color-surface);
  box-shadow: var(--shadow-xs);
}
.panel h2 {
  margin: 0;
  font-size: 0.95rem;
  font-weight: 700;
  letter-spacing: -0.02em;
}
.chart {
  display: grid;
  grid-template-columns: 2.4rem minmax(0, 1fr);
  gap: 0.65rem;
  margin-top: 0.75rem;
  height: 8.5rem;
}
.chart__y {
  display: flex;
  flex-direction: column;
  justify-content: space-between;
  align-items: flex-end;
  padding-bottom: 1.15rem;
  font-size: 0.68rem;
  color: var(--color-text-muted);
  font-variant-numeric: tabular-nums;
}
.chart__bars {
  display: grid;
  grid-template-columns: repeat(6, minmax(0, 1fr));
  align-items: end;
  gap: 0.55rem;
  min-width: 0;
  border-bottom: 1px solid var(--color-border);
}
.chart__col {
  display: flex;
  flex-direction: column;
  align-items: center;
  height: 100%;
  min-width: 0;
  gap: 0.3rem;
}
.chart__track {
  flex: 1;
  width: 100%;
  display: flex;
  align-items: flex-end;
  justify-content: center;
}
.chart__bar {
  width: 1.15rem;
  border-radius: 6px 6px 2px 2px;
  background: var(--color-brand-600);
}
.chart__x {
  font-size: 0.68rem;
  color: var(--color-text-muted);
  white-space: nowrap;
}

.ledger { padding-bottom: 0.35rem; }
.filters {
  display: flex;
  flex-wrap: wrap;
  gap: 0.55rem;
  margin-bottom: 0.35rem;
}
.search { position: relative; flex: 1; min-width: min(100%, 16rem); }
.search__icon {
  position: absolute;
  left: 0.7rem;
  top: 50%;
  transform: translateY(-50%);
  color: var(--color-text-muted);
  pointer-events: none;
}
.search input.field { width: 100%; padding-left: 2.15rem !important; }
.filters .field { min-width: 10.5rem; }

.rows { list-style: none; margin: 0.35rem 0 0; padding: 0; }
.row {
  display: grid;
  grid-template-columns: auto minmax(0, 1fr) auto auto;
  gap: 0.85rem;
  align-items: center;
  padding: 0.75rem 0.15rem;
  border-top: 1px solid var(--color-border);
}
.mark {
  display: grid;
  place-items: center;
  width: 2.15rem;
  height: 2.15rem;
  border-radius: 10px;
  background: var(--color-canvas);
  color: var(--color-text-primary);
  font-size: 0.72rem;
  font-weight: 700;
  letter-spacing: 0.02em;
}
.who { min-width: 0; }
.name, .desc, .ref, .amount, .when { margin: 0; }
.name { font-weight: 700; letter-spacing: -0.02em; }
.desc, .ref, .when { color: var(--color-text-muted); font-size: 0.78rem; }
.desc {
  margin-top: 0.1rem;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.meta { text-align: right; }
.amount {
  display: block;
  font-weight: 700;
  font-variant-numeric: tabular-nums;
  letter-spacing: -0.02em;
}
.amount.is-out { color: var(--color-warning); }
.empty {
  margin: 1rem 0 0.6rem;
  color: var(--color-text-muted);
  text-align: center;
}

@keyframes pay-spin { to { transform: rotate(-360deg); } }

@media (max-width: 980px) {
  .stage, .tiles { grid-template-columns: 1fr 1fr; }
  .spot { grid-column: 1 / -1; }
}
@media (max-width: 720px) {
  .stage, .tiles, .row { grid-template-columns: 1fr; }
  .meta { text-align: left; }
  .mark { display: none; }
}
</style>
