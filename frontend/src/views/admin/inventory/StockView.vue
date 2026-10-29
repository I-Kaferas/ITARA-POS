<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import InventoryLayout from '../../../components/inventory/InventoryLayout.vue'
import StatusBadge from '../../../components/organization/StatusBadge.vue'
import AppModal from '../../../components/ui/AppModal.vue'
import DataTableShell from '../../../components/ui/DataTableShell.vue'
import FieldLabel from '../../../components/ui/FieldLabel.vue'
import KpiCard from '../../../components/ui/KpiCard.vue'
import LoadingBlock from '../../../components/ui/LoadingBlock.vue'
import { realtimeTopics, useRealtimeSync } from '../../../composables/useRealtimeSync'
import { api } from '../../../api/client'
import { useBackofficeStore } from '../../../stores/backoffice'
import { useContextStore } from '../../../stores/context'
import type { InventoryMovement, Product, StockBalance, Warehouse } from '../../../types'
import { isStockableProduct } from '../../../utils/product'
import { formatDate } from '../../../utils/format'
import { formatMoney } from '../../../utils/money'
import AppIcon from '../../../components/ui/AppIcon.vue'
import ListPager from '../../../components/ui/ListPager.vue'
import { useClientPager } from '../../../composables/useClientPager'

const { t } = useI18n()
const store = useBackofficeStore()
const context = useContextStore()
const warehouses = computed(() => {
  const linked = context.stores
    .map(item => item.stock_warehouse)
    .filter((warehouse): warehouse is Warehouse => Boolean(warehouse?.id))
  return linked.length ? linked : store.warehouseCatalog
})
const warehouseId = ref('')
const search = ref('')
const showHistory = ref(false)
const historyRow = ref<StockBalance | null>(null)
const history = ref<InventoryMovement[]>([])
const historyLoading = ref(false)
const historyFrom = ref('')
const historyTo = ref('')

const movementTypes = [
  { value: 'OPENING', label: t('inventory.types.opening') },
  { value: 'PURCHASE', label: t('inventory.types.purchase') },
  { value: 'SALE', label: t('inventory.types.sale') },
  { value: 'SALE_RETURN', label: t('inventory.types.saleReturn') },
  { value: 'PURCHASE_RETURN', label: t('inventory.types.purchaseReturn') },
  { value: 'TRANSFER_IN', label: t('inventory.types.transferIn') },
  { value: 'TRANSFER_OUT', label: t('inventory.types.transferOut') },
  { value: 'ADJUSTMENT_IN', label: t('inventory.types.adjustmentIn') },
  { value: 'ADJUSTMENT_OUT', label: t('inventory.types.adjustmentOut') },
  { value: 'DAMAGE', label: t('inventory.types.damage') },
  { value: 'LOSS', label: t('inventory.types.loss') },
  { value: 'EXPIRED', label: t('inventory.types.expired') },
]

const inboundTypes = new Set(['INITIAL_STOCK', 'PURCHASE', 'SALE_RETURN', 'TRANSFER_IN', 'ADJUSTMENT_IN'])

const catalogProducts = ref<Product[]>([])

const rows = computed(() => {
  const known = new Set(store.stockBalances.map(row => row.product_id))
  const extras: StockBalance[] = catalogProducts.value
    .filter(product => !isStockableProduct(product) && !known.has(product.id))
    .map(product => ({
      id: `service-${product.id}`,
      product_id: product.id,
      quantity_on_hand: 0,
      quantity_available: 0,
      product: {
        id: product.id,
        sku: product.sku,
        name: product.name,
        unit: product.unit,
        base_price: product.base_price,
        is_active: product.is_active,
        product_type: product.product_type,
        category: product.category ? { id: product.category.id, name: product.category.name } : null,
      },
    }))

  return [...store.stockBalances, ...extras]
})

const filteredRows = computed(() => {
  const query = search.value.trim().toLowerCase()
  if (!query) return rows.value
  return rows.value.filter(row => {
    const haystack = `${row.product?.sku ?? ''} ${row.product?.name ?? ''} ${row.product?.category?.name ?? ''}`
    return haystack.toLowerCase().includes(query)
  })
})

