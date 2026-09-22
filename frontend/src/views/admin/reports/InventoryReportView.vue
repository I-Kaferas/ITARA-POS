<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import ReportsLayout from '../../../components/reports/ReportsLayout.vue'
import AppIcon from '../../../components/ui/AppIcon.vue'
import FieldLabel from '../../../components/ui/FieldLabel.vue'
import { useBackofficeStore } from '../../../stores/backoffice'
import type { InventoryReport, Warehouse } from '../../../types'
import { formatDate, formatMoney } from '../../../utils/format'

type InventoryTab = 'overview' | 'movements' | 'aging' | 'turnover'

const { t } = useI18n()
const store = useBackofficeStore()

const report = ref<InventoryReport | null>(null)
const warehouses = ref<Warehouse[]>([])
const warehouseId = ref('')
const from = ref('')
const to = ref('')
const loading = ref(false)
const activeTab = ref<InventoryTab>('overview')

const tabs: { id: InventoryTab; labelKey: string; icon: string }[] = [
  { id: 'overview', labelKey: 'reports.inventoryAnalytics.tabs.overview', icon: 'dashboard' },
  { id: 'movements', labelKey: 'reports.inventoryAnalytics.tabs.movements', icon: 'transfer' },
  { id: 'aging', labelKey: 'reports.inventoryAnalytics.tabs.aging', icon: 'clock' },
  { id: 'turnover', labelKey: 'reports.inventoryAnalytics.tabs.turnover', icon: 'sparkles' },
]

const healthColors: Record<string, string> = {
  healthy: '#059669',
  low: '#d97706',
  out: '#dc2626',
  over: '#2563eb',
}

function localDate(date: Date) {
  const month = String(date.getMonth() + 1).padStart(2, '0')
  const day = String(date.getDate()).padStart(2, '0')
  return `${date.getFullYear()}-${month}-${day}`
}

function initDates() {
  const now = new Date()
  const start = new Date(now.getFullYear(), now.getMonth() - 2, 1)
  from.value = localDate(start)
  to.value = localDate(now)
}

async function load() {
  loading.value = true
  try {
    report.value = await store.loadInventoryReport({
      warehouse_id: warehouseId.value || undefined,
      from: from.value || undefined,
      to: to.value || undefined,
    })
  } finally {
    loading.value = false
  }
}

async function exportExcel() {
  await store.exportInventoryReport({
    warehouse_id: warehouseId.value || undefined,
    from: from.value || undefined,
    to: to.value || undefined,
  })
}

function exportPdf() {
  window.print()
}

const totalArticles = computed(() => report.value?.total_articles ?? report.value?.skus_in_stock ?? 0)
const stockValue = computed(() => report.value?.estimated_value ?? 0)
const lowStock = computed(() => report.value?.low_stock_count ?? 0)
const outOfStock = computed(() => report.value?.out_of_stock_count ?? 0)
const overstock = computed(() => report.value?.overstock_count ?? 0)

const stockHealth = computed(() => report.value?.stock_health ?? [
  { label: 'healthy', count: report.value?.healthy_count ?? 0 },
  { label: 'low', count: lowStock.value },
  { label: 'out', count: outOfStock.value },
  { label: 'over', count: overstock.value },
])

const healthTotal = computed(() => Math.max(1, stockHealth.value.reduce((sum, row) => sum + row.count, 0)))

const healthDonut = computed(() => {
  let cursor = 0
  const stops = stockHealth.value.map(row => {
    const start = (cursor / healthTotal.value) * 100
    cursor += row.count
    const end = (cursor / healthTotal.value) * 100
    const color = healthColors[row.label] ?? '#64748b'
    return `${color} ${start}% ${end}%`
  })
  return `conic-gradient(${stops.join(', ')})`
})

const dominantHealth = computed(() => {
  const sorted = [...stockHealth.value].sort((a, b) => b.count - a.count)
  return sorted[0] ?? null
})

const byCategory = computed(() => report.value?.by_category ?? [])
const categoryMax = computed(() => Math.max(1, ...byCategory.value.map(r => r.value)))

const byWarehouse = computed(() => report.value?.by_warehouse ?? [])
const warehouseMax = computed(() => Math.max(1, ...byWarehouse.value.map(r => r.value)))

