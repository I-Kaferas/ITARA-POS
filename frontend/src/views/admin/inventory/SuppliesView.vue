<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import { extractApiErrorMessage } from '../../../api/client'
import InventoryActionDetails from '../../../components/inventory/InventoryActionDetails.vue'
import InventoryLayout from '../../../components/inventory/InventoryLayout.vue'
import StatusBadge from '../../../components/organization/StatusBadge.vue'
import AppModal from '../../../components/ui/AppModal.vue'
import FieldLabel from '../../../components/ui/FieldLabel.vue'
import { useConfirm } from '../../../composables/useConfirm'
import { useBackofficeStore } from '../../../stores/backoffice'
import type { Product, PurchaseOrderDetail, Warehouse } from '../../../types'
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
const detail = ref<PurchaseOrderDetail | null>(null)
const saving = ref(false)
const formError = ref('')
const form = ref({
  warehouse_id: '',
  supplier_id: '',
  notes: '',
  items: [{ product_id: '', quantity: 1 }],
})

onMounted(async () => {
  try {
    await Promise.all([store.loadPurchaseOrders(), store.loadSuppliers()])
    warehouses.value = await store.loadAllWarehouses()
  } catch (error) {
    notify(extractApiErrorMessage(error))
  }
})

function productsForLine(index: number) {
  const used = new Set(
    form.value.items
      .filter((_, i) => i !== index)
      .map(line => line.product_id)
      .filter(Boolean),
  )
  return products.value.filter(p => !used.has(p.id))
}

function addLine() {
  form.value.items.push({ product_id: '', quantity: 1 })
}

function removeLine(index: number) {
  form.value.items.splice(index, 1)
  if (!form.value.items.length) addLine()
}

async function openCreate() {
  products.value = (await store.loadAllProducts()).filter(isStockableProduct)
  formError.value = ''
  form.value = {
    warehouse_id: warehouses.value[0]?.id ?? '',
    supplier_id: '',
    notes: '',
    items: [{ product_id: '', quantity: 1 }],
  }
  showModal.value = true
}

function actorLabel(user?: { name: string } | null, at?: string | null) {
  if (!user?.name) return ''
  return at ? `${user.name} · ${formatDateTime(at)}` : user.name
}

function isApplied(status?: string) {
  return !!status && ['approved', 'partially_received', 'received', 'completed'].includes(status)
}

async function openDetails(id: string) {
  showDetails.value = true
  detailsLoading.value = true
  detail.value = null
  try {
    detail.value = await store.loadPurchaseOrder(id)
  } catch (error) {
    notify(extractApiErrorMessage(error))
    showDetails.value = false
  } finally {
    detailsLoading.value = false
  }
}

function statusLabel(status: string) {
  if (status === 'draft') return t('inventory.statusDraft')
  if (status === 'pending') return t('inventory.statusPending')
  if (status === 'approved') return t('inventory.statusApproved')
  if (status === 'partially_received') return t('inventory.statusPartial')
  if (['received', 'completed'].includes(status)) return t('inventory.statusCompleted')
  return status
}

function canConfirm(status: string) {
  return ['draft', 'pending', 'approved', 'partially_received'].includes(status)
}

function confirmLabel(status: string) {
  if (status === 'draft') return t('inventory.confirm')
  if (status === 'pending') return t('inventory.confirmFinal')
  return t('inventory.receiveStock')
}

async function receiveRemaining(id: string) {
  const order = await store.loadPurchaseOrder(id)
  const items = (order.items ?? [])
    .map(item => ({
      purchase_order_item_id: item.id,
      quantity: item.remaining ?? Math.max(0, (item.quantity_ordered ?? item.quantity ?? 0) - (item.received_quantity ?? item.quantity_received ?? 0)),
    }))
    .filter(item => item.quantity > 0)
  if (!items.length) return
  await store.receivePurchaseOrder(id, { notes: t('inventory.supplyReceiptNote'), items })
}

async function save() {
  formError.value = ''
  const items = form.value.items
    .filter(line => line.product_id && line.quantity > 0)
    .map(line => {
      const product = products.value.find(item => item.id === line.product_id)
      return {
        product_id: line.product_id,
        quantity: Math.trunc(line.quantity),
        unit_cost: product?.cost_price ?? 0,
      }
    })

  if (!items.length) {
    formError.value = t('inventory.needItems')
    return
  }

  saving.value = true
  try {
    await store.createPurchaseOrder({
      warehouse_id: form.value.warehouse_id,
      supplier_id: form.value.supplier_id || null,
      notes: form.value.notes || undefined,
      items,
    })
    showModal.value = false
    await store.loadPurchaseOrders()
  } catch (error) {
    formError.value = extractApiErrorMessage(error)
  } finally {
    saving.value = false
  }
}

async function confirm(id: string, status: string) {
  const approve = status !== 'draft'
  if (!(await confirmDialog(
    approve ? t('inventory.approveModalMessage') : t('inventory.confirmModalMessage'),
    {
      title: approve ? t('inventory.approveModalTitle') : t('inventory.confirmModalTitle'),
      confirmLabel: confirmLabel(status),
      danger: false,
    },
  ))) return
  try {
    if (status === 'draft' || status === 'pending') {
      await store.confirmPurchaseOrderStep(id)
    }
    if (status !== 'draft') {
      await receiveRemaining(id)
    }
    await store.loadPurchaseOrders()
  } catch (error) {
    await notify(extractApiErrorMessage(error))
    await store.loadPurchaseOrders()
  }
}
</script>

