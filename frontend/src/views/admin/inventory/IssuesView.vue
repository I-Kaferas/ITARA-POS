<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import { extractApiErrorMessage } from '../../../api/client'
import InventoryActionDetails from '../../../components/inventory/InventoryActionDetails.vue'
import InventoryLayout from '../../../components/inventory/InventoryLayout.vue'
import WarehouseOptions from '../../../components/inventory/WarehouseOptions.vue'
import StatusBadge from '../../../components/organization/StatusBadge.vue'
import AppModal from '../../../components/ui/AppModal.vue'
import FieldLabel from '../../../components/ui/FieldLabel.vue'
import ModuleFilters from '../../../components/ui/ModuleFilters.vue'
import { useConfirm } from '../../../composables/useConfirm'
import { useBackofficeStore } from '../../../stores/backoffice'
import type { Product, StockAdjustment, StockAdjustmentDetail, StockAdjustmentItem, StockBalance, Warehouse } from '../../../types'
import { isStockableProduct } from '../../../utils/product'
import { formatDate, formatDateTime } from '../../../utils/format'
import { emptyListFilters, inPeriod, matchesSearch, type ListFilters } from '../../../utils/listFilters'

type SaleUnit = { id: string; name: string; volume_ml: number; is_base?: boolean }
type IssueLine = {
  product_id: string
  quantity: number
  sale_unit_id: string
  units: SaleUnit[]
  bottle_volume_ml: number
}

const { t } = useI18n()
const store = useBackofficeStore()
const { notify, confirm: confirmDialog } = useConfirm()

const warehouses = ref<Warehouse[]>([])
const products = ref<Product[]>([])
const balances = ref<StockBalance[]>([])
const rows = ref<StockAdjustment[]>([])
const showModal = ref(false)
const showDetails = ref(false)
const detailsLoading = ref(false)
const detail = ref<StockAdjustmentDetail | null>(null)
const saving = ref(false)
const formError = ref('')

const movementTypes = [
  { value: 'LOSS', label: t('inventory.types.loss') },
  { value: 'DAMAGE', label: t('inventory.types.damage') },
  { value: 'EXPIRED', label: t('inventory.types.expired') },
  { value: 'ADJUSTMENT_OUT', label: t('inventory.types.adjustmentOut') },
]

const form = ref({
  warehouse_id: '',
  movement_type: 'LOSS',
  reason: '',
  items: [emptyLine()],
})

const filters = ref<ListFilters>(emptyListFilters('all'))
const warehouseOptions = computed(() => warehouses.value.map(w => ({ id: w.id, name: w.name })))
const statusOptions = computed(() =>
  ['draft', 'approved', 'completed'].map(value => ({ value, label: statusLabel(value) })),
)
const filtered = computed(() => rows.value.filter(row =>
  matchesSearch(
    `${row.adjustment_number} ${row.reason ?? ''} ${row.warehouse?.name ?? ''} ${row.movement_type ?? ''}`,
    filters.value.search,
  )
  && (!filters.value.status || row.status === filters.value.status)
  && inPeriod(row.created_at, filters.value)
  && (!filters.value.warehouse_id || row.warehouse_id === filters.value.warehouse_id),
))

function emptyLine(): IssueLine {
  return { product_id: '', quantity: 1, sale_unit_id: '', units: [], bottle_volume_ml: 0 }
}

onMounted(async () => {
  warehouses.value = await store.loadAllWarehouses()
  await refresh()
})

async function refresh() {
  await store.loadStockAdjustments(true)
  rows.value = [...store.stockAdjustments]
}

async function openCreate() {
  products.value = (await store.loadAllProducts()).filter(isStockableProduct)
  formError.value = ''
  form.value = {
    warehouse_id: warehouses.value[0]?.id ?? '',
    movement_type: 'LOSS',
    reason: '',
    items: [emptyLine()],
  }
  showModal.value = true
  await loadStock(form.value.warehouse_id)
}