const stockLevels = computed(() => report.value?.stock_levels ?? [])
const aging = computed(() => report.value?.aging ?? [])
const agingMax = computed(() => Math.max(1, ...aging.value.map(r => r.count)))
const turnover = computed(() => report.value?.turnover ?? [])

const statusLabel = (key: string) => {
  const path = `reports.inventoryAnalytics.status.${key}`
  const translated = t(path)
  return translated === path ? key : translated
}

const agingLabel = (key: string) => {
  const path = `reports.inventoryAnalytics.agingBuckets.${key}`
  const translated = t(path)
  return translated === path ? key : translated
}

const movementLabel = (type: string) => {
  const map: Record<string, string> = {
    INITIAL_STOCK: 'initial',
    OPENING: 'opening',
    PURCHASE: 'purchase',
    SALE: 'sale',
    SALE_RETURN: 'saleReturn',
    PURCHASE_RETURN: 'purchaseReturn',
    TRANSFER_IN: 'transferIn',
    TRANSFER_OUT: 'transferOut',
    ADJUSTMENT_IN: 'adjustmentIn',
    ADJUSTMENT_OUT: 'adjustmentOut',
    DAMAGE: 'damage',
    LOSS: 'loss',
    EXPIRED: 'expired',
  }
  const key = map[type.toUpperCase()] ?? type
  const path = `inventory.types.${key}`
  const translated = t(path)
  return translated === path ? type : translated
}

function safeMoney(amount?: number | null) {
  return formatMoney(Number.isFinite(amount as number) ? Number(amount) : 0)
}

onMounted(async () => {
  initDates()
  warehouses.value = await store.loadAllWarehouses()
  await load()
})
</script>

