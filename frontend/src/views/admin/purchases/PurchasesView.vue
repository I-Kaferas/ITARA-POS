<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import { useRoute, useRouter } from 'vue-router'
import PurchasingLayout from '../../../components/purchasing/PurchasingLayout.vue'
import StatusBadge from '../../../components/organization/StatusBadge.vue'
import AppModal from '../../../components/ui/AppModal.vue'
import FieldLabel from '../../../components/ui/FieldLabel.vue'
import ModuleFilters from '../../../components/ui/ModuleFilters.vue'
import { useBackofficeStore } from '../../../stores/backoffice'
import type { Product, PurchaseInvoice, Supplier, Warehouse } from '../../../types'
import { isStockableProduct } from '../../../utils/product'
import { formatDate, formatMoney } from '../../../utils/format'
import { emptyListFilters, inPeriod, matchesSearch, type ListFilters } from '../../../utils/listFilters'

const { t } = useI18n()
const route = useRoute()
const router = useRouter()
const store = useBackofficeStore()

const showPayModal = ref(false)
const showCreateModal = ref(false)
const payingInvoice = ref<PurchaseInvoice | null>(null)
const saving = ref(false)
const warehouses = ref<Warehouse[]>([])
const suppliers = ref<Supplier[]>([])
const products = ref<Product[]>([])
const filters = ref<ListFilters>(emptyListFilters('month'))
const payForm = ref({ amount: 0, payment_method: 'bank_transfer', reference: '', notes: '' })
const poForm = ref({
  warehouse_id: '',
  supplier_id: '',
  notes: '',
  items: [{ product_id: '', quantity: 1, unit_cost: 0 }],
})

const activeTab = computed<'orders' | 'invoices'>(() =>
  route.path.includes('/invoices') ? 'invoices' : 'orders',
)

watch(activeTab, () => {
  filters.value = { ...filters.value, status: '' }
})

const orderStatusOptions = computed(() => [
  { value: 'draft', label: orderStatusLabel('draft') },
  { value: 'pending', label: orderStatusLabel('pending') },
  { value: 'approved', label: orderStatusLabel('approved') },
  { value: 'partially_received', label: orderStatusLabel('partially_received') },
  { value: 'received', label: orderStatusLabel('received') },
  { value: 'completed', label: orderStatusLabel('completed') },
  { value: 'cancelled', label: orderStatusLabel('cancelled') },
])

const invoiceStatusOptions = computed(() => [
  { value: 'posted', label: invoiceStatusLabel('posted') },
  { value: 'partially_paid', label: invoiceStatusLabel('partially_paid') },
  { value: 'paid', label: invoiceStatusLabel('paid') },
  { value: 'cancelled', label: invoiceStatusLabel('cancelled') },
])

const statusOptions = computed(() =>
  activeTab.value === 'orders' ? orderStatusOptions.value : invoiceStatusOptions.value,
)

const supplierOptions = computed(() =>
  (suppliers.value.length ? suppliers.value : store.suppliers).map(s => ({ id: s.id, name: s.name })),
)

const filteredOrders = computed(() =>
  store.purchaseOrders.filter((row) => {
    const haystack = [row.order_number, row.supplier?.name, row.warehouse?.name].filter(Boolean).join(' ')
    if (!matchesSearch(haystack, filters.value.search)) return false
    if (!inPeriod(row.created_at ?? row.expected_at, filters.value)) return false
    if (filters.value.status && row.status !== filters.value.status) return false
    if (filters.value.supplier_id && row.supplier_id !== filters.value.supplier_id && row.supplier?.id !== filters.value.supplier_id) return false
    return true
  }),
)

const filteredInvoices = computed(() =>
  store.purchaseInvoices.filter((row) => {
    const haystack = [row.invoice_number, row.supplier?.name, row.purchase_order?.order_number].filter(Boolean).join(' ')
    if (!matchesSearch(haystack, filters.value.search)) return false
    if (!inPeriod(row.invoiced_at, filters.value)) return false
    if (filters.value.status && row.status !== filters.value.status) return false
    if (filters.value.supplier_id && row.supplier?.id !== filters.value.supplier_id) return false
    return true
  }),
)

onMounted(async () => {
  await Promise.all([
    store.loadPurchaseOrders(),
    store.loadPurchaseInvoices(),
    store.loadSuppliers().then(() => { suppliers.value = store.suppliers }),
  ])
  if (typeof route.query.supplier === 'string' && route.query.supplier) {
    await openCreateOrder()
    poForm.value.supplier_id = route.query.supplier
  }
})

