<script setup lang="ts">
import { computed, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import PageFrame from '../../../components/layout/PageFrame.vue'
import AppModal from '../../../components/ui/AppModal.vue'
import Badge from '../../../components/ui/Badge.vue'
import { intlLocale } from '../../../i18n/locales'
import { useContextStore } from '../../../stores/context'

type OrderType = 'dine_in' | 'takeaway' | 'delivery'
type OrderStatus = 'new' | 'processing' | 'completed' | 'cancelled'
type PaymentStatus = 'paid' | 'unpaid' | 'partial'

type MobileOrder = {
  id: string
  customer: string
  items: number
  type: OrderType
  table: string | null
  amount: number
  status: OrderStatus
  payment: PaymentStatus
  at: string
}

const orders: MobileOrder[] = [
  { id: '00001', customer: 'Jean Mobile', items: 3, type: 'dine_in', table: 'T5', amount: 45000, status: 'new', payment: 'paid', at: '2026-03-09T14:30:00' },
  { id: '00002', customer: 'Marie App', items: 2, type: 'takeaway', table: null, amount: 18500, status: 'processing', payment: 'paid', at: '2026-03-09T13:15:00' },
  { id: '00005', customer: 'Pierre Mobile', items: 5, type: 'dine_in', table: 'T2', amount: 72000, status: 'completed', payment: 'paid', at: '2026-03-08T21:45:00' },
  { id: '00004', customer: 'Alice App', items: 4, type: 'delivery', table: null, amount: 35000, status: 'completed', payment: 'paid', at: '2026-03-08T20:00:00' },
  { id: '00003', customer: 'Claude App', items: 1, type: 'dine_in', table: 'T8', amount: 12000, status: 'cancelled', payment: 'unpaid', at: '2026-03-08T16:20:00' },
  { id: '00010', customer: 'David App', items: 8, type: 'dine_in', table: 'T1', amount: 95000, status: 'completed', payment: 'paid', at: '2026-03-07T22:10:00' },
  { id: '00009', customer: 'Grace App', items: 2, type: 'takeaway', table: null, amount: 22000, status: 'completed', payment: 'partial', at: '2026-03-07T15:30:00' },
]

const statusKeys: OrderStatus[] = ['new', 'processing', 'completed', 'cancelled']
const paymentKeys: PaymentStatus[] = ['paid', 'unpaid', 'partial']

const statusTone: Record<OrderStatus, 'info' | 'warning' | 'success' | 'danger'> = {
  new: 'info',
  processing: 'warning',
  completed: 'success',
  cancelled: 'danger',
}

const paymentTone: Record<PaymentStatus, 'success' | 'neutral' | 'warning'> = {
  paid: 'success',
  unpaid: 'neutral',
  partial: 'warning',
}

const { t, locale } = useI18n()
const context = useContextStore()
const query = ref('')
const status = ref<OrderStatus | ''>('')
const payment = ref<PaymentStatus | ''>('')
const refreshing = ref(false)
const selected = ref<MobileOrder | null>(null)

const paidRevenue = computed(() =>
  orders.filter(order => order.payment === 'paid').reduce((sum, order) => sum + order.amount, 0),
)

const stats = computed(() => [
  { key: '' as const, label: t('mobileOrdersPage.total'), value: orders.length },
  ...statusKeys.map(key => ({
    key,
    label: t(`mobileOrdersPage.${key}`),
    value: orders.filter(order => order.status === key).length,
  })),
])

const visible = computed(() => {
  const q = query.value.trim().toLowerCase()
  return orders.filter(order => {
    if (status.value && order.status !== status.value) return false
    if (payment.value && order.payment !== payment.value) return false
    if (!q) return true
    return order.id.toLowerCase().includes(q) || order.customer.toLowerCase().includes(q)
  })
})

function money(amount: number) {
  const formatted = new Intl.NumberFormat(intlLocale(locale.value)).format(amount)
  return `${formatted} ${context.currencyCode || 'BIF'}`
}

function when(value: string) {
  const date = new Date(value)
  const loc = intlLocale(locale.value)
  const day = new Intl.DateTimeFormat(loc, { day: '2-digit', month: 'long', year: 'numeric' }).format(date)
  const time = new Intl.DateTimeFormat(loc, { hour: '2-digit', minute: '2-digit' }).format(date)
  return `${day}, ${time}`
}

function itemsLabel(count: number) {
  return count === 1
    ? t('mobileOrdersPage.itemOne', { n: count })
    : t('mobileOrdersPage.itemMany', { n: count })
}

function selectStatus(key: OrderStatus | '') {
  status.value = status.value === key ? '' : key
}

function refresh() {
  if (refreshing.value) return
  refreshing.value = true
  query.value = ''
  status.value = ''
  payment.value = ''
  window.setTimeout(() => {
    refreshing.value = false
  }, 350)
}
</script>

<template>
  <PageFrame>
    <template #title>{{ t('mobileOrdersPage.title') }}</template>
    <template #subtitle>{{ t('mobileOrdersPage.subtitle') }}</template>

    <div class="orders">
      <div class="orders__toolbar">
        <button type="button" class="btn-secondary" :disabled="refreshing" @click="refresh">
          {{ t('mobileOrdersPage.refresh') }}
        </button>
      </div>

      <section class="orders__stats" :aria-busy="refreshing">
        <button
          v-for="stat in stats"
          :key="stat.label"
          type="button"
          class="orders__stat"
          :class="{ 'is-on': status === stat.key }"
          :aria-pressed="status === stat.key"
          @click="selectStatus(stat.key)"
        >
          <span class="orders__value">{{ stat.value }}</span>
          <span class="orders__label">{{ stat.label }}</span>
        </button>
      </section>

      <p class="orders__revenue">
        <span>{{ t('mobileOrdersPage.paidRevenue') }}</span>
        <strong>{{ money(paidRevenue) }}</strong>
      </p>

      <div class="orders__filters">
        <label class="orders__search">
          <span class="sr-only">{{ t('mobileOrdersPage.search') }}</span>
          <input
            v-model="query"
            class="field"
            type="search"
            :placeholder="t('mobileOrdersPage.search')"
          />
        </label>
        <label>
          <span class="sr-only">{{ t('mobileOrdersPage.status') }}</span>
          <select v-model="status" class="field">
            <option value="">{{ t('mobileOrdersPage.allStatuses') }}</option>
            <option v-for="key in statusKeys" :key="key" :value="key">{{ t(`mobileOrdersPage.${key}`) }}</option>
          </select>
        </label>
        <label>
          <span class="sr-only">{{ t('mobileOrdersPage.payment') }}</span>
          <select v-model="payment" class="field">
            <option value="">{{ t('mobileOrdersPage.allPayments') }}</option>
            <option v-for="key in paymentKeys" :key="key" :value="key">{{ t(`mobileOrdersPage.${key}`) }}</option>
          </select>
        </label>
      </div>

      <div class="orders__table-wrap">
        <table class="ui-table">
          <thead>
            <tr>
              <th>{{ t('mobileOrdersPage.orderNumber') }}</th>
              <th>{{ t('mobileOrdersPage.customer') }}</th>
              <th>{{ t('mobileOrdersPage.type') }}</th>
              <th>{{ t('mobileOrdersPage.amount') }}</th>
              <th>{{ t('mobileOrdersPage.status') }}</th>
              <th>{{ t('mobileOrdersPage.payment') }}</th>
              <th>{{ t('mobileOrdersPage.date') }}</th>
              <th>{{ t('mobileOrdersPage.actions') }}</th>
            </tr>
          </thead>
          <tbody>
            <tr v-if="!visible.length">
              <td class="orders__empty" colspan="8">{{ t('mobileOrdersPage.empty') }}</td>
            </tr>
            <tr v-for="order in visible" :key="order.id">
              <td class="orders__id">{{ order.id }}</td>
              <td>
                <p class="orders__name">{{ order.customer }}</p>
                <p class="orders__meta">{{ itemsLabel(order.items) }}</p>
              </td>
              <td>
                <p class="orders__name">{{ t(`mobileOrdersPage.${order.type === 'dine_in' ? 'dineIn' : order.type}`) }}</p>
                <p v-if="order.table" class="orders__meta">{{ t('mobileOrdersPage.table', { name: order.table }) }}</p>
              </td>
              <td class="orders__amount">{{ money(order.amount) }}</td>
              <td><Badge :variant="statusTone[order.status]">{{ t(`mobileOrdersPage.${order.status}`) }}</Badge></td>
              <td><Badge :variant="paymentTone[order.payment]">{{ t(`mobileOrdersPage.${order.payment}`) }}</Badge></td>
              <td class="orders__when">{{ when(order.at) }}</td>
              <td>
                <button type="button" class="btn-secondary orders__view" @click="selected = order">
                  {{ t('mobileOrdersPage.view') }}
                </button>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>

    <AppModal
      :open="selected !== null"
      :title="selected ? selected.id : ''"
      :subtitle="selected ? selected.customer : ''"
      size="sm"
      icon="receipt"
      @close="selected = null"
    >
      <dl v-if="selected" class="orders__detail">
        <div>
          <dt>{{ t('mobileOrdersPage.type') }}</dt>
          <dd>
            {{ t(`mobileOrdersPage.${selected.type === 'dine_in' ? 'dineIn' : selected.type}`) }}
            <template v-if="selected.table"> · {{ t('mobileOrdersPage.table', { name: selected.table }) }}</template>
          </dd>
        </div>
        <div>
          <dt>{{ t('mobileOrdersPage.customer') }}</dt>
          <dd>{{ itemsLabel(selected.items) }}</dd>
        </div>
        <div>
          <dt>{{ t('mobileOrdersPage.amount') }}</dt>
          <dd>{{ money(selected.amount) }}</dd>
        </div>
        <div>
          <dt>{{ t('mobileOrdersPage.status') }}</dt>
          <dd>{{ t(`mobileOrdersPage.${selected.status}`) }}</dd>
        </div>
        <div>
          <dt>{{ t('mobileOrdersPage.payment') }}</dt>
          <dd>{{ t(`mobileOrdersPage.${selected.payment}`) }}</dd>
        </div>
        <div>
          <dt>{{ t('mobileOrdersPage.date') }}</dt>
          <dd>{{ when(selected.at) }}</dd>
        </div>
      </dl>
    </AppModal>
  </PageFrame>
</template>

<style scoped>
.orders {
  display: flex;
  flex-direction: column;
  gap: var(--space-5);
  max-width: 76rem;
}

.orders__toolbar,
.orders__filters {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: var(--space-2);
}

.orders__search {
  flex: 1;
  min-width: min(100%, 16rem);
}

.orders__search .field,
.orders__filters .field {
  width: 100%;
  min-width: 11rem;
}

.orders__stats {
  display: grid;
  grid-template-columns: repeat(5, minmax(0, 1fr));
  border: 1px solid var(--color-border);
  border-radius: 12px;
  background: var(--color-surface);
  overflow: hidden;
}

.orders__stat {
  display: flex;
  flex-direction: column;
  align-items: flex-start;
  gap: 0.15rem;
  min-width: 0;
  padding: var(--space-4) var(--space-5);
  border: 0;
  border-right: 1px solid var(--color-border);
  background: transparent;
  text-align: left;
  cursor: pointer;
}

.orders__stat:last-child {
  border-right: 0;
}

.orders__stat:hover {
  background: var(--color-table-header);}

.orders__stat.is-on {
  background: var(--color-canvas);
  box-shadow: inset 0 -2px 0 #1c2430;}

.orders__stat:focus-visible,
.orders__view:focus-visible {
  outline: 2px solid #1c2430;
  outline-offset: 2px;
}

.orders__value {
  font-size: 1.5rem;
  font-weight: 650;
  letter-spacing: -0.02em;
  font-variant-numeric: tabular-nums;
  line-height: 1.15;
  color: var(--color-text-primary);
}

.orders__label,
.orders__meta,
.orders__revenue span {
  font-size: var(--text-sm);
  color: var(--color-text-muted);
}

.orders__revenue {
  display: flex;
  flex-wrap: wrap;
  align-items: baseline;
  gap: 0.35rem 0.75rem;
  margin: 0;
}

.orders__revenue strong {
  font-size: 1.15rem;
  font-weight: 650;
  font-variant-numeric: tabular-nums;
  color: var(--color-text-primary);
}

.orders__table-wrap {
  overflow-x: auto;
  border-top: 1px solid var(--color-border);
}

.orders__id,
.orders__amount,
.orders__when {
  font-variant-numeric: tabular-nums;
  white-space: nowrap;
}

.orders__name {
  margin: 0;
  font-weight: 600;
  color: var(--color-text-primary);
}

.orders__meta {
  margin: 0.15rem 0 0;
}

.orders__empty {
  color: var(--color-text-muted);
  font-weight: 450;
}

.orders__view {
  min-height: 2rem;
  padding-inline: 0.75rem;
}

.orders__detail {
  display: grid;
  gap: 0.75rem;
  margin: 0;
}

.orders__detail div {
  display: grid;
  grid-template-columns: 8rem minmax(0, 1fr);
  gap: 0.75rem;
}

.orders__detail dt {
  margin: 0;
  font-size: var(--text-sm);
  color: var(--color-text-muted);
}

.orders__detail dd {
  margin: 0;
  font-size: var(--text-sm);
  font-weight: 600;
  color: var(--color-text-primary);
}

@media (max-width: 960px) {
  .orders__stats {
    grid-template-columns: 1fr 1fr;
  }

  .orders__stat {
    border-bottom: 1px solid var(--color-border);
  }

  .orders__stat:nth-child(2n) {
    border-right: 0;
  }

  .orders__stat:last-child {
    border-bottom: 0;
  }
}

@media (max-width: 520px) {
  .orders__stats {
    grid-template-columns: 1fr;
  }

  .orders__stat {
    border-right: 0;
  }
}
</style>
