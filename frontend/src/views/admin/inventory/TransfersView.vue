<script setup lang="ts">
import { computed, nextTick, onMounted, ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import { extractApiErrorMessage } from '../../../api/client'
import InventoryActionDetails from '../../../components/inventory/InventoryActionDetails.vue'
import InventoryLayout from '../../../components/inventory/InventoryLayout.vue'
import StatusBadge from '../../../components/organization/StatusBadge.vue'
import AppModal from '../../../components/ui/AppModal.vue'
import FieldLabel from '../../../components/ui/FieldLabel.vue'
import ModuleFilters from '../../../components/ui/ModuleFilters.vue'
import ListPager from '../../../components/ui/ListPager.vue'
import { useClientPager } from '../../../composables/useClientPager'
import { useConfirm } from '../../../composables/useConfirm'
import { useBackofficeStore } from '../../../stores/backoffice'
import { useContextStore } from '../../../stores/context'
import type { Product, StockBalance, StockTransferDetail, Warehouse } from '../../../types'
import { isStockableProduct } from '../../../utils/product'
import { formatDate, formatDateTime } from '../../../utils/format'
import { emptyListFilters, inPeriod, matchesSearch, type ListFilters } from '../../../utils/listFilters'
import AppIcon from '../../../components/ui/AppIcon.vue'

const { t } = useI18n()
const store = useBackofficeStore()
const context = useContextStore()
const { notify, confirm: confirmDialog } = useConfirm()

const warehouses = ref<Warehouse[]>([])
const products = ref<Product[]>([])
const sourceStock = ref<StockBalance[]>([])
const showModal = ref(false)
const showDetails = ref(false)
const detailsLoading = ref(false)
const detail = ref<StockTransferDetail | null>(null)
const saving = ref(false)
const formError = ref('')

const destinationWarehouses = computed(() =>
  warehouses.value.filter(w => w.id !== form.value.source_warehouse_id),
)
const sourceWarehouse = computed(() =>
  warehouses.value.find(w => w.store_id && w.store_id === context.currentStoreId) ?? null,
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

const { page, lastPage, total, perPage, paged, setPage } = useClientPager(filtered)

const form = ref({
  source_warehouse_id: '',
  destination_warehouse_id: '',
  notes: '',
  items: [{ product_id: '', quantity: 1 }],
})

const filledLines = computed(() => form.value.items.filter(line => line.product_id).length)
const transferUnits = computed(() =>
  form.value.items.reduce((sum, line) => {
    if (!line.product_id) return sum
    return sum + Math.max(0, Math.trunc(Number(line.quantity) || 0))
  }, 0),
)

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
  const sourceId = sourceWarehouse.value?.id ?? ''
  sourceStock.value = []
  if (sourceId) {
    await store.loadStockBalances(sourceId, false)
    sourceStock.value = store.stockBalances.slice()
  }
  formError.value = ''
  form.value = {
    source_warehouse_id: sourceId,
    destination_warehouse_id: pickDestination(sourceId),
    notes: '',
    items: [{ product_id: '', quantity: 1 }],
  }
  showModal.value = true
}

function availableOf(productId: string) {
  if (!productId) return 0
  return sourceStock.value
    .filter(row => row.product_id === productId)
    .reduce((sum, row) => sum + Number(row.quantity_available ?? row.quantity_on_hand ?? 0), 0)
}

function clampLine(index: number) {
  const line = form.value.items[index]
  if (!line?.product_id) return
  const available = availableOf(line.product_id)
  const qty = Math.trunc(Number(line.quantity) || 0)
  line.quantity = available < 1 ? 0 : Math.min(Math.max(qty, 1), available)
}

function onProduct(index: number) {
  void nextTick(() => clampLine(index))
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
  form.value.source_warehouse_id = sourceWarehouse.value?.id ?? ''
  if (!form.value.source_warehouse_id) {
    formError.value = t('inventory.transferNoSource')
    return
  }
  if (!form.value.destination_warehouse_id) {
    formError.value = t('inventory.needDestination')
    return
  }
  if (form.value.source_warehouse_id === form.value.destination_warehouse_id) {
    formError.value = t('inventory.sameWarehouse')
    return
  }

  for (const line of form.value.items.filter(item => item.product_id)) {
    const available = availableOf(line.product_id)
    if (Math.trunc(Number(line.quantity) || 0) > available) {
      const name = products.value.find(product => product.id === line.product_id)?.name ?? ''
      formError.value = t('inventory.transferQtyExceeds', { name, available })
      return
    }
  }

  const items = form.value.items
    .filter(i => i.product_id && i.quantity > 0)
    .map(i => ({ product_id: i.product_id, quantity: Math.trunc(i.quantity) }))

  if (!items.length) {
    formError.value = t('inventory.needItems')
    return
  }

  for (const item of items) {
    const available = availableOf(item.product_id)
    if (item.quantity > available) {
      const name = products.value.find(product => product.id === item.product_id)?.name ?? ''
      formError.value = t('inventory.transferQtyExceeds', { name, available })
      return
    }
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
        <button class="btn-primary" @click="openCreate"><AppIcon name="plus" :size="16" /> {{ t('inventory.newTransfer') }}</button>
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
            <th class="px-4 py-3 text-right font-medium">{{ t('inventory.actions') }}</th>
          </tr>
        </thead>
        <tbody class="divide-y divide-slate-100">
          <tr v-for="row in paged" :key="row.id" class="hover:bg-slate-50">
            <td class="px-4 py-3 font-mono">{{ row.transfer_number }}</td>
            <td class="px-4 py-3">{{ row.source_warehouse?.name ?? '—' }}</td>
            <td class="px-4 py-3">{{ row.destination_warehouse?.name ?? '—' }}</td>
            <td class="px-4 py-3"><StatusBadge :active="row.status === 'completed'" :label="statusLabel(row.status)" /></td>
            <td class="px-4 py-3 text-slate-500">{{ formatDate(row.created_at) }}</td>
            <td class="px-4 py-3">
              <div class="row-actions">
                <button class="row-action row-action--view" @click="openDetails(row.id)"><AppIcon name="eye" :size="16" /> {{ t('inventory.viewDetails') }}</button>
                <button v-if="nextAction(row.status)" class="row-action row-action--confirm" @click="advance(row.id, nextAction(row.status)!.kind)">
                  <AppIcon name="check" :size="16" /> {{ nextAction(row.status)!.label }}
                </button>
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
      :title="t('inventory.newTransfer')"
      :subtitle="t('inventory.entryHint')"
      icon="transfer"
      tone="info"
      size="xl"
      @close="showModal = false"
    >
      <form id="transfer-form" class="xfer-form" @submit.prevent="save">
        <section class="xfer-route" :aria-label="t('inventory.newTransfer')">
          <div class="xfer-store xfer-store--locked">
            <FieldLabel icon="stores">{{ t('inventory.storeA') }}</FieldLabel>
            <input class="field" :value="sourceWarehouse?.name || '—'" readonly tabindex="-1">
            <p class="xfer-note">{{ t('inventory.transferSourceFixed') }}</p>
          </div>
          <div class="xfer-arrow" aria-hidden="true">
            <AppIcon name="chevron-right" :size="18" />
          </div>
          <div class="xfer-store">
            <FieldLabel icon="stores">{{ t('inventory.storeB') }}</FieldLabel>
            <select v-model="form.destination_warehouse_id" required class="field">
              <option value="">—</option>
              <option v-for="w in destinationWarehouses" :key="w.id" :value="w.id">{{ w.name }}</option>
            </select>
            <p v-if="!destinationWarehouses.length" class="xfer-note xfer-note--warn">
              {{ t('inventory.needDestination') }}
              <router-link to="/admin/organization/stores" class="underline">{{ t('org.tabs.stores') }}</router-link>
            </p>
          </div>
        </section>

        <p v-if="formError" class="xfer-alert" role="alert">{{ formError }}</p>
        <p v-else-if="!sourceWarehouse" class="xfer-alert" role="alert">{{ t('inventory.transferNoSource') }}</p>
        <p v-else class="xfer-hint">{{ t('inventory.stockableOnly') }}</p>

        <section class="xfer-lines">
          <header class="xfer-lines__head">
            <div>
              <h3 class="xfer-lines__title">{{ t('inventory.articles') }}</h3>
              <p class="xfer-lines__meta">{{ filledLines }} {{ t('inventory.articles') }} · {{ transferUnits }} {{ t('inventory.qtyShort') }}</p>
            </div>
            <button
              v-if="form.items.length < products.length"
              type="button"
              class="btn-secondary xfer-add"
              @click="addLine"
            >
              <AppIcon name="plus" :size="16" /> {{ t('inventory.addLine') }}
            </button>
          </header>
          <div class="xfer-lines__list">
            <div class="xfer-line xfer-line--head">
              <span>{{ t('inventory.articles') }}</span>
              <span>{{ t('inventory.available') }}</span>
              <span>{{ t('inventory.qtyShort') }}</span>
              <span class="sr-only">{{ t('inventory.removeLine') }}</span>
            </div>
            <div v-for="(line, idx) in form.items" :key="idx" class="xfer-line">
              <select v-model="line.product_id" required class="field" @change="onProduct(idx)">
                <option value="">—</option>
                <option v-for="p in productsForLine(idx)" :key="p.id" :value="p.id">
                  {{ p.name }} · {{ availableOf(p.id) }}
                </option>
              </select>
              <span
                class="xfer-avail"
                :class="{ 'xfer-avail--empty': line.product_id && availableOf(line.product_id) < 1 }"
              >
                {{ line.product_id ? availableOf(line.product_id) : '—' }}
              </span>
              <input
                v-model.number="line.quantity"
                type="number"
                min="1"
                :max="line.product_id ? availableOf(line.product_id) : undefined"
                required
                class="field xfer-qty"
                :aria-label="t('inventory.qtyShort')"
                @input="clampLine(idx)"
              />
              <button
                type="button"
                class="xfer-remove"
                :aria-label="t('inventory.removeLine')"
                :title="t('inventory.removeLine')"
                @click="removeLine(idx)"
              >
                <AppIcon name="trash" :size="16" />
              </button>
            </div>
            <p v-if="!filledLines" class="xfer-empty">{{ t('inventory.needItems') }}</p>
          </div>
        </section>

        <div class="xfer-notes">
          <FieldLabel icon="note">{{ t('inventory.notes') }}</FieldLabel>
          <textarea v-model="form.notes" class="field" rows="2" />
        </div>
      </form>
      <template #footer>
        <button type="button" class="btn-secondary" @click="showModal = false">
          <AppIcon name="close" :size="16" /> {{ t('common.cancel') }}
        </button>
        <button
          type="submit"
          form="transfer-form"
          class="btn-primary"
          :class="{ 'is-busy': saving }"
          :disabled="saving || !sourceWarehouse || !destinationWarehouses.length"
        >
          {{ t('inventory.saveEntry') }}
        </button>
      </template>
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
:global(.app-modal--drawer .app-modal__body:has(> .xfer-form)) {
  display: flex;
  flex-direction: column;
}

.xfer-form {
  display: flex;
  flex: 1 1 auto;
  flex-direction: column;
  gap: 1rem;
  min-height: 0;
  height: 100%;
}

.xfer-route {
  flex-shrink: 0;
  display: grid;
  grid-template-columns: minmax(0, 1fr) auto minmax(0, 1fr);
  gap: 0.75rem;
  align-items: stretch;
}

.xfer-store {
  display: flex;
  flex-direction: column;
  min-width: 0;
  padding: 0.9rem 1rem 1rem;
  border: 1px solid var(--color-border-strong);
  background: var(--color-surface);
}

.xfer-store--locked {
  background: var(--color-canvas);
}

.xfer-store :is(input, select) {
  width: 100%;
}

.xfer-arrow {
  display: flex;
  align-items: center;
  justify-content: center;
  color: var(--color-brand-700);
}

.xfer-note {
  margin: 0.45rem 0 0;
  font-size: 0.75rem;
  line-height: 1.4;
  color: var(--color-text-muted);
}

.xfer-note--warn,
.xfer-alert {
  color: var(--color-danger);
}

.xfer-alert,
.xfer-hint {
  flex-shrink: 0;
  margin: 0;
  padding: 0.7rem 0.9rem;
  border-left: 3px solid var(--color-brand-700);
  background: var(--color-surface);
  font-size: 0.8125rem;
  line-height: 1.45;
  color: var(--color-text-secondary);
}

.xfer-alert {
  border-left-color: var(--color-danger);
}

.xfer-lines {
  display: flex;
  flex: 1 1 auto;
  flex-direction: column;
  min-height: 0;
  border: 1px solid var(--color-border-strong);
  background: var(--color-surface);
}

.xfer-lines__head {
  display: flex;
  flex-shrink: 0;
  align-items: center;
  justify-content: space-between;
  gap: 0.75rem;
  padding: 0.75rem 1rem;
  border-bottom: 1px solid var(--color-border-strong);
}

.xfer-lines__title {
  margin: 0;
  font-size: 0.75rem;
  font-weight: 600;
  letter-spacing: 0.06em;
  text-transform: uppercase;
  color: var(--color-text-muted);
}

.xfer-lines__meta {
  margin: 0.15rem 0 0;
  font-size: 0.8125rem;
  font-variant-numeric: tabular-nums;
  color: var(--color-text-secondary);
}

.xfer-add {
  flex-shrink: 0;
}

.xfer-lines__list {
  display: flex;
  flex: 1 1 auto;
  flex-direction: column;
  min-height: 0;
  overflow: auto;
}

.xfer-empty {
  display: flex;
  flex: 1 1 auto;
  align-items: center;
  justify-content: center;
  margin: 0;
  padding: 2rem 1.5rem;
  color: var(--color-text-faint);
  font-size: 0.875rem;
  text-align: center;
}

.xfer-line {
  display: grid;
  grid-template-columns: minmax(0, 1fr) 6.5rem 5.5rem 2.5rem;
  gap: 0.65rem;
  align-items: center;
  padding: 0.65rem 1rem;
  border-bottom: 1px solid var(--color-border);
}

.xfer-line--head {
  position: sticky;
  top: 0;
  z-index: 1;
  background: var(--color-canvas);
  color: var(--color-text-faint);
  font-size: 0.6875rem;
  font-weight: 600;
  letter-spacing: 0.06em;
  text-transform: uppercase;
}

.xfer-line--head span:nth-child(2),
.xfer-line--head span:nth-child(3) {
  text-align: right;
}

.xfer-avail {
  text-align: right;
  font-variant-numeric: tabular-nums;
  font-weight: 600;
  color: var(--color-text-primary);
}

.xfer-avail--empty {
  color: var(--color-danger);
}

.xfer-qty {
  text-align: center;
}

.xfer-remove {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 2.5rem;
  height: 2.5rem;
  border: 1px solid var(--color-border-strong);
  border-radius: 0;
  background: var(--color-surface);
  color: var(--color-danger);
  cursor: pointer;
}

.xfer-remove:hover {
  border-color: var(--color-danger);
  background: var(--color-danger-bg);
}

.xfer-notes {
  flex-shrink: 0;
}

.xfer-notes textarea {
  width: 100%;
  min-height: 4.5rem;
  resize: vertical;
}

input[readonly].field {
  background: var(--color-surface-muted, #f4f6f8);
}

.text-brand-600 { color: var(--color-ink-brand, var(--color-brand-600)); }

@media (max-width: 720px) {
  .xfer-route {
    grid-template-columns: 1fr;
  }

  .xfer-arrow {
    transform: rotate(90deg);
  }

  .xfer-line,
  .xfer-line--head {
    grid-template-columns: minmax(0, 1fr) 4.25rem 2.5rem;
  }

  .xfer-line--head span:nth-child(2),
  .xfer-avail {
    display: none;
  }
}
</style>
