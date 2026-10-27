<script setup lang="ts">
import { computed, onMounted, onUnmounted, ref } from 'vue'
import CountUp from '../../../components/motion/CountUp.vue'
import { useI18n } from 'vue-i18n'
import { RouterLink } from 'vue-router'
import PageFrame from '../../../components/layout/PageFrame.vue'
import { useAuthStore } from '../../../stores/auth'
import { useContextStore } from '../../../stores/context'
import AppIcon from '../../../components/ui/AppIcon.vue'

const LINKS = '/admin/customer-hub/linked-users'
const REQUESTS = '/admin/customer-hub/link-requests'
const ORDERS = '/admin/customer-hub/mobile-orders'
const PAYMENTS = '/admin/customer-hub/payments'

const { t, locale } = useI18n()
const auth = useAuthStore()
const context = useContextStore()
const refreshing = ref(false)
const now = ref(new Date())

let clock: number | undefined

const money = computed(() => `0 ${context.currencyCode || 'BIF'}`)
const firstName = computed(() => auth.user?.name?.split(' ')[0] ?? '')
const storeName = computed(() => context.currentStore?.name ?? '')

const greeting = computed(() => {
  if (!firstName.value) return t('dashboard.welcome')
  const hour = now.value.getHours()
  const key = hour < 12 ? 'dashboard.morning' : hour < 18 ? 'dashboard.afternoon' : 'dashboard.evening'
  return t(key, { name: firstName.value })
})

const clockLabel = computed(() =>
  new Intl.DateTimeFormat(locale.value || undefined, { hour: '2-digit', minute: '2-digit' }).format(now.value),
)

const rooms = computed(() => [
  {
    to: REQUESTS,
    title: t('customerHubPage.roomRequests'),
    hint: t('customerHubPage.roomRequestsHint'),
    count: '0',
    meta: t('customerHubPage.pendingRequests'),
    icon: 'note',
  },
  {
    to: LINKS,
    title: t('customerHubPage.roomLinks'),
    hint: t('customerHubPage.roomLinksHint'),
    count: '0',
    meta: t('customerHubPage.activeLinks'),
    icon: 'customers',
  },
  {
    to: ORDERS,
    title: t('customerHubPage.roomOrders'),
    hint: t('customerHubPage.roomOrdersHint'),
    count: '0',
    meta: t('customerHubPage.ordersToday'),
    icon: 'sales',
  },
  {
    to: PAYMENTS,
    title: t('customerHubPage.roomPayments'),
    hint: t('customerHubPage.roomPaymentsHint'),
    count: '0',
    meta: t('customerHubPage.totalPayments'),
    icon: 'card',
  },
])

const facts = computed(() => [
  { key: 'orders', label: t('customerHubPage.totalOrders'), value: '0' },
  { key: 'rejected', label: t('customerHubPage.rejectedLinks'), value: '0' },
  { key: 'payments', label: t('customerHubPage.totalPayments'), value: '0' },
  { key: 'revenue', label: t('customerHubPage.totalRevenue'), value: money.value },
])

function refresh() {
  if (refreshing.value) return
  refreshing.value = true
  now.value = new Date()
  window.setTimeout(() => {
    refreshing.value = false
  }, 350)
}

onMounted(() => {
  clock = window.setInterval(() => {
    now.value = new Date()
  }, 30000)
})

onUnmounted(() => {
  if (clock) window.clearInterval(clock)
})
</script>

<template>
  <PageFrame>
    <template #title>{{ t('customerHubPage.title') }}</template>
    <template #subtitle>{{ t('customerHubPage.subtitle') }}</template>

    <div class="hub" :class="{ 'is-refreshing': refreshing }">
      <header class="hello">
        <div>
          <p v-if="storeName" class="hello__where">{{ storeName }}</p>
          <h2 class="hello__title">{{ greeting }}</h2>
          <p class="hello__line">{{ t('customerHubPage.calm') }}</p>
        </div>
        <button type="button" class="hello__refresh" :disabled="refreshing" @click="refresh">
          <AppIcon name="refresh" :size="15" :class="{ 'is-spin': refreshing }" />
          {{ t('customerHubPage.refresh') }}
        </button>
      </header>

      <section class="day" :aria-busy="refreshing">
        <div class="day__copy">
          <p class="day__kicker">{{ t('customerHubPage.revenueToday') }}</p>
          <p class="day__amount"><CountUp :value="0" :suffix="' ' + (context.currencyCode || 'BIF')" /></p>
          <p class="day__hint">{{ t('customerHubPage.calmHint') }}</p>
        </div>
        <div class="day__now">
          <AppIcon name="clock" :size="16" />
          <strong>{{ clockLabel }}</strong>
        </div>
      </section>

      <section class="rooms" :aria-label="t('customerHubPage.quickActions')">
        <RouterLink v-for="room in rooms" :key="room.to" class="room" :to="room.to">
          <span class="room__icon" aria-hidden="true"><AppIcon :name="room.icon" :size="18" /></span>
          <span class="room__count">{{ room.count }}</span>
          <span class="room__title">{{ room.title }}</span>
          <span class="room__hint">{{ room.hint }}</span>
          <span class="room__go">
            {{ t('customerHubPage.open') }}
            <AppIcon name="chevron-right" :size="14" />
          </span>
          <span class="room__meta">{{ room.meta }}</span>
        </RouterLink>
      </section>

      <section class="facts" :aria-label="t('customerHubPage.totalRevenue')">
        <article v-for="fact in facts" :key="fact.key" class="fact">
          <p class="fact__value">{{ fact.value }}</p>
          <p class="fact__label">{{ fact.label }}</p>
        </article>
      </section>
    </div>
  </PageFrame>
</template>

