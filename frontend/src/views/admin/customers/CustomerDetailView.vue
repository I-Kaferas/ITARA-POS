<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import { useConfirm } from '../../../composables/useConfirm'
import { useRoute, useRouter } from 'vue-router'
import AdminLayout from '../../../components/layout/AdminLayout.vue'
import AppModal from '../../../components/ui/AppModal.vue'
import { useBackofficeStore } from '../../../stores/backoffice'
import type {
  Customer,
  CustomerAddress,
  CustomerPayment,
  CustomerStatementLine,
  CustomerSummary,
  Sale,
} from '../../../types'
import { formatDate, formatMoney } from '../../../utils/format'

const { t } = useI18n()
const { confirm: confirmDialog } = useConfirm()
const route = useRoute()
const router = useRouter()
const store = useBackofficeStore()

const customer = ref<Customer | null>(null)
const summary = ref<CustomerSummary | null>(null)
const statement = ref<CustomerStatementLine[]>([])
const payments = ref<CustomerPayment[]>([])
const salesHistory = ref<Sale[]>([])
const addresses = ref<CustomerAddress[]>([])
const activeTab = ref<'statement' | 'payments' | 'sales' | 'addresses'>('statement')
const showPaymentModal = ref(false)
const showAddressModal = ref(false)
const saving = ref(false)
const editingAddress = ref<CustomerAddress | null>(null)

const paymentForm = ref({
  amount: 0,
  payment_method: 'cash',
  reference: '',
  notes: '',
})

const addressForm = ref({
  label: 'default',
  line1: '',
  line2: '',
  city: '',
  state: '',
  postal_code: '',
  country_code: 'BI',
  is_primary: false,
  is_billing: false,
  is_shipping: true,
})

const customerId = computed(() => route.params.id as string)

onMounted(() => loadAll())

async function loadAll() {
  const id = customerId.value
  customer.value = await store.loadCustomerDetail(id)
  summary.value = await store.loadCustomerSummary(id)
  const hist = await store.loadCustomerHistory(id)
  statement.value = hist.data
  payments.value = await store.loadCustomerPayments(id)
  salesHistory.value = await store.loadCustomerSales(id)
  addresses.value = await store.loadCustomerAddresses(id)
}

function openPaymentModal() {
  paymentForm.value = {
    amount: summary.value?.receivable ?? 0,
    payment_method: 'cash',
    reference: '',
    notes: '',
  }
  showPaymentModal.value = true
}

async function submitPayment() {
  saving.value = true
  try {
    await store.recordCustomerPayment(customerId.value, {
      amount: paymentForm.value.amount,
      payment_method: paymentForm.value.payment_method,
      reference: paymentForm.value.reference || undefined,
      notes: paymentForm.value.notes || undefined,
    })
    showPaymentModal.value = false
    await loadAll()
  } finally {
    saving.value = false
  }
}

function openAddressModal(address?: CustomerAddress) {
  editingAddress.value = address ?? null
  addressForm.value = {
    label: address?.label ?? 'default',
    line1: address?.line1 ?? '',
    line2: address?.line2 ?? '',
    city: address?.city ?? '',
    state: address?.state ?? '',
    postal_code: address?.postal_code ?? '',
    country_code: address?.country_code ?? 'BI',
    is_primary: address?.is_primary ?? false,
    is_billing: address?.is_billing ?? false,
    is_shipping: address?.is_shipping ?? true,
  }
  showAddressModal.value = true
}

async function saveAddress() {
  saving.value = true
  try {
    await store.saveCustomerAddress(customerId.value, addressForm.value, editingAddress.value?.id)
    showAddressModal.value = false
    addresses.value = await store.loadCustomerAddresses(customerId.value)
  } finally {
    saving.value = false
  }
}

async function removeAddress(address: CustomerAddress) {
  if (!(await confirmDialog(t('org.confirmDelete')))) return
  await store.deleteCustomerAddress(address.id)
  addresses.value = await store.loadCustomerAddresses(customerId.value)
}

