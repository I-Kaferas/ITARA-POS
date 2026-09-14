<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import { useConfirm } from '../../../composables/useConfirm'
import { useRoute, useRouter } from 'vue-router'
import { extractApiErrorMessage } from '../../../api/client'
import AdminLayout from '../../../components/layout/AdminLayout.vue'
import AppModal from '../../../components/ui/AppModal.vue'
import AppIcon from '../../../components/ui/AppIcon.vue'
import FieldLabel from '../../../components/ui/FieldLabel.vue'
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
import { parseMoneyInput } from '../../../utils/money'

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
const activeTab = ref<'statement' | 'payments' | 'sales' | 'loyalty' | 'addresses'>('statement')
const showPaymentModal = ref(false)
const showAddressModal = ref(false)
const saving = ref(false)
const redeemPoints = ref(100)
const redeemError = ref('')
const editingAddress = ref<CustomerAddress | null>(null)

const paymentForm = ref({
  amount: '',
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
const ledgerLines = computed<CustomerStatementLine[]>(() => [
  {
    id: 'opening',
    occurred_at: customer.value?.created_at ?? '',
    transaction_type: 'OPENING_BALANCE',
    reference: null,
    description: null,
    debit: 0,
    credit: 0,
    balance: 0,
    outstanding: 0,
  },
  ...statement.value.filter(line => line.debit > 0 || line.credit > 0),
])
const primaryAddress = computed(() => addresses.value.find(item => item.is_primary) ?? addresses.value[0] ?? null)

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
  const due = summary.value?.receivable ?? 0
  paymentForm.value = {
    amount: due > 0 ? String(due / 100) : '',
    payment_method: 'cash',
    reference: '',
    notes: '',
  }
  showPaymentModal.value = true
}

async function submitPayment() {
  saving.value = true
  try {
    const amount = parseMoneyInput(paymentForm.value.amount)
    if (amount < 1) return
    await store.recordCustomerPayment(customerId.value, {
      amount,
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

async function redeemLoyalty() {
  redeemError.value = ''
  saving.value = true
  try {
    await store.redeemCustomerLoyalty(customerId.value, Math.max(1, Math.round(redeemPoints.value)))
    await loadAll()
  } catch (error) {
    redeemError.value = extractApiErrorMessage(error, t('customers.redeemFailed'))
  } finally {
    saving.value = false
  }
}

function transactionTypeLabel(type: string): string {
  const map: Record<string, string> = {
    SALE: t('customers.creditSale'),
    PAYMENT: t('customers.payment'),
    CREDIT_NOTE: t('customers.creditNote'),
    SALE_RETURN: t('customers.saleReturn'),
    OPENING_BALANCE: t('customers.openingBalance'),
    ADJUSTMENT: t('customers.adjustment'),
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

      <div v-if="customer" class="rounded-xl bg-white p-4 shadow-sm ring-1 ring-slate-200">
        <p class="m-0 text-xs font-medium uppercase tracking-wide text-slate-400">{{ t('customers.identity') }}</p>
        <div class="mt-2 grid gap-2 text-sm sm:grid-cols-2">
          <p class="m-0"><span class="text-slate-400">{{ t('customers.name') }}</span> · {{ customer.name }}</p>
          <p class="m-0"><span class="text-slate-400">{{ t('customers.phone') }}</span> · {{ customer.phone || '—' }}</p>
          <p class="m-0"><span class="text-slate-400">{{ t('auth.email') }}</span> · {{ customer.email || '—' }}</p>
          <p class="m-0"><span class="text-slate-400">{{ t('customers.types.company') }}</span> · {{ customer.company_name || '—' }}</p>
          <p class="m-0 sm:col-span-2">
            <span class="text-slate-400">{{ t('customers.addresses') }}</span> ·
            {{ primaryAddress ? [primaryAddress.line1, primaryAddress.city].filter(Boolean).join(', ') : '—' }}
          </p>
        </div>
      </div>

      <div v-if="summary" class="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <div class="stat-card">
          <p class="stat-label">{{ t('customers.balance') }}</p>
          <p class="stat-value">{{ formatMoney(summary.balance) }}</p>
          <p class="m-0 mt-1 text-xs text-slate-400">{{ t('customers.ledgerHint') }}</p>
        </div>
        <div class="stat-card">
          <p class="stat-label">{{ t('customers.creditLimit') }}</p>
          <p class="stat-value">{{ summary.credit_limit == null ? '—' : formatMoney(summary.credit_limit) }}</p>
          <p class="m-0 mt-1 text-xs text-slate-400">{{ t('customers.availableCredit') }} · {{ summary.available_credit == null ? '—' : formatMoney(summary.available_credit) }}</p>
        </div>
        <div class="stat-card">
          <p class="stat-label">{{ t('customers.loyaltyPoints') }}</p>
          <p class="stat-value">{{ summary.loyalty_points }}</p>
          <p class="m-0 mt-1 text-xs text-slate-400">{{ summary.loyalty_tier || 'standard' }}</p>
        </div>
        <div class="stat-card">
          <p class="stat-label">{{ t('customers.totalSales') }}</p>
          <p class="stat-value">{{ formatMoney(summary.total_sales) }}</p>
        </div>
      </div>

      <div class="flex gap-2 border-b border-slate-200">
        <button
          v-for="tab in ([['statement', t('payables.tabs.statement')], ['payments', t('payables.tabs.payments')], ['sales', t('nav.sales')], ['loyalty', t('customers.loyalty')], ['addresses', t('customers.addresses')]] as const)"
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
            <tr v-for="line in ledgerLines" :key="line.id">
              <td class="px-4 py-3 text-slate-500">{{ formatDate(line.occurred_at) }}</td>
              <td class="px-4 py-3">{{ transactionTypeLabel(line.transaction_type) }}</td>
              <td class="px-4 py-3 font-mono text-slate-500">{{ line.reference ?? '—' }}</td>
              <td class="px-4 py-3 text-right">{{ line.debit ? formatMoney(line.debit) : '—' }}</td>
              <td class="px-4 py-3 text-right">{{ line.credit ? formatMoney(line.credit) : '—' }}</td>
              <td class="px-4 py-3 text-right font-medium">{{ formatMoney(line.balance) }}</td>
            </tr>
          </tbody>
        </table>
        <p v-if="statement.length === 0" class="px-4 py-3 text-center text-sm text-slate-500">{{ t('customers.ledgerEmpty') }}</p>
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

      <div v-else-if="activeTab === 'loyalty'" class="rounded-xl bg-white p-6 shadow-sm ring-1 ring-slate-200 space-y-3">
        <p class="m-0 text-sm text-slate-500">{{ t('customers.loyaltyHint') }}</p>
        <p class="m-0 text-sm font-medium">{{ t('customers.loyaltyRule') }}</p>
        <p class="m-0 text-sm text-slate-500">{{ t('customers.loyaltyReward') }}</p>
        <p class="m-0 text-sm">{{ summary?.loyalty_points ?? 0 }} {{ t('customers.loyaltyPoints') }} · {{ summary?.loyalty_tier || 'standard' }}</p>
        <form class="flex flex-wrap items-end gap-3" @submit.prevent="redeemLoyalty">
          <label class="text-sm">
            <span class="mb-1 flex items-center gap-2 font-medium">
              <span class="field-icon"><AppIcon name="coins" :size="14" /></span>
              {{ t('customers.redeemPoints') }}
            </span>
            <input v-model.number="redeemPoints" type="number" min="1" class="field w-32" />
          </label>
          <button type="submit" class="btn-primary" :disabled="saving">{{ t('customers.redeem') }}</button>
        </form>
        <p v-if="redeemError" class="m-0 text-sm text-red-600">{{ redeemError }}</p>
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
          <FieldLabel icon="coins">{{ t('products.price') }}</FieldLabel>
          <input v-model="paymentForm.amount" type="text" inputmode="decimal" required class="field" placeholder="50000" />
          <p class="mt-1 text-xs text-slate-500">{{ t('customers.paymentHint') }}</p>
        </div>
        <div>
          <FieldLabel icon="card">{{ t('payables.method') }}</FieldLabel>
          <select v-model="paymentForm.payment_method" class="field">
            <option value="cash">Espèces</option>
            <option value="card">Carte</option>
            <option value="bank_transfer">Virement</option>
            <option value="mobile_money">Mobile money</option>
          </select>
        </div>
        <div class="app-modal__actions">
          <button type="button" class="btn-secondary" @click="showPaymentModal = false">{{ t('common.cancel') }}</button>
          <button type="submit" class="btn-primary gap-1.5" :disabled="saving">
            <AppIcon name="check" :size="15" />
            {{ t('common.save') }}
          </button>
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
        <div><FieldLabel icon="tag">{{ t('org.name') }}</FieldLabel><input v-model="addressForm.label" class="field" /></div>
        <div><FieldLabel icon="pin">{{ t('org.street') }}</FieldLabel><input v-model="addressForm.line1" required class="field" /></div>
        <div><FieldLabel icon="building">{{ t('org.city') }}</FieldLabel><input v-model="addressForm.city" class="field" /></div>
        <div><FieldLabel icon="store-pin">{{ t('org.country') }}</FieldLabel><input v-model="addressForm.country_code" maxlength="2" class="field" /></div>
        <label class="flex items-center gap-2 text-sm"><span class="field-icon"><AppIcon name="check" :size="14" /></span><input v-model="addressForm.is_primary" type="checkbox" class="rounded" />{{ t('org.default') }}</label>
        <div class="app-modal__actions">
          <button type="button" class="btn-secondary" @click="showAddressModal = false">{{ t('common.cancel') }}</button>
          <button type="submit" class="btn-primary gap-1.5" :disabled="saving">
            <AppIcon name="check" :size="15" />
            {{ t('common.save') }}
          </button>
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