async function loadStock(warehouseId: string) {
  if (!warehouseId) {
    balances.value = []
    return
  }
  try {
    await store.loadStockBalances(warehouseId)
    balances.value = [...store.stockBalances]
  } catch {
    balances.value = []
  }
}

function addLine() {
  form.value.items.push(emptyLine())
}

function removeLine(index: number) {
  form.value.items.splice(index, 1)
  if (!form.value.items.length) addLine()
}

function productsForLine(index: number) {
  const used = new Set(
    form.value.items
      .filter((_, i) => i !== index)
      .map(line => line.product_id)
      .filter(Boolean),
  )
  return products.value.filter(product => !used.has(product.id) || product.id === form.value.items[index]?.product_id)
}

async function onProduct(index: number) {
  const line = form.value.items[index]
  if (!line?.product_id) {
    form.value.items[index] = emptyLine()
    return
  }
  try {
    const detailProduct = await store.loadProduct(line.product_id)
    const units = (detailProduct.sale_units ?? []).filter(unit => unit.volume_ml > 0)
    const base = units.find(unit => unit.is_base) ?? units[0]
    form.value.items[index] = {
      ...line,
      units,
      sale_unit_id: base?.id ?? '',
      bottle_volume_ml: Number(detailProduct.bottle_volume_ml ?? 0),
    }
  } catch (error) {
    notify(extractApiErrorMessage(error), 'error')
  }
}

function available(productId: string, bottleMl: number) {
  const row = balances.value.find(item => item.product_id === productId)
  const qty = row?.quantity_available ?? 0
  if (bottleMl > 0) {
    const bottles = Math.floor(qty / bottleMl)
    const remainder = qty % bottleMl
    return remainder ? `${bottles} + ${remainder} ml` : String(bottles)
  }
  return String(qty)
}

function conversion(line: IssueLine) {
  const unit = line.units.find(item => item.id === line.sale_unit_id)
  if (!unit?.volume_ml) return ''
  const qty = Math.max(0, Math.trunc(Number(line.quantity) || 0))
  return `${qty} ${unit.name} = ${qty * unit.volume_ml} ml`
}

function displayQuantity(item: StockAdjustmentItem) {
  if (item.entered_quantity && item.unit_name) return `${item.entered_quantity} ${item.unit_name}`
  return item.quantity
}

function actorLabel(user?: { name: string } | null, at?: string | null) {
  if (!user?.name) return ''
  return at ? `${user.name} · ${formatDateTime(at)}` : user.name
}

function movementLabel(type?: string) {
  return movementTypes.find(item => item.value === type)?.label ?? type ?? '—'
}

function statusLabel(status: string) {
  if (status === 'draft') return t('inventory.statusDraft')
  if (status === 'approved') return t('inventory.statusConfirmed')
  if (status === 'completed') return t('inventory.statusCompleted')
  return status
}

async function openDetails(id: string) {
  showDetails.value = true
  detailsLoading.value = true
  detail.value = null
  try {
    detail.value = await store.loadStockAdjustment(id)
  } catch (error) {
    notify(extractApiErrorMessage(error), 'error')
    showDetails.value = false
  } finally {
    detailsLoading.value = false
  }
}

async function save() {
  const items = form.value.items
    .filter(line => line.product_id && line.quantity >= 1)
    .map(line => ({
      product_id: line.product_id,
      quantity: Math.trunc(line.quantity),
      sale_unit_id: line.sale_unit_id || null,
    }))
  if (!form.value.warehouse_id || !items.length) {
    formError.value = t('inventory.needItems')
    return
  }
  saving.value = true
  formError.value = ''
  try {
    await store.createStockAdjustment({
      warehouse_id: form.value.warehouse_id,
      movement_type: form.value.movement_type,
      reason: form.value.reason || undefined,
      items,
    })
    showModal.value = false
    await refresh()
  } catch (error) {
    formError.value = extractApiErrorMessage(error)
  } finally {
    saving.value = false
  }
}

