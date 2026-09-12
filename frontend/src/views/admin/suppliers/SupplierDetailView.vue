<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import { useConfirm } from '../../../composables/useConfirm'
import { useRoute, useRouter } from 'vue-router'
import AdminLayout from '../../../components/layout/AdminLayout.vue'
import AppModal from '../../../components/ui/AppModal.vue'
import { useBackofficeStore } from '../../../stores/backoffice'
import type { DueDateItem, Supplier, SupplierContact, SupplierStatementLine, SupplierSummary } from '../../../types'
import { formatDate, formatMoney } from '../../../utils/format'

const { t } = useI18n()
const { confirm: confirmDialog } = useConfirm()
const route = useRoute()
const router = useRouter()
const store = useBackofficeStore()

const supplier = ref<Supplier | null>(null)
const summary = ref<SupplierSummary | null>(null)
const statement = ref<SupplierStatementLine[]>([])
const dueDates = ref<{ open: DueDateItem[]; overdue: DueDateItem[] }>({ open: [], overdue: [] })
const payments = ref<Awaited<ReturnType<typeof store.loadSupplierPayments>>>([])
const contacts = ref<SupplierContact[]>([])
const activeTab = ref<'statement' | 'schedule' | 'payments' | 'contacts'>('statement')
const showPaymentModal = ref(false)
const showContactModal = ref(false)
const saving = ref(false)
const editingContact = ref<SupplierContact | null>(null)

const paymentForm = ref({
  amount: 0,
  payment_method: 'bank_transfer',
  reference: '',
  notes: '',
})

const contactForm = ref({
  name: '',
  title: '',
  email: '',
  phone: '',
  is_primary: false,
  notes: '',
})

const supplierId = computed(() => route.params.id as string)

onMounted(() => loadAll())

async function loadAll() {
  const id = supplierId.value
  const detail = await store.loadSupplierDetail(id)
  supplier.value = detail.supplier
  summary.value = detail.summary
  const stmt = await store.loadSupplierStatement(id)
  statement.value = stmt.data
  dueDates.value = await store.loadSupplierDueDates(id)
  payments.value = await store.loadSupplierPayments(id)
  contacts.value = await store.loadSupplierContacts(id)
}

function openPaymentModal() {
  paymentForm.value = {
    amount: summary.value?.debt ?? 0,
    payment_method: 'bank_transfer',
    reference: '',
    notes: '',
  }
  showPaymentModal.value = true
}

