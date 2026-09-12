<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import { extractApiErrorMessage } from '../../../api/client'
import InventoryActionDetails from '../../../components/inventory/InventoryActionDetails.vue'
import InventoryLayout from '../../../components/inventory/InventoryLayout.vue'
import { useConfirm } from '../../../composables/useConfirm'
import StatusBadge from '../../../components/organization/StatusBadge.vue'
import AppModal from '../../../components/ui/AppModal.vue'
import { useBackofficeStore } from '../../../stores/backoffice'
import type { Product, StockAdjustmentDetail, Warehouse } from '../../../types'
import { isStockableProduct } from '../../../utils/product'
import { formatDate, formatDateTime } from '../../../utils/format'

const { t } = useI18n()
const store = useBackofficeStore()
const { notify, confirm: confirmDialog } = useConfirm()

const warehouses = ref<Warehouse[]>([])
const products = ref<Product[]>([])
const showModal = ref(false)
const showDetails = ref(false)
const detailsLoading = ref(false)
const detail = ref<StockAdjustmentDetail | null>(null)
const saving = ref(false)

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

onMounted(async () => {
  await store.loadStockAdjustments()
  warehouses.value = await store.loadAllWarehouses()
})

async function openCreate() {
  products.value = (await store.loadAllProducts()).filter(isStockableProduct)
  form.value = {
    warehouse_id: warehouses.value[0]?.id ?? '',
    movement_type: 'ADJUSTMENT_IN',
    reason: '',
    items: [{ product_id: '', quantity: 1 }],
  }
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
    notify(extractApiErrorMessage(error), 'error')
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
  saving.value = true
  try {
    await store.createStockAdjustment({
      warehouse_id: form.value.warehouse_id,
      movement_type: form.value.movement_type,
      reason: form.value.reason || undefined,
      items: form.value.items.filter(i => i.product_id && i.quantity > 0),
    })
    showModal.value = false
    await store.loadStockAdjustments()
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
    <div class="mb-4 flex justify-end">
      <button class="btn-primary" @click="openCreate">+ {{ t('inventory.newAdjustment') }}</button>
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
            <th />
          </tr>
        </thead>
        <tbody class="divide-y divide-slate-100">
          <tr v-for="row in store.stockAdjustments" :key="row.id" class="hover:bg-slate-50">
            <td class="px-4 py-3 font-mono">{{ row.adjustment_number }}</td>
            <td class="px-4 py-3">{{ row.warehouse?.name ?? '—' }}</td>
            <td class="px-4 py-3 text-slate-600">{{ row.reason ?? '—' }}</td>
            <td class="px-4 py-3"><StatusBadge :active="row.status === 'completed'" :label="statusLabel(row.status)" /></td>
            <td class="px-4 py-3 text-slate-500">{{ formatDate(row.created_at) }}</td>
            <td class="px-4 py-3 text-right">
              <button class="text-slate-600" @click="openDetails(row.id)">{{ t('inventory.viewDetails') }}</button>
              <button v-if="row.status === 'draft'" class="ml-3 text-brand-600" @click="confirm(row.id)">{{ t('inventory.confirm') }}</button>
              <button v-else-if="row.status === 'approved'" class="ml-3 text-brand-600" @click="complete(row.id)">{{ t('inventory.confirmFinal') }}</button>
            </td>
          </tr>
        </tbody>
      </table>
      <p v-if="!store.stockAdjustments.length" class="px-4 py-8 text-center text-slate-500">{{ t('org.empty') }}</p>
    </div>

    <AppModal
      :open="showModal"
      :title="t('inventory.newAdjustment')"
      icon="adjust"
      tone="warning"
      size="md"
      @close="showModal = false"
    >
      <form class="space-y-3" @submit.prevent="save">
        <div>
          <label class="mb-1 block text-sm font-medium">{{ t('inventory.warehouse') }}</label>
          <select v-model="form.warehouse_id" required class="field">
            <option v-for="w in warehouses" :key="w.id" :value="w.id">{{ w.name }}</option>
          </select>
        </div>
        <div>
          <label class="mb-1 block text-sm font-medium">{{ t('inventory.movementType') }}</label>
          <select v-model="form.movement_type" required class="field">
            <option v-for="mt in movementTypes" :key="mt.value" :value="mt.value">{{ mt.label }}</option>
          </select>
        </div>
        <div>
          <label class="mb-1 block text-sm font-medium">{{ t('inventory.reason') }}</label>
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
            <button type="button" class="text-sm text-red-600" @click="removeLine(idx)">{{ t('inventory.removeLine') }}</button>
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
.field { width: 100%; border-radius: 0.5rem; border: 1px solid #cbd5e1; padding: 0.5rem 0.75rem; }
.line-row { display: flex; align-items: center; gap: 0.5rem; }
.line-row > .name { flex: 0 1 9.5rem; width: 9.5rem; min-width: 0; }
.line-row > .qty { flex: 1 1 12rem; min-width: 7rem; }
.btn-primary { border-radius: 0.5rem; padding: 0.5rem 1rem; font-weight: 500; color: white; background-color: var(--color-brand-600); }
.btn-secondary { border-radius: 0.5rem; border: 1px solid #cbd5e1; padding: 0.5rem 1rem; }
.text-brand-600 { color: var(--color-brand-600); }
.text-brand-600 { color: var(--color-brand-600); }
</style>
