<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import InventoryLayout from '../../../components/inventory/InventoryLayout.vue'
import StatusBadge from '../../../components/organization/StatusBadge.vue'
import AppModal from '../../../components/ui/AppModal.vue'
import DataTableShell from '../../../components/ui/DataTableShell.vue'
import FieldLabel from '../../../components/ui/FieldLabel.vue'
import KpiCard from '../../../components/ui/KpiCard.vue'
import { api } from '../../../api/client'
import { useBackofficeStore } from '../../../stores/backoffice'
import type { InventoryMovement, Product, StockBalance, Warehouse } from '../../../types'
import { isStockableProduct } from '../../../utils/product'
import { formatDate } from '../../../utils/format'
import { formatMoney } from '../../../utils/money'

const { t } = useI18n()
const store = useBackofficeStore()
const warehouses = ref<Warehouse[]>([])
const products = ref<Product[]>([])
const warehouseId = ref('')
const showModal = ref(false)
const showHistory = ref(false)
const historyRow = ref<StockBalance | null>(null)
const history = ref<InventoryMovement[]>([])
const historyLoading = ref(false)
const historyFrom = ref('')
const historyTo = ref('')
const saving = ref(false)

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

const form = ref({
  product_id: '',
  movement_type: 'INITIAL_STOCK',
  quantity: 1,
  notes: '',
})

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

onMounted(async () => {
  warehouses.value = await store.loadAllWarehouses()
  catalogProducts.value = await store.loadAllProducts()
  warehouseId.value = warehouses.value[0]?.id ?? ''
})

watch(warehouseId, async (id) => {
  if (!id) return
  await store.loadStockBalances(id, false)
})

function stockQty(row: StockBalance) {
  if (row.product && !isStockableProduct({ product_type: row.product.product_type as Product['product_type'] })) {
    return 'N/S'
  }
  return row.quantity_on_hand
}

async function openCreate() {
  if (!products.value.length) {
    products.value = catalogProducts.value.filter(isStockableProduct)
  }
  form.value = {
    product_id: products.value[0]?.id ?? '',
    movement_type: 'OPENING',
    quantity: 1,
    notes: '',
  }
  showModal.value = true
}

async function save() {
  if (!warehouseId.value) return
  saving.value = true
  try {
    await store.createInventoryMovement(warehouseId.value, {
      product_id: form.value.product_id,
      movement_type: form.value.movement_type,
      quantity: form.value.quantity,
      notes: form.value.notes || undefined,
    })
    showModal.value = false
    await store.loadStockBalances(warehouseId.value, false)
  } finally {
    saving.value = false
  }
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
      <div class="flex flex-wrap items-end justify-between gap-3">
        <div>
          <FieldLabel icon="inventory">{{ t('inventory.warehouse') }}</FieldLabel>
          <select v-model="warehouseId" class="field max-w-xs">
            <option v-for="wh in warehouses" :key="wh.id" :value="wh.id">{{ wh.name }} ({{ wh.code }})</option>
          </select>
        </div>
        <button class="btn-primary" :disabled="!warehouseId" @click="openCreate">+ {{ t('inventory.newMovement') }}</button>
      </div>

      <p class="m-0 text-xs text-slate-500">{{ t('inventory.movementRule') }}</p>

      <div class="hub-strip">
        <KpiCard
          :label="t('inventory.onHand')"
          :value="stockableRows.length"
          icon="inventory"
          accent="#4a6d86"
          icon-bg="#e4edf2"
        />
        <KpiCard
          :label="t('products.price')"
          :value="formatMoney(stockValue)"
          icon="tag"
          accent="#059669"
          icon-bg="#ecfdf5"
        />
        <KpiCard
          :label="t('dashboard.stockAlerts')"
          :value="lowStockCount"
          icon="bell"
          accent="#c4841d"
          icon-bg="#f8efdc"
          :delta="lowStockCount ? t('dashboard.alertsOpen') : t('dashboard.alertsClear')"
          :delta-tone="lowStockCount ? 'down' : 'up'"
        />
        <KpiCard
          :label="t('inventory.outOfStock')"
          :value="zeroStockCount"
          icon="package"
          accent="#dc2626"
          icon-bg="#fef2f2"
        />
      </div>

      <DataTableShell
        :title="t('nav.inventory')"
        :meta="`${rows.length} ${t('products.name').toLowerCase()}`"
        :empty="!rows.length"
        :empty-title="t('org.empty')"
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
            <tr v-for="row in rows" :key="row.id" class="cursor-pointer" @click="openHistory(row)">
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
        <p v-if="historyLoading" class="text-sm text-slate-500">{{ t('common.loading') }}</p>
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
          <button type="button" class="btn-secondary" @click="showHistory = false">{{ t('common.cancel') }}</button>
        </div>
      </div>
    </AppModal>

    <AppModal :open="showModal" :title="t('inventory.newMovement')" icon="inventory" tone="info" @close="showModal = false">
      <form class="space-y-3" @submit.prevent="save">
        <div>
          <FieldLabel icon="products">{{ t('products.name') }}</FieldLabel>
          <select v-model="form.product_id" required class="field w-full">
            <option v-for="p in products" :key="p.id" :value="p.id">{{ p.sku }} — {{ p.name }}</option>
          </select>
        </div>
        <div>
          <FieldLabel icon="transfer">{{ t('inventory.movementType') }}</FieldLabel>
          <select v-model="form.movement_type" class="field w-full">
            <option v-for="type in movementTypes" :key="type.value" :value="type.value">{{ type.label }}</option>
          </select>
        </div>
        <div>
          <FieldLabel icon="package">{{ t('sales.qty') }}</FieldLabel>
          <input v-model.number="form.quantity" type="number" min="1" required class="field w-full" />
        </div>
        <div>
          <FieldLabel icon="note">{{ t('inventory.reason') }}</FieldLabel>
          <textarea v-model="form.notes" rows="2" class="field w-full" />
        </div>
        <div class="app-modal__actions">
          <button type="button" class="btn-secondary" @click="showModal = false">{{ t('common.cancel') }}</button>
          <button type="submit" class="btn-primary" :disabled="saving">{{ t('common.save') }}</button>
        </div>
      </form>
    </AppModal>
  </InventoryLayout>
</template>

<style scoped>
.field { border-radius: 0.5rem; border: 1px solid #cbd5e1; padding: 0.5rem 0.75rem; }
.btn-primary { border-radius: 0.5rem; padding: 0.5rem 1rem; font-weight: 500; color: white; background-color: var(--color-brand-600); }
.btn-secondary { border-radius: 0.5rem; border: 1px solid #cbd5e1; padding: 0.5rem 1rem; }
.text-brand-600 { color: var(--color-brand-600); }
.history-list { max-height: 22rem; overflow: auto; border: 1px solid #e2e8f0; border-radius: 0.75rem; }
.history-row { display: flex; align-items: center; gap: 0.75rem; padding: 0.65rem 0.8rem; border-bottom: 1px solid #f1f5f9; }
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
.history-arrow--in { background: #ecfdf5; color: #059669; }
.history-arrow--out { background: #fef2f2; color: #dc2626; }
.history-qty { min-width: 3.5rem; text-align: right; font-weight: 650; }
.history-qty--in { color: #059669; }
.history-qty--out { color: #dc2626; }
</style>
