<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import { useRouter } from 'vue-router'
import { extractApiErrorMessage } from '../../../api/client'
import PurchasingLayout from '../../../components/purchasing/PurchasingLayout.vue'
import AppModal from '../../../components/ui/AppModal.vue'
import Badge from '../../../components/ui/Badge.vue'
import FieldLabel from '../../../components/ui/FieldLabel.vue'
import ModuleFilters from '../../../components/ui/ModuleFilters.vue'
import { useBackofficeStore } from '../../../stores/backoffice'
import type { Product, PurchaseRequisition, Supplier, Warehouse } from '../../../types'
import { isStockableProduct } from '../../../utils/product'
import { formatDate, formatMoney } from '../../../utils/format'
import { emptyListFilters, inPeriod, matchesSearch, type ListFilters } from '../../../utils/listFilters'

const { t } = useI18n()
const router = useRouter()
const store = useBackofficeStore()

const rows = ref<PurchaseRequisition[]>([])
const warehouses = ref<Warehouse[]>([])
const suppliers = ref<Supplier[]>([])
const products = ref<Product[]>([])
const filters = ref<ListFilters>(emptyListFilters())
const saving = ref(false)
const error = ref('')
const showCreate = ref(false)
const converting = ref<PurchaseRequisition | null>(null)
const form = ref(emptyForm())
const convertForm = ref({ target: 'purchase_order' as 'proforma' | 'purchase_order', supplier_id: '', warehouse_id: '' })

const statusOptions = computed(() =>
  (['draft', 'submitted', 'approved', 'rejected', 'converted'] as const).map(key => ({
    value: key,
    label: t(`purchases.hub.reqStatus.${key}`),
  })),
)

const priorityOptions = computed(() =>
  (['low', 'normal', 'high', 'urgent'] as const).map(key => ({
    value: key,
    label: t(`purchases.hub.priorities.${key}`),
  })),
)

const warehouseOptions = computed(() =>
  warehouses.value.map(w => ({ id: w.id, name: w.name })),
)

const filteredRows = computed(() =>
  rows.value.filter((row) => {
    const haystack = [row.number, row.warehouse?.name, row.supplier?.name, row.department, row.priority].filter(Boolean).join(' ')
    if (!matchesSearch(haystack, filters.value.search)) return false
    if (!inPeriod(row.created_at ?? row.needed_at, filters.value)) return false
    if (filters.value.priority && row.priority !== filters.value.priority) return false
    if (filters.value.warehouse_id && row.warehouse_id !== filters.value.warehouse_id && row.warehouse?.id !== filters.value.warehouse_id) return false
    return true
  }),
)

function emptyForm() {
  return {
    warehouse_id: '',
    supplier_id: '',
    department: '',
    priority: 'normal',
    needed_at: '',
    reason: '',
    notes: '',
    items: [{ product_id: '', quantity: 1, unit_cost: 0 }],
  }
}

onMounted(async () => {
  warehouses.value = await store.loadAllWarehouses()
  await store.loadSuppliers()
  suppliers.value = store.suppliers
  await load()
})

async function load() {
  error.value = ''
  rows.value = await store.loadPurchaseRequisitions(filters.value.status ? { status: filters.value.status } : {})
}

function statusVariant(value: string): 'success' | 'warning' | 'neutral' | 'brand' {
  if (value === 'approved' || value === 'converted') return 'success'
  if (value === 'submitted') return 'brand'
  if (value === 'rejected') return 'neutral'
  return 'warning'
}

function nextAction(row: PurchaseRequisition) {
  if (row.status === 'draft') return t('purchases.submit')
  if (row.status === 'submitted') return t('purchases.approve')
  if (row.status === 'approved') return t('purchases.hub.toOrder')
  return '—'
}

async function openCreate() {
  products.value = (await store.loadAllProducts()).filter(isStockableProduct)
  form.value = {
    ...emptyForm(),
    warehouse_id: warehouses.value[0]?.id ?? '',
    supplier_id: '',
    items: [{ product_id: '', quantity: 1, unit_cost: 0 }],
  }
  error.value = ''
  showCreate.value = true
}

function productsForLine(index: number) {
  const used = new Set(
    form.value.items
      .filter((_, i) => i !== index)
      .map(line => line.product_id)
      .filter(Boolean),
  )
  return products.value.filter(product => !used.has(product.id))
}

function canAddLine() {
  const used = new Set(form.value.items.map(line => line.product_id).filter(Boolean))
  return used.size < products.value.length
}