<template>
  <ReportsLayout>
    <div class="inv">
      <div class="inv__chrome">
        <nav class="inv__tabs" role="tablist" :aria-label="t('reports.explore.inventory.title')">
          <button
            v-for="tab in tabs"
            :key="tab.id"
            type="button"
            role="tab"
            class="inv__tab"
            :class="{ 'is-active': activeTab === tab.id }"
            :aria-selected="activeTab === tab.id"
            @click="activeTab = tab.id"
          >
            <span class="inv__tab-icon" aria-hidden="true">
              <AppIcon :name="tab.icon" :size="15" />
            </span>
            <span class="inv__tab-label">{{ t(tab.labelKey) }}</span>
          </button>
        </nav>

        <div class="inv__actions">
          <button type="button" class="btn-secondary" @click="exportPdf">
            <AppIcon name="receipt" :size="15" />
            <span>{{ t('reports.inventoryAnalytics.exportPdf') }}</span>
          </button>
          <button type="button" class="btn-secondary" @click="exportExcel">
            <AppIcon name="import" :size="15" />
            <span>{{ t('reports.inventoryAnalytics.exportExcel') }}</span>
          </button>
          <button type="button" class="btn-secondary" :disabled="loading" @click="load">
            <AppIcon name="import" :size="15" />
            <span>{{ t('common.refresh') }}</span>
          </button>
        </div>
      </div>

      <div class="inv__filters">
        <div>
          <FieldLabel icon="inventory">{{ t('inventory.warehouse') }}</FieldLabel>
          <select v-model="warehouseId" class="field">
            <option value="">{{ t('org.allStores') }}</option>
            <option v-for="w in warehouses" :key="w.id" :value="w.id">{{ w.name }}</option>
          </select>
        </div>
        <div>
          <FieldLabel icon="calendar">{{ t('reports.inventoryAnalytics.from') }}</FieldLabel>
          <input v-model="from" type="date" class="field" />
        </div>
        <div>
          <FieldLabel icon="calendar">{{ t('reports.inventoryAnalytics.to') }}</FieldLabel>
          <input v-model="to" type="date" class="field" />
        </div>
        <button type="button" class="btn-primary" :disabled="loading" @click="load">
          {{ t('reports.inventoryAnalytics.apply') }}
        </button>
      </div>

      <template v-if="activeTab === 'overview'">
        <div class="inv__kpis">
          <article class="kpi">
            <p class="kpi__label">{{ t('reports.inventoryAnalytics.totalArticles') }}</p>
            <p class="kpi__value">{{ totalArticles }}</p>
          </article>
          <article class="kpi">
            <p class="kpi__label">{{ t('reports.inventoryAnalytics.stockValue') }}</p>
            <p class="kpi__value">{{ safeMoney(stockValue) }}</p>
          </article>
          <article class="kpi">
            <p class="kpi__label">{{ t('reports.inventoryAnalytics.lowStock') }}</p>
            <p class="kpi__value kpi__value--warn">{{ lowStock }}</p>
          </article>
          <article class="kpi">
            <p class="kpi__label">{{ t('reports.inventoryAnalytics.outOfStock') }}</p>
            <p class="kpi__value kpi__value--danger">{{ outOfStock }}</p>
          </article>
          <article class="kpi">
            <p class="kpi__label">{{ t('reports.inventoryAnalytics.overstock') }}</p>
            <p class="kpi__value">{{ overstock }}</p>
          </article>
        </div>

        <div class="inv__grid">
          <section class="panel">
            <header class="panel__header">
              <h3 class="panel__title">{{ t('reports.inventoryAnalytics.stockHealth') }}</h3>
            </header>
            <div v-if="stockHealth.some(r => r.count > 0)" class="donut-wrap">
              <div class="donut" :style="{ background: healthDonut }">
                <div class="donut__center">
                  <strong v-if="dominantHealth">{{ Math.round((dominantHealth.count / healthTotal) * 100) }}%</strong>
                  <span v-if="dominantHealth">{{ statusLabel(dominantHealth.label) }}</span>
                </div>
              </div>
              <ul class="donut-legend">
                <li v-for="row in stockHealth" :key="row.label">
                  <i class="dot" :style="{ background: healthColors[row.label] || '#64748b' }" />
                  <span>{{ statusLabel(row.label) }}</span>
                  <strong>{{ row.count }}</strong>
                </li>
              </ul>
            </div>
            <p v-else class="panel__empty">{{ t('org.empty') }}</p>
          </section>

          <section class="panel">
            <header class="panel__header">
              <h3 class="panel__title">{{ t('reports.inventoryAnalytics.valueByCategory') }}</h3>
            </header>
            <div v-if="byCategory.length" class="bar-list">
              <div v-for="row in byCategory" :key="row.label" class="bar-list__row">
                <div class="bar-list__meta">
                  <span>{{ row.label }}</span>
                  <strong>{{ safeMoney(row.value) }}</strong>
                </div>
                <div class="bar-list__track">
                  <div class="bar-list__fill" :style="{ width: `${(row.value / categoryMax) * 100}%` }" />
                </div>
              </div>
            </div>
            <p v-else class="panel__empty">{{ t('org.empty') }}</p>
          </section>
        </div>

        <section class="panel">
          <header class="panel__header">
            <h3 class="panel__title">{{ t('reports.inventoryAnalytics.valueByWarehouse') }}</h3>
          </header>
          <div v-if="byWarehouse.length" class="warehouse">
            <div
              v-for="row in byWarehouse"
              :key="row.label"
              class="warehouse__col"
              :title="`${row.label}: ${safeMoney(row.value)}`"
            >
              <div class="warehouse__meta">
                <span class="warehouse__name">{{ row.label }}</span>
                <strong>{{ safeMoney(row.value) }}</strong>
                <small>{{ t('reports.inventoryAnalytics.totalQty') }}: {{ row.quantity }}</small>
              </div>
              <div class="warehouse__track">
                <div class="warehouse__fill" :style="{ height: `${Math.max(6, (row.value / warehouseMax) * 100)}%` }" />
              </div>
            </div>
          </div>
          <p v-else class="panel__empty">{{ t('org.empty') }}</p>
        </section>

        <section class="panel panel--table">
          <header class="panel__header">
            <h3 class="panel__title">{{ t('reports.inventoryAnalytics.stockLevels') }}</h3>
          </header>
          <table class="table">
            <thead>
              <tr>
                <th>{{ t('products.name') }}</th>
                <th>{{ t('reports.byCategory') }}</th>
                <th>{{ t('inventory.warehouse') }}</th>
                <th class="text-right">{{ t('inventory.onHand') }}</th>
                <th class="text-right">{{ t('reports.inventoryAnalytics.reorderPoint') }}</th>
                <th class="text-right">{{ t('reports.inventoryAnalytics.unitPrice') }}</th>
                <th class="text-right">{{ t('reports.inventoryAnalytics.value') }}</th>
                <th>{{ t('reports.inventoryAnalytics.statusCol') }}</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="row in stockLevels" :key="`${row.product_id}-${row.warehouse}`">
                <td>
                  <div class="product">
                    <strong>{{ row.name }}</strong>
                    <span v-if="row.sku" class="mono">{{ row.sku }}</span>
                  </div>
                </td>
                <td>{{ row.category || '—' }}</td>
                <td>{{ row.warehouse || '—' }}</td>
                <td class="text-right">{{ row.quantity_on_hand.toFixed(3) }}</td>
                <td class="text-right">{{ row.reorder_point || '—' }}</td>
                <td class="text-right">{{ safeMoney(row.unit_cost) }}</td>
                <td class="text-right">{{ safeMoney(row.value) }}</td>
                <td>
                  <span class="badge" :class="`badge--${row.status}`">{{ statusLabel(row.status) }}</span>
                </td>
              </tr>
            </tbody>
          </table>
          <p v-if="!stockLevels.length" class="panel__empty">{{ t('org.empty') }}</p>
        </section>
      </template>

      <template v-else-if="activeTab === 'movements'">
        <div class="inv__grid inv__grid--2">
          <section class="panel panel--table">
            <header class="panel__header">
              <h3 class="panel__title">{{ t('reports.movements') }}</h3>
            </header>
            <table class="table">
              <thead>
                <tr>
                  <th>{{ t('inventory.date') }}</th>
                  <th>{{ t('products.name') }}</th>
                  <th>{{ t('inventory.warehouse') }}</th>
                  <th>{{ t('inventory.movementType') }}</th>
                  <th class="text-right">{{ t('inventory.qtyShort') }}</th>
                  <th class="text-right">{{ t('reports.inventoryAnalytics.value') }}</th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="(row, index) in report?.movements ?? []" :key="`${row.occurred_at}-${index}`">
                  <td>{{ row.occurred_at ? formatDate(row.occurred_at) : '—' }}</td>
                  <td>
                    <div class="product">
                      <strong>{{ row.name }}</strong>
                      <span v-if="row.sku" class="mono">{{ row.sku }}</span>
                    </div>
                  </td>
                  <td>{{ row.warehouse || '—' }}</td>
                  <td>{{ movementLabel(row.type) }}</td>
                  <td class="text-right">{{ row.quantity }}</td>
                  <td class="text-right">{{ safeMoney(row.amount) }}</td>
                </tr>
              </tbody>
            </table>
            <p v-if="!report?.movements?.length" class="panel__empty">{{ t('org.empty') }}</p>
          </section>

          <section class="panel panel--table">
            <header class="panel__header">
              <h3 class="panel__title">{{ t('reports.losses') }}</h3>
              <strong class="panel__meta">{{ safeMoney(report?.losses_value ?? 0) }}</strong>
            </header>
            <table class="table">
              <tbody>
                <tr v-for="(row, index) in report?.losses ?? []" :key="`loss-${row.occurred_at}-${index}`">
                  <td>{{ row.name }} · {{ movementLabel(row.type) }}</td>
                  <td class="text-right">{{ row.quantity }}</td>
                  <td class="text-right">{{ safeMoney(row.amount) }}</td>
                </tr>
              </tbody>
            </table>
            <p v-if="!report?.losses?.length" class="panel__empty">{{ t('org.empty') }}</p>
          </section>
        </div>
      </template>

      <template v-else-if="activeTab === 'aging'">
        <section class="panel">
          <header class="panel__header">
            <h3 class="panel__title">{{ t('reports.inventoryAnalytics.agingDistribution') }}</h3>
          </header>
          <div v-if="aging.some(r => r.count > 0)" class="aging">
            <div v-for="row in aging" :key="row.label" class="aging__col">
              <div class="aging__bar-wrap">
                <div
                  class="aging__bar"
                  :class="`aging__bar--${row.label}`"
                  :style="{ height: `${Math.max(4, (row.count / agingMax) * 100)}%` }"
                />
              </div>
              <strong>{{ row.count }}</strong>
              <span>{{ agingLabel(row.label) }}</span>
              <small>{{ row.quantity }} {{ t('reports.inventoryAnalytics.units') }}</small>
            </div>
          </div>
          <p v-else class="panel__empty">{{ t('reports.inventoryAnalytics.noAging') }}</p>
        </section>

        <section class="panel panel--table">
          <header class="panel__header">
            <h3 class="panel__title">{{ t('reports.expiration') }}</h3>
          </header>
          <table class="table">
            <thead>
              <tr>
                <th>{{ t('products.name') }}</th>
                <th>{{ t('inventory.warehouse') }}</th>
                <th>{{ t('inventory.batch') }}</th>
                <th class="text-right">{{ t('inventory.onHand') }}</th>
                <th>{{ t('inventory.expires') }}</th>
                <th class="text-right">{{ t('reports.inventoryAnalytics.daysLeft') }}</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="(row, index) in report?.expiration ?? []" :key="`${row.batch}-${index}`">
                <td>
                  <div class="product">
                    <strong>{{ row.name }}</strong>
                    <span v-if="row.sku" class="mono">{{ row.sku }}</span>
                  </div>
                </td>
                <td>{{ row.warehouse || '—' }}</td>
                <td>{{ row.batch || '—' }}</td>
                <td class="text-right">{{ row.quantity_on_hand }}</td>
                <td :class="{ 'text-danger': row.expired }">{{ row.expires_at ? formatDate(row.expires_at) : '—' }}</td>
                <td class="text-right" :class="{ 'text-danger': row.expired || (row.days_left != null && row.days_left <= 30) }">
                  {{ row.days_left ?? '—' }}
                </td>
              </tr>
            </tbody>
          </table>
          <p v-if="!report?.expiration?.length" class="panel__empty">{{ t('org.empty') }}</p>
        </section>
      </template>

      <template v-else>
        <section class="panel panel--table">
          <header class="panel__header">
            <h3 class="panel__title">{{ t('reports.inventoryAnalytics.turnoverAnalysis') }}</h3>
          </header>
          <table class="table">
            <thead>
              <tr>
                <th>{{ t('products.name') }}</th>
                <th>{{ t('reports.byCategory') }}</th>
                <th class="text-right">{{ t('inventory.onHand') }}</th>
                <th class="text-right">{{ t('reports.inventoryAnalytics.soldQty') }}</th>
                <th class="text-right">{{ t('reports.inventoryAnalytics.turnoverRate') }}</th>
                <th class="text-right">{{ t('reports.inventoryAnalytics.daysOfSupply') }}</th>
                <th class="text-right">{{ t('reports.inventoryAnalytics.value') }}</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="row in turnover" :key="row.product_id">
                <td>
                  <div class="product">
                    <strong>{{ row.name }}</strong>
                    <span v-if="row.sku" class="mono">{{ row.sku }}</span>
                  </div>
                </td>
                <td>{{ row.category || '—' }}</td>
                <td class="text-right">{{ row.quantity_on_hand }}</td>
                <td class="text-right">{{ row.sold_qty }}</td>
                <td class="text-right">{{ row.turnover_rate.toFixed(2) }}×</td>
                <td class="text-right">{{ row.days_of_supply ?? '—' }}</td>
                <td class="text-right">{{ safeMoney(row.value) }}</td>
              </tr>
            </tbody>
          </table>
          <p v-if="!turnover.length" class="panel__empty">{{ t('org.empty') }}</p>
        </section>
      </template>
    </div>
  </ReportsLayout>
