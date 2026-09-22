<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import { extractApiErrorMessage } from '../../../api/client'
import InventoryActionDetails from '../../../components/inventory/InventoryActionDetails.vue'
import InventoryLayout from '../../../components/inventory/InventoryLayout.vue'
import StatusBadge from '../../../components/organization/StatusBadge.vue'
import AppModal from '../../../components/ui/AppModal.vue'
import FieldLabel from '../../../components/ui/FieldLabel.vue'
import ModuleFilters from '../../../components/ui/ModuleFilters.vue'
import { useConfirm } from '../../../composables/useConfirm'
import { useBackofficeStore } from '../../../stores/backoffice'
import type { Product, StockTransferDetail, Warehouse } from '../../../types'
import { isStockableProduct } from '../../../utils/product'
import { formatDate, formatDateTime } from '../../../utils/format'
import { emptyListFilters, inPeriod, matchesSearch, type ListFilters } from '../../../utils/listFilters'

const { t } = useI18n()
const store = useBackofficeStore()
const { notify, confirm: confirmDialog } = useConfirm()

const warehouses = ref<Warehouse[]>([])
const products = ref<Product[]>([])
const showModal = ref(false)
const showDetails = ref(false)
const detailsLoading = ref(false)
const detail = ref<StockTransferDetail | null>(null)
const saving = ref(false)
const formError = ref('')

const destinationWarehouses = computed(() =>
  warehouses.value.filter(w => w.id !== form.value.source_warehouse_id),
)
const filters = ref<ListFilters>(emptyListFilters('all'))
const warehouseOptions = computed(() => warehouses.value.map(w => ({ id: w.id, name: w.name })))
const statusOptions = computed(() =>
  ['draft', 'pending', 'approved', 'in_transit', 'completed', 'cancelled'].map(value => ({
    value,
    label: statusLabel(value),
  })),
)
const filtered = computed(() => store.stockTransfers.filter(row =>
  matchesSearch(
    `${row.transfer_number} ${(row as { notes?: string | null }).notes ?? ''} ${row.source_warehouse?.name ?? ''} ${row.destination_warehouse?.name ?? ''}`,
    filters.value.search,
  )
  && (!filters.value.status || row.status === filters.value.status)
  && inPeriod(row.created_at, filters.value)
  && (!filters.value.warehouse_id
    || row.source_warehouse_id === filters.value.warehouse_id
    || row.destination_warehouse_id === filters.value.warehouse_id),
))
const form = ref({
  source_warehouse_id: '',
  destination_warehouse_id: '',
  notes: '',
  items: [{ product_id: '', quantity: 1 }],
})

onMounted(async () => {
  await store.loadStockTransfers()
  warehouses.value = await store.loadAllWarehouses()
})

function pickDestination(sourceId: string) {
  return warehouses.value.find(w => w.id !== sourceId)?.id ?? ''
}

watch(() => form.value.source_warehouse_id, (sourceId) => {
  if (!sourceId || form.value.destination_warehouse_id === sourceId) {
    form.value.destination_warehouse_id = pickDestination(sourceId)
  }
})

async function openCreate() {
  products.value = (await store.loadAllProducts()).filter(isStockableProduct)
  const sourceId = warehouses.value[0]?.id ?? ''
  formError.value = ''
  form.value = {
    source_warehouse_id: sourceId,
    destination_warehouse_id: pickDestination(sourceId),
    notes: '',
    items: [{ product_id: '', quantity: 1 }],
  }
  showModal.value = true
}

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

function actorLabel(user?: { name: string } | null, at?: string | null) {
  if (!user?.name) return ''
  return at ? `${user.name} · ${formatDateTime(at)}` : user.name
}

function confirmedActor(row: StockTransferDetail | null) {
  if (!row) return ''
  if (row.confirmed_by) return actorLabel(row.confirmed_by, row.confirmed_at)
  return actorLabel(row.approved_by)
}

function approvedActor(row: StockTransferDetail | null) {
  if (!row || row.status !== 'completed' || !row.confirmed_by) return ''
  return actorLabel(row.approved_by)
}

async function openDetails(id: string) {
  showDetails.value = true
  detailsLoading.value = true
  detail.value = null
  try {
    detail.value = await store.loadStockTransfer(id)
  } catch (error) {
    notify(extractApiErrorMessage(error), 'error')
    showDetails.value = false
  } finally {
    detailsLoading.value = false
  }
}