async function applyFilters() {
  const params: Record<string, string> = {}
  if (filters.value.status) params.status = filters.value.status
  if (filters.value.supplier_id) params.supplier_id = filters.value.supplier_id
  if (activeTab.value === 'orders') {
    await Promise.all([
      store.loadPurchaseOrders(params),
      store.loadPurchaseInvoices(filters.value.supplier_id ? { supplier_id: filters.value.supplier_id } : {}),
    ])
  } else {
    await Promise.all([
      store.loadPurchaseOrders(filters.value.supplier_id ? { supplier_id: filters.value.supplier_id } : {}),
      store.loadPurchaseInvoices(params),
    ])
  }
}

function outstanding(invoice: PurchaseInvoice): number {
  return Math.max(0, invoice.total - invoice.paid_amount)
}

function openPay(invoice: PurchaseInvoice) {
  payingInvoice.value = invoice
  payForm.value = {
    amount: outstanding(invoice) / 100,
    payment_method: 'bank_transfer',
    reference: '',
    notes: '',
  }
  showPayModal.value = true
}

async function submitPayment() {
  if (!payingInvoice.value) return
  saving.value = true
  try {
    await store.recordPurchaseInvoicePayment(payingInvoice.value.id, {
      ...payForm.value,
      amount: Math.round(payForm.value.amount * 100),
    })
    showPayModal.value = false
    await store.loadPurchaseInvoices()
  } finally {
    saving.value = false
  }
}

async function openCreateOrder() {
  warehouses.value = await store.loadAllWarehouses()
  await store.loadSuppliers()
  suppliers.value = store.suppliers
  products.value = (await store.loadAllProducts()).filter(isStockableProduct)
  poForm.value = {
    warehouse_id: warehouses.value[0]?.id ?? '',
    supplier_id: suppliers.value[0]?.id ?? '',
    notes: '',
    items: [{ product_id: products.value[0]?.id ?? '', quantity: 1, unit_cost: (products.value[0]?.cost_price ?? 0) / 100 }],
  }
  showCreateModal.value = true
}

function addPoLine() {
  poForm.value.items.push({ product_id: '', quantity: 1, unit_cost: 0 })
}

function removePoLine(index: number) {
  poForm.value.items.splice(index, 1)
  if (!poForm.value.items.length) addPoLine()
}

async function submitCreateOrder() {
  saving.value = true
  try {
    const order = await store.createPurchaseOrder({
      warehouse_id: poForm.value.warehouse_id,
      supplier_id: poForm.value.supplier_id,
      notes: poForm.value.notes || undefined,
      items: poForm.value.items
        .filter(i => i.product_id && i.quantity > 0)
        .map(i => ({ ...i, unit_cost: Math.round(Number(i.unit_cost) * 100) })),
    })
    showCreateModal.value = false
    await store.loadPurchaseOrders()
    router.push({ name: 'purchase-order-detail', params: { id: order.id } })
  } finally {
    saving.value = false
  }
}

function nextStep(status: string): string {
  if (status === 'draft') return t('purchases.submit')
  if (status === 'pending') return t('purchases.approve')
  if (status === 'approved' || status === 'partially_received') return t('purchases.receive')
  if (status === 'received') return t('purchases.pay')
  return '—'
}

function orderStatusLabel(status: string): string {
  const map: Record<string, string> = {
    draft: t('inventory.statusDraft'),
    pending: t('inventory.statusPending'),
    approved: 'Approuvée',
    partially_received: 'Partielle',
    received: 'Reçue',
    completed: 'Terminée',
    cancelled: 'Annulée',
  }
  return map[status] ?? status
}

function invoiceStatusLabel(status: string): string {
  const map: Record<string, string> = {
    posted: 'Comptabilisée',
    partially_paid: 'Partiellement payée',
    paid: 'Payée',
    cancelled: 'Annulée',
  }
  return map[status] ?? status
}

function orderStatusActive(status: string): boolean {
  return status === 'completed' || status === 'received'
}

function invoiceStatusActive(status: string): boolean {
  return status === 'paid'
}
</script>