async function askStep(kind: 'confirm' | 'approve', id: string) {
  let loaded: StockAdjustmentDetail
  try {
    loaded = await store.loadStockAdjustment(id)
  } catch (error) {
    await notify(extractApiErrorMessage(error))
    return false
  }
  return confirmDialog(
    kind === 'approve' ? t('inventory.approveModalMessage') : t('inventory.confirmModalMessage'),
    {
      title: kind === 'approve' ? t('inventory.approveModalTitle') : t('inventory.confirmModalTitle'),
      confirmLabel: kind === 'approve' ? t('inventory.confirmFinal') : t('inventory.confirm'),
      danger: false,
      items: (loaded.items ?? []).map(item => ({
        name: item.product?.name ?? '—',
        detail: item.product?.sku,
        quantity: displayQuantity(item),
      })),
    },
  )
}

async function confirmIssue(id: string) {
  if (!(await askStep('confirm', id))) return
  try {
    await store.confirmStockAdjustment(id)
    await refresh()
  } catch (error) {
    await notify(extractApiErrorMessage(error))
  }
}

async function complete(id: string) {
  if (!(await askStep('approve', id))) return
  try {
    await store.completeStockAdjustment(id)
    await refresh()
  } catch (error) {
    await notify(extractApiErrorMessage(error))
  }
}
</script>

