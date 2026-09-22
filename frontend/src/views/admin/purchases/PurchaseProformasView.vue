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
import type { Product, PurchaseProforma, Supplier, Warehouse } from '../../../types'
import { isStockableProduct } from '../../../utils/product'
import { formatDate, formatMoney } from '../../../utils/format'
import { emptyListFilters, inPeriod, matchesSearch, type ListFilters } from '../../../utils/listFilters'

const { t } = useI18n()
const router = useRouter()
const store = useBackofficeStore()

const rows = ref<PurchaseProforma[]>([])
const warehouses = ref<Warehouse[]>([])
const suppliers = ref<Supplier[]>([])
const products = ref<Product[]>([])
const filters = ref<ListFilters>(emptyListFilters())
const saving = ref(false)
const error = ref('')
const showCreate = ref(false)
const converting = ref<PurchaseProforma | null>(null)
const convertWarehouseId = ref('')
const form = ref(emptyForm())

const statusOptions = computed(() =>
  (['draft', 'sent', 'under_review', 'approved', 'rejected', 'expired', 'converted'] as const).map(key => ({
    value: key,
    label: t(`purchases.hub.proStatus.${key}`),
  })),
)

const supplierOptions = computed(() =>
  suppliers.value.map(s => ({ id: s.id, name: s.name })),
)

const filteredRows = computed(() =>
  rows.value.filter((row) => {
    const haystack = [row.number, row.supplier?.name, row.warehouse?.name, row.requisition?.number].filter(Boolean).join(' ')
    if (!matchesSearch(haystack, filters.value.search)) return false
    if (!inPeriod(row.created_at ?? row.expires_at, filters.value)) return false
    if (filters.value.supplier_id && row.supplier_id !== filters.value.supplier_id && row.supplier?.id !== filters.value.supplier_id) return false
    return true
  }),
)