<style scoped>
.hub {
  display: flex;
  flex-direction: column;
  gap: 1.1rem;
}
.hub.is-refreshing { opacity: 0.72; }

.hello {
  display: flex;
  align-items: flex-end;
  justify-content: space-between;
  gap: 1rem;
}
.hello__where {
  margin: 0 0 0.2rem;
  font-size: 0.75rem;
  font-weight: 700;
  letter-spacing: 0.12em;
  text-transform: uppercase;
  color: var(--color-accent);
}
.hello__title {
  margin: 0;
  font-family: var(--font-display);
  font-size: clamp(1.55rem, 2.2vw, 2rem);
  font-weight: 650;
  letter-spacing: -0.03em;
  line-height: 1.1;
  color: var(--color-text-primary);
}
.hello__line {
  margin: 0.35rem 0 0;
  color: var(--color-text-secondary);
  font-size: 0.95rem;
}
.hello__refresh {
  display: inline-flex;
  align-items: center;
  gap: 0.4rem;
  height: 2.25rem;
  padding: 0 0.85rem;
  border: 1px solid var(--color-border);
  border-radius: 999px;
  background: var(--color-surface);
  color: var(--color-text-primary);
  font: inherit;
  font-size: 0.82rem;
  font-weight: 650;
  cursor: pointer;
}
.hello__refresh:disabled { opacity: 0.6; cursor: default; }
.hello__refresh :deep(.is-spin) { animation: hub-spin 0.7s linear infinite; }

.day {
  display: flex;
  align-items: flex-end;
  justify-content: space-between;
  gap: 1.5rem;
  padding: 0.95rem 1.05rem;
  border: 1px solid var(--color-border);
  border-left: 6px solid var(--color-accent);
  border-radius: 18px;
  background: var(--color-surface);
  box-shadow: var(--shadow-xs);
}
.day__kicker {
  margin: 0;
  font-size: 0.75rem;
  font-weight: 700;
  letter-spacing: 0.08em;
  text-transform: uppercase;
  color: var(--color-text-muted);
}
.day__amount {
  margin: 0.2rem 0 0;
  font-family: var(--font-display);
  font-size: clamp(1.7rem, 2.6vw, 2.15rem);
  font-weight: 680;
  letter-spacing: -0.045em;
  line-height: 1;
  color: var(--color-text-primary);
}
.day__hint {
  margin: 0.7rem 0 0;
  max-width: 36ch;
  color: var(--color-text-secondary);
  font-size: 0.92rem;
  line-height: 1.4;
}
.day__now {
  display: flex;
  align-items: center;
  gap: 0.45rem;
  padding: 0.55rem 0.75rem;
  border-radius: 999px;
  background: var(--color-accent-soft);
  color: var(--color-text-primary);
  flex: none;
}
.day__now strong {
  font-variant-numeric: tabular-nums;
  font-size: 0.95rem;
}

.rooms {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 0.85rem;
}
.room {
  display: grid;
  grid-template-columns: auto 1fr auto;
  grid-template-areas:
    "icon count meta"
    "title title title"
    "hint hint hint"
    "go go go";
  column-gap: 0.7rem;
  row-gap: 0.05rem;
  padding: 0.7rem 0.85rem;
  border: 1px solid var(--color-border);
  border-radius: 14px;
  background: var(--color-surface);
  text-decoration: none;
  color: inherit;
  box-shadow: var(--shadow-xs);
}
.room:hover { border-color: var(--color-brand-600); }
.room__icon {
  grid-area: icon;
  display: grid;
  place-items: center;
  width: 2rem;
  height: 2rem;
  border-radius: 8px;
  background: var(--color-canvas);
  color: var(--color-text-primary);
}
.room__count {
  grid-area: count;
  font-family: var(--font-display);
  font-size: 1.15rem;
  font-weight: 700;
  letter-spacing: -0.03em;
  line-height: 1;
}
.room__meta {
  grid-area: meta;
  align-self: center;
  color: var(--color-text-muted);
  font-size: 0.72rem;
  text-align: right;
}
.room__title {
  grid-area: title;
  margin-top: 0.35rem;
  font-size: 0.92rem;
  font-weight: 700;
  letter-spacing: -0.02em;
}
.room__hint {
  grid-area: hint;
  color: var(--color-text-secondary);
  font-size: 0.8rem;
  line-height: 1.3;
}
.room__go {
  grid-area: go;
  display: inline-flex;
  align-items: center;
  gap: 0.2rem;
  margin-top: 0.25rem;
  font-size: 0.78rem;
  font-weight: 700;
  color: var(--color-text-primary);
}

.facts {
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  border: 1px solid var(--color-border);
  border-radius: 16px;
  background: var(--color-surface);
  overflow: hidden;
}
.fact {
  padding: 0.85rem 1rem;
  border-right: 1px solid var(--color-border);
}
.fact:last-child { border-right: 0; }
.fact__value {
  margin: 0;
  font-weight: 700;
  font-variant-numeric: tabular-nums;
  letter-spacing: -0.02em;
}
.fact__label {
  margin: 0.15rem 0 0;
  color: var(--color-text-muted);
  font-size: 0.78rem;
}

@keyframes hub-spin { to { transform: rotate(-360deg); } }

@media (max-width: 860px) {
  .rooms, .facts { grid-template-columns: 1fr 1fr; }
  .fact:nth-child(2) { border-right: 0; }
  .fact:nth-child(-n + 2) { border-bottom: 1px solid var(--color-border); }
}
@media (max-width: 640px) {
  .hello, .day { flex-direction: column; align-items: flex-start; }
  .rooms, .facts { grid-template-columns: 1fr; }
  .fact { border-right: 0; border-bottom: 1px solid var(--color-border); }
  .fact:last-child { border-bottom: 0; }
}
</style>
