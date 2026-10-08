<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import PageFrame from '../../../components/layout/PageFrame.vue'
import AppModal from '../../../components/ui/AppModal.vue'
import Badge from '../../../components/ui/Badge.vue'
import { intlLocale } from '../../../i18n/locales'
import { useContextStore } from '../../../stores/context'
import {
  cloneMobileOrders,
  nextStatuses,
  type MobileOrder,
  type OrderStatus,
  type PaymentStatus,
} from './mobileOrdersData'

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

const actionLabel: Record<OrderStatus, string> = {
  new: 'markNew',
  processing: 'startPreparing',
  completed: 'markCompleted',
  cancelled: 'markCancelled',
}

const { t, locale } = useI18n()
const context = useContextStore()
const orders = ref<MobileOrder[]>([])
const query = ref('')
const status = ref<OrderStatus | ''>('')
const payment = ref<PaymentStatus | ''>('')
const refreshing = ref(false)
const selected = ref<MobileOrder | null>(null)
const loaded = ref(false)

const paidRevenue = computed(() =>
  orders.value.filter(order => order.payment === 'paid').reduce((sum, order) => sum + order.amount, 0),
)

const stats = computed(() => [
  { key: '' as const, label: t('mobileOrdersPage.total'), value: orders.value.length },
  ...statusKeys.map(key => ({
    key,
    label: t(`mobileOrdersPage.${key}`),
    value: orders.value.filter(order => order.status === key).length,
  })),
])

const visible = computed(() => {
  const q = query.value.trim().toLowerCase()
  return orders.value.filter(order => {
    if (status.value && order.status !== status.value) return false
    if (payment.value && order.payment !== payment.value) return false
    if (!q) return true
    return (
      order.reference.toLowerCase().includes(q)
      || order.customer.toLowerCase().includes(q)
      || order.phone.toLowerCase().includes(q)
      || (order.table ?? '').toLowerCase().includes(q)
    )
  })
})

const selectedActions = computed(() =>
  selected.value ? nextStatuses(selected.value.status) : [],
)

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

function typeLabel(order: MobileOrder) {
  return t(`mobileOrdersPage.${order.type === 'dine_in' ? 'dineIn' : order.type}`)
}

function selectStatus(key: OrderStatus | '') {
  status.value = status.value === key ? '' : key
}

function openOrder(order: MobileOrder) {
  selected.value = order
}

function setStatus(next: OrderStatus) {
  if (!selected.value) return
  const target = orders.value.find(order => order.id === selected.value?.id)
  if (!target) return
  target.status = next
  if (next === 'cancelled' && target.payment === 'unpaid') {
    // keep unpaid
  }
  selected.value = { ...target, lines: target.lines.map(line => ({ ...line })) }
}

function loadOrders() {
  orders.value = cloneMobileOrders()
  loaded.value = true
}

function refresh() {
  if (refreshing.value) return
  refreshing.value = true
  query.value = ''
  status.value = ''
  payment.value = ''
  selected.value = null
  window.setTimeout(() => {
    loadOrders()
    refreshing.value = false
  }, 280)
}

onMounted(loadOrders)
</script>