</template>

<style scoped>
.inv {
  display: flex;
  flex-direction: column;
  gap: 1.1rem;
}

.inv__chrome {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  justify-content: space-between;
  gap: 0.85rem;
}

.inv__actions,
.inv__filters {
  display: flex;
  flex-wrap: wrap;
  gap: 0.65rem;
  align-items: flex-end;
}

.inv__tabs {
  display: inline-flex;
  flex-wrap: nowrap;
  align-items: center;
  gap: 0.2rem;
  padding: 0.28rem;
  border: 1px solid #e2e8f0;
  border-radius: 0.95rem;
  background: #f8fafc;
  box-shadow: inset 0 1px 0 rgba(255, 255, 255, 0.8);
  overflow-x: auto;
  max-width: 100%;
  scrollbar-width: none;
}

.inv__tabs::-webkit-scrollbar {
  display: none;
}

.inv__tab {
  position: relative;
  display: inline-flex;
  align-items: center;
  gap: 0.45rem;
  border: 1px solid transparent;
  background: transparent;
  color: #64748b;
  font-size: 0.875rem;
  font-weight: 600;
  line-height: 1;
  padding: 0.62rem 0.95rem;
  border-radius: 0.72rem;
  white-space: nowrap;
  cursor: pointer;
  transition:
    color 0.18s ease,
    background 0.18s ease,
    border-color 0.18s ease,
    box-shadow 0.18s ease;
}

