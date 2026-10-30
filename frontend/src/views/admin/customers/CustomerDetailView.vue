<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import { useConfirm } from '../../../composables/useConfirm'
import { useRoute, useRouter } from 'vue-router'
import { extractApiErrorMessage } from '../../../api/client'
import PageFrame from '../../../components/layout/PageFrame.vue'
import AppModal from '../../../components/ui/AppModal.vue'
import AppIcon from '../../../components/ui/AppIcon.vue'
import FieldLabel from '../../../components/ui/FieldLabel.vue'
import KpiCard from '../../../components/ui/KpiCard.vue'
import StatusBadge from '../../../components/organization/StatusBadge.vue'
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
const initials = computed(() => {
  const parts = (customer.value?.name ?? '').trim().split(/\s+/).filter(Boolean)
  return ((parts[0]?.[0] ?? '') + (parts[1]?.[0] ?? '')).toUpperCase() || 'C'
})
const addressLine = computed(() => {
  const address = primaryAddress.value
  if (!address) return '—'
  return [address.line1, address.city, address.country_code].filter(Boolean).join(', ')
})

function termsLabel(days?: number | null) {
  if (days == null) return '—'
  const key = `customers.terms.${days}`
  const label = t(key)
  return label === key ? String(days) : label
}

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
  <PageFrame>
    <template #title>{{ customer?.name ?? t('customers.detail') }}</template>
    <template #subtitle>{{ customer?.code }}</template>

    <div class="dossier">
      <div class="dossier-bar">
        <button type="button" class="btn-secondary" @click="router.push({ name: 'customers' })">
          <AppIcon name="chevron-left" :size="16" /> {{ t('nav.customers') }}
        </button>
        <button type="button" class="btn-primary" @click="openPaymentModal">
          <AppIcon name="card" :size="16" /> {{ t('customers.recordPayment') }}
        </button>
      </div>

      <p v-if="!customer" class="panel-empty">{{ t('common.loading') }}</p>

      <section v-else class="profile">
        <div class="profile-mark" aria-hidden="true">{{ initials }}</div>
        <div class="profile-main">
          <p class="profile-kicker">{{ t('customers.identity') }}</p>
          <h2>{{ customer.name }}</h2>
          <div class="profile-meta">
            <span class="profile-code">{{ customer.code || '—' }}</span>
            <StatusBadge :active="customer.is_active" :label="customer.is_active ? t('products.active') : t('products.inactive')" />
          </div>
        </div>
        <dl class="facts">
          <div>
            <dt>{{ t('customers.phone') }}</dt>
            <dd>{{ customer.phone || '—' }}</dd>
          </div>
          <div>
            <dt>{{ t('customers.email') }}</dt>
            <dd>{{ customer.email || '—' }}</dd>
          </div>
          <div>
            <dt>{{ t('customers.types.company') }}</dt>
            <dd>{{ customer.company_name || '—' }}</dd>
          </div>
          <div>
            <dt>{{ t('customers.nif') }}</dt>
            <dd>{{ customer.tax_id || '—' }}</dd>
          </div>
          <div>
            <dt>{{ t('customers.addresses') }}</dt>
            <dd>{{ addressLine }}</dd>
          </div>
          <div>
            <dt>{{ t('customers.paymentTerms') }}</dt>
            <dd>{{ termsLabel(customer.payment_terms_days) }}</dd>
          </div>
        </dl>
        <p v-if="customer.notes" class="profile-notes">{{ customer.notes }}</p>
      </section>

      <div v-if="summary" class="hub-strip">
        <KpiCard
          :label="t('customers.balance')"
          :value="formatMoney(summary.balance ?? 0)"
          :count-to="Number(summary.balance ?? 0)"
          count-format="money"
          icon="coins"
          accent="var(--color-brand-700)"
          :info="t('customers.ledgerHint')"
        />
        <KpiCard
          :label="t('customers.creditLimit')"
          :value="summary.credit_limit == null ? '—' : formatMoney(summary.credit_limit)"
          :count-to="summary.credit_limit == null ? null : Number(summary.credit_limit)"
          count-format="money"
          icon="card"
          accent="var(--color-brand-600)"
          :hint="`${t('customers.availableCredit')} · ${summary.available_credit == null ? '—' : formatMoney(summary.available_credit)}`"
        />
        <KpiCard
          :label="t('customers.loyaltyPoints')"
          :value="Number(summary.loyalty_points ?? 0)"
          :count-to="Number(summary.loyalty_points ?? 0)"
          icon="tag"
          accent="var(--color-warning, #b45309)"
          :hint="summary.loyalty_tier || 'standard'"
        />
        <KpiCard
          :label="t('customers.totalSales')"
          :value="formatMoney(summary.total_sales ?? 0)"
          :count-to="Number(summary.total_sales ?? 0)"
          count-format="money"
          icon="inventory"
          accent="var(--color-success, #157347)"
        />
      </div>

      <div class="ui-tabbar" role="tablist">
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

      <div v-if="activeTab === 'statement'" class="panel">
        <table class="ui-table">
          <thead>
            <tr>
              <th>{{ t('inventory.date') }}</th>
              <th>{{ t('payables.type') }}</th>
              <th>{{ t('payables.reference') }}</th>
              <th class="num">{{ t('payables.debit') }}</th>
              <th class="num">{{ t('payables.creditCol') }}</th>
              <th class="num">{{ t('payables.balance') }}</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="line in ledgerLines" :key="line.id">
              <td>{{ formatDate(line.occurred_at) }}</td>
              <td>{{ transactionTypeLabel(line.transaction_type) }}</td>
              <td class="font-mono">{{ line.reference ?? '—' }}</td>
              <td class="num">{{ line.debit ? formatMoney(line.debit) : '—' }}</td>
              <td class="num">{{ line.credit ? formatMoney(line.credit) : '—' }}</td>
              <td class="num">{{ formatMoney(line.balance) }}</td>
            </tr>
          </tbody>
        </table>
        <p v-if="statement.length === 0" class="panel-empty">{{ t('customers.ledgerEmpty') }}</p>
      </div>

      <div v-else-if="activeTab === 'payments'" class="panel">
        <table class="ui-table">
          <thead>
            <tr>
              <th>{{ t('payables.paymentNumber') }}</th>
              <th class="num">{{ t('products.price') }}</th>
              <th>{{ t('payables.method') }}</th>
              <th>{{ t('inventory.date') }}</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="p in payments" :key="p.id">
              <td class="font-mono">{{ p.payment_number }}</td>
              <td class="num">{{ formatMoney(p.amount) }}</td>
              <td>{{ p.payment_method }}</td>
              <td>{{ formatDate(p.paid_at) }}</td>
            </tr>
          </tbody>
        </table>
        <p v-if="!payments.length" class="panel-empty">{{ t('org.empty') }}</p>
      </div>

      <div v-else-if="activeTab === 'sales'" class="panel">
        <table class="ui-table">
          <thead>
            <tr>
              <th>{{ t('sales.reference') }}</th>
              <th class="num">{{ t('products.price') }}</th>
              <th>{{ t('inventory.date') }}</th>
            </tr>
          </thead>
          <tbody>
            <tr
              v-for="s in salesHistory"
              :key="s.id"
              class="is-link"
              @click="router.push({ name: 'sale-detail', params: { id: s.id } })"
            >
              <td class="font-mono">{{ s.reference ?? s.id.slice(0, 8) }}</td>
              <td class="num">{{ formatMoney(s.total) }}</td>
              <td>{{ formatDate(s.created_at) }}</td>
            </tr>
          </tbody>
        </table>
        <p v-if="!salesHistory.length" class="panel-empty">{{ t('org.empty') }}</p>
      </div>

      <div v-else-if="activeTab === 'loyalty'" class="panel loyalty">
        <div>
          <h3>{{ t('customers.loyalty') }}</h3>
          <p>{{ t('customers.loyaltyHint') }}</p>
          <p class="loyalty-rule">{{ t('customers.loyaltyRule') }}</p>
          <p>{{ t('customers.loyaltyReward') }}</p>
        </div>
        <form class="loyalty-form" @submit.prevent="redeemLoyalty">
          <p class="loyalty-balance">{{ summary?.loyalty_points ?? 0 }} <span>{{ t('customers.loyaltyPoints') }}</span></p>
          <p class="loyalty-tier">{{ summary?.loyalty_tier || 'standard' }}</p>
          <FieldLabel icon="coins">{{ t('customers.redeemPoints') }}</FieldLabel>
          <input v-model.number="redeemPoints" type="number" min="1" class="field" />
          <button type="submit" class="btn-primary" :class="{ 'is-busy': saving }" :disabled="saving">{{ t('customers.redeem') }}</button>
          <p v-if="redeemError" class="loyalty-error">{{ redeemError }}</p>
        </form>
      </div>

      <div v-else class="panel">
        <div class="panel-head">
          <h3>{{ t('customers.addresses') }}</h3>
          <button type="button" class="btn-primary" @click="openAddressModal()">
            <AppIcon name="plus" :size="16" /> {{ t('customers.addAddress') }}
          </button>
        </div>
        <div v-if="addresses.length" class="address-list">
          <article v-for="address in addresses" :key="address.id" class="address-card">
            <header>
              <strong>{{ address.label || '—' }}</strong>
              <StatusBadge v-if="address.is_primary" :active="true" :label="t('org.default')" />
            </header>
            <p>{{ [address.line1, address.line2, address.city, address.country_code].filter(Boolean).join(', ') }}</p>
            <div class="address-actions">
              <button type="button" class="btn-secondary" @click="openAddressModal(address)">
                <AppIcon name="edit" :size="16" /> {{ t('common.edit') }}
              </button>
              <button type="button" class="btn-danger" @click="removeAddress(address)">
                <AppIcon name="trash" :size="16" /> {{ t('common.delete') }}
              </button>
            </div>
          </article>
        </div>
        <p v-else class="panel-empty">{{ t('org.empty') }}</p>
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
          <button type="button" class="btn-secondary" @click="showPaymentModal = false"><AppIcon name="close" :size="16" /> {{ t('common.cancel') }}</button>
          <button type="submit" class="btn-primary gap-1.5" :class="{ 'is-busy': saving }" :disabled="saving">
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
          <button type="button" class="btn-secondary" @click="showAddressModal = false"><AppIcon name="close" :size="16" /> {{ t('common.cancel') }}</button>
          <button type="submit" class="btn-primary gap-1.5" :class="{ 'is-busy': saving }" :disabled="saving">
            <AppIcon name="check" :size="15" />
            {{ t('common.save') }}
          </button>
        </div>
      </form>
    </AppModal>
  </PageFrame>