<template>
  <PageFrame>
    <template #title>{{ t('mobileOrdersPage.title') }}</template>
    <template #subtitle>{{ t('mobileOrdersPage.subtitle') }}</template>

    <div class="orders" :aria-busy="refreshing">
      <div class="orders__toolbar">
        <button type="button" class="btn-secondary" :disabled="refreshing" @click="refresh">
          {{ t('mobileOrdersPage.refresh') }}
        </button>
        <p class="orders__revenue">
          <span>{{ t('mobileOrdersPage.paidRevenue') }}</span>
          <strong>{{ money(paidRevenue) }}</strong>
        </p>
      </div>

      <section class="orders__stats">
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
            <tr v-if="loaded && !visible.length">
              <td class="orders__empty" colspan="8">{{ t('mobileOrdersPage.empty') }}</td>
            </tr>
            <tr v-for="order in visible" :key="order.id">
              <td class="orders__id">{{ order.reference }}</td>
              <td>
                <p class="orders__name">{{ order.customer }}</p>
                <p class="orders__meta">{{ itemsLabel(order.lines.length) }} · {{ order.phone }}</p>
              </td>
              <td>
                <p class="orders__name">{{ typeLabel(order) }}</p>
                <p v-if="order.table" class="orders__meta">{{ t('mobileOrdersPage.table', { name: order.table }) }}</p>
                <p v-else-if="order.address" class="orders__meta">{{ order.address }}</p>
              </td>
              <td class="orders__amount">{{ money(order.amount) }}</td>
              <td><Badge :variant="statusTone[order.status]">{{ t(`mobileOrdersPage.${order.status}`) }}</Badge></td>
              <td><Badge :variant="paymentTone[order.payment]">{{ t(`mobileOrdersPage.${order.payment}`) }}</Badge></td>
              <td class="orders__when">{{ when(order.at) }}</td>
              <td>
                <button type="button" class="btn-secondary orders__view" @click="openOrder(order)">
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
      :title="selected ? `${t('mobileOrdersPage.orderNumber')} ${selected.reference}` : ''"
      :subtitle="selected ? selected.customer : ''"
      size="md"
      icon="receipt"
      @close="selected = null"
    >
      <div v-if="selected" class="orders__detail">
        <dl class="orders__facts">
          <div>
            <dt>{{ t('mobileOrdersPage.customer') }}</dt>
            <dd>{{ selected.customer }}</dd>
          </div>
          <div>
            <dt>{{ t('mobileOrdersPage.phone') }}</dt>
            <dd>{{ selected.phone }}</dd>
          </div>
          <div>
            <dt>{{ t('mobileOrdersPage.type') }}</dt>
            <dd>
              {{ typeLabel(selected) }}
              <template v-if="selected.table"> · {{ t('mobileOrdersPage.table', { name: selected.table }) }}</template>
            </dd>
          </div>
          <div v-if="selected.address">
            <dt>{{ t('mobileOrdersPage.address') }}</dt>
            <dd>{{ selected.address }}</dd>
          </div>
          <div>
            <dt>{{ t('mobileOrdersPage.status') }}</dt>
            <dd><Badge :variant="statusTone[selected.status]">{{ t(`mobileOrdersPage.${selected.status}`) }}</Badge></dd>
          </div>
          <div>
            <dt>{{ t('mobileOrdersPage.payment') }}</dt>
            <dd><Badge :variant="paymentTone[selected.payment]">{{ t(`mobileOrdersPage.${selected.payment}`) }}</Badge></dd>
          </div>
          <div>
            <dt>{{ t('mobileOrdersPage.amount') }}</dt>
            <dd>{{ money(selected.amount) }}</dd>
          </div>
          <div>
            <dt>{{ t('mobileOrdersPage.date') }}</dt>
            <dd>{{ when(selected.at) }}</dd>
          </div>
          <div v-if="selected.notes" class="orders__facts-full">
            <dt>{{ t('mobileOrdersPage.notes') }}</dt>
            <dd>{{ selected.notes }}</dd>
          </div>
        </dl>

        <section class="orders__lines" aria-labelledby="mobile-order-lines">
          <h3 id="mobile-order-lines">{{ t('mobileOrdersPage.lines') }}</h3>
          <table class="ui-table">
            <thead>
              <tr>
                <th>{{ t('mobileOrdersPage.lineItem') }}</th>
                <th>{{ t('mobileOrdersPage.qty') }}</th>
                <th>{{ t('mobileOrdersPage.unitPrice') }}</th>
                <th>{{ t('mobileOrdersPage.lineTotal') }}</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="(line, index) in selected.lines" :key="`${selected.id}-${index}`">
                <td>
                  <p class="orders__name">{{ line.name }}</p>
                  <p v-if="line.notes" class="orders__meta">{{ line.notes }}</p>
                </td>
                <td>{{ line.quantity }}</td>
                <td>{{ money(line.unit_price) }}</td>
                <td>{{ money(line.quantity * line.unit_price) }}</td>
              </tr>
            </tbody>
          </table>
        </section>

        <div v-if="selectedActions.length" class="orders__actions">
          <button
            v-for="next in selectedActions"
            :key="next"
            type="button"
            :class="next === 'cancelled' ? 'btn-secondary' : 'btn-primary'"
            @click="setStatus(next)"
          >
            {{ t(`mobileOrdersPage.${actionLabel[next]}`) }}
          </button>
        </div>
      </div>
    </AppModal>
  </PageFrame>
</template>

<style scoped>
.orders {
  display: flex;
  flex-direction: column;
  gap: var(--space-5);
  width: 100%;
  min-height: calc(100vh - 11rem);
}

.orders__toolbar {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  justify-content: space-between;
  gap: var(--space-3);
}

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
  background: var(--color-table-header);
}

.orders__stat.is-on {
  background: var(--color-canvas);
  box-shadow: inset 0 -2px 0 #1c2430;
}

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
  flex: 1;
  overflow: auto;
  border: 1px solid var(--color-border);
  border-radius: 12px;
  background: var(--color-surface);
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
  gap: var(--space-5);
}

.orders__facts {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 0.85rem 1rem;
  margin: 0;
}

.orders__facts div,
.orders__facts-full {
  display: grid;
  gap: 0.25rem;
}

.orders__facts-full {
  grid-column: 1 / -1;
}

.orders__facts dt {
  margin: 0;
  font-size: var(--text-sm);
  color: var(--color-text-muted);
}

.orders__facts dd {
  margin: 0;
  font-size: var(--text-sm);
  font-weight: 600;
  color: var(--color-text-primary);
}

.orders__lines h3 {
  margin: 0 0 0.75rem;
  font-size: var(--text-sm);
  font-weight: 650;
  color: var(--color-text-primary);
}

.orders__actions {
  display: flex;
  flex-wrap: wrap;
  gap: 0.5rem;
  justify-content: flex-end;
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

  .orders__facts {
    grid-template-columns: 1fr;
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
