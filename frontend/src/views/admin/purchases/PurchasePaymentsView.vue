<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import PurchasingLayout from '../../../components/purchasing/PurchasingLayout.vue'
import AppModal from '../../../components/ui/AppModal.vue'
import FieldLabel from '../../../components/ui/FieldLabel.vue'
import ModuleFilters from '../../../components/ui/ModuleFilters.vue'
import { extractApiErrorMessage } from '../../../api/client'
import { useBackofficeStore } from '../../../stores/backoffice'
import type { PurchaseInvoice } from '../../../types'
import { formatDate, formatMoney } from '../../../utils/format'
import { parseMoneyInput } from '../../../utils/money'
import { emptyListFilters, inPeriod, matchesSearch, type ListFilters } from '../../../utils/listFilters'

const { t } = useI18n()
const store = useBackofficeStore()
const payments = ref<Array<{
  id: string
  payment_number: string
  amount: number
  payment_method: string
  reference?: string | null
  paid_at?: string | null
  invoice?: { id: string; invoice_number: string; supplier?: { name: string } | null } | null
}>>([])
const filters = ref<ListFilters>(emptyListFilters('month'))
const showPay = ref(false)
const paying = ref<PurchaseInvoice | null>(null)
const payAmount = ref('')
const payMethod = ref('bank_transfer')
const payReference = ref('')
const saving = ref(false)
const error = ref('')

const methodOptions = [
  { value: 'bank_transfer', label: 'Virement' },
  { value: 'cash', label: 'Espèces' },
  { value: 'mobile_money', label: 'Mobile money' },
  { value: 'check', label: 'Chèque' },
]

const filteredOutstanding = computed(() =>
  store.purchaseInvoices.filter((row) => {
    if (row.total <= row.paid_amount) return false
    const haystack = [row.invoice_number, row.supplier?.name].filter(Boolean).join(' ')
    if (!matchesSearch(haystack, filters.value.search)) return false
    if (!inPeriod(row.invoiced_at, filters.value)) return false
    return true
  }),
)

const filteredPayments = computed(() =>
  payments.value.filter((row) => {
    const haystack = [
      row.payment_number,
      row.reference,
      row.invoice?.invoice_number,
      row.invoice?.supplier?.name,
      row.payment_method,
    ].filter(Boolean).join(' ')
    if (!matchesSearch(haystack, filters.value.search)) return false
    if (!inPeriod(row.paid_at, filters.value)) return false
    if (filters.value.payment_method && row.payment_method !== filters.value.payment_method) return false
    return true
  }),
)

onMounted(load)

async function load() {
  await store.loadPurchaseInvoices()
  payments.value = await store.loadPurchasePayments()
}

function openPay(invoice: PurchaseInvoice) {
  paying.value = invoice
  payAmount.value = String(Math.max(0, invoice.total - invoice.paid_amount) / 100)
  payMethod.value = 'bank_transfer'
  payReference.value = ''
  error.value = ''
  showPay.value = true
}

async function submitPay() {
  if (!paying.value) return
  saving.value = true
  error.value = ''
  try {
    await store.recordPurchaseInvoicePayment(paying.value.id, {
      amount: parseMoneyInput(payAmount.value),
      payment_method: payMethod.value,
      reference: payReference.value || undefined,
    })
    showPay.value = false
    await load()
  } catch (err) {
    error.value = extractApiErrorMessage(err)
  } finally {
    saving.value = false
  }
}
</script>

