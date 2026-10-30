<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import { extractApiErrorMessage } from '../../../api/client'
import InventoryActionDetails from '../../../components/inventory/InventoryActionDetails.vue'
import InventoryLayout from '../../../components/inventory/InventoryLayout.vue'
import { useConfirm } from '../../../composables/useConfirm'
import StatusBadge from '../../../components/organization/StatusBadge.vue'
import AppModal from '../../../components/ui/AppModal.vue'
import FieldLabel from '../../../components/ui/FieldLabel.vue'
import ModuleFilters from '../../../components/ui/ModuleFilters.vue'
import ListPager from '../../../components/ui/ListPager.vue'
import { useClientPager } from '../../../composables/useClientPager'
import { useBackofficeStore } from '../../../stores/backoffice'
import { useContextStore } from '../../../stores/context'
import type { Product, StockAdjustmentDetail, Warehouse } from '../../../types'
import { isStockableProduct } from '../../../utils/product'
import { formatDate, formatDateTime } from '../../../utils/format'
import { emptyListFilters, inPeriod, matchesSearch, type ListFilters } from '../../../utils/listFilters'
import AppIcon from '../../../components/ui/AppIcon.vue'

const { t } = useI18n()
const store = useBackofficeStore()
const context = useContextStore()
const { notify, confirm: confirmDialog } = useConfirm()

const warehouses = ref<Warehouse[]>([])
const products = ref<Pick<Product, 'id' | 'name'>[]>([])
const editingId = ref<string | null>(null)
const editingWarehouseName = ref('')
const currentWarehouse = computed(() =>
  warehouses.value.find(w => w.store_id && w.store_id === context.currentStoreId) ?? null,
)
const showModal = ref(false)
const showDetails = ref(false)
const detailsLoading = ref(false)
const detail = ref<StockAdjustmentDetail | null>(null)
const saving = ref(false)
const formError = ref('')

const movementTypes = [
  { value: 'ADJUSTMENT_IN', label: t('inventory.types.adjustmentIn') },
  { value: 'ADJUSTMENT_OUT', label: t('inventory.types.adjustmentOut') },
  { value: 'DAMAGE', label: t('inventory.types.damage') },
  { value: 'LOSS', label: t('inventory.types.loss') },
  { value: 'EXPIRED', label: t('inventory.types.expired') },
]

const form = ref({
  warehouse_id: '',
  movement_type: 'ADJUSTMENT_IN',
  reason: '',
  items: [{ product_id: '', quantity: 1 }],
})

const filters = ref<ListFilters>(emptyListFilters('all'))
const warehouseOptions = computed(() => warehouses.value.map(w => ({ id: w.id, name: w.name })))
const statusOptions = computed(() =>
  ['draft', 'approved', 'completed'].map(value => ({ value, label: statusLabel(value) })),
)
const filtered = computed(() => store.stockAdjustments.filter(row =>
  matchesSearch(
    `${row.adjustment_number} ${row.reason ?? ''} ${row.warehouse?.name ?? ''} ${row.movement_type ?? ''}`,
    filters.value.search,
  )
  && (!filters.value.status || row.status === filters.value.status)
  && inPeriod(row.created_at, filters.value)
  && (!filters.value.warehouse_id || row.warehouse_id === filters.value.warehouse_id),
))

const { page, lastPage, total, perPage, paged, setPage } = useClientPager(filtered)

onMounted(async () => {
  await store.loadStockAdjustments()
  warehouses.value = await store.loadAllWarehouses()
})

async function loadStoreStockables(): Promise<Product[]> {
  const storeId = context.currentStoreId
  if (!storeId) return []
  return (await store.loadStoreProducts(storeId))
    .map(item => item.product)
    .filter(isStockableProduct)
    .sort((a, b) => a.name.localeCompare(b.name))
}

async function openCreate() {
  try {
    products.value = await loadStoreStockables()
  } catch (error) {
    notify(extractApiErrorMessage(error))
    return
  }
  formError.value = ''
  editingId.value = null
  editingWarehouseName.value = ''
  form.value = {
    warehouse_id: currentWarehouse.value?.id ?? '',
    movement_type: 'ADJUSTMENT_IN',
    reason: '',
    items: [{ product_id: '', quantity: 1 }],
  }
  showModal.value = true
}

async function openEdit(id: string) {
  let adjustment: StockAdjustmentDetail
  try {
    const [loaded, stockables] = await Promise.all([store.loadStockAdjustment(id), loadStoreStockables()])
    adjustment = loaded
    products.value = stockables
  } catch (error) {
    notify(extractApiErrorMessage(error))
    return
  }
  if (adjustment.status !== 'draft') {
    await store.loadStockAdjustments()
    return
  }
  const known = new Set(products.value.map(p => p.id))
  for (const item of adjustment.items ?? []) {
    if (!known.has(item.product_id)) {
      products.value.push({ id: item.product_id, name: item.product?.name ?? item.product_id })
      known.add(item.product_id)
    }
  }
  formError.value = ''
  editingId.value = adjustment.id
  editingWarehouseName.value = adjustment.warehouse?.name ?? ''
  form.value = {
    warehouse_id: adjustment.warehouse_id,
    movement_type: adjustment.movement_type ?? 'ADJUSTMENT_IN',
    reason: adjustment.reason ?? '',
    items: (adjustment.items ?? []).map(item => ({ product_id: item.product_id, quantity: item.quantity })),
  }
  if (!form.value.items.length) addLine()
  showModal.value = true
}