function statusLabel(status: string) {
  const key = `inventory.transferStatus.${status}`
  const label = t(key)
  return label === key ? status : label
}

function transferSteps(status?: string) {
  const labels = [
    t('inventory.storeA'),
    t('inventory.transferSteps.request'),
    t('inventory.transferSteps.validation'),
    t('inventory.transferSteps.shipment'),
    t('inventory.transferSteps.transit'),
    t('inventory.transferSteps.reception'),
    t('inventory.storeB'),
  ]
  const activeIndex = ({
    draft: 1,
    pending: 2,
    approved: 3,
    in_transit: 4,
    completed: labels.length,
  } as Record<string, number>)[status ?? 'draft'] ?? 1
  return labels.map((label, index) => ({
    label,
    done: status === 'completed' || index < activeIndex,
    active: status !== 'completed' && index === activeIndex,
  }))
}

function nextAction(status: string) {
  if (status === 'draft') return { kind: 'request' as const, label: t('inventory.transferActions.request') }
  if (status === 'pending') return { kind: 'validate' as const, label: t('inventory.transferActions.validate') }
  if (status === 'approved') return { kind: 'ship' as const, label: t('inventory.transferActions.ship') }
  if (status === 'in_transit') return { kind: 'receive' as const, label: t('inventory.transferActions.receive') }
  return null
}

async function save() {
  formError.value = ''
  if (!form.value.destination_warehouse_id) {
    formError.value = t('inventory.needDestination')
    return
  }
  if (form.value.source_warehouse_id === form.value.destination_warehouse_id) {
    formError.value = t('inventory.sameWarehouse')
    return
  }

  const items = form.value.items
    .filter(i => i.product_id && i.quantity > 0)
    .map(i => ({ product_id: i.product_id, quantity: Math.trunc(i.quantity) }))

  if (!items.length) {
    formError.value = t('inventory.needItems')
    return
  }

  saving.value = true
  try {
    await store.createStockTransfer({
      source_warehouse_id: form.value.source_warehouse_id,
      destination_warehouse_id: form.value.destination_warehouse_id,
      notes: form.value.notes || undefined,
      items,
    })
    showModal.value = false
    await store.loadStockTransfers()
  } catch (error) {
    formError.value = extractApiErrorMessage(error)
  } finally {
    saving.value = false
  }
}

async function advance(id: string, kind: 'request' | 'validate' | 'ship' | 'receive') {
  const messages = {
    request: t('inventory.transferActions.requestHint'),
    validate: t('inventory.transferActions.validateHint'),
    ship: t('inventory.transferActions.shipHint'),
    receive: t('inventory.transferActions.receiveHint'),
  }
  if (!(await confirmDialog(messages[kind], { title: t('inventory.tabs.transfers'), confirmLabel: t('inventory.confirm'), danger: false }))) return
  try {
    if (kind === 'request') await store.confirmStockTransfer(id)
    else if (kind === 'validate') await store.approveStockTransfer(id)
    else if (kind === 'ship') await store.shipStockTransfer(id)
    else await store.receiveStockTransfer(id)
    await store.loadStockTransfers()
    if (detail.value?.id === id) detail.value = await store.loadStockTransfer(id)
  } catch (error) {
    await notify(extractApiErrorMessage(error))
  }
}
</script>