</template>

<style scoped>
.dossier {
  display: flex;
  flex-direction: column;
  gap: 1.25rem;
}

.dossier-bar {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  justify-content: space-between;
  gap: 0.75rem;
}

.profile {
  display: grid;
  grid-template-columns: auto minmax(0, 1fr);
  gap: 0.85rem 1.15rem;
  padding: 1.1rem 1.15rem 1.1rem 1.25rem;
  background: var(--color-surface);
  border: 1px solid var(--color-border);
  border-left: 8px solid var(--color-brand-700, #1e3a5f);
  border-radius: var(--radius-lg);
}

.profile-mark {
  display: grid;
  width: 3.25rem;
  height: 3.25rem;
  place-items: center;
  background: var(--color-brand-700, #1e3a5f);
  color: #fff;
  font-weight: 700;
  letter-spacing: 0.04em;
}

.profile-kicker {
  margin: 0;
  color: var(--color-text-muted);
  font-size: 0.72rem;
  font-weight: 700;
  letter-spacing: 0.06em;
  text-transform: uppercase;
}

.profile-main h2 {
  margin: 0.15rem 0 0;
  color: var(--color-text-primary);
  font-size: 1.45rem;
  line-height: 1.2;
}

.profile-meta {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 0.5rem;
  margin-top: 0.45rem;
}

.profile-code {
  padding: 0.15rem 0.45rem;
  border: 1px solid var(--color-border);
  border-radius: var(--radius-sm, 4px);
  color: var(--color-text-secondary);
  font-family: ui-monospace, monospace;
  font-size: 0.8rem;
}

.facts {
  display: grid;
  grid-column: 1 / -1;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 0.85rem 1.25rem;
  margin: 0.2rem 0 0;
}

.facts div {
  min-width: 0;
  padding-top: 0.7rem;
  border-top: 1px solid var(--color-border);
}

.facts dt {
  color: var(--color-text-muted);
  font-size: 0.72rem;
  font-weight: 700;
  letter-spacing: 0.04em;
  text-transform: uppercase;
}

.facts dd {
  margin: 0.25rem 0 0;
  overflow-wrap: anywhere;
  color: var(--color-text-primary);
  font-weight: 650;
}

.profile-notes {
  grid-column: 1 / -1;
  margin: 0;
  color: var(--color-text-secondary);
  font-size: 0.9rem;
}

.panel {
  overflow: hidden;
  background: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-lg);
}

.panel .ui-table {
  width: 100%;
}

.panel-empty {
  margin: 0;
  padding: 1.4rem 1rem;
  color: var(--color-text-muted);
  font-size: 0.875rem;
  text-align: center;
}

.panel-head,
.address-card header,
.address-actions,
.loyalty-form {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 0.5rem;
}

.panel-head {
  justify-content: space-between;
  padding: 0.85rem 1rem;
  border-bottom: 1px solid var(--color-border);
}

.panel-head h3,
.loyalty h3 {
  margin: 0;
  color: var(--color-text-primary);
  font-size: 1rem;
}

.is-link {
  cursor: pointer;
}

.loyalty {
  display: grid;
  grid-template-columns: minmax(0, 1.4fr) minmax(16rem, 0.8fr);
  gap: 1.25rem;
  padding: 1.15rem;
}

.loyalty p {
  margin: 0 0 0.4rem;
  color: var(--color-text-secondary);
  font-size: 0.9rem;
}

.loyalty-rule {
  color: var(--color-text-primary);
  font-weight: 700;
}

.loyalty-form {
  align-items: stretch;
  align-content: start;
  padding: 0.9rem;
  border: 1px solid var(--color-border);
  border-radius: var(--radius-md);
}

.loyalty-balance {
  margin: 0;
  color: var(--color-text-primary);
  font-size: 1.6rem;
  font-weight: 750;
  line-height: 1;
}

.loyalty-balance span,
.loyalty-tier {
  color: var(--color-text-muted);
  font-size: 0.8rem;
  font-weight: 650;
}

.loyalty-error {
  color: var(--color-danger, #b91c1c);
}

.address-list {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(16rem, 1fr));
  gap: 0.75rem;
  padding: 1rem;
}

.address-card {
  display: grid;
  gap: 0.45rem;
  padding: 0.9rem;
  border: 1px solid var(--color-border);
  border-radius: var(--radius-md);
}

.address-card p {
  margin: 0;
  color: var(--color-text-secondary);
}

.address-card header {
  justify-content: space-between;
}

@media (max-width: 800px) {
  .facts,
  .loyalty {
    grid-template-columns: 1fr;
  }
}
</style>