function emptyForm() {
  return {
    warehouse_id: '',
    supplier_id: '',
    payment_terms: '',
    delivery_terms: '',
    expires_at: '',
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
  rows.value = await store.loadPurchaseProformas(filters.value.status ? { status: filters.value.status } : {})
}

function statusVariant(value: string): 'success' | 'warning' | 'neutral' | 'brand' {
  if (value === 'approved' || value === 'converted') return 'success'
  if (value === 'sent' || value === 'under_review') return 'brand'
  if (value === 'rejected' || value === 'expired') return 'neutral'
  return 'warning'
}

function nextAction(row: PurchaseProforma) {
  if (row.status === 'draft') return t('purchases.hub.send')
  if (row.status === 'sent') return t('purchases.hub.review')
  if (row.status === 'under_review') return t('purchases.approve')
  if (row.status === 'approved') return t('purchases.hub.toOrder')
  return '—'
}

async function openCreate() {
  products.value = (await store.loadAllProducts()).filter(isStockableProduct)
  form.value = {
    ...emptyForm(),
    warehouse_id: warehouses.value[0]?.id ?? '',
    supplier_id: suppliers.value[0]?.id ?? '',
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
    await store.createPurchaseProforma({
      warehouse_id: form.value.warehouse_id || undefined,
      supplier_id: form.value.supplier_id,
      payment_terms: form.value.payment_terms || undefined,
      delivery_terms: form.value.delivery_terms || undefined,
      expires_at: form.value.expires_at || undefined,
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

async function act(row: PurchaseProforma, action: 'send' | 'review' | 'approve' | 'reject') {
  saving.value = true
  error.value = ''
  try {
    await store.actPurchaseProforma(row.id, action)
    await load()
  } catch (err) {
    error.value = extractApiErrorMessage(err)
  } finally {
    saving.value = false
  }
}

function openConvert(row: PurchaseProforma) {
  converting.value = row
  convertWarehouseId.value = row.warehouse_id || warehouses.value[0]?.id || ''
}

async function submitConvert() {
  if (!converting.value) return
  saving.value = true
  error.value = ''
  try {
    const created = await store.convertPurchaseProforma(converting.value.id, convertWarehouseId.value)
    converting.value = null
    await router.push({ name: 'purchase-order-detail', params: { id: created.id } })
  } catch (err) {
    error.value = extractApiErrorMessage(err)
  } finally {
    saving.value = false
  }
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
        :suppliers="supplierOptions"
        show-search
        show-period
        show-status
        show-supplier
        @apply="load"
      />
    </div>

    <div class="overflow-hidden rounded-xl bg-white shadow-sm ring-1 ring-slate-200">
      <div class="flex flex-wrap items-center justify-between gap-3 border-b border-slate-100 px-4 py-3">
        <h3 class="m-0 text-sm font-semibold text-slate-700">{{ t('purchases.hub.proformas') }}</h3>
        <button class="btn-primary-sm" @click="openCreate">+ {{ t('purchases.hub.newProforma') }}</button>
      </div>

      <table class="min-w-full divide-y divide-slate-200 text-sm">
        <thead class="bg-slate-50">
          <tr>
            <th class="px-4 py-3 text-left font-medium">{{ t('purchases.hub.number') }}</th>
            <th class="px-4 py-3 text-left font-medium">{{ t('nav.suppliers') }}</th>
            <th class="px-4 py-3 text-left font-medium">{{ t('purchases.hub.expires') }}</th>
            <th class="px-4 py-3 text-left font-medium">{{ t('products.status') }}</th>
            <th class="px-4 py-3 text-right font-medium">{{ t('purchases.hub.amount') }}</th>
            <th class="px-4 py-3 text-left font-medium">{{ t('purchases.nextStep') }}</th>
            <th class="px-4 py-3 text-left font-medium">{{ t('purchases.hub.date') }}</th>
            <th class="px-4 py-3"></th>
          </tr>
        </thead>
        <tbody class="divide-y divide-slate-100">
          <tr v-for="row in filteredRows" :key="row.id" class="hover:bg-slate-50">
            <td class="px-4 py-3 font-mono">
              {{ row.number }}
              <span v-if="row.requisition" class="ml-1 text-xs text-slate-400">{{ row.requisition.number }}</span>
            </td>
            <td class="px-4 py-3">{{ row.supplier?.name ?? '—' }}</td>
            <td class="px-4 py-3">{{ formatDate(row.expires_at) }}</td>
            <td class="px-4 py-3">
              <Badge :variant="statusVariant(row.status)">{{ t(`purchases.hub.proStatus.${row.status}`) }}</Badge>
            </td>
            <td class="px-4 py-3 text-right">{{ formatMoney(row.total) }}</td>
            <td class="px-4 py-3 text-slate-600">{{ nextAction(row) }}</td>
            <td class="px-4 py-3 text-slate-500">{{ formatDate(row.created_at) }}</td>
            <td class="px-4 py-3 text-right">
              <div class="flex justify-end gap-2">
                <button v-if="row.status === 'draft'" class="link" :disabled="saving" @click="act(row, 'send')">{{ t('purchases.hub.send') }}</button>
                <button v-if="row.status === 'sent'" class="link" :disabled="saving" @click="act(row, 'review')">{{ t('purchases.hub.review') }}</button>
                <button v-if="row.status === 'under_review'" class="link" :disabled="saving" @click="act(row, 'approve')">{{ t('purchases.approve') }}</button>
                <button v-if="row.status === 'sent' || row.status === 'under_review'" class="link-danger" :disabled="saving" @click="act(row, 'reject')">{{ t('purchases.hub.reject') }}</button>
                <button v-if="row.status === 'approved'" class="link" :disabled="saving" @click="openConvert(row)">{{ t('purchases.hub.toOrder') }}</button>
                <button
                  v-if="row.converted_purchase_order"
                  class="link"
                  @click="router.push({ name: 'purchase-order-detail', params: { id: row.converted_purchase_order.id } })"
                >
                  {{ row.converted_purchase_order.order_number }}
                </button>
              </div>
            </td>
          </tr>
        </tbody>
      </table>
      <p v-if="!filteredRows.length" class="px-4 py-8 text-center text-slate-500">{{ t('org.empty') }}</p>
    </div>

    <AppModal :open="showCreate" :title="t('purchases.hub.newProforma')" icon="receipt" @close="showCreate = false">
      <form class="space-y-3" @submit.prevent="submitCreate">
        <div class="grid gap-3 sm:grid-cols-2">
          <div>
            <FieldLabel icon="suppliers">{{ t('nav.suppliers') }}</FieldLabel>
            <select v-model="form.supplier_id" required class="field">
              <option v-for="supplier in suppliers" :key="supplier.id" :value="supplier.id">{{ supplier.name }}</option>
            </select>
          </div>
          <div>
            <FieldLabel icon="inventory">{{ t('inventory.warehouse') }}</FieldLabel>
            <select v-model="form.warehouse_id" class="field">
              <option value="">{{ t('common.optional') }}</option>
              <option v-for="warehouse in warehouses" :key="warehouse.id" :value="warehouse.id">{{ warehouse.name }}</option>
            </select>
          </div>
          <div>
            <FieldLabel icon="calendar">{{ t('purchases.hub.expires') }}</FieldLabel>
            <input v-model="form.expires_at" type="date" class="field" />
          </div>
          <div>
            <FieldLabel icon="card">{{ t('purchases.hub.paymentTerms') }}</FieldLabel>
            <input v-model="form.payment_terms" class="field" />
          </div>
          <div class="sm:col-span-2">
            <FieldLabel icon="transfer">{{ t('purchases.hub.deliveryTerms') }}</FieldLabel>
            <input v-model="form.delivery_terms" class="field" />
          </div>
        </div>
        <div class="space-y-2">
          <div v-for="(line, idx) in form.items" :key="idx" class="flex gap-2">
            <select v-model="line.product_id" required class="field flex-1" @change="onProductChange(idx)">
              <option value="">—</option>
              <option v-for="product in productsForLine(idx)" :key="product.id" :value="product.id">{{ product.name }}</option>
            </select>
            <input v-model.number="line.quantity" type="number" min="1" required class="field w-16" />
            <input v-model.number="line.unit_cost" type="number" min="0" step="0.01" required class="field w-24" />
            <button type="button" class="text-sm text-red-600" @click="removeLine(idx)">{{ t('inventory.removeLine') }}</button>
          </div>
          <button v-if="canAddLine()" type="button" class="text-sm text-brand-600" @click="addLine">+ {{ t('inventory.addLine') }}</button>
        </div>
        <div class="app-modal__actions">
          <button type="button" class="btn-secondary" @click="showCreate = false">{{ t('common.cancel') }}</button>
          <button type="submit" class="btn-primary" :disabled="saving">{{ t('common.save') }}</button>
        </div>
      </form>
    </AppModal>

    <AppModal :open="Boolean(converting)" :title="t('purchases.hub.toOrder')" icon="purchases" @close="converting = null">
      <form class="space-y-3" @submit.prevent="submitConvert">
        <div>
          <FieldLabel icon="inventory">{{ t('inventory.warehouse') }}</FieldLabel>
          <select v-model="convertWarehouseId" required class="field">
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

.btn-secondary { border-radius: 0.5rem; border: 1px solid #cbd5e1; padding: 0.5rem 1rem; }
.link { color: var(--color-brand-600); font-size: 0.8rem; font-weight: 600; }
.link-danger { color: #dc2626; font-size: 0.8rem; font-weight: 600; }
.text-brand-600 { color: var(--color-brand-600); }
</style>
