<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import { useRouter } from 'vue-router'
import PageFrame from '../../../components/layout/PageFrame.vue'
import AppIcon from '../../../components/ui/AppIcon.vue'
import KpiCard from '../../../components/ui/KpiCard.vue'
import LoadingBlock from '../../../components/ui/LoadingBlock.vue'
import StatusBadge from '../../../components/organization/StatusBadge.vue'
import { extractApiErrorMessage } from '../../../api/client'
import { realtimeTopics, useRealtimeSync } from '../../../composables/useRealtimeSync'
import { useBackofficeStore } from '../../../stores/backoffice'
import { useContextStore } from '../../../stores/context'
import type { PosOverview } from '../../../types'
import { formatDate, formatMoney } from '../../../utils/format'

const { t } = useI18n()
const router = useRouter()
const store = useBackofficeStore()
const context = useContextStore()

const storeId = computed(() => context.currentStoreId)
const overview = ref<PosOverview | null>(null)
const loading = ref(false)
const error = ref('')

const openShifts = computed(() => store.cashierShifts.filter(s => s.status === 'open'))
const maxHourRevenue = computed(() =>
  Math.max(1, ...(overview.value?.sales_by_hour.map(h => h.revenue) ?? [1])),
)
const activeHours = computed(() =>
  (overview.value?.sales_by_hour ?? []).filter(h => h.sales_count > 0 || (h.hour >= 7 && h.hour <= 22)),
)

const cards = computed(() => [
  {
    key: 'shifts',
    title: t('nav.posShifts'),
    description: t('pointOfSale.overview.shiftsHint'),
    to: '/admin/pos/shifts',
    icon: 'account',
  },
  {
    key: 'tables',
    title: t('nav.restaurant'),
    description: t('pointOfSale.overview.tablesHint'),
    to: '/admin/hospitality',
    icon: 'tables',
  },
  {
    key: 'orders',
    title: t('nav.posOrders'),
    description: t('pointOfSale.overview.ordersHint'),
    to: '/admin/pos/orders',
    icon: 'sales',
  },
  {
    key: 'reservations',
    title: t('nav.posReservations'),
    description: t('pointOfSale.overview.reservationsHint'),
    to: '/admin/pos/reservations',
    icon: 'layers',
  },
])

async function load() {
  if (!storeId.value) return
  loading.value = true
  error.value = ''
  try {
    const [data] = await Promise.all([
      store.loadPosOverview(storeId.value),
      store.loadStoreCashierShifts(storeId.value),
      store.loadCurrentCashierShift(),
    ])
    overview.value = data
  } catch (e) {
    error.value = extractApiErrorMessage(e, t('pointOfSale.overview.loadError'))
  } finally {
    loading.value = false
  }
}

onMounted(load)
watch(storeId, load)
useRealtimeSync(realtimeTopics.posOverview, load)
</script>