.inv__tab:hover {
  color: #0f172a;
  background: rgba(255, 255, 255, 0.7);
}

.inv__tab-icon {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 1.35rem;
  height: 1.35rem;
  border-radius: 0.45rem;
  background: rgba(148, 163, 184, 0.16);
  color: inherit;
}

.inv__tab.is-active {
  color: #0f766e;
  background: white;
  border-color: #ccfbf1;
  box-shadow:
    0 1px 2px rgba(15, 23, 42, 0.06),
    0 4px 12px rgba(15, 118, 110, 0.08);
}

.inv__tab.is-active .inv__tab-icon {
  background: #ecfdf5;
  color: #0f766e;
}

.inv__tab.is-active::after {
  content: '';
  position: absolute;
  left: 0.9rem;
  right: 0.9rem;
  bottom: 0.2rem;
  height: 2px;
  border-radius: 999px;
  background: #0f766e;
  opacity: 0.85;
}

@media (max-width: 720px) {
  .inv__chrome {
    flex-direction: column;
    align-items: stretch;
  }

  .inv__tabs {
    width: 100%;
  }

  .inv__actions .btn-secondary span {
    display: none;
  }
}



.btn-secondary {
  display: inline-flex;
  align-items: center;
  gap: 0.4rem;
  border-radius: 0.55rem;
  padding: 0.5rem 0.9rem;
  font-size: 0.875rem;
  font-weight: 500;
  cursor: pointer;
}