function transactionTypeLabel(type: string): string {
  const map: Record<string, string> = {
    SALE: 'Vente',
    PAYMENT: 'Paiement',
    CREDIT_NOTE: 'Avoir',
    DEBIT_NOTE: 'Note de débit',
    RETURN: 'Retour',
    OPENING_BALANCE: 'Solde initial',
    ADJUSTMENT: 'Ajustement',
  }
  return map[type] ?? type
}
</script>

<template>
  <AdminLayout>
    <template #title>{{ customer?.name ?? t('customers.detail') }}</template>
    <template #subtitle>{{ customer?.code }}</template>

    <div class="space-y-6">
      <div class="flex flex-wrap items-center justify-between gap-3">
        <button class="btn-secondary" @click="router.push({ name: 'customers' })">← {{ t('nav.customers') }}</button>
        <button class="btn-primary" @click="openPaymentModal">{{ t('customers.recordPayment') }}</button>
      </div>

      <div v-if="summary" class="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <div class="stat-card">
          <p class="stat-label">{{ t('customers.receivable') }}</p>
          <p class="stat-value">{{ formatMoney(summary.receivable) }}</p>
        </div>
        <div class="stat-card">
          <p class="stat-label">{{ t('customers.credit') }}</p>
          <p class="stat-value">{{ formatMoney(summary.credit) }}</p>
        </div>
        <div class="stat-card">
          <p class="stat-label">{{ t('customers.loyaltyPoints') }}</p>
          <p class="stat-value">{{ summary.loyalty_points }}</p>
        </div>
        <div class="stat-card">
          <p class="stat-label">{{ t('customers.totalSales') }}</p>
          <p class="stat-value">{{ formatMoney(summary.total_sales) }}</p>
        </div>
      </div>

      <div class="flex gap-2 border-b border-slate-200">
        <button
          v-for="tab in ([['statement', t('payables.tabs.statement')], ['payments', t('payables.tabs.payments')], ['sales', t('nav.sales')], ['addresses', t('customers.addresses')]] as const)"
          :key="tab[0]"
          class="tab-btn"
          :class="{ 'tab-btn--active': activeTab === tab[0] }"
          @click="activeTab = tab[0]"
        >
          {{ tab[1] }}
        </button>
      </div>

      <div v-if="activeTab === 'statement'" class="overflow-hidden rounded-xl bg-white shadow-sm ring-1 ring-slate-200">
        <table class="min-w-full divide-y divide-slate-200 text-sm">
          <thead class="bg-slate-50">
            <tr>
              <th class="px-4 py-3 text-left font-medium">{{ t('inventory.date') }}</th>
              <th class="px-4 py-3 text-left font-medium">{{ t('payables.type') }}</th>
              <th class="px-4 py-3 text-left font-medium">{{ t('payables.reference') }}</th>
              <th class="px-4 py-3 text-right font-medium">{{ t('payables.debit') }}</th>
              <th class="px-4 py-3 text-right font-medium">{{ t('payables.creditCol') }}</th>
              <th class="px-4 py-3 text-right font-medium">{{ t('payables.balance') }}</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-slate-100">
            <tr v-for="line in statement" :key="line.id">
              <td class="px-4 py-3 text-slate-500">{{ formatDate(line.occurred_at) }}</td>
              <td class="px-4 py-3">{{ transactionTypeLabel(line.transaction_type) }}</td>
              <td class="px-4 py-3 font-mono text-slate-500">{{ line.reference ?? '—' }}</td>
              <td class="px-4 py-3 text-right">{{ line.debit ? formatMoney(line.debit) : '—' }}</td>
              <td class="px-4 py-3 text-right">{{ line.credit ? formatMoney(line.credit) : '—' }}</td>
              <td class="px-4 py-3 text-right font-medium">{{ formatMoney(line.balance) }}</td>
            </tr>
          </tbody>
        </table>
        <p v-if="!statement.length" class="px-4 py-8 text-center text-slate-500">{{ t('org.empty') }}</p>
      </div>

      <div v-else-if="activeTab === 'payments'" class="overflow-hidden rounded-xl bg-white shadow-sm ring-1 ring-slate-200">
        <table class="min-w-full divide-y divide-slate-200 text-sm">
          <thead class="bg-slate-50">
            <tr>
              <th class="px-4 py-3 text-left font-medium">{{ t('payables.paymentNumber') }}</th>
              <th class="px-4 py-3 text-right font-medium">{{ t('products.price') }}</th>
              <th class="px-4 py-3 text-left font-medium">{{ t('payables.method') }}</th>
              <th class="px-4 py-3 text-left font-medium">{{ t('inventory.date') }}</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-slate-100">
            <tr v-for="p in payments" :key="p.id">
              <td class="px-4 py-3 font-mono">{{ p.payment_number }}</td>
              <td class="px-4 py-3 text-right font-medium">{{ formatMoney(p.amount) }}</td>
              <td class="px-4 py-3">{{ p.payment_method }}</td>
              <td class="px-4 py-3 text-slate-500">{{ formatDate(p.paid_at) }}</td>
            </tr>
          </tbody>
        </table>
        <p v-if="!payments.length" class="px-4 py-8 text-center text-slate-500">{{ t('org.empty') }}</p>
      </div>

      <div v-else-if="activeTab === 'sales'" class="overflow-hidden rounded-xl bg-white shadow-sm ring-1 ring-slate-200">
        <table class="min-w-full divide-y divide-slate-200 text-sm">
          <thead class="bg-slate-50">
            <tr>
              <th class="px-4 py-3 text-left font-medium">{{ t('sales.reference') }}</th>
              <th class="px-4 py-3 text-right font-medium">{{ t('products.price') }}</th>
              <th class="px-4 py-3 text-left font-medium">{{ t('inventory.date') }}</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-slate-100">
            <tr
              v-for="s in salesHistory"
              :key="s.id"
              class="cursor-pointer hover:bg-slate-50"
              @click="router.push({ name: 'sale-detail', params: { id: s.id } })"
            >
              <td class="px-4 py-3 font-mono">{{ s.reference ?? s.id.slice(0, 8) }}</td>
              <td class="px-4 py-3 text-right">{{ formatMoney(s.total) }}</td>
              <td class="px-4 py-3 text-slate-500">{{ formatDate(s.created_at) }}</td>
            </tr>
          </tbody>
        </table>
        <p v-if="!salesHistory.length" class="px-4 py-8 text-center text-slate-500">{{ t('org.empty') }}</p>
      </div>

      <div v-else class="overflow-hidden rounded-xl bg-white shadow-sm ring-1 ring-slate-200">
        <div class="flex items-center justify-between border-b border-slate-100 px-4 py-3">
          <h3 class="m-0 text-sm font-semibold text-slate-700">{{ t('customers.addresses') }}</h3>
          <button class="btn-primary" @click="openAddressModal()">+ {{ t('customers.addAddress') }}</button>
        </div>
        <table class="min-w-full divide-y divide-slate-200 text-sm">
          <thead class="bg-slate-50">
            <tr>
              <th class="px-4 py-3 text-left font-medium">{{ t('org.name') }}</th>
              <th class="px-4 py-3 text-left font-medium">{{ t('org.address') }}</th>
              <th class="px-4 py-3 text-left font-medium">{{ t('org.city') }}</th>
              <th class="px-4 py-3 text-right">{{ t('common.edit') }}</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-slate-100">
            <tr v-for="address in addresses" :key="address.id">
              <td class="px-4 py-3 font-medium">{{ address.label || '—' }}</td>
              <td class="px-4 py-3">{{ address.line1 }}</td>
              <td class="px-4 py-3 text-slate-500">{{ address.city || '—' }}</td>
              <td class="px-4 py-3 space-x-2 text-right">
                <button class="text-brand-600" @click="openAddressModal(address)">{{ t('common.edit') }}</button>
                <button class="text-red-600" @click="removeAddress(address)">{{ t('common.delete') }}</button>
              </td>
            </tr>
          </tbody>
        </table>
        <p v-if="!addresses.length" class="px-4 py-8 text-center text-slate-500">{{ t('org.empty') }}</p>
      </div>
    </div>

    <AppModal
      :open="showPaymentModal"
      :title="t('customers.recordPayment')"
      icon="card"
      tone="success"
      @close="showPaymentModal = false"
    >
      <form class="space-y-3" @submit.prevent="submitPayment">
        <div>
          <label class="mb-1 block text-sm font-medium">{{ t('products.price') }}</label>
          <input v-model.number="paymentForm.amount" type="number" min="1" required class="field" />
        </div>
        <div>
          <label class="mb-1 block text-sm font-medium">{{ t('payables.method') }}</label>
          <select v-model="paymentForm.payment_method" class="field">
            <option value="cash">Espèces</option>
            <option value="card">Carte</option>
            <option value="bank_transfer">Virement</option>
            <option value="mobile_money">Mobile money</option>
          </select>
        </div>
        <div class="app-modal__actions">
          <button type="button" class="btn-secondary" @click="showPaymentModal = false">{{ t('common.cancel') }}</button>
          <button type="submit" class="btn-primary" :disabled="saving">{{ t('common.save') }}</button>
        </div>
      </form>
    </AppModal>

    <AppModal
      :open="showAddressModal"
      :title="editingAddress ? t('customers.editAddress') : t('customers.addAddress')"
      icon="pin"
      tone="info"
      @close="showAddressModal = false"
    >
      <form class="space-y-3" @submit.prevent="saveAddress">
        <div><label class="mb-1 block text-sm font-medium">{{ t('org.name') }}</label><input v-model="addressForm.label" class="field" /></div>
        <div><label class="mb-1 block text-sm font-medium">{{ t('org.street') }}</label><input v-model="addressForm.line1" required class="field" /></div>
        <div><label class="mb-1 block text-sm font-medium">{{ t('org.city') }}</label><input v-model="addressForm.city" class="field" /></div>
        <div><label class="mb-1 block text-sm font-medium">{{ t('org.country') }}</label><input v-model="addressForm.country_code" maxlength="2" class="field" /></div>
        <label class="flex items-center gap-2 text-sm"><input v-model="addressForm.is_primary" type="checkbox" class="rounded" />{{ t('org.default') }}</label>
        <div class="app-modal__actions">
          <button type="button" class="btn-secondary" @click="showAddressModal = false">{{ t('common.cancel') }}</button>
          <button type="submit" class="btn-primary" :disabled="saving">{{ t('common.save') }}</button>
        </div>
      </form>
    </AppModal>
  </AdminLayout>
</template>

<style scoped>
.field { width: 100%; border-radius: 0.5rem; border: 1px solid #cbd5e1; padding: 0.5rem 0.75rem; }
.btn-primary { border-radius: 0.5rem; padding: 0.5rem 1rem; font-weight: 500; color: white; background-color: var(--color-brand-600); }
.btn-secondary { border-radius: 0.5rem; border: 1px solid #cbd5e1; padding: 0.5rem 1rem; }
.stat-card { border-radius: 0.75rem; background: white; padding: 1rem; box-shadow: 0 1px 2px rgb(0 0 0 / 0.05); ring: 1px solid #e2e8f0; }
.stat-label { margin: 0; font-size: 0.75rem; color: #64748b; }
.stat-value { margin: 0.25rem 0 0; font-size: 1.25rem; font-weight: 700; color: #0f172a; }
.tab-btn { padding: 0.5rem 1rem; font-size: 0.875rem; color: #64748b; border-bottom: 2px solid transparent; }
.tab-btn--active { color: var(--color-brand-600); border-bottom-color: var(--color-brand-600); font-weight: 500; }
.text-brand-600 { color: var(--color-brand-600); }
</style>