<template>
  <PageFrame>
    <template #title>{{ t('nav.posOverview') }}</template>
    <template #subtitle>{{ t('pointOfSale.overview.subtitle') }}</template>

    <div v-if="!storeId" class="rounded-xl bg-amber-50 p-4 text-sm text-amber-800">
      {{ t('pos.selectStore') }}
    </div>

    <template v-else>
      <p v-if="error" class="mb-4 rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700">{{ error }}</p>

      <button type="button" class="connection-link" @click="router.push('/admin/settings')">
        <strong>{{ t('pointOfSale.overview.connection') }}</strong>
        <span>{{ t('pointOfSale.overview.connectionHint') }}</span>
      </button>

      <div class="hub-strip mb-6">
        <KpiCard
          :label="t('pointOfSale.overview.todaySales')"
          :value="overview?.kpis.sales_count ?? 0"
          icon="sales"
          accent="#059669"
          icon-bg="#ecfdf5"
        />
        <KpiCard
          :label="t('pointOfSale.overview.todayRevenue')"
          :value="formatMoney(overview?.kpis.revenue ?? 0)"
          icon="receipt"
          accent="var(--color-brand-600)"
          icon-bg="#e4edf2"
        />
        <KpiCard
          :label="t('pointOfSale.overview.currentShift')"
          :value="store.currentCashierShift ? t('pointOfSale.shifts.open') : t('pointOfSale.shifts.closed')"
          icon="shift"
          accent="#2563eb"
          icon-bg="#eff6ff"
          :delta="store.currentCashierShift ? formatDate(store.currentCashierShift.opened_at) : null"
          delta-tone="flat"
        />
        <KpiCard
          :label="t('pointOfSale.overview.openShifts')"
          :value="openShifts.length"
          icon="account"
          accent="#e39b2b"
          icon-bg="#f8efdc"
        />
      </div>

      <LoadingBlock v-if="loading" :label="t('common.loading')" class="mb-6" />

      <div v-else class="mb-6 grid gap-4 xl:grid-cols-2">
        <!-- Articles les plus vendus -->
        <section class="panel">
          <header class="panel__header">
            <h3 class="panel__title">{{ t('pointOfSale.overview.bestSellers') }}</h3>
            <span class="panel__meta">{{ t('pointOfSale.overview.today') }}</span>
          </header>
          <table v-if="overview?.best_selling_products.length" class="mini-table">
            <thead>
              <tr>
                <th>{{ t('products.name') }}</th>
                <th class="num">{{ t('pointOfSale.overview.qty') }}</th>
                <th class="num">{{ t('pointOfSale.overview.revenue') }}</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="(item, index) in overview.best_selling_products" :key="item.product_id ?? item.product_sku ?? index">
                <td>
                  <span class="rank">{{ index + 1 }}</span>
                  <span class="font-medium text-slate-800">{{ item.product_name }}</span>
                  <span v-if="item.product_sku" class="block text-xs text-slate-400">{{ item.product_sku }}</span>
                </td>
                <td class="num">{{ item.quantity }}</td>
                <td class="num font-medium">{{ formatMoney(item.revenue) }}</td>
              </tr>
            </tbody>
          </table>
          <p v-else class="panel__empty">{{ t('pointOfSale.overview.noBestSellers') }}</p>
        </section>

        <!-- Commandes récentes -->
        <section class="panel">
          <header class="panel__header">
            <h3 class="panel__title">{{ t('pointOfSale.overview.recentOrders') }}</h3>
            <button type="button" class="panel__link" @click="router.push('/admin/pos/orders')">
              {{ t('pointOfSale.overview.seeAll') }}
            </button>
          </header>
          <table v-if="overview?.recent_orders.length" class="mini-table">
            <thead>
              <tr>
                <th>{{ t('sales.reference') }}</th>
                <th>{{ t('nav.customers') }}</th>
                <th class="num">{{ t('products.price') }}</th>
              </tr>
            </thead>
            <tbody>
              <tr
                v-for="order in overview.recent_orders"
                :key="order.id"
                class="clickable"
                @click="router.push({ name: 'sale-detail', params: { id: order.id } })"
              >
                <td>
                  <span class="font-mono text-xs">{{ order.reference }}</span>
                  <span class="block text-xs text-slate-400">{{ formatDate(order.completed_at ?? order.created_at) }}</span>
                </td>
                <td>{{ order.customer?.name ?? '—' }}</td>
                <td class="num">
                  <div class="font-medium">{{ formatMoney(order.total, order.currency) }}</div>
                  <StatusBadge
                    class="mt-1"
                    :active="order.payment_status === 'paid'"
                    :label="order.payment_status"
                  />
                </td>
              </tr>
            </tbody>
          </table>
          <p v-else class="panel__empty">{{ t('pointOfSale.overview.noRecentOrders') }}</p>
        </section>

        <!-- Modes de paiement -->
        <section class="panel">
          <header class="panel__header">
            <h3 class="panel__title">{{ t('pointOfSale.overview.paymentMethods') }}</h3>
            <span class="panel__meta">{{ t('pointOfSale.overview.today') }}</span>
          </header>
          <div v-if="overview?.payment_methods.length" class="pay-list">
            <div v-for="method in overview.payment_methods" :key="method.payment_method" class="pay-row">
              <div class="pay-row__top">
                <span class="font-medium text-slate-800">{{ method.label }}</span>
                <span class="text-sm font-semibold">{{ formatMoney(method.amount) }}</span>
              </div>
              <div class="pay-row__bar">
                <span class="pay-row__fill" :style="{ width: `${method.share}%` }" />
              </div>
              <div class="pay-row__meta">
                <span>{{ method.count }} {{ t('pointOfSale.overview.transactions') }}</span>
                <span>{{ method.share }}%</span>
              </div>
            </div>
          </div>
          <p v-else class="panel__empty">{{ t('pointOfSale.overview.noPayments') }}</p>
        </section>

        <!-- Ventes par heure -->
        <section class="panel">
          <header class="panel__header">
            <h3 class="panel__title">{{ t('pointOfSale.overview.salesByHour') }}</h3>
            <span class="panel__meta">{{ t('pointOfSale.overview.today') }}</span>
          </header>
          <div v-if="overview && overview.kpis.sales_count > 0" class="hour-chart">
            <div
              v-for="bucket in activeHours"
              :key="bucket.hour"
              class="hour-col"
              :title="`${bucket.label} — ${bucket.sales_count} / ${formatMoney(bucket.revenue)}`"
            >
              <div class="hour-col__bar-wrap">
                <div
                  class="hour-col__bar"
                  :style="{ height: `${Math.max(bucket.revenue > 0 ? 8 : 2, (bucket.revenue / maxHourRevenue) * 100)}%` }"
                />
              </div>
              <span class="hour-col__label">{{ String(bucket.hour).padStart(2, '0') }}</span>
            </div>
          </div>
          <p v-else class="panel__empty">{{ t('pointOfSale.overview.noHourly') }}</p>
          <div v-if="overview && overview.kpis.sales_count > 0" class="hour-legend">
            <span>{{ t('pointOfSale.overview.peakHint') }}</span>
            <span class="font-medium">{{ formatMoney(maxHourRevenue === 1 ? 0 : maxHourRevenue) }}</span>
          </div>
        </section>
      </div>

      <div class="grid gap-4 sm:grid-cols-2">
        <button
          v-for="card in cards"
          :key="card.key"
          type="button"
          class="action-card"
          @click="router.push(card.to)"
        >
          <div class="action-card__icon">
            <AppIcon :name="card.icon" :size="18" />
          </div>
          <div class="min-w-0">
            <p class="action-card__title">{{ card.title }}</p>
            <p class="action-card__desc">{{ card.description }}</p>
          </div>
          <AppIcon name="chevron-right" :size="16" class="shrink-0 text-slate-400" />
        </button>
      </div>
    </template>
  </PageFrame>
