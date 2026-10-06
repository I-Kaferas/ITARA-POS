<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import { RouterLink } from 'vue-router'
import PurchasingLayout from '../../../components/purchasing/PurchasingLayout.vue'
import AppIcon from '../../../components/ui/AppIcon.vue'
import DataTableShell from '../../../components/ui/DataTableShell.vue'
import { useBackofficeStore } from '../../../stores/backoffice'
import type { Supplier, Warehouse } from '../../../types'
import { formatMoney } from '../../../utils/money'

const { t } = useI18n()
const store = useBackofficeStore()
const period = ref('month')
const from = ref('')
const to = ref('')
const supplierId = ref('')
const warehouseId = ref('')
const suppliers = ref<Supplier[]>([])
const warehouses = ref<Warehouse[]>([])
const data = ref<Record<string, any>>({})
const showFilters = ref(false)
const loading = ref(false)

function range() {
  const now = new Date()
  const end = now.toISOString().slice(0, 10)
  const start = new Date(now)
  if (period.value === 'today') return { from: end, to: end }
  if (period.value === 'week') { start.setDate(now.getDate() - 6); return { from: start.toISOString().slice(0, 10), to: end } }
  if (period.value === 'quarter') { start.setMonth(Math.floor(now.getMonth() / 3) * 3, 1); return { from: start.toISOString().slice(0, 10), to: end } }
  if (period.value === 'year') return { from: `${now.getFullYear()}-01-01`, to: end }
  if (period.value === 'custom') return { from: from.value, to: to.value }
  return { from: `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-01`, to: end }
}

async function load() {
  loading.value = true
  try {
    const dates = range()
    data.value = await store.loadPurchaseOverview({
      from: dates.from || undefined,
      to: dates.to || undefined,
      supplier_id: supplierId.value || undefined,
      warehouse_id: warehouseId.value || undefined,
    })
  } finally {
    loading.value = false
  }
}

onMounted(async () => {
  suppliers.value = await store.loadSuppliers()
  warehouses.value = await store.loadAllWarehouses()
  await load()
})

const signals = computed(() => [
  {
    to: '/admin/purchases/requisitions',
    label: t('purchases.hub.requisitions'),
    value: Number(data.value.pending_requisitions ?? 0),
    icon: 'note',
    tone: 'blue',
  },
  {
    to: '/admin/purchases/orders',
    label: t('purchases.hub.orders'),
    value: Number(data.value.open_orders ?? 0),
    icon: 'purchases',
    tone: 'green',
  },
  {
    to: '/admin/purchases/invoices',
    label: t('purchases.hub.invoices'),
    value: Number(data.value.unpaid_invoices ?? 0),
    icon: 'receipt',
    tone: 'red',
  },
])

const shortcuts = [
  { to: '/admin/purchases/requisitions', icon: 'note', key: 'requisitions' },
  { to: '/admin/purchases/proformas', icon: 'receipt', key: 'proformas' },
  { to: '/admin/purchases/orders', icon: 'purchases', key: 'orders' },
  { to: '/admin/purchases/invoices', icon: 'receipt', key: 'invoices' },
  { to: '/admin/purchases/payments', icon: 'coins', key: 'payments' },
  { to: '/admin/purchases/returns', icon: 'transfer', key: 'returns' },
] as const
</script>

