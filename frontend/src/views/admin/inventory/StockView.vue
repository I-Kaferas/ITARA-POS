<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import InventoryLayout from '../../../components/inventory/InventoryLayout.vue'
import StatusBadge from '../../../components/organization/StatusBadge.vue'
import AppModal from '../../../components/ui/AppModal.vue'
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
const saving = ref(false)

const movementTypes = [
  { value: 'INITIAL_STOCK', label: t('inventory.types.initial') },
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

onMounted(async () => {
  warehouses.value = await store.loadAllWarehouses()
  catalogProducts.value = await store.loadAllProducts()
  warehouseId.value = warehouses.value[0]?.id ?? ''
})

watch(warehouseId, async (id) => {
  if (!id) return
  await store.loadStockBalances(id)
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
    movement_type: 'INITIAL_STOCK',
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
    await store.loadStockBalances(warehouseId.value)
  } finally {
    saving.value = false
  }
}

function unitLabel(row: StockBalance) {
  const unit = row.product?.unit_model
  return unit?.symbol || unit?.name || row.product?.unit || '—'
}

function movementLabel(type: string) {
  return movementTypes.find(item => item.value === type)?.label ?? type
}

function isInbound(row: InventoryMovement) {
  const qty = Number(row.quantity) || 0
  if (qty !== 0) return qty > 0
  return inboundTypes.has(row.movement_type)
}

function displayQty(row: InventoryMovement) {
  return Math.abs(Number(row.quantity) || 0)
}

async function openHistory(row: StockBalance) {
  if (!warehouseId.value || !row.product_id) return
  historyRow.value = row
  history.value = []
  showHistory.value = true
  historyLoading.value = true
  try {
    const res = await api.get<{ data: { data: InventoryMovement[] } }>(
      `/warehouses/${warehouseId.value}/movements?product_id=${row.product_id}&per_page=100`,
    )
    history.value = res.data.data ?? []
  } finally {
    historyLoading.value = false
  }
}
</script>

<template>
  <InventoryLayout>
    <div class="space-y-4">
      <div class="flex flex-wrap items-center justify-between gap-3">
        <div class="flex flex-wrap items-center gap-3">
          <label class="text-sm font-medium text-slate-600">{{ t('inventory.warehouse') }}</label>
          <select v-model="warehouseId" class="field max-w-xs">
            <option v-for="wh in warehouses" :key="wh.id" :value="wh.id">{{ wh.name }} ({{ wh.code }})</option>
          </select>
        </div>
        <button class="btn-primary" :disabled="!warehouseId" @click="openCreate">+ {{ t('inventory.newMovement') }}</button>
      </div>

      <div class="overflow-hidden rounded-xl bg-white shadow-sm ring-1 ring-slate-200">
        <table class="min-w-full divide-y divide-slate-200 text-sm">
          <thead class="bg-slate-50">
            <tr>
              <th class="px-4 py-3 text-left font-medium">SKU</th>
              <th class="px-4 py-3 text-left font-medium">{{ t('products.name') }}</th>
              <th class="px-4 py-3 text-left font-medium">{{ t('inventory.category') }}</th>
              <th class="px-4 py-3 text-left font-medium">{{ t('inventory.unit') }}</th>
              <th class="px-4 py-3 text-right font-medium">{{ t('inventory.onHand') }}</th>
              <th class="px-4 py-3 text-right font-medium">{{ t('products.price') }}</th>
              <th class="px-4 py-3 text-left font-medium">{{ t('products.status') }}</th>
              <th class="px-4 py-3 text-right font-medium">{{ t('inventory.history') }}</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-slate-100">
            <tr v-for="row in rows" :key="row.id" class="cursor-pointer hover:bg-slate-50" @click="openHistory(row)">
              <td class="px-4 py-3 font-mono text-slate-500">{{ row.product?.sku ?? '—' }}</td>
              <td class="px-4 py-3 font-medium">{{ row.product?.name ?? '—' }}</td>
              <td class="px-4 py-3 text-slate-600">{{ row.product?.category?.name ?? '—' }}</td>
              <td class="px-4 py-3 text-slate-600">{{ unitLabel(row) }}</td>
              <td class="px-4 py-3 text-right font-mono">{{ stockQty(row) }}</td>
              <td class="px-4 py-3 text-right font-mono">{{ formatMoney(row.product?.base_price ?? 0) }}</td>
              <td class="px-4 py-3">
                <StatusBadge
                  :active="row.product?.is_active !== false"
                  :label="row.product?.is_active === false ? t('products.inactive') : t('products.active')"
                />
              </td>
              <td class="px-4 py-3 text-right" @click.stop>
                <button class="text-sm text-brand-600" @click="openHistory(row)">{{ t('inventory.history') }}</button>
              </td>
            </tr>
          </tbody>
        </table>
        <p v-if="!rows.length" class="px-4 py-8 text-center text-slate-500">{{ t('org.empty') }}</p>
      </div>
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
        <p v-if="historyLoading" class="text-sm text-slate-500">{{ t('common.loading') }}</p>
        <div v-else class="history-list">
          <p v-if="!history.length" class="px-3 py-6 text-center text-sm text-slate-500">{{ t('inventory.historyEmpty') }}</p>
          <div v-for="row in history" :key="row.id" class="history-row">
            <span
              class="history-arrow"
              :class="isInbound(row) ? 'history-arrow--in' : 'history-arrow--out'"
              :title="isInbound(row) ? t('inventory.historyIn') : t('inventory.historyOut')"
            >
              <svg viewBox="0 0 24 24" aria-hidden="true">
                <path v-if="isInbound(row)" d="M12 19V6M6.5 11.5 12 5l5.5 6.5" />
                <path v-else d="M12 5v13M6.5 12.5 12 19l5.5-6.5" />
              </svg>
            </span>
            <div class="min-w-0 flex-1">
              <span class="block font-medium">{{ movementLabel(row.movement_type) }}</span>
              <span class="text-xs text-slate-500">
                {{ formatDate(row.occurred_at) }}
                <span v-if="row.performed_by?.name"> · {{ row.performed_by.name }}</span>
              </span>
              <span v-if="row.notes" class="mt-0.5 block truncate text-xs text-slate-500">{{ row.notes }}</span>
            </div>
            <span class="history-qty" :class="isInbound(row) ? 'history-qty--in' : 'history-qty--out'">
              {{ isInbound(row) ? '+' : '−' }}{{ displayQty(row) }}
            </span>
          </div>
        </div>
        <div class="app-modal__actions">
          <button type="button" class="btn-secondary" @click="showHistory = false">{{ t('common.cancel') }}</button>
        </div>
      </div>
    </AppModal>

    <AppModal :open="showModal" :title="t('inventory.newMovement')" icon="inventory" tone="info" @close="showModal = false">
      <form class="space-y-3" @submit.prevent="save">
        <div>
          <label class="mb-1 block text-sm font-medium">{{ t('products.name') }}</label>
          <select v-model="form.product_id" required class="field w-full">
            <option v-for="p in products" :key="p.id" :value="p.id">{{ p.sku }} — {{ p.name }}</option>
          </select>
        </div>
        <div>
          <label class="mb-1 block text-sm font-medium">{{ t('inventory.movementType') }}</label>
          <select v-model="form.movement_type" class="field w-full">
            <option v-for="type in movementTypes" :key="type.value" :value="type.value">{{ type.label }}</option>
          </select>
        </div>
        <div>
          <label class="mb-1 block text-sm font-medium">{{ t('sales.qty') }}</label>
          <input v-model.number="form.quantity" type="number" min="1" required class="field w-full" />
        </div>
        <div>
          <label class="mb-1 block text-sm font-medium">{{ t('inventory.reason') }}</label>
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