function addLine() {
  form.value.items.push({ product_id: '', quantity: 1 })
}

function removeLine(index: number) {
  form.value.items.splice(index, 1)
  if (!form.value.items.length) addLine()
}

function actorLabel(user?: { name: string } | null, at?: string | null) {
  if (!user?.name) return ''
  return at ? `${user.name} · ${formatDateTime(at)}` : user.name
}

function movementLabel(type?: string) {
  return movementTypes.find(item => item.value === type)?.label ?? type ?? '—'
}

async function openDetails(id: string) {
  showDetails.value = true
  detailsLoading.value = true
  detail.value = null
  try {
    detail.value = await store.loadStockAdjustment(id)
  } catch (error) {
    notify(extractApiErrorMessage(error))
    showDetails.value = false
  } finally {
    detailsLoading.value = false
  }
}

function statusLabel(status: string) {
  if (status === 'draft') return t('inventory.statusDraft')
  if (status === 'approved') return t('inventory.statusConfirmed')
  if (status === 'completed') return t('inventory.statusCompleted')
  return status
}

async function save() {
  formError.value = ''
  const items = form.value.items.filter(i => i.product_id && i.quantity > 0)
  if (editingId.value) {
    saving.value = true
    try {
      await store.updateStockAdjustment(editingId.value, {
        reason: form.value.reason || undefined,
        items,
      })
      showModal.value = false
      await store.loadStockAdjustments()
    } catch (error) {
      formError.value = extractApiErrorMessage(error)
    } finally {
      saving.value = false
    }
    return
  }
  form.value.warehouse_id = currentWarehouse.value?.id ?? ''
  if (!form.value.warehouse_id) {
    formError.value = t('inventory.adjustmentNoStore')
    return
  }
  saving.value = true
  try {
    await store.createStockAdjustment({
      warehouse_id: form.value.warehouse_id,
      movement_type: form.value.movement_type,
      reason: form.value.reason || undefined,
      items,
    })
    showModal.value = false
    await store.loadStockAdjustments()
  } catch (error) {
    formError.value = extractApiErrorMessage(error)
  } finally {
    saving.value = false
  }
}

async function askStep(kind: 'confirm' | 'approve', id: string) {
  let detail
  try {
    detail = await store.loadStockAdjustment(id)
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
      items: (detail.items ?? []).map(item => ({
        name: item.product?.name ?? '—',
        detail: item.product?.sku,
        quantity: item.quantity,
      })),
    },
  )
}

async function confirm(id: string) {
  if (!(await askStep('confirm', id))) return
  try {
    await store.confirmStockAdjustment(id)
    await store.loadStockAdjustments()
  } catch (error) {
    await notify(extractApiErrorMessage(error))
  }
}

async function complete(id: string) {
  if (!(await askStep('approve', id))) return
  try {
    await store.completeStockAdjustment(id)
    await store.loadStockAdjustments()
  } catch (error) {
    await notify(extractApiErrorMessage(error))
  }
}
</script>