const { page, lastPage, total, perPage, paged, setPage } = useClientPager(filteredRows)

const stockableRows = computed(() =>
  rows.value.filter(row => !row.product || isStockableProduct({ product_type: row.product.product_type as Product['product_type'] })),
)
const lowStockCount = computed(() =>
  stockableRows.value.filter(row => Number(row.quantity_on_hand) > 0 && Number(row.quantity_on_hand) <= 5).length,
)
const zeroStockCount = computed(() =>
  stockableRows.value.filter(row => Number(row.quantity_on_hand) <= 0).length,
)
const stockValue = computed(() =>
  stockableRows.value.reduce((sum, row) => sum + Number(row.quantity_on_hand || 0) * Number(row.product?.base_price || 0), 0),
)

function warehouseForCurrentStore() {
  const match = warehouses.value.find(warehouse => warehouse.store_id && warehouse.store_id === context.currentStoreId)
  if (match) return match.id
  if (!context.currentStoreId) return warehouses.value[0]?.id ?? ''
  return ''
}

function syncWarehouse() {
  const next = warehouseForCurrentStore()
  if (next && next !== warehouseId.value) warehouseId.value = next
}

onMounted(() => {
  void store.loadAllWarehouses().then(() => syncWarehouse())
  void store.loadAllProducts().then(products => {
    catalogProducts.value = products
  })
})

useRealtimeSync(realtimeTopics.stock, async () => {
  if (warehouseId.value) await store.loadStockBalances(warehouseId.value, false)
})

watch(warehouseId, async (id) => {
  if (!id) return
  await store.loadStockBalances(id, false)
})

watch(() => context.currentStoreId, () => syncWarehouse())
syncWarehouse()

function stockQty(row: StockBalance) {
  if (row.product && !isStockableProduct({ product_type: row.product.product_type as Product['product_type'] })) {
    return 'N/S'
  }
  return row.quantity_on_hand
}

function unitLabel(row: StockBalance) {
  const unit = row.product?.unit_model
  return unit?.symbol || unit?.name || row.product?.unit || '—'
}

function movementLabel(type: string) {
  if (type === 'INITIAL_STOCK' || type === 'OPENING') return t('inventory.types.opening')
  return movementTypes.find(item => item.value === type)?.label ?? type
}

function specCode(row: InventoryMovement) {
  return row.spec_code || (row.movement_type === 'INITIAL_STOCK' ? 'OPENING' : row.movement_type)
}

function signedQty(row: InventoryMovement) {
  const qty = Number(row.quantity) || 0
  return `${qty > 0 ? '+' : ''}${qty}`
}

function isInbound(row: InventoryMovement) {
  const qty = Number(row.quantity) || 0
  if (qty !== 0) return qty > 0
  return inboundTypes.has(row.movement_type)
}

async function openHistory(row: StockBalance) {
  if (!warehouseId.value || !row.product_id) return
  historyRow.value = row
  history.value = []
  historyFrom.value = ''
  historyTo.value = ''
  showHistory.value = true
  await loadHistory()
}

async function loadHistory() {
  const row = historyRow.value
  if (!warehouseId.value || !row?.product_id) return
  historyLoading.value = true
  try {
    const params = new URLSearchParams({
      product_id: row.product_id,
      per_page: '100',
    })
    if (historyFrom.value) params.set('from', historyFrom.value)
    if (historyTo.value) params.set('to', historyTo.value)
    const res = await api.get<{ data: { data: InventoryMovement[] } }>(
      `/warehouses/${warehouseId.value}/movements?${params}`,
    )
    history.value = res.data.data ?? []
  } finally {
    historyLoading.value = false
  }
}

function clearHistoryDates() {
  historyFrom.value = ''
  historyTo.value = ''
  void loadHistory()
}
</script>