<template>
  <InventoryLayout>
    <p class="mb-4 text-xs text-slate-500">{{ t('inventory.transferFlowHint') }}</p>
    <div class="mb-4 space-y-3">
      <div class="flex justify-end">
        <button class="btn-primary" @click="openCreate">+ {{ t('inventory.newTransfer') }}</button>
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
            <th class="px-4 py-3 text-left font-medium">{{ t('inventory.storeA') }}</th>
            <th class="px-4 py-3 text-left font-medium">{{ t('inventory.storeB') }}</th>
            <th class="px-4 py-3 text-left font-medium">{{ t('products.status') }}</th>
            <th class="px-4 py-3 text-left font-medium">{{ t('inventory.date') }}</th>
            <th class="px-4 py-3 text-right font-medium">{{ t('common.edit') }}</th>
          </tr>
        </thead>
        <tbody class="divide-y divide-slate-100">
          <tr v-for="row in filtered" :key="row.id" class="hover:bg-slate-50">
            <td class="px-4 py-3 font-mono">{{ row.transfer_number }}</td>
            <td class="px-4 py-3">{{ row.source_warehouse?.name ?? '—' }}</td>
            <td class="px-4 py-3">{{ row.destination_warehouse?.name ?? '—' }}</td>
            <td class="px-4 py-3"><StatusBadge :active="row.status === 'completed'" :label="statusLabel(row.status)" /></td>
            <td class="px-4 py-3 text-slate-500">{{ formatDate(row.created_at) }}</td>
            <td class="px-4 py-3 text-right">
              <button class="text-slate-600" @click="openDetails(row.id)">{{ t('inventory.viewDetails') }}</button>
              <button v-if="nextAction(row.status)" class="ml-3 text-brand-600" @click="advance(row.id, nextAction(row.status)!.kind)">
                {{ nextAction(row.status)!.label }}
              </button>
            </td>
          </tr>
        </tbody>
      </table>
      <p v-if="!filtered.length" class="px-4 py-8 text-center text-slate-500">{{ t('org.empty') }}</p>
    </div>

    <AppModal
      :open="showModal"
      :title="t('inventory.newTransfer')"
      icon="transfer"
      tone="info"
      size="xl"
      @close="showModal = false"
    >
      <form class="space-y-3" @submit.prevent="save">
        <div>
          <FieldLabel icon="stores">{{ t('inventory.storeA') }}</FieldLabel>
          <select v-model="form.source_warehouse_id" required class="field">
            <option v-for="w in warehouses" :key="w.id" :value="w.id">{{ w.name }}</option>
          </select>
        </div>
        <div>
          <FieldLabel icon="stores">{{ t('inventory.storeB') }}</FieldLabel>
          <select v-model="form.destination_warehouse_id" required class="field">
            <option value="">—</option>
            <option v-for="w in destinationWarehouses" :key="w.id" :value="w.id">{{ w.name }}</option>
          </select>
        </div>
        <p v-if="formError" class="text-sm text-red-600">{{ formError }}</p>
        <p v-else-if="!destinationWarehouses.length" class="text-sm text-red-600">
          {{ t('inventory.needDestination') }}
          <router-link to="/admin/organization/warehouses" class="underline">{{ t('org.tabs.warehouses') }}</router-link>
        </p>
        <p class="text-xs text-slate-500">{{ t('inventory.entryHint') }}</p>
        <p class="text-xs text-slate-500">{{ t('inventory.stockableOnly') }}</p>
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
          <button type="submit" class="btn-primary" :disabled="saving || !destinationWarehouses.length">{{ t('inventory.saveEntry') }}</button>
        </div>
      </form>
    </AppModal>

    <InventoryActionDetails
      :open="showDetails"
      :title="t('inventory.detailsTitle')"
      :reference="detail?.transfer_number"
      :status="detail?.status"
      :status-label="detail ? statusLabel(detail.status) : ''"
      :loading="detailsLoading"
      :confirmed-by="confirmedActor(detail)"
      :approved-by="approvedActor(detail)"
      :fields="[
        { label: t('inventory.storeA'), value: detail?.source_warehouse?.name },
        { label: t('inventory.storeB'), value: detail?.destination_warehouse?.name },
        { label: t('inventory.date'), value: formatDate(detail?.created_at) },
        { label: t('inventory.transferActions.ship'), value: detail?.shipped_at ? formatDateTime(detail.shipped_at) : '—' },
        { label: t('inventory.transferActions.receive'), value: detail?.received_at ? formatDateTime(detail.received_at) : '—' },
      ]"
      :steps="detail ? transferSteps(detail.status) : []"
      :items="(detail?.items ?? []).map(item => ({
        name: item.product?.name ?? '—',
        sku: item.product?.sku,
        quantity: `${item.quantity_requested ?? item.quantity} · ${t('inventory.transferSteps.shipment')} ${item.quantity_shipped ?? 0} · ${t('inventory.transferSteps.reception')} ${item.quantity_received ?? 0}`,
      }))"
      @close="showDetails = false"
    />
  </InventoryLayout>
</template>

<style scoped>

.line-row { display: flex; align-items: center; gap: 0.5rem; }
.line-row > .field { flex: 1 1 14rem; min-width: 0; }
.line-row > .qty { flex: 0 0 6.5rem; width: 6.5rem; padding-left: 0.4rem; padding-right: 0.35rem; text-align: center; }

.btn-secondary { border-radius: 0.5rem; border: 1px solid #cbd5e1; padding: 0.5rem 1rem; }
.text-brand-600 { color: var(--color-brand-600); }
</style>
