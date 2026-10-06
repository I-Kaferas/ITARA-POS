<script setup lang="ts">
import { computed, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import { RouterLink } from 'vue-router'
import PageFrame from '../../../components/layout/PageFrame.vue'
import { useContextStore } from '../../../stores/context'

const LINKS = '/admin/customer-hub/linked-users'
const REQUESTS = '/admin/customer-hub/link-requests'
const ORDERS = '/admin/customer-hub/mobile-orders'
const PAYMENTS = '/admin/customer-hub/payments'

const { t } = useI18n()
const context = useContextStore()
const refreshing = ref(false)

const money = computed(() => `0 ${context.currencyCode || 'BIF'}`)

const stats = computed(() => [
  { key: 'active', label: t('customerHubPage.activeLinks'), value: '0', to: LINKS },
  { key: 'pending', label: t('customerHubPage.pendingRequests'), value: '0', to: REQUESTS },
  { key: 'rejected', label: t('customerHubPage.rejectedLinks'), value: '0', to: REQUESTS },
  { key: 'orders', label: t('customerHubPage.totalOrders'), value: '0', to: ORDERS },
  { key: 'ordersToday', label: t('customerHubPage.ordersToday'), value: '0', to: ORDERS },
  { key: 'payments', label: t('customerHubPage.totalPayments'), value: '0', to: PAYMENTS },
  { key: 'revenue', label: t('customerHubPage.totalRevenue'), value: money.value, to: '' },
  { key: 'revenueToday', label: t('customerHubPage.revenueToday'), value: money.value, to: '' },
])

const actions = computed(() => [
  { to: REQUESTS, label: t('customerHubPage.viewRequests') },
  { to: ORDERS, label: t('customerHubPage.viewOrders') },
  { to: PAYMENTS, label: t('customerHubPage.viewPayments') },
])

function refresh() {
  if (refreshing.value) return
  refreshing.value = true
  window.setTimeout(() => {
    refreshing.value = false
  }, 350)
}
</script>

<template>
  <PageFrame>
    <template #title>{{ t('customerHubPage.title') }}</template>
    <template #subtitle>{{ t('customerHubPage.subtitle') }}</template>

    <div class="hub">
      <div class="hub__toolbar">
        <button type="button" class="btn-secondary" :disabled="refreshing" @click="refresh">
          {{ t('customerHubPage.refresh') }}
        </button>
      </div>

      <section class="hub__stats" :aria-busy="refreshing">
        <article v-for="stat in stats" :key="stat.key" class="hub__stat">
          <p class="hub__label">{{ stat.label }}</p>
          <p class="hub__value">{{ stat.value }}</p>
          <RouterLink v-if="stat.to" class="hub__more" :to="stat.to">
            {{ t('customerHubPage.viewAll') }}
          </RouterLink>
        </article>
      </section>

      <section class="hub__block" aria-labelledby="hub-actions">
        <h2 id="hub-actions">{{ t('customerHubPage.quickActions') }}</h2>
        <div class="hub__actions">
          <RouterLink v-for="action in actions" :key="action.to" class="btn-secondary" :to="action.to">
            {{ action.label }}
          </RouterLink>
        </div>
      </section>

      <div class="hub__split">
        <section class="hub__block" aria-labelledby="hub-trend">
          <h2 id="hub-trend">{{ t('customerHubPage.orderTrend') }}</h2>
          <p class="hub__empty">{{ t('customerHubPage.empty') }}</p>
        </section>
        <section class="hub__block" aria-labelledby="hub-links">
          <h2 id="hub-links">{{ t('customerHubPage.linkDistribution') }}</h2>
          <p class="hub__empty">{{ t('customerHubPage.empty') }}</p>
        </section>
      </div>

      <div class="hub__split">
        <section class="hub__block" aria-labelledby="hub-requests">
          <div class="hub__head">
            <h2 id="hub-requests">{{ t('customerHubPage.recentRequests') }}</h2>
            <RouterLink class="hub__more" :to="REQUESTS">{{ t('customerHubPage.viewAll') }}</RouterLink>
          </div>
          <p class="hub__empty">{{ t('customerHubPage.empty') }}</p>
        </section>
        <section class="hub__block" aria-labelledby="hub-orders">
          <div class="hub__head">
            <h2 id="hub-orders">{{ t('customerHubPage.recentOrders') }}</h2>
            <RouterLink class="hub__more" :to="ORDERS">{{ t('customerHubPage.viewAll') }}</RouterLink>
          </div>
          <p class="hub__empty">{{ t('customerHubPage.empty') }}</p>
        </section>
      </div>

      <section class="hub__block" aria-labelledby="hub-payments">
        <div class="hub__head">
          <h2 id="hub-payments">{{ t('customerHubPage.recentPayments') }}</h2>
          <RouterLink class="hub__more" :to="PAYMENTS">{{ t('customerHubPage.viewAll') }}</RouterLink>
        </div>
        <div class="hub__table-wrap">
          <table class="ui-table">
            <thead>
              <tr>
                <th>{{ t('customerHubPage.reference') }}</th>
                <th>{{ t('customerHubPage.counterparty') }}</th>
                <th>{{ t('customerHubPage.amount') }}</th>
                <th>{{ t('customerHubPage.status') }}</th>
                <th>{{ t('customerHubPage.date') }}</th>
              </tr>
            </thead>
            <tbody>
              <tr>
                <td class="hub__empty-cell" colspan="5">{{ t('customerHubPage.empty') }}</td>
              </tr>
            </tbody>
          </table>
        </div>
      </section>
    </div>
  </PageFrame>
</template>

<style scoped>
.hub {
  display: flex;
  flex-direction: column;
  gap: var(--space-7);
  max-width: 72rem;
}

.hub__toolbar {
  display: flex;
}

.hub__stats {
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  border: 1px solid var(--color-border);
  border-radius: 12px;
  background: var(--color-surface);
  overflow: hidden;
}

.hub__stat {
  display: flex;
  flex-direction: column;
  align-items: flex-start;
  gap: 0.2rem;
  min-width: 0;
  min-height: 6.5rem;
  padding: var(--space-4) var(--space-5);
  border-right: 1px solid var(--color-border);
  border-bottom: 1px solid var(--color-border);
}

.hub__stat:nth-child(4n) {
  border-right: 0;
}

.hub__stat:nth-child(n + 5) {
  border-bottom: 0;
}

.hub__label {
  margin: 0;
  font-size: var(--text-sm);
  color: var(--color-text-muted);
}

.hub__value {
  margin: 0;
  font-size: 1.5rem;
  font-weight: 650;
  letter-spacing: -0.02em;
  font-variant-numeric: tabular-nums;
  line-height: 1.2;
  color: var(--color-text-primary);
}

.hub__more {
  margin-top: auto;
  font-size: var(--text-sm);
  font-weight: 600;
  color: var(--color-text-secondary);
  text-decoration: none;
}

.hub__more:hover {
  color: var(--color-text-primary);
  text-decoration: underline;
}

.hub__more:focus-visible {
  outline: 2px solid var(--color-text-primary);
  outline-offset: 2px;
  border-radius: 4px;
}

.hub__block h2 {
  margin: 0;
  font-size: var(--text-lg);
  font-weight: 650;
  letter-spacing: -0.01em;
  color: var(--color-text-primary);
}

.hub__head {
  display: flex;
  align-items: baseline;
  justify-content: space-between;
  gap: var(--space-3);
}

.hub__actions {
  display: flex;
  flex-wrap: wrap;
  gap: var(--space-2);
  margin-top: var(--space-3);
}

.hub__empty {
  margin: var(--space-3) 0 0;
  font-size: var(--text-sm);
  color: var(--color-text-muted);
}

.hub__split {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: var(--space-7);
}

.hub__table-wrap {
  margin-top: var(--space-3);
  overflow-x: auto;
  border-top: 1px solid var(--color-border);
}

.hub__empty-cell {
  color: var(--color-text-muted);
  font-weight: 450;
}

@media (max-width: 960px) {
  .hub__stats {
    grid-template-columns: 1fr 1fr;
  }

  .hub__stat:nth-child(4n) {
    border-right: 1px solid var(--color-border);
  }

  .hub__stat:nth-child(2n) {
    border-right: 0;
  }

  .hub__stat:nth-child(n + 5) {
    border-bottom: 1px solid var(--color-border);
  }

  .hub__stat:nth-last-child(-n + 2) {
    border-bottom: 0;
  }

  .hub__split {
    grid-template-columns: 1fr;
    gap: var(--space-6);
  }
}

@media (max-width: 560px) {
  .hub__stats {
    grid-template-columns: 1fr;
  }

  .hub__stat,
  .hub__stat:nth-child(2n),
  .hub__stat:nth-last-child(-n + 2) {
    border-right: 0;
    border-bottom: 1px solid var(--color-border);
  }

  .hub__stat:last-child {
    border-bottom: 0;
  }
}
</style>