function addLine() {
  if (!canAddLine()) return
  form.value.items.push({ product_id: '', quantity: 1, unit_cost: 0 })
}

function removeLine(index: number) {
  form.value.items.splice(index, 1)
  if (!form.value.items.length) addLine()
}

function onProductChange(index: number) {
  const product = products.value.find(item => item.id === form.value.items[index].product_id)
  if (product) form.value.items[index].unit_cost = (product.cost_price ?? 0) / 100
}

async function submitCreate() {
  saving.value = true
  error.value = ''
  try {
    await store.createPurchaseRequisition({
      warehouse_id: form.value.warehouse_id || undefined,
      supplier_id: form.value.supplier_id || undefined,
      department: form.value.department || undefined,
      priority: form.value.priority,
      needed_at: form.value.needed_at || undefined,
      reason: form.value.reason || undefined,
      notes: form.value.notes || undefined,
      items: form.value.items
        .filter(line => line.product_id && line.quantity > 0)
        .map(line => ({ ...line, unit_cost: Math.round(Number(line.unit_cost) * 100) })),
    })
    showCreate.value = false
    await load()
  } catch (err) {
    error.value = extractApiErrorMessage(err)
  } finally {
    saving.value = false
  }
}

async function act(row: PurchaseRequisition, action: 'submit' | 'approve' | 'reject') {
  saving.value = true
  error.value = ''
  try {
    await store.actPurchaseRequisition(row.id, action)
    await load()
  } catch (err) {
    error.value = extractApiErrorMessage(err)
  } finally {
    saving.value = false
  }
}

function openConvert(row: PurchaseRequisition) {
  converting.value = row
  convertForm.value = {
    target: 'purchase_order',
    supplier_id: row.supplier_id || suppliers.value[0]?.id || '',
    warehouse_id: row.warehouse_id || warehouses.value[0]?.id || '',
  }
}

async function submitConvert() {
  if (!converting.value) return
  saving.value = true
  error.value = ''
  try {
    const created = await store.convertPurchaseRequisition(
      converting.value.id,
      convertForm.value.target,
      convertForm.value.supplier_id || undefined,
      convertForm.value.warehouse_id || undefined,
    )
    converting.value = null
    if (created.type === 'purchase_order') {
      await router.push({ name: 'purchase-order-detail', params: { id: created.id } })
      return
    }
    await router.push({ name: 'purchase-proformas' })
  } catch (err) {
    error.value = extractApiErrorMessage(err)
  } finally {
    saving.value = false
  }
}

function openOrder(row: PurchaseRequisition) {
  const id = row.converted_purchase_order?.id
  if (id) router.push({ name: 'purchase-order-detail', params: { id } })
}
</script>