<template>
  <PurchasingLayout>
    <div class="space-y-4">
      <p class="m-0 text-sm text-slate-500">{{ t('purchases.hub.paymentsHint') }}</p>

      <ModuleFilters
        v-model="filters"
        :methods="methodOptions"
        show-method
        show-period
        show-search
      />

      <div class="overflow-hidden rounded-xl bg-white shadow-sm ring-1 ring-slate-200">
        <div class="border-b border-slate-100 px-4 py-3">
          <h3 class="m-0 text-sm font-semibold text-slate-700">{{ t('purchases.tabs.invoices') }}</h3>
        </div>
        <table class="min-w-full divide-y divide-slate-200 text-sm">
          <thead class="bg-slate-50">
            <tr>
              <th class="px-4 py-3 text-left font-medium">#</th>
              <th class="px-4 py-3 text-left font-medium">{{ t('nav.suppliers') }}</th>
              <th class="px-4 py-3 text-right font-medium">{{ t('purchases.outstanding') }}</th>
              <th class="px-4 py-3 text-right font-medium"></th>
            </tr>
          </thead>
          <tbody class="divide-y divide-slate-100">
            <tr v-for="invoice in filteredOutstanding" :key="invoice.id">
              <td class="px-4 py-3 font-mono">{{ invoice.invoice_number }}</td>
              <td class="px-4 py-3">{{ invoice.supplier?.name ?? '—' }}</td>
              <td class="px-4 py-3 text-right">{{ formatMoney(invoice.total - invoice.paid_amount) }}</td>
              <td class="px-4 py-3 text-right">
                <button class="text-brand-600" @click="openPay(invoice)">{{ t('purchases.pay') }}</button>
              </td>
            </tr>
          </tbody>
        </table>
        <p v-if="!filteredOutstanding.length" class="px-4 py-6 text-center text-sm text-slate-500">{{ t('org.empty') }}</p>
      </div>

      <div class="overflow-hidden rounded-xl bg-white shadow-sm ring-1 ring-slate-200">
        <div class="border-b border-slate-100 px-4 py-3">
          <h3 class="m-0 text-sm font-semibold text-slate-700">{{ t('purchases.hub.payments') }}</h3>
        </div>
        <table class="min-w-full divide-y divide-slate-200 text-sm">
          <thead class="bg-slate-50">
            <tr>
              <th class="px-4 py-3 text-left font-medium">#</th>
              <th class="px-4 py-3 text-left font-medium">{{ t('purchases.tabs.invoices') }}</th>
              <th class="px-4 py-3 text-left font-medium">{{ t('nav.suppliers') }}</th>
              <th class="px-4 py-3 text-left font-medium">{{ t('payables.method') }}</th>
              <th class="px-4 py-3 text-right font-medium">{{ t('products.price') }}</th>
              <th class="px-4 py-3 text-left font-medium">{{ t('inventory.date') }}</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-slate-100">
            <tr v-for="row in filteredPayments" :key="row.id">
              <td class="px-4 py-3 font-mono">{{ row.payment_number }}</td>
              <td class="px-4 py-3 font-mono">{{ row.invoice?.invoice_number ?? '—' }}</td>
              <td class="px-4 py-3">{{ row.invoice?.supplier?.name ?? '—' }}</td>
              <td class="px-4 py-3">{{ row.payment_method }}</td>
              <td class="px-4 py-3 text-right">{{ formatMoney(row.amount) }}</td>
              <td class="px-4 py-3 text-slate-500">{{ formatDate(row.paid_at) }}</td>
            </tr>
          </tbody>
        </table>
        <p v-if="!filteredPayments.length" class="px-4 py-6 text-center text-sm text-slate-500">{{ t('org.empty') }}</p>
      </div>
    </div>

    <AppModal :open="showPay" :title="t('purchases.payInvoice')" icon="card" tone="success" @close="showPay = false">
      <form class="space-y-3" @submit.prevent="submitPay">
        <p class="text-sm text-slate-600">{{ paying?.invoice_number }}</p>
        <p v-if="error" class="m-0 text-sm text-red-700">{{ error }}</p>
        <div>
          <FieldLabel icon="coins">{{ t('products.price') }}</FieldLabel>
          <input v-model="payAmount" required class="field" />
        </div>
        <div>
          <FieldLabel icon="card">{{ t('payables.method') }}</FieldLabel>
          <select v-model="payMethod" class="field">
            <option value="bank_transfer">Virement</option>
            <option value="cash">Espèces</option>
            <option value="check">Chèque</option>
            <option value="mobile_money">Mobile money</option>
          </select>
        </div>
        <div>
          <FieldLabel icon="tag">{{ t('payables.reference') }}</FieldLabel>
          <input v-model="payReference" class="field" />
        </div>
        <div class="app-modal__actions">
          <button type="button" class="btn-secondary" @click="showPay = false">{{ t('common.cancel') }}</button>
          <button type="submit" class="btn-primary" :disabled="saving">{{ t('purchases.pay') }}</button>
        </div>
      </form>
    </AppModal>
  </PurchasingLayout>
</template>

<style scoped>
.field { width: 100%; border-radius: 0.5rem; border: 1px solid #cbd5e1; padding: 0.5rem 0.75rem; }
.btn-primary { border-radius: 0.5rem; padding: 0.5rem 1rem; font-weight: 500; color: white; background-color: var(--color-brand-600); }
.btn-secondary { border-radius: 0.5rem; border: 1px solid #cbd5e1; padding: 0.5rem 1rem; }
.text-brand-600 { color: var(--color-brand-600); }
</style>