<template>
  <PurchasingLayout>
    <div class="purchase-hub">
      <div class="purchase-hub__toolbar">
        <button type="button" class="ui-btn ui-btn--secondary" @click="showFilters = !showFilters">
          <AppIcon name="filter" :size="15" />
          {{ showFilters ? t('filters.hide') : t('filters.show') }}
        </button>
        <button type="button" class="ui-btn purchase-hub__refresh" :disabled="loading" @click="load">
          <AppIcon name="refresh" :size="15" :class="{ 'purchase-hub__spin': loading }" />
          {{ t('purchases.hub.refresh') }}
        </button>
      </div>

      <div v-show="showFilters" class="purchase-hub__filters">
        <select v-model="period" class="ui-select" @change="load">
          <option value="today">{{ t('purchases.hub.today') }}</option>
          <option value="week">{{ t('purchases.hub.week') }}</option>
          <option value="month">{{ t('purchases.hub.month') }}</option>
          <option value="quarter">{{ t('purchases.hub.quarter') }}</option>
          <option value="year">{{ t('purchases.hub.year') }}</option>
          <option value="custom">{{ t('purchases.hub.custom') }}</option>
        </select>
        <input v-if="period === 'custom'" v-model="from" type="date" class="ui-input" />
        <input v-if="period === 'custom'" v-model="to" type="date" class="ui-input" />
        <select v-model="supplierId" class="ui-select" @change="load">
          <option value="">{{ t('purchases.hub.allSuppliers') }}</option>
          <option v-for="supplier in suppliers" :key="supplier.id" :value="supplier.id">{{ supplier.name }}</option>
        </select>
        <select v-model="warehouseId" class="ui-select" @change="load">
          <option value="">{{ t('purchases.hub.allWarehouses') }}</option>
          <option v-for="warehouse in warehouses" :key="warehouse.id" :value="warehouse.id">{{ warehouse.name }}</option>
        </select>
      </div>

      <div class="signal-row stagger-in" :aria-busy="loading">
        <RouterLink
          v-for="card in signals"
          :key="card.to"
          :to="card.to"
          class="signal-tile"
          :class="`signal-tile--${card.tone}`"
        >
          <span>
            <span class="signal-tile__label">{{ card.label }}</span>
            <span class="signal-tile__value" :key="card.value">{{ card.value }}</span>
          </span>
          <span class="signal-tile__icon" aria-hidden="true">
            <AppIcon :name="card.icon" :size="22" />
          </span>
        </RouterLink>
      </div>

      <div class="metric-row stagger-in">
        <article class="metric-tile">
          <p class="metric-tile__label">{{ t('purchases.hub.outstanding') }}</p>
          <p class="metric-tile__value metric-tile__value--due" :key="String(data.amount_due ?? 0)">
            {{ formatMoney(Number(data.amount_due ?? 0)) }}
          </p>
        </article>
        <article class="metric-tile">
          <p class="metric-tile__label">{{ t('purchases.hub.kpi.month') }}</p>
          <p class="metric-tile__value metric-tile__value--month" :key="String(data.month_purchases ?? 0)">
            {{ formatMoney(Number(data.month_purchases ?? 0)) }}
          </p>
        </article>
      </div>

      <section class="purchase-hub__links">
        <h2 class="text-section-title">{{ t('purchases.hub.quickLinks') }}</h2>
        <div class="quick-grid stagger-in">
          <RouterLink
            v-for="link in shortcuts"
            :key="link.to"
            :to="link.to"
            class="quick-link"
          >
            <span class="quick-link__icon" aria-hidden="true">
              <AppIcon :name="link.icon" :size="18" />
            </span>
            <span class="quick-link__copy">
              <span class="quick-link__title">{{ t(`purchases.hub.${link.key}`) }}</span>
              <span class="quick-link__desc">{{ t(`purchases.hub.linkHint.${link.key}`) }}</span>
            </span>
            <AppIcon name="chevron-right" :size="16" class="quick-link__go" />
          </RouterLink>
        </div>
      </section>

      <DataTableShell
        :title="t('purchases.hub.topSuppliers')"
        :loading="loading"
        :empty="!loading && !(data.top_suppliers || []).length"
        :empty-title="t('org.empty')"
        empty-icon="suppliers"
        :loading-label="t('common.loading')"
      >
        <table class="ui-table">
          <thead>
            <tr>
              <th>{{ t('purchases.hub.supplier') }}</th>
              <th class="num">{{ t('purchases.hub.orderCount') }}</th>
              <th class="num">{{ t('purchases.hub.amount') }}</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="row in data.top_suppliers || []" :key="row.supplier_id">
              <td class="font-medium">{{ row.name || '—' }}</td>
              <td class="num">{{ row.orders }}</td>
              <td class="num font-medium">{{ formatMoney(row.amount) }}</td>
            </tr>
          </tbody>
        </table>
      </DataTableShell>
    </div>
  </PurchasingLayout>
</template>