<template>
  <PurchasingLayout>
    <div class="mb-4">
      <ModuleFilters
        v-model="filters"
        :statuses="statusOptions"
        :suppliers="supplierOptions"
        :show-supplier="supplierOptions.length > 0"
        show-status
        show-period
        @apply="applyFilters"
      />
    </div>

    <div v-if="activeTab === 'orders'" class="overflow-hidden rounded-xl bg-white shadow-sm ring-1 ring-slate-200">
      <div class="flex items-center justify-between border-b border-slate-100 px-4 py-3">
        <h3 class="m-0 text-sm font-semibold text-slate-700">{{ t('purchases.tabs.orders') }}</h3>
        <div class="flex items-center gap-3">
          <span class="rounded-full bg-slate-100 px-2.5 py-0.5 text-xs font-medium text-slate-600">
            {{ filteredOrders.length }}
          </span>
          <button class="btn-primary-sm" @click="openCreateOrder">+ {{ t('purchases.newOrder') }}</button>
        </div>
      </div>
      <table class="min-w-full divide-y divide-slate-200 text-sm">
        <thead class="bg-slate-50">
          <tr>
            <th class="px-4 py-3 text-left font-medium">#</th>
            <th class="px-4 py-3 text-left font-medium">{{ t('nav.suppliers') }}</th>
            <th class="px-4 py-3 text-left font-medium">{{ t('inventory.warehouse') }}</th>
            <th class="px-4 py-3 text-left font-medium">{{ t('products.status') }}</th>
            <th class="px-4 py-3 text-right font-medium">{{ t('products.price') }}</th>
            <th class="px-4 py-3 text-left font-medium">{{ t('purchases.nextStep') }}</th>
            <th class="px-4 py-3 text-left font-medium">{{ t('inventory.date') }}</th>
          </tr>
        </thead>
        <tbody class="divide-y divide-slate-100">
          <tr
            v-for="row in filteredOrders"
            :key="row.id"
            class="cursor-pointer hover:bg-slate-50"
            @click="router.push({ name: 'purchase-order-detail', params: { id: row.id } })"
          >
            <td class="px-4 py-3 font-mono">{{ row.order_number }}</td>
            <td class="px-4 py-3">{{ row.supplier?.name ?? '—' }}</td>
            <td class="px-4 py-3">{{ row.warehouse?.name ?? '—' }}</td>
            <td class="px-4 py-3">
              <StatusBadge :active="orderStatusActive(row.status)" :label="orderStatusLabel(row.status)" />
            </td>
            <td class="px-4 py-3 text-right">{{ formatMoney(row.total) }}</td>
            <td class="px-4 py-3 text-slate-600">{{ nextStep(row.status) }}</td>
            <td class="px-4 py-3 text-slate-500">{{ formatDate(row.created_at) }}</td>
          </tr>
        </tbody>
      </table>
      <p v-if="!filteredOrders.length" class="px-4 py-8 text-center text-slate-500">{{ t('org.empty') }}</p>
    </div>

    <div v-else class="overflow-hidden rounded-xl bg-white shadow-sm ring-1 ring-slate-200">
      <div class="flex items-center justify-between border-b border-slate-100 px-4 py-3">
        <h3 class="m-0 text-sm font-semibold text-slate-700">{{ t('purchases.tabs.invoices') }}</h3>
        <span class="rounded-full bg-slate-100 px-2.5 py-0.5 text-xs font-medium text-slate-600">
          {{ filteredInvoices.length }}
        </span>
      </div>
      <table class="min-w-full divide-y divide-slate-200 text-sm">
        <thead class="bg-slate-50">
          <tr>
            <th class="px-4 py-3 text-left font-medium">#</th>
            <th class="px-4 py-3 text-left font-medium">{{ t('nav.suppliers') }}</th>
            <th class="px-4 py-3 text-left font-medium">{{ t('purchases.order') }}</th>
            <th class="px-4 py-3 text-left font-medium">{{ t('products.status') }}</th>
            <th class="px-4 py-3 text-right font-medium">{{ t('products.price') }}</th>
            <th class="px-4 py-3 text-right font-medium">{{ t('purchases.outstanding') }}</th>
            <th class="px-4 py-3 text-left font-medium">{{ t('inventory.date') }}</th>
            <th class="px-4 py-3 text-right font-medium">{{ t('common.edit') }}</th>
          </tr>
        </thead>
        <tbody class="divide-y divide-slate-100">
          <tr v-for="row in filteredInvoices" :key="row.id" class="hover:bg-slate-50">
            <td class="px-4 py-3 font-mono">{{ row.invoice_number }}</td>
            <td class="px-4 py-3">{{ row.supplier?.name ?? '—' }}</td>
            <td class="px-4 py-3 font-mono text-slate-500">{{ row.purchase_order?.order_number ?? '—' }}</td>
            <td class="px-4 py-3">
              <StatusBadge :active="invoiceStatusActive(row.status)" :label="invoiceStatusLabel(row.status)" />
            </td>
            <td class="px-4 py-3 text-right">{{ formatMoney(row.total) }}</td>
            <td class="px-4 py-3 text-right font-medium">{{ formatMoney(outstanding(row)) }}</td>
            <td class="px-4 py-3 text-slate-500">{{ formatDate(row.invoiced_at) }}</td>
            <td class="px-4 py-3 text-right">
              <button
                v-if="outstanding(row) > 0"
                class="text-brand-600"
                @click="openPay(row)"
              >
                {{ t('purchases.pay') }}
              </button>
            </td>
          </tr>
        </tbody>
      </table>
      <p v-if="!filteredInvoices.length" class="px-4 py-8 text-center text-slate-500">{{ t('org.empty') }}</p>
    </div>

    <AppModal
      :open="showCreateModal"
      :title="t('purchases.newOrder')"
      icon="purchases"
      tone="brand"
      size="lg"
      @close="showCreateModal = false"
    >
      <form class="space-y-3" @submit.prevent="submitCreateOrder">
        <div>
          <FieldLabel icon="inventory">{{ t('inventory.warehouse') }}</FieldLabel>
          <select v-model="poForm.warehouse_id" required class="field">
            <option v-for="w in warehouses" :key="w.id" :value="w.id">{{ w.name }}</option>
          </select>
        </div>
        <div>
          <FieldLabel icon="suppliers">{{ t('nav.suppliers') }}</FieldLabel>
          <select v-model="poForm.supplier_id" required class="field">
            <option v-for="s in suppliers" :key="s.id" :value="s.id">{{ s.name }}</option>
          </select>
        </div>
        <p class="text-xs text-slate-500">{{ t('inventory.entryHint') }}</p>
        <div class="space-y-2">
          <div v-for="(line, idx) in poForm.items" :key="idx" class="flex gap-2">
            <select v-model="line.product_id" required class="field flex-1">
              <option v-for="p in products" :key="p.id" :value="p.id">{{ p.name }}</option>
            </select>
            <input v-model.number="line.quantity" type="number" min="1" required class="field w-16" placeholder="Qté" />
            <input v-model.number="line.unit_cost" type="number" min="0" required class="field w-24" placeholder="Coût" />
            <button type="button" class="text-sm text-red-600" @click="removePoLine(idx)">{{ t('inventory.removeLine') }}</button>
          </div>
          <button type="button" class="text-sm text-brand-600" @click="addPoLine">+ {{ t('inventory.addLine') }}</button>
        </div>
        <div class="app-modal__actions">
          <button type="button" class="btn-secondary" @click="showCreateModal = false">{{ t('common.cancel') }}</button>
          <button type="submit" class="btn-primary" :disabled="saving">{{ t('inventory.saveEntry') }}</button>
        </div>
      </form>
    </AppModal>

    <AppModal
      :open="showPayModal"
      :title="t('purchases.payInvoice')"
      icon="card"
      tone="success"
      @close="showPayModal = false"
    >
      <form class="space-y-3" @submit.prevent="submitPayment">
        <p class="text-sm text-slate-600">{{ payingInvoice?.invoice_number }}</p>
        <div>
          <FieldLabel icon="coins">{{ t('products.price') }}</FieldLabel>
          <input v-model.number="payForm.amount" type="number" min="1" required class="field" />
        </div>
        <div>
          <FieldLabel icon="card">{{ t('payables.method') }}</FieldLabel>
          <select v-model="payForm.payment_method" class="field">
            <option value="bank_transfer">Virement</option>
            <option value="cash">Espèces</option>
            <option value="check">Chèque</option>
            <option value="mobile_money">Mobile money</option>
          </select>
        </div>
        <div>
          <FieldLabel icon="tag">{{ t('payables.reference') }}</FieldLabel>
          <input v-model="payForm.reference" class="field" />
        </div>
        <div class="app-modal__actions">
          <button type="button" class="btn-secondary" @click="showPayModal = false">{{ t('common.cancel') }}</button>
          <button type="submit" class="btn-primary" :disabled="saving">{{ t('purchases.pay') }}</button>
        </div>
      </form>
    </AppModal>
  </PurchasingLayout>
</template>

<style scoped>
.field { width: 100%; border-radius: 0.5rem; border: 1px solid #cbd5e1; padding: 0.5rem 0.75rem; }
.btn-primary { border-radius: 0.5rem; padding: 0.5rem 1rem; font-weight: 500; color: white; background-color: var(--color-brand-600); }
.btn-primary-sm { border-radius: 0.5rem; padding: 0.375rem 0.75rem; font-size: 0.875rem; font-weight: 500; color: white; background-color: var(--color-brand-600); }
.btn-secondary { border-radius: 0.5rem; border: 1px solid #cbd5e1; padding: 0.5rem 1rem; }
.text-brand-600 { color: var(--color-brand-600); }
</style>