<template>
  <InventoryLayout>
    <div class="mb-4 space-y-3">
      <div class="flex justify-end">
        <button class="btn-primary" @click="openCreate"><AppIcon name="plus" :size="16" /> {{ t('inventory.newAdjustment') }}</button>
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
            <th class="px-4 py-3 text-left font-medium">{{ t('inventory.reason') }}</th>
            <th class="px-4 py-3 text-left font-medium">{{ t('products.status') }}</th>
            <th class="px-4 py-3 text-left font-medium">{{ t('inventory.date') }}</th>
            <th class="px-4 py-3 text-right font-medium">{{ t('inventory.actions') }}</th>
          </tr>
        </thead>
        <tbody class="divide-y divide-slate-100">
          <tr v-for="row in paged" :key="row.id" class="hover:bg-slate-50">
            <td class="px-4 py-3 font-mono">{{ row.adjustment_number }}</td>
            <td class="px-4 py-3">{{ row.warehouse?.name ?? '—' }}</td>
            <td class="px-4 py-3 text-slate-600">{{ row.reason ?? '—' }}</td>
            <td class="px-4 py-3"><StatusBadge :active="row.status === 'completed'" :label="statusLabel(row.status)" /></td>
            <td class="px-4 py-3 text-slate-500">{{ formatDate(row.created_at) }}</td>
            <td class="px-4 py-3">
              <div class="row-actions">
                <button class="row-action row-action--view" @click="openDetails(row.id)"><AppIcon name="eye" :size="16" /> {{ t('inventory.viewDetails') }}</button>
                <button v-if="row.status === 'draft'" class="row-action row-action--edit" @click="openEdit(row.id)"><AppIcon name="edit" :size="16" /> {{ t('common.edit') }}</button>
                <button v-if="row.status === 'draft'" class="row-action row-action--confirm" @click="confirm(row.id)"><AppIcon name="check" :size="16" /> {{ t('inventory.confirm') }}</button>
                <button v-else-if="row.status === 'approved'" class="row-action row-action--approve" @click="complete(row.id)"><AppIcon name="check" :size="16" /> {{ t('inventory.confirmFinal') }}</button>
              </div>
            </td>
          </tr>
        </tbody>
      </table>
      <p v-if="!filtered.length" class="px-4 py-8 text-center text-slate-500">{{ t('org.empty') }}</p>
      <ListPager
        :page="page"
        :last-page="lastPage"
        :total="total"
        :per-page="perPage"
        @change="setPage"
      />
    </div>

    <AppModal
      :open="showModal"
      :title="editingId ? t('inventory.editAdjustment') : t('inventory.newAdjustment')"
      icon="adjust"
      tone="warning"
      size="xl"
      @close="showModal = false"
    >
      <form class="space-y-3" @submit.prevent="save">
        <div>
          <FieldLabel icon="inventory">{{ t('inventory.warehouse') }}</FieldLabel>
          <input class="field" :value="(editingId ? editingWarehouseName : currentWarehouse?.name) || '—'" readonly tabindex="-1">
          <p class="mt-1 text-xs text-slate-500">{{ t('inventory.adjustmentStoreFixed') }}</p>
        </div>
        <p v-if="!editingId && !currentWarehouse" class="text-sm text-red-600">{{ t('inventory.adjustmentNoStore') }}</p>
        <p v-else-if="!products.length" class="text-sm text-amber-700">{{ t('inventory.supplyNoProducts') }}</p>
        <div>
          <FieldLabel icon="transfer">{{ t('inventory.movementType') }}</FieldLabel>
          <select v-model="form.movement_type" required class="field" :disabled="!!editingId">
            <option v-for="mt in movementTypes" :key="mt.value" :value="mt.value">{{ mt.label }}</option>
          </select>
        </div>
        <div>
          <FieldLabel icon="note">{{ t('inventory.reason') }}</FieldLabel>
          <input v-model="form.reason" class="field" />
        </div>
        <p class="text-xs text-slate-500">{{ t('inventory.entryHint') }}</p>
        <p class="text-xs text-slate-500">{{ t('inventory.stockableOnly') }}</p>
        <div class="space-y-2">
          <div v-for="(line, idx) in form.items" :key="idx" class="line-row">
            <select v-model="line.product_id" required class="field name">
              <option value="">—</option>
              <option v-for="p in products" :key="p.id" :value="p.id">{{ p.name }}</option>
            </select>
            <input v-model.number="line.quantity" type="number" min="1" required class="field qty" />
            <button type="button" class="text-sm text-red-600" @click="removeLine(idx)"><AppIcon name="trash" :size="16" /> {{ t('inventory.removeLine') }}</button>
          </div>
          <button type="button" class="text-sm text-brand-600" @click="addLine"><AppIcon name="plus" :size="16" /> {{ t('inventory.addLine') }}</button>
        </div>
        <p v-if="formError" class="text-sm text-red-600">{{ formError }}</p>
        <div class="app-modal__actions">
          <button type="button" class="btn-secondary" @click="showModal = false"><AppIcon name="close" :size="16" /> {{ t('common.cancel') }}</button>
          <button type="submit" class="btn-primary" :class="{ 'is-busy': saving }" :disabled="saving || (!editingId && !currentWarehouse)">{{ editingId ? t('common.saveChanges') : t('inventory.saveEntry') }}</button>
        </div>
      </form>
    </AppModal>

    <InventoryActionDetails
      :open="showDetails"
      :title="t('inventory.detailsTitle')"
      :reference="detail?.adjustment_number"
      :status="detail?.status"
      :status-label="detail ? statusLabel(detail.status) : ''"
      :loading="detailsLoading"
      :confirmed-by="actorLabel(detail?.confirmed_by)"
      :approved-by="detail?.status === 'completed' ? actorLabel(detail?.approved_by) : ''"
      :fields="[
        { label: t('inventory.warehouse'), value: detail?.warehouse?.name },
        { label: t('inventory.reason'), value: detail?.reason || movementLabel(detail?.movement_type) },
        { label: t('inventory.date'), value: formatDate(detail?.created_at) },
      ]"
      :items="(detail?.items ?? []).map(item => ({
        name: item.product?.name ?? '—',
        sku: item.product?.sku,
        quantity: item.quantity,
      }))"
      @close="showDetails = false"
    />
  </InventoryLayout>
</template>

<style scoped>

.line-row { display: flex; align-items: center; gap: 0.5rem; }
.line-row > .name { flex: 1 1 16rem; width: auto; min-width: 0; }
.line-row > .qty { flex: 0 0 7rem; width: 7rem; min-width: 6rem; }

.btn-secondary { border-radius: 0.5rem; border: 1px solid #cbd5e1; padding: 0.5rem 1rem; }
.text-brand-600 { color: var(--color-ink-brand, var(--color-brand-600));}
.text-brand-600 { color: var(--color-ink-brand, var(--color-brand-600));}
</style>