.btn-secondary {
  border: 1px solid #cbd5e1;
  background: white;
  color: #334155;
}



.inv__kpis {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(150px, 1fr));
  gap: 0.85rem;
}

.kpi {
  border: 1px solid #e2e8f0;
  border-radius: 0.85rem;
  background: white;
  padding: 1rem 1.05rem;
}

.kpi__label {
  margin: 0;
  font-size: 0.75rem;
  font-weight: 600;
  letter-spacing: 0.02em;
  text-transform: uppercase;
  color: #64748b;
}

.kpi__value {
  margin: 0.45rem 0 0;
  font-size: 1.35rem;
  font-weight: 700;
  color: #0f172a;
}

.kpi__value--warn { color: #d97706; }
.kpi__value--danger { color: #dc2626; }

.inv__grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 0.85rem;
}

.inv__grid--2 {
  grid-template-columns: repeat(2, minmax(0, 1fr));
}

@media (max-width: 900px) {
  .inv__grid,
  .inv__grid--2 {
    grid-template-columns: 1fr;
  }
}

.panel {
  border: 1px solid #e2e8f0;
  border-radius: 0.85rem;
  background: white;
  padding: 1rem 1.1rem 1.15rem;
  min-height: 200px;
}

.panel--table {
  overflow: auto;
}

.panel__header {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  justify-content: space-between;
  gap: 0.5rem;
  margin-bottom: 0.85rem;
}

.panel__title {
  margin: 0;
  font-size: 0.95rem;
  font-weight: 700;
  color: #0f172a;
}

.panel__meta {
  font-size: 0.9rem;
  color: #0f766e;
}

.panel__empty {
  margin: 2rem 0 0;
  text-align: center;
  color: #94a3b8;
  font-size: 0.9rem;
}

.donut-wrap {
  display: flex;
  flex-wrap: wrap;
  gap: 1.25rem;
  align-items: center;
}

.donut {
  position: relative;
  width: 9.5rem;
  height: 9.5rem;
  border-radius: 999px;
  flex-shrink: 0;
}

.donut__center {
  position: absolute;
  inset: 1.55rem;
  border-radius: 999px;
  background: white;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  text-align: center;
  gap: 0.15rem;
}

.donut__center strong {
  font-size: 1.1rem;
  color: #0f172a;
}

.donut__center span {
  font-size: 0.7rem;
  color: #64748b;
  max-width: 5.5rem;
  line-height: 1.2;
}

.donut-legend {
  list-style: none;
  margin: 0;
  padding: 0;
  display: flex;
  flex-direction: column;
  gap: 0.45rem;
  flex: 1;
  min-width: 10rem;
}

.donut-legend li {
  display: grid;
  grid-template-columns: auto 1fr auto;
  gap: 0.5rem;
  align-items: center;
  font-size: 0.85rem;
  color: #475569;
}

.dot {
  display: inline-block;
  width: 0.55rem;
  height: 0.55rem;
  border-radius: 999px;
}

.bar-list {
  display: flex;
  flex-direction: column;
  gap: 0.7rem;
}

.bar-list__meta {
  display: flex;
  justify-content: space-between;
  gap: 0.75rem;
  font-size: 0.82rem;
  color: #475569;
  margin-bottom: 0.25rem;
}

.bar-list__track {
  height: 0.45rem;
  border-radius: 999px;
  background: #f1f5f9;
  overflow: hidden;
}

.bar-list__fill {
  height: 100%;
  border-radius: 999px;
  background: #0f766e;
}

.warehouse {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(7rem, 1fr));
  gap: 0.75rem;
  align-items: end;
  min-height: 180px;
}