<template>
  <PurchasingLayout>
    <p class="mb-3 text-sm text-slate-500">{{ t('purchases.hub.cycleHint') }}</p>
    <p v-if="error" class="mb-3 text-sm text-red-600">{{ error }}</p>

    <div class="mb-4">
      <ModuleFilters
        v-model="filters"
        :statuses="statusOptions"
        :priorities="priorityOptions"
        :warehouses="warehouseOptions"
        show-search
        show-period
        show-status
        show-priority
        show-warehouse
        @apply="load"
      />
    </div>

    <div class="overflow-hidden rounded-xl bg-white shadow-sm ring-1 ring-slate-200">
      <div class="flex flex-wrap items-center justify-between gap-3 border-b border-slate-100 px-4 py-3">
        <h3 class="m-0 text-sm font-semibold text-slate-700">{{ t('purchases.hub.requisitions') }}</h3>
        <button class="btn-primary-sm" @click="openCreate">+ {{ t('purchases.hub.newRequisition') }}</button>
      </div>

      <table class="min-w-full divide-y divide-slate-200 text-sm">
        <thead class="bg-slate-50">
          <tr>
            <th class="px-4 py-3 text-left font-medium">{{ t('purchases.hub.number') }}</th>
            <th class="px-4 py-3 text-left font-medium">{{ t('inventory.warehouse') }}</th>
            <th class="px-4 py-3 text-left font-medium">{{ t('purchases.hub.priority') }}</th>
            <th class="px-4 py-3 text-left font-medium">{{ t('products.status') }}</th>
            <th class="px-4 py-3 text-right font-medium">{{ t('purchases.hub.amount') }}</th>
            <th class="px-4 py-3 text-left font-medium">{{ t('purchases.nextStep') }}</th>
            <th class="px-4 py-3 text-left font-medium">{{ t('purchases.hub.date') }}</th>
            <th class="px-4 py-3"></th>
          </tr>
        </thead>
        <tbody class="divide-y divide-slate-100">
          <tr v-for="row in filteredRows" :key="row.id" class="hover:bg-slate-50">
            <td class="px-4 py-3 font-mono">{{ row.number }}</td>
            <td class="px-4 py-3">{{ row.warehouse?.name ?? '—' }}</td>
            <td class="px-4 py-3">{{ t(`purchases.hub.priorities.${row.priority}`) }}</td>
            <td class="px-4 py-3">
              <Badge :variant="statusVariant(row.status)">{{ t(`purchases.hub.reqStatus.${row.status}`) }}</Badge>
            </td>
            <td class="px-4 py-3 text-right">{{ formatMoney(row.total) }}</td>
            <td class="px-4 py-3 text-slate-600">{{ nextAction(row) }}</td>
            <td class="px-4 py-3 text-slate-500">{{ formatDate(row.created_at) }}</td>
            <td class="px-4 py-3 text-right">
              <div class="flex justify-end gap-2">
                <button v-if="row.status === 'draft'" class="link" :disabled="saving" @click="act(row, 'submit')">{{ t('purchases.submit') }}</button>
                <button v-if="row.status === 'submitted'" class="link" :disabled="saving" @click="act(row, 'approve')">{{ t('purchases.approve') }}</button>
                <button v-if="row.status === 'submitted'" class="link-danger" :disabled="saving" @click="act(row, 'reject')">{{ t('purchases.hub.reject') }}</button>
                <button v-if="row.status === 'approved'" class="link" :disabled="saving" @click="openConvert(row)">{{ t('purchases.hub.toOrder') }}</button>
                <button v-if="row.converted_purchase_order" class="link" @click="openOrder(row)">{{ row.converted_purchase_order.order_number }}</button>
              </div>
            </td>
          </tr>
        </tbody>
      </table>
      <p v-if="!filteredRows.length" class="px-4 py-8 text-center text-slate-500">{{ t('org.empty') }}</p>
    </div>

    <AppModal
      :open="showCreate"
      :title="t('purchases.hub.newRequisition')"
      icon="note"
      size="xl"
      @close="showCreate = false"
    >
      <form class="space-y-3" @submit.prevent="submitCreate">
        <div>
          <FieldLabel icon="inventory">{{ t('inventory.warehouse') }}</FieldLabel>
          <select v-model="form.warehouse_id" required class="field">
            <option v-for="warehouse in warehouses" :key="warehouse.id" :value="warehouse.id">{{ warehouse.name }}</option>
          </select>
        </div>
        <div>
          <FieldLabel icon="suppliers">{{ t('nav.suppliers') }}</FieldLabel>
          <select v-model="form.supplier_id" class="field">
            <option value="">{{ t('common.optional') }}</option>
            <option v-for="supplier in suppliers" :key="supplier.id" :value="supplier.id">{{ supplier.name }}</option>
          </select>
        </div>
        <div>
          <FieldLabel icon="tag">{{ t('purchases.hub.department') }}</FieldLabel>
          <input v-model="form.department" class="field" />
        </div>
        <div>
          <FieldLabel icon="alert">{{ t('purchases.hub.priority') }}</FieldLabel>
          <select v-model="form.priority" class="field">
            <option v-for="key in ['low', 'normal', 'high', 'urgent']" :key="key" :value="key">{{ t(`purchases.hub.priorities.${key}`) }}</option>
          </select>
        </div>
        <div>
          <FieldLabel icon="calendar">{{ t('purchases.hub.needed') }}</FieldLabel>
          <input v-model="form.needed_at" type="date" class="field" />
        </div>
        <div>
          <FieldLabel icon="note">{{ t('purchases.hub.reason') }}</FieldLabel>
          <input v-model="form.reason" class="field" />
        </div>
        <p v-if="error" class="form-error">{{ error }}</p>
        <div class="space-y-2">
          <div class="line-head">
            <span>{{ t('products.name') }}</span>
            <span>{{ t('sales.qty') }}</span>
            <span>{{ t('purchases.unitCost') }}</span>
            <span></span>
          </div>
          <div v-for="(line, idx) in form.items" :key="idx" class="line-row">
            <select v-model="line.product_id" required class="field name" @change="onProductChange(idx)">
              <option value="">—</option>
              <option v-for="product in productsForLine(idx)" :key="product.id" :value="product.id">{{ product.name }}</option>
            </select>
            <input v-model.number="line.quantity" type="number" min="1" required class="field qty" />
            <input v-model.number="line.unit_cost" type="number" min="0" step="0.01" class="field cost" />
            <button type="button" class="line-remove" @click="removeLine(idx)">{{ t('inventory.removeLine') }}</button>
          </div>
          <button v-if="canAddLine()" type="button" class="line-add" @click="addLine">+ {{ t('inventory.addLine') }}</button>
        </div>
        <div class="app-modal__actions">
          <button type="button" class="btn-secondary" @click="showCreate = false">{{ t('common.cancel') }}</button>
          <button type="submit" class="btn-primary" :disabled="saving">{{ t('common.save') }}</button>
        </div>
      </form>
    </AppModal>

    <AppModal :open="Boolean(converting)" :title="t('purchases.hub.convert')" icon="purchases" @close="converting = null">
      <form class="space-y-3" @submit.prevent="submitConvert">
        <p class="m-0 text-sm text-slate-500">{{ t('purchases.hub.convertHint') }}</p>
        <div>
          <FieldLabel icon="sparkles">{{ t('purchases.hub.convertTarget') }}</FieldLabel>
          <select v-model="convertForm.target" class="field">
            <option value="purchase_order">{{ t('purchases.hub.toOrder') }}</option>
            <option value="proforma">{{ t('purchases.hub.toProforma') }}</option>
          </select>
        </div>
        <div>
          <FieldLabel icon="suppliers">{{ t('nav.suppliers') }}</FieldLabel>
          <select v-model="convertForm.supplier_id" required class="field">
            <option v-for="supplier in suppliers" :key="supplier.id" :value="supplier.id">{{ supplier.name }}</option>
          </select>
        </div>
        <div v-if="convertForm.target === 'purchase_order'">
          <FieldLabel icon="inventory">{{ t('inventory.warehouse') }}</FieldLabel>
          <select v-model="convertForm.warehouse_id" required class="field">
            <option v-for="warehouse in warehouses" :key="warehouse.id" :value="warehouse.id">{{ warehouse.name }}</option>
          </select>
        </div>
        <div class="app-modal__actions">
          <button type="button" class="btn-secondary" @click="converting = null">{{ t('common.cancel') }}</button>
          <button type="submit" class="btn-primary" :disabled="saving">{{ t('purchases.hub.convert') }}</button>
        </div>
      </form>
    </AppModal>
  </PurchasingLayout>