<template>
  <InventoryLayout>
    <div class="mb-4 space-y-3">
      <div class="flex justify-end">
        <button class="btn-primary" @click="openCreate">+ {{ t('inventory.newIssue') }}</button>
      </div>
      <ModuleFilters
        v-model="filters"
        :statuses="statusOptions"
        :warehouses="warehouseOptions"
        show-search
        show-period
        show-status
        show-warehouse
      />
    </div>

    <div class="overflow-hidden rounded-xl bg-white shadow-sm ring-1 ring-slate-200">
      <table class="min-w-full divide-y divide-slate-200 text-sm">
        <thead class="bg-slate-50">
          <tr>
            <th class="px-4 py-3 text-left font-medium">#</th>
            <th class="px-4 py-3 text-left font-medium">{{ t('inventory.warehouse') }}</th>
            <th class="px-4 py-3 text-left font-medium">{{ t('inventory.movementType') }}</th>
            <th class="px-4 py-3 text-left font-medium">{{ t('inventory.reason') }}</th>
            <th class="px-4 py-3 text-left font-medium">{{ t('products.status') }}</th>
            <th class="px-4 py-3 text-left font-medium">{{ t('inventory.date') }}</th>
            <th />
          </tr>
        </thead>
        <tbody class="divide-y divide-slate-100">
          <tr v-for="row in filtered" :key="row.id" class="hover:bg-slate-50">
            <td class="px-4 py-3 font-mono">{{ row.adjustment_number }}</td>
            <td class="px-4 py-3">{{ row.warehouse?.name ?? '—' }}</td>
            <td class="px-4 py-3">{{ movementLabel(row.movement_type) }}</td>
            <td class="px-4 py-3 text-slate-600">{{ row.reason ?? '—' }}</td>
            <td class="px-4 py-3"><StatusBadge :active="row.status === 'completed'" :label="statusLabel(row.status)" /></td>
            <td class="px-4 py-3 text-slate-500">{{ formatDate(row.created_at) }}</td>
            <td class="px-4 py-3 text-right">
              <button class="text-slate-600" @click="openDetails(row.id)">{{ t('inventory.viewDetails') }}</button>
              <button v-if="row.status === 'draft'" class="ml-3 text-brand-600" @click="confirmIssue(row.id)">{{ t('inventory.confirm') }}</button>
              <button v-else-if="row.status === 'approved'" class="ml-3 text-brand-600" @click="complete(row.id)">{{ t('inventory.confirmFinal') }}</button>
            </td>
          </tr>
        </tbody>
      </table>
      <p v-if="!filtered.length" class="px-4 py-8 text-center text-slate-500">{{ t('inventory.issueEmpty') }}</p>
    </div>

    <AppModal
      :open="showModal"
      :title="t('inventory.newIssue')"
      icon="inventory"
      tone="warning"
      size="xl"
      @close="showModal = false"
    >
      <form class="space-y-3" @submit.prevent="save">
        <div>
          <FieldLabel icon="inventory">{{ t('inventory.warehouse') }}</FieldLabel>
          <WarehouseOptions v-model="form.warehouse_id" :warehouses="warehouses" @update:model-value="loadStock" />
        </div>
        <div>
          <FieldLabel icon="transfer">{{ t('inventory.movementType') }}</FieldLabel>
          <select v-model="form.movement_type" required class="field">
            <option v-for="mt in movementTypes" :key="mt.value" :value="mt.value">{{ mt.label }}</option>
          </select>
        </div>
        <div>
          <FieldLabel icon="note">{{ t('inventory.reason') }}</FieldLabel>
          <input v-model="form.reason" class="field" />
        </div>
        <p class="text-xs text-slate-500">{{ t('inventory.issueHint') }}</p>
        <p class="text-xs text-slate-500">{{ t('inventory.quantifiableOnly') }}</p>
        <p v-if="formError" class="rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700">{{ formError }}</p>
        <div class="space-y-3">
          <div v-for="(line, idx) in form.items" :key="idx" class="space-y-2 rounded-lg bg-slate-50 p-3">
            <div class="line-row">
              <select v-model="line.product_id" required class="field name" @change="onProduct(idx)">
                <option value="">—</option>
                <option v-for="product in productsForLine(idx)" :key="product.id" :value="product.id">{{ product.name }}</option>
              </select>
              <input v-model.number="line.quantity" type="number" min="1" required class="field qty" />
              <select v-if="line.units.length" v-model="line.sale_unit_id" class="field unit">
                <option v-for="unit in line.units" :key="unit.id" :value="unit.id">{{ unit.name }}</option>
              </select>
              <button type="button" class="text-sm text-red-600" @click="removeLine(idx)">{{ t('inventory.removeLine') }}</button>
            </div>
            <p v-if="line.product_id" class="text-xs text-slate-500">
              {{ t('inventory.availableStock') }} : {{ available(line.product_id, line.bottle_volume_ml) }}
              <span v-if="conversion(line)"> · {{ conversion(line) }}</span>
            </p>
          </div>
          <button type="button" class="text-sm text-brand-600" @click="addLine">+ {{ t('inventory.addLine') }}</button>
        </div>
        <div class="app-modal__actions">
          <button type="button" class="btn-secondary" @click="showModal = false">{{ t('common.cancel') }}</button>
          <button type="submit" class="btn-primary" :disabled="saving">{{ t('inventory.saveEntry') }}</button>
        </div>
      </form>
    </AppModal>

    <InventoryActionDetails
      :open="showDetails"
      :title="t('inventory.newIssue')"
      :reference="detail?.adjustment_number"
      :status="detail?.status"
      :status-label="detail ? statusLabel(detail.status) : ''"
      :loading="detailsLoading"
      :confirmed-by="actorLabel(detail?.confirmed_by)"
      :approved-by="detail?.status === 'completed' ? actorLabel(detail?.approved_by) : ''"
      :fields="[
        { label: t('inventory.warehouse'), value: detail?.warehouse?.name },
        { label: t('inventory.movementType'), value: movementLabel(detail?.movement_type) },
        { label: t('inventory.reason'), value: detail?.reason },
        { label: t('inventory.date'), value: formatDate(detail?.created_at) },
      ]"
      :items="(detail?.items ?? []).map(item => ({
        name: item.product?.name ?? '—',
        sku: item.product?.sku,
        quantity: displayQuantity(item),
      }))"
      @close="showDetails = false"
    />
  </InventoryLayout>
</template>

<style scoped>

.line-row { display: flex; align-items: center; gap: 0.5rem; }
.line-row > .name { flex: 1 1 16rem; min-width: 0; }
.line-row > .qty { flex: 0 0 6.5rem; width: 6.5rem; }
.line-row > .unit { flex: 0 1 10rem; width: 10rem; }

.btn-secondary { border-radius: 0.5rem; border: 1px solid #cbd5e1; padding: 0.5rem 1rem; }
.text-brand-600 { color: var(--color-brand-600); }
</style>