<template>
  <InventoryLayout>
    <div class="mb-4 flex justify-end">
      <button class="btn-primary" @click="openCreate">+ {{ t('inventory.newSupply') }}</button>
    </div>

    <div class="overflow-hidden rounded-xl bg-white shadow-sm ring-1 ring-slate-200">
      <table class="min-w-full divide-y divide-slate-200 text-sm">
        <thead class="bg-slate-50">
          <tr>
            <th class="px-4 py-3 text-left font-medium">#</th>
            <th class="px-4 py-3 text-left font-medium">{{ t('inventory.warehouse') }}</th>
            <th class="px-4 py-3 text-left font-medium">{{ t('inventory.supplier') }}</th>
            <th class="px-4 py-3 text-left font-medium">{{ t('products.status') }}</th>
            <th class="px-4 py-3 text-left font-medium">{{ t('inventory.date') }}</th>
            <th class="px-4 py-3 text-right font-medium">{{ t('common.edit') }}</th>
          </tr>
        </thead>
        <tbody class="divide-y divide-slate-100">
          <tr v-for="row in store.purchaseOrders" :key="row.id" class="hover:bg-slate-50">
            <td class="px-4 py-3 font-mono">{{ row.order_number }}</td>
            <td class="px-4 py-3">{{ row.warehouse?.name ?? '—' }}</td>
            <td class="px-4 py-3">{{ row.supplier?.name ?? '—' }}</td>
            <td class="px-4 py-3">
              <StatusBadge :active="['received', 'completed'].includes(row.status)" :label="statusLabel(row.status)" />
            </td>
            <td class="px-4 py-3 text-slate-500">{{ formatDate(row.created_at) }}</td>
            <td class="px-4 py-3 text-right">
              <button class="text-slate-600" @click="openDetails(row.id)">{{ t('inventory.viewDetails') }}</button>
              <button v-if="canConfirm(row.status)" class="ml-3 text-brand-600" @click="confirm(row.id, row.status)">
                {{ confirmLabel(row.status) }}
              </button>
            </td>
          </tr>
        </tbody>
      </table>
      <p v-if="!store.purchaseOrders.length" class="px-4 py-8 text-center text-slate-500">{{ t('org.empty') }}</p>
    </div>

    <AppModal
      :open="showModal"
      :title="t('inventory.newSupply')"
      icon="purchases"
      tone="info"
      size="xl"
      @close="showModal = false"
    >
      <form class="space-y-3" @submit.prevent="save">
        <div>
          <FieldLabel icon="inventory">{{ t('inventory.warehouse') }}</FieldLabel>
          <select v-model="form.warehouse_id" required class="field">
            <option v-for="w in warehouses" :key="w.id" :value="w.id">{{ w.name }}</option>
          </select>
        </div>
        <div>
          <FieldLabel icon="suppliers">{{ t('inventory.supplier') }}</FieldLabel>
          <select v-model="form.supplier_id" class="field">
            <option value="">—</option>
            <option v-for="s in store.suppliers" :key="s.id" :value="s.id">{{ s.name }}</option>
          </select>
          <p class="mt-1 text-xs text-slate-500">{{ t('inventory.supplierOptionalHint') }}</p>
        </div>
        <p class="text-xs text-slate-500">{{ t('inventory.entryHint') }}</p>
        <p v-if="formError" class="text-sm text-red-600">{{ formError }}</p>
        <div class="space-y-2">
          <div v-for="(line, idx) in form.items" :key="idx" class="line-row">
            <select v-model="line.product_id" required class="field">
              <option value="">—</option>
              <option v-for="p in productsForLine(idx)" :key="p.id" :value="p.id">{{ p.name }}</option>
            </select>
            <input v-model.number="line.quantity" type="number" min="1" required class="field qty" />
            <button type="button" class="text-sm text-red-600" @click="removeLine(idx)">{{ t('inventory.removeLine') }}</button>
          </div>
          <button v-if="form.items.length < products.length" type="button" class="text-sm text-brand-600" @click="addLine">+ {{ t('inventory.addLine') }}</button>
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
      :reference="detail?.order_number"
      :status="detail?.status"
      :status-label="detail ? statusLabel(detail.status) : ''"
      :loading="detailsLoading"
      :confirmed-by="actorLabel(detail?.confirmed_by_user, detail?.submitted_at)"
      :approved-by="isApplied(detail?.status) ? actorLabel(detail?.approved_by_user, detail?.approved_at) : ''"
      :fields="[
        { label: t('inventory.warehouse'), value: detail?.warehouse?.name },
        { label: t('inventory.supplier'), value: detail?.supplier?.name },
        { label: t('inventory.date'), value: formatDate(detail?.created_at) },
      ]"
      :items="(detail?.items ?? []).map(item => ({
        name: item.product?.name ?? '—',
        sku: item.product?.sku,
        quantity: item.quantity_ordered ?? item.quantity,
      }))"
      @close="showDetails = false"
    />
  </InventoryLayout>
</template>

<style scoped>
.field { width: 100%; border-radius: 0.5rem; border: 1px solid #cbd5e1; padding: 0.5rem 0.75rem; }
.line-row { display: flex; align-items: center; gap: 0.5rem; }
.line-row > .field { flex: 1 1 14rem; min-width: 0; }
.line-row > .qty { flex: 0 0 6.5rem; width: 6.5rem; padding-left: 0.4rem; padding-right: 0.35rem; text-align: center; }
.btn-primary { border-radius: 0.5rem; padding: 0.5rem 1rem; font-weight: 500; color: white; background-color: var(--color-brand-600); }
.btn-secondary { border-radius: 0.5rem; border: 1px solid #cbd5e1; padding: 0.5rem 1rem; }
.text-brand-600 { color: var(--color-brand-600); }
</style>