</template>

<style scoped>
.field { width: 100%; min-width: 0; }
.line-head,
.line-row {
  display: grid;
  grid-template-columns: minmax(0, 1fr) 7rem 8.5rem auto;
  gap: 0.6rem;
  align-items: center;
}
.line-head {
  padding: 0 0.1rem;
  color: #64748b;
  font-size: 0.75rem;
  font-weight: 600;
  letter-spacing: 0.01em;
}
.line-head span:nth-child(2),
.line-head span:nth-child(3) {
  text-align: center;
}
.line-row > .qty,
.line-row > .cost {
  width: 100%;
  text-align: right;
  font-variant-numeric: tabular-nums;
}
.line-remove {
  height: var(--control-lg);
  border: 0;
  background: transparent;
  color: #dc2626;
  font-size: 0.8rem;
  font-weight: 600;
  text-align: left;
  white-space: nowrap;
}
.line-add {
  margin-top: 0.15rem;
  border: 0;
  background: transparent;
  color: var(--color-brand-600);
  font-size: 0.85rem;
  font-weight: 600;
}
.form-error {
  margin: 0;
  color: #dc2626;
  font-size: 0.85rem;
}
.btn-primary, .btn-primary-sm { border-radius: 0.5rem; font-weight: 500; color: white; background-color: var(--color-brand-600); }
.btn-primary { padding: 0.5rem 1rem; }
.btn-primary-sm { padding: 0.375rem 0.75rem; font-size: 0.875rem; }
.btn-secondary { border-radius: 0.5rem; border: 1px solid #cbd5e1; padding: 0.5rem 1rem; }
.link { color: var(--color-brand-600); font-size: 0.8rem; font-weight: 600; }
.link-danger { color: #dc2626; font-size: 0.8rem; font-weight: 600; }
@media (max-width: 640px) {
  .line-row,
  .line-head {
    grid-template-columns: minmax(0, 1fr) 5.5rem 6.5rem auto;
  }
}
</style>