</template>

<style scoped>
.connection-link {
  display: flex;
  flex-direction: column;
  gap: 0.15rem;
  width: 100%;
  margin-bottom: 1rem;
  padding: 0.85rem 1rem;
  border: 1px solid #c5d4df;
  border-radius: 0.75rem;
  background: #f4f8fb;
  text-align: left;
  cursor: pointer;
}
.connection-link strong { color: #1c2830; font-size: 0.9rem; }
.connection-link span { color: #5b6b78; font-size: 0.8rem; }
.stat-card {
  border: 1px solid #e2e8f0;
  border-radius: 0.75rem;
  background: #fff;
  padding: 1rem 1.125rem;
}

.stat-card__label {
  margin: 0;
  font-size: 0.75rem;
  font-weight: 500;
  color: #64748b;
}

.stat-card__value {
  margin: 0.35rem 0 0;
  font-size: 1.5rem;
  font-weight: 700;
  color: #0f172a;
  letter-spacing: -0.02em;
}

.stat-card__meta {
  margin: 0.25rem 0 0;
  font-size: 0.75rem;
  color: #94a3b8;
}

.panel {
  border: 1px solid #e2e8f0;
  border-radius: 0.75rem;
  background: #fff;
  overflow: hidden;
}

.panel__header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 0.75rem;
  padding: 0.875rem 1rem;
  border-bottom: 1px solid #f1f5f9;
}

.panel__title {
  margin: 0;
  font-size: 0.875rem;
  font-weight: 600;
  color: #0f172a;
}

.panel__meta,
.panel__link {
  font-size: 0.75rem;
  color: #64748b;
}

.panel__link {
  background: none;
  border: 0;
  cursor: pointer;
  color: var(--color-brand-600);
  font-weight: 500;
}

.panel__empty {
  margin: 0;
  padding: 2rem 1rem;
  text-align: center;
  font-size: 0.8125rem;
  color: #94a3b8;
}

.mini-table {
  width: 100%;
  border-collapse: collapse;
  font-size: 0.8125rem;
}

.mini-table th,
.mini-table td {
  padding: 0.7rem 1rem;
  text-align: left;
  border-bottom: 1px solid #f1f5f9;
  vertical-align: top;
}

.mini-table th {
  font-size: 0.6875rem;
  font-weight: 600;
  color: #64748b;
  text-transform: uppercase;
  letter-spacing: 0.04em;
  background: #f8fafc;
}

.mini-table .num { text-align: right; white-space: nowrap; }
.mini-table tr.clickable { cursor: pointer; }
.mini-table tr.clickable:hover { background: #f8fafc; }

.rank {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 1.25rem;
  height: 1.25rem;
  margin-right: 0.5rem;
  border-radius: 999px;
  background: #e4edf2;
  color: var(--color-brand-600);
  font-size: 0.6875rem;
  font-weight: 700;
}

.pay-list { padding: 0.75rem 1rem 1rem; display: grid; gap: 0.875rem; }
.pay-row__top,
.pay-row__meta {
  display: flex;
  justify-content: space-between;
  gap: 0.75rem;
  font-size: 0.8125rem;
}
.pay-row__meta { margin-top: 0.25rem; color: #94a3b8; font-size: 0.75rem; }
.pay-row__bar {
  margin-top: 0.4rem;
  height: 0.375rem;
  border-radius: 999px;
  background: #f1f5f9;
  overflow: hidden;
}
.pay-row__fill {
  display: block;
  height: 100%;
  border-radius: 999px;
  background: var(--color-brand-600);
}

.hour-chart {
  display: flex;
  align-items: flex-end;
  gap: 0.35rem;
  min-height: 10rem;
  padding: 1rem 1rem 0.5rem;
}
.hour-col {
  flex: 1;
  display: flex;
  flex-direction: column;
  align-items: center;
  min-width: 0;
}
.hour-col__bar-wrap {
  width: 100%;
  height: 8rem;
  display: flex;
  align-items: flex-end;
}
.hour-col__bar {
  width: 100%;
  border-radius: 0.3rem 0.3rem 0 0;
  background: var(--color-brand-600);
  min-height: 2px;
}
.hour-col__label {
  margin-top: 0.35rem;
  font-size: 0.625rem;
  color: #94a3b8;
}
.hour-legend {
  display: flex;
  justify-content: space-between;
  padding: 0 1rem 1rem;
  font-size: 0.75rem;
  color: #64748b;
}

.action-card {
  display: flex;
  align-items: center;
  gap: 0.875rem;
  width: 100%;
  border: 1px solid #e2e8f0;
  border-radius: 0.75rem;
  background: #fff;
  padding: 1rem;
  text-align: left;
  cursor: pointer;
  transition: border-color 0.15s ease, box-shadow 0.15s ease;
}

.action-card:hover {
  border-color: #c5d4df;
  box-shadow: 0 8px 24px rgba(15, 23, 42, 0.05);
}

.action-card__icon {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 2.25rem;
  height: 2.25rem;
  border-radius: 0.625rem;
  background: #e4edf2;
  color: var(--color-brand-600);
  flex-shrink: 0;
}

.action-card__title {
  margin: 0;
  font-size: 0.875rem;
  font-weight: 600;
  color: #0f172a;
}

.action-card__desc {
  margin: 0.2rem 0 0;
  font-size: 0.75rem;
  line-height: 1.35;
  color: #64748b;
}
</style>