.warehouse__col {
  display: flex;
  flex-direction: column;
  gap: 0.55rem;
  height: 100%;
}

.warehouse__meta {
  display: flex;
  flex-direction: column;
  gap: 0.15rem;
  font-size: 0.78rem;
  color: #64748b;
}

.warehouse__name {
  font-weight: 600;
  color: #334155;
}

.warehouse__track {
  flex: 1;
  min-height: 100px;
  display: flex;
  align-items: flex-end;
  background: #f8fafc;
  border-radius: 0.5rem;
  overflow: hidden;
}

.warehouse__fill {
  width: 100%;
  background: #0f766e;
  border-radius: 0.5rem 0.5rem 0 0;
}

.table {
  width: 100%;
  border-collapse: collapse;
  font-size: 0.85rem;
}

.table th,
.table td {
  padding: 0.65rem 0.55rem;
  border-bottom: 1px solid #f1f5f9;
  text-align: left;
  vertical-align: top;
}

.table th {
  font-size: 0.72rem;
  text-transform: uppercase;
  letter-spacing: 0.03em;
  color: #64748b;
  font-weight: 600;
}

.text-right { text-align: right !important; }
.text-danger { color: #dc2626; }

.product {
  display: flex;
  flex-direction: column;
  gap: 0.1rem;
}

.product strong {
  font-weight: 600;
  color: #0f172a;
}

.mono {
  font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace;
  font-size: 0.75rem;
  color: #94a3b8;
}

.badge {
  display: inline-flex;
  align-items: center;
  border-radius: 999px;
  padding: 0.15rem 0.55rem;
  font-size: 0.72rem;
  font-weight: 700;
}

.badge--healthy { background: #ecfdf5; color: #047857; }
.badge--low { background: #fffbeb; color: #b45309; }
.badge--out { background: #fef2f2; color: #b91c1c; }
.badge--over { background: #eff6ff; color: #1d4ed8; }

.aging {
  display: grid;
  grid-template-columns: repeat(5, minmax(0, 1fr));
  gap: 0.65rem;
  align-items: end;
  min-height: 180px;
}

@media (max-width: 700px) {
  .aging {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }
}

.aging__col {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 0.3rem;
  height: 100%;
  font-size: 0.75rem;
  color: #64748b;
  text-align: center;
}

.aging__bar-wrap {
  flex: 1;
  width: 100%;
  display: flex;
  align-items: flex-end;
  min-height: 110px;
}

.aging__bar {
  width: 100%;
  border-radius: 0.45rem 0.45rem 0 0;
  background: #0f766e;
}

.aging__bar--expired { background: #dc2626; }
.aging__bar--0_30 { background: #d97706; }
.aging__bar--31_60 { background: #ca8a04; }
.aging__bar--61_90 { background: #2563eb; }
.aging__bar--90_plus { background: #059669; }

@media print {
  .inv__chrome,
  .inv__filters {
    display: none !important;
  }
}
</style>