async function submitPayment() {
  saving.value = true
  try {
    await store.recordSupplierPayment(supplierId.value, {
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

function openContactModal(contact?: SupplierContact) {
  editingContact.value = contact ?? null
  contactForm.value = {
    name: contact?.name ?? '',
    title: contact?.title ?? '',
    email: contact?.email ?? '',
    phone: contact?.phone ?? '',
    is_primary: contact?.is_primary ?? false,
    notes: contact?.notes ?? '',
  }
  showContactModal.value = true
}

async function saveContact() {
  saving.value = true
  try {
    await store.saveSupplierContact(supplierId.value, contactForm.value, editingContact.value?.id)
    showContactModal.value = false
    contacts.value = await store.loadSupplierContacts(supplierId.value)
  } finally {
    saving.value = false
  }
}

async function removeContact(contact: SupplierContact) {
  if (!(await confirmDialog(t('org.confirmDelete')))) return
  await store.deleteSupplierContact(contact.id)
  contacts.value = await store.loadSupplierContacts(supplierId.value)
}

function transactionTypeLabel(type: string): string {
  const map: Record<string, string> = {
    PURCHASE: 'Achat',
    PAYMENT: 'Paiement',
    CREDIT_NOTE: 'Avoir',
    DEBIT_NOTE: 'Note de débit',
    OPENING_BALANCE: 'Solde initial',
    ADJUSTMENT: 'Ajustement',
  }
  return map[type] ?? type
}
</script>

<template>
  <AdminLayout>
    <template #title>{{ supplier?.name ?? t('payables.supplierDetail') }}</template>
    <template #subtitle>{{ supplier?.code }}</template>

    <div class="space-y-6">
      <div class="flex flex-wrap items-center justify-between gap-3">
        <button class="btn-secondary" @click="router.push({ name: 'payables' })">← {{ t('payables.title') }}</button>
        <button class="btn-primary" @click="openPaymentModal">{{ t('payables.recordPayment') }}</button>
      </div>

      <div v-if="summary" class="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <div class="stat-card">
          <p class="stat-label">{{ t('payables.outstanding') }}</p>
          <p class="stat-value">{{ formatMoney(summary.debt) }}</p>
        </div>
        <div class="stat-card">
          <p class="stat-label">{{ t('payables.credit') }}</p>
          <p class="stat-value">{{ formatMoney(summary.credit) }}</p>
        </div>
        <div class="stat-card">
          <p class="stat-label">{{ t('payables.openInvoices') }}</p>
          <p class="stat-value">{{ summary.open_invoices }}</p>
        </div>
        <div class="stat-card">
          <p class="stat-label">{{ t('payables.overdueInvoices') }}</p>
          <p class="stat-value text-red-600">{{ summary.overdue_invoices }}</p>
        </div>
      </div>

      <div class="flex gap-2 border-b border-slate-200">
        <button
          v-for="tab in ([
            ['statement', t('payables.tabs.statement')],
            ['schedule', t('payables.tabs.schedule')],
            ['payments', t('payables.tabs.payments')],
            ['contacts', t('suppliers.contacts')],
          ] as const)"
          :key="tab[0]"
          class="tab-btn"
          :class="{ active: activeTab === tab[0] }"
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
            <tr v-for="line in statement" :key="line.id" class="hover:bg-slate-50">
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

      <div v-else-if="activeTab === 'schedule'" class="overflow-hidden rounded-xl bg-white shadow-sm ring-1 ring-slate-200">
        <table class="min-w-full divide-y divide-slate-200 text-sm">
          <thead class="bg-slate-50">
            <tr>
              <th class="px-4 py-3 text-left font-medium">{{ t('payables.dueDate') }}</th>
              <th class="px-4 py-3 text-left font-medium">{{ t('payables.reference') }}</th>
              <th class="px-4 py-3 text-right font-medium">{{ t('payables.outstanding') }}</th>
              <th class="px-4 py-3 text-left font-medium">{{ t('products.status') }}</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-slate-100">
            <tr v-for="item in dueDates.open" :key="item.id" class="hover:bg-slate-50">
              <td class="px-4 py-3">{{ formatDate(item.due_date) }}</td>
              <td class="px-4 py-3 font-mono text-slate-500">{{ item.reference ?? '—' }}</td>
              <td class="px-4 py-3 text-right font-medium">{{ formatMoney(item.outstanding) }}</td>
              <td class="px-4 py-3">
                <span v-if="item.is_overdue" class="badge-overdue">{{ t('payables.overdue') }}</span>
                <span v-else class="badge-open">{{ t('payables.open') }}</span>
              </td>
            </tr>
          </tbody>
        </table>
        <p v-if="!dueDates.open.length" class="px-4 py-8 text-center text-slate-500">{{ t('org.empty') }}</p>
      </div>

      <div v-else-if="activeTab === 'payments'" class="overflow-hidden rounded-xl bg-white shadow-sm ring-1 ring-slate-200">
        <table class="min-w-full divide-y divide-slate-200 text-sm">
          <thead class="bg-slate-50">
            <tr>
              <th class="px-4 py-3 text-left font-medium">{{ t('payables.paymentNumber') }}</th>
              <th class="px-4 py-3 text-left font-medium">{{ t('payables.method') }}</th>
              <th class="px-4 py-3 text-right font-medium">{{ t('products.price') }}</th>
              <th class="px-4 py-3 text-left font-medium">{{ t('inventory.date') }}</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-slate-100">
            <tr v-for="payment in payments" :key="payment.id" class="hover:bg-slate-50">
              <td class="px-4 py-3 font-mono">{{ payment.payment_number }}</td>
              <td class="px-4 py-3 text-slate-600">{{ payment.payment_method }}</td>
              <td class="px-4 py-3 text-right font-medium">{{ formatMoney(payment.amount) }}</td>
              <td class="px-4 py-3 text-slate-500">{{ formatDate(payment.paid_at) }}</td>
            </tr>
          </tbody>
        </table>
        <p v-if="!payments.length" class="px-4 py-8 text-center text-slate-500">{{ t('org.empty') }}</p>
      </div>

      <div v-else class="overflow-hidden rounded-xl bg-white shadow-sm ring-1 ring-slate-200">
        <div class="flex items-center justify-between border-b border-slate-100 px-4 py-3">
          <h3 class="m-0 text-sm font-semibold text-slate-700">{{ t('suppliers.contacts') }}</h3>
          <button class="btn-primary" @click="openContactModal()">+ {{ t('suppliers.addContact') }}</button>
        </div>
        <table class="min-w-full divide-y divide-slate-200 text-sm">
          <thead class="bg-slate-50">
            <tr>
              <th class="px-4 py-3 text-left font-medium">{{ t('org.name') }}</th>
              <th class="px-4 py-3 text-left font-medium">{{ t('auth.email') }}</th>
              <th class="px-4 py-3 text-left font-medium">{{ t('org.phone') }}</th>
              <th class="px-4 py-3 text-right">{{ t('common.edit') }}</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-slate-100">
            <tr v-for="contact in contacts" :key="contact.id">
              <td class="px-4 py-3 font-medium">{{ contact.name }}</td>
              <td class="px-4 py-3 text-slate-500">{{ contact.email || '—' }}</td>
              <td class="px-4 py-3 text-slate-500">{{ contact.phone || '—' }}</td>
              <td class="px-4 py-3 space-x-2 text-right">
                <button class="text-brand-600" @click="openContactModal(contact)">{{ t('common.edit') }}</button>
                <button class="text-red-600" @click="removeContact(contact)">{{ t('common.delete') }}</button>
              </td>
            </tr>
          </tbody>
        </table>
        <p v-if="!contacts.length" class="px-4 py-8 text-center text-slate-500">{{ t('org.empty') }}</p>
      </div>
    </div>

    <AppModal
      :open="showPaymentModal"
      :title="t('payables.recordPayment')"
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
            <option value="bank_transfer">Virement</option>
            <option value="cash">Espèces</option>
            <option value="check">Chèque</option>
            <option value="mobile_money">Mobile money</option>
            <option value="card">Carte</option>
          </select>
        </div>
        <div>
          <label class="mb-1 block text-sm font-medium">{{ t('payables.reference') }}</label>
          <input v-model="paymentForm.reference" class="field" />
        </div>
        <div>
          <label class="mb-1 block text-sm font-medium">{{ t('inventory.reason') }}</label>
          <textarea v-model="paymentForm.notes" rows="2" class="field" />
        </div>
        <div class="app-modal__actions">
          <button type="button" class="btn-secondary" @click="showPaymentModal = false">{{ t('common.cancel') }}</button>
          <button type="submit" class="btn-primary" :disabled="saving">{{ t('common.save') }}</button>
        </div>
      </form>
    </AppModal>

    <AppModal
      :open="showContactModal"
      :title="editingContact ? t('suppliers.editContact') : t('suppliers.addContact')"
      icon="customers"
      tone="info"
      @close="showContactModal = false"
    >
      <form class="space-y-3" @submit.prevent="saveContact">
        <div><label class="mb-1 block text-sm font-medium">{{ t('org.name') }}</label><input v-model="contactForm.name" required class="field" /></div>
        <div><label class="mb-1 block text-sm font-medium">{{ t('auth.email') }}</label><input v-model="contactForm.email" type="email" class="field" /></div>
        <div><label class="mb-1 block text-sm font-medium">{{ t('org.phone') }}</label><input v-model="contactForm.phone" class="field" /></div>
        <label class="flex items-center gap-2 text-sm"><input v-model="contactForm.is_primary" type="checkbox" class="rounded" />{{ t('org.default') }}</label>
        <div class="app-modal__actions">
          <button type="button" class="btn-secondary" @click="showContactModal = false">{{ t('common.cancel') }}</button>
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
.stat-card { border-radius: 0.75rem; background: white; padding: 1rem 1.25rem; box-shadow: 0 1px 2px rgb(0 0 0 / 0.05); border: 1px solid #e2e8f0; }
.stat-label { font-size: 0.875rem; color: #64748b; }
.stat-value { margin-top: 0.25rem; font-size: 1.5rem; font-weight: 600; }
.tab-btn { padding: 0.5rem 1rem; font-size: 0.875rem; font-weight: 500; color: #64748b; border-bottom: 2px solid transparent; }
.tab-btn.active { color: var(--color-brand-600); border-bottom-color: var(--color-brand-600); }
.badge-overdue { border-radius: 9999px; background: #fef2f2; padding: 0.125rem 0.625rem; font-size: 0.75rem; font-weight: 500; color: #dc2626; }
.badge-open { border-radius: 9999px; background: #f0fdf4; padding: 0.125rem 0.625rem; font-size: 0.75rem; font-weight: 500; color: #16a34a; }
.text-brand-600 { color: var(--color-brand-600); }
</style>