<template>
  <InventoryLayout>
    <div class="space-y-4">
      <div class="flex flex-wrap items-end gap-3">
        <div>
          <FieldLabel icon="inventory">{{ t('inventory.warehouse') }}</FieldLabel>
          <select v-model="warehouseId" class="field max-w-xs">
            <option v-for="wh in warehouses" :key="wh.id" :value="wh.id">{{ wh.name }} ({{ wh.code }})</option>
          </select>
        </div>
        <div class="min-w-64 flex-1">
          <FieldLabel icon="search">{{ t('inventory.searchProduct') }}</FieldLabel>
          <input v-model="search" type="search" class="field" :placeholder="t('inventory.searchProduct')" />
        </div>
      </div>

      <p class="m-0 text-xs text-slate-500">{{ t('inventory.movementRule') }}</p>

      <div class="hub-strip">
        <KpiCard
          :label="t('inventory.onHand')"
          :value="stockableRows.length"
          icon="inventory"
          accent="var(--color-brand-600)"
          icon-bg="var(--color-brand-50)"
        />
        <KpiCard
          :label="t('products.price')"
          :value="formatMoney(stockValue)"
          :count-to="stockValue"
          count-format="money"
          icon="tag"
          accent="var(--color-success)"
          icon-bg="var(--color-success-bg)"
        />
        <KpiCard
          :label="t('dashboard.stockAlerts')"
          :value="lowStockCount"
          icon="bell"
          accent="var(--color-warning)"
          icon-bg="var(--color-warning-bg)"
          :delta="lowStockCount ? t('dashboard.alertsOpen') : t('dashboard.alertsClear')"
          :delta-tone="lowStockCount ? 'down' : 'up'"
        />
        <KpiCard
          :label="t('inventory.outOfStock')"
          :value="zeroStockCount"
          icon="package"
          accent="var(--color-danger)"
          icon-bg="var(--color-danger-bg)"
        />
      </div>

      <DataTableShell
        :title="t('nav.inventory')"
        :meta="`${total} ${t('products.name').toLowerCase()}`"
        :empty="!filteredRows.length"
        :empty-title="search.trim() ? t('inventory.noArticles') : t('org.empty')"
        empty-icon="inventory"
      >
        <table class="ui-table">
          <thead>
            <tr>
              <th>SKU</th>
              <th>{{ t('products.name') }}</th>
              <th>{{ t('inventory.category') }}</th>
              <th>{{ t('inventory.unit') }}</th>
              <th class="num">{{ t('inventory.onHand') }}</th>
              <th class="num">{{ t('products.price') }}</th>
              <th>{{ t('products.status') }}</th>
              <th class="num">{{ t('inventory.history') }}</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="row in paged" :key="row.id" class="cursor-pointer" @click="openHistory(row)">
              <td class="font-mono text-slate-500">{{ row.product?.sku ?? '—' }}</td>
              <td class="font-medium">{{ row.product?.name ?? '—' }}</td>
              <td>{{ row.product?.category?.name ?? '—' }}</td>
              <td>{{ unitLabel(row) }}</td>
              <td class="num font-mono">{{ stockQty(row) }}</td>
              <td class="num font-mono">{{ formatMoney(row.product?.base_price ?? 0) }}</td>
              <td>
                <StatusBadge
                  :active="row.product?.is_active !== false"
                  :label="row.product?.is_active === false ? t('products.inactive') : t('products.active')"
                />
              </td>
              <td class="num" @click.stop>
                <button type="button" class="ui-btn ui-btn--ghost ui-btn--sm" @click="openHistory(row)">
                  {{ t('inventory.history') }}
                </button>
              </td>
            </tr>
          </tbody>
        </table>
        <ListPager
          :page="page"
          :last-page="lastPage"
          :total="total"
          :per-page="perPage"
          @change="setPage"
        />
      </DataTableShell>
    </div>

    <AppModal
      :open="showHistory"
      :title="historyRow ? `${t('inventory.historyTitle')} · ${historyRow.product?.name ?? ''}` : t('inventory.historyTitle')"
      icon="inventory"
      tone="info"
      size="lg"
      @close="showHistory = false"
    >
      <div class="space-y-3">
        <p class="text-sm text-slate-500">
          {{ historyRow?.product?.sku }} · {{ t('inventory.onHand') }} {{ historyRow ? stockQty(historyRow) : '—' }}
        </p>
        <div class="grid gap-3 sm:grid-cols-[1fr_1fr_auto] sm:items-end">
          <div>
            <FieldLabel icon="calendar">{{ t('reports.from') }}</FieldLabel>
            <input v-model="historyFrom" type="date" class="field w-full" @change="loadHistory" />
          </div>
          <div>
            <FieldLabel icon="calendar">{{ t('reports.to') }}</FieldLabel>
            <input v-model="historyTo" type="date" class="field w-full" @change="loadHistory" />
          </div>
          <button
            v-if="historyFrom || historyTo"
            type="button"
            class="btn-secondary"
            @click="clearHistoryDates"
          >
            {{ t('common.reset') }}
          </button>
        </div>
        <LoadingBlock v-if="historyLoading" variant="list" :rows="4" :label="t('common.loading')" />
        <div v-else class="max-h-80 overflow-auto rounded-xl ring-1 ring-slate-200">
          <p v-if="!history.length" class="px-3 py-6 text-center text-sm text-slate-500">
            {{ historyFrom || historyTo ? t('inventory.historyEmptyPeriod') : t('inventory.historyEmpty') }}
          </p>
          <table v-else class="min-w-full text-sm">
            <thead class="bg-slate-50 text-left text-xs uppercase text-slate-500">
              <tr>
                <th class="px-3 py-2">{{ t('inventory.movementType') }}</th>
                <th class="px-3 py-2 text-right">{{ t('sales.qty') }}</th>
                <th class="px-3 py-2 text-right">{{ t('inventory.balanceAfter') }}</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="row in history" :key="row.id" class="border-t border-slate-100">
                <td class="px-3 py-2">
                  <span class="font-mono font-semibold">{{ specCode(row) }}</span>
                  <span class="mt-0.5 block text-xs text-slate-500">
                    {{ movementLabel(row.movement_type) }} · {{ formatDate(row.occurred_at) }}
                  </span>
                </td>
                <td class="px-3 py-2 text-right font-mono" :class="isInbound(row) ? 'text-emerald-700' : 'text-rose-700'">
                  {{ signedQty(row) }}
                </td>
                <td class="px-3 py-2 text-right font-mono font-semibold">{{ row.balance_after ?? '—' }}</td>
              </tr>
            </tbody>
          </table>
        </div>
        <div class="app-modal__actions">
          <button type="button" class="btn-secondary" @click="showHistory = false"><AppIcon name="close" :size="16" /> {{ t('common.cancel') }}</button>
        </div>
      </div>
    </AppModal>

  </InventoryLayout>
</template>

<style scoped>


.btn-secondary { border-radius: var(--radius-md); }
.text-brand-600 { color: var(--color-ink-brand, var(--color-brand-600));}
.history-list { max-height: 22rem; overflow: auto; border: 1px solid var(--color-border); border-radius: var(--radius-lg); }
.history-row { display: flex; align-items: center; gap: 0.75rem; padding: 0.65rem 0.8rem; border-bottom: 1px solid var(--color-table-border); }
.history-arrow {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 1.85rem;
  height: 1.85rem;
  flex-shrink: 0;
  border-radius: 999px;
}
.history-arrow svg { width: 1.05rem; height: 1.05rem; fill: none; stroke: currentColor; stroke-width: 2.4; stroke-linecap: round; stroke-linejoin: round; }
.history-arrow--in { background: var(--color-success-bg); color: var(--color-success); }
.history-arrow--out { background: var(--color-danger-bg); color: var(--color-danger); }
.history-qty { min-width: 3.5rem; text-align: right; font-weight: 650; }
.history-qty--in { color: var(--color-success); }
.history-qty--out { color: var(--color-danger); }
</style>
