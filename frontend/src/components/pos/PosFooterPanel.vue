<script setup lang="ts">
import { computed, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import AppModal from '../ui/AppModal.vue'
import { usePosStore } from '../../stores/pos'
import { formatMoney, parseMoneyInput } from '../../utils/money'
import type { CartCalculation, CartDiscountPayload, PosCustomerOption, PosHeldSale, PosPaymentLine, PosPaymentMethod } from '../../types/pos'

const props = defineProps<{
  totals: CartCalculation
  customer: PosCustomerOption | null
  note: string | null
  globalDiscount: CartDiscountPayload | null
  heldSales: PosHeldSale[]
  isEmpty: boolean
  calculating?: boolean
  paymentMethods?: PosPaymentMethod[]
  labels: {
    customer: string
    discount: string
    note: string
    subtotal: string
    lineDiscounts: string
    promoDiscounts: string
    globalDiscount: string
    fees: string
    tax: string
    total: string
    hold: string
    retrieve: string
    cancel: string
    pay: string
    searchCustomer: string
    discountType: string
    fixed: string
    percent: string
    amount: string
    payment: string
    cash: string
    card: string
    tendered: string
    change: string
    heldSales: string
    noHeldSales: string
    modify?: string
    addArticles?: string
    payHeld?: string
    heldItems?: string
    notePlaceholder: string
    confirm: string
    createCustomer: string
    customerName: string
    customerPhone: string
    customerEmail: string
    noCustomerFound: string
    customerCreated: string
    noPaymentMethods?: string
    customerRequired?: string
    paymentSingle?: string
    paymentMixed?: string
    remaining?: string
    paid?: string
    addPaymentLine?: string
    removeLine?: string
    fillRemaining?: string
    mixedMinLines?: string
    amountMismatch?: string
  }
}>()

const emit = defineEmits<{
  selectCustomer: [customer: PosCustomerOption | null]
  setDiscount: [discount: CartDiscountPayload | null]
  setNote: [note: string | null]
  hold: []
  retrieve: [id: string, options?: { openPayment?: boolean }]
  deleteHeld: [id: string]
  cancel: []
  pay: [payments: PosPaymentLine[]]
}>()

const { locale } = useI18n()
const pos = usePosStore()

const showCustomer = ref(false)
const showDiscount = ref(false)
const showNote = ref(false)
const showHeld = ref(false)
const showPayment = ref(false)

const customerQuery = ref('')
const customerResults = ref<PosCustomerOption[]>([])
const customerLoading = ref(false)
const customerMode = ref<'search' | 'create'>('search')
const creatingCustomer = ref(false)
const newCustomer = ref({ name: '', phone: '', email: '' })
const customerSearched = ref(false)

const discountType = ref<'fixed' | 'percent'>('percent')
const discountValue = ref('')

const noteInput = ref('')
const paymentMode = ref<'single' | 'mixed'>('single')
const paymentMethod = ref('cash')
const tenderedInput = ref('')
const paymentError = ref('')
const mixedLines = ref<{ method: string; amountInput: string; tenderedInput: string }[]>([])

const MOBILE_MONEY: PosPaymentMethod = {
  value: 'mobile_money',
  label: 'Mobile Money',
  label_fr: 'Mobile Money',
  requires_customer: false,
  supports_change: false,
}

function withMobileMoney(list: PosPaymentMethod[]) {
  if (list.some(method => method.value === 'mobile_money')) return list
  const cardIndex = list.findIndex(method => method.value === 'card')
  const next = [...list]
  next.splice(cardIndex >= 0 ? cardIndex : next.length, 0, MOBILE_MONEY)
  return next
}

const methods = computed(() => {
  if (props.paymentMethods?.length) return withMobileMoney(props.paymentMethods)
  if (pos.availablePaymentMethods.length) return withMobileMoney(pos.availablePaymentMethods)
  return [
    { value: 'cash', label: props.labels.cash, label_fr: props.labels.cash, requires_customer: false, supports_change: true },
    { value: 'mobile_money', label: 'Mobile Money', label_fr: 'Mobile Money', requires_customer: false, supports_change: false },
    { value: 'card', label: props.labels.card, label_fr: props.labels.card, requires_customer: false, supports_change: false },
    { value: 'bank_transfer', label: 'Virement', label_fr: 'Virement', requires_customer: false, supports_change: false },
    { value: 'credit', label: 'Crédit', label_fr: 'Crédit', requires_customer: true, supports_change: false },
  ] as PosPaymentMethod[]
})

const selectedMethod = computed(() => methods.value.find(m => m.value === paymentMethod.value) ?? null)
const supportsChange = computed(() => selectedMethod.value?.supports_change ?? paymentMethod.value === 'cash')

const mixedPaid = computed(() =>
  mixedLines.value.reduce((sum, line) => sum + parseMoneyInput(line.amountInput), 0),
)
const mixedRemaining = computed(() => props.totals.grand_total - mixedPaid.value)
const mixedChange = computed(() =>
  mixedLines.value.reduce((sum, line) => {
    const meta = methods.value.find(m => m.value === line.method)
    if (!meta?.supports_change) return sum
    const amount = parseMoneyInput(line.amountInput)
    const tendered = parseMoneyInput(line.tenderedInput || line.amountInput)
    return sum + Math.max(0, tendered - amount)
  }, 0),
)

function methodLabel(method: PosPaymentMethod) {
  return locale.value === 'fr' ? (method.label_fr || method.label) : method.label
}

function money(amount: number) {
  return formatMoney(amount, props.totals.currency)
}

function openPaymentModal() {
  if (props.isEmpty) return
  showPayment.value = true
}

defineExpose({ openPaymentModal })

function amountInputFromCents(amount: number) {
  const major = Math.max(0, amount) / 100
  return Number.isInteger(major) ? String(major) : major.toFixed(2)
}

function firstAvailableMethod(exclude: string[] = []) {
  return methods.value.find(m =>
    !exclude.includes(m.value) && (!m.requires_customer || props.customer),
  ) ?? methods.value.find(m => !m.requires_customer || props.customer) ?? methods.value[0]
}

function methodMeta(code: string) {
  return methods.value.find(m => m.value === code)
}

async function searchCustomers() {
  customerSearched.value = true
  if (!customerQuery.value.trim()) {
    customerResults.value = []
    return
  }
  customerLoading.value = true
  try {
    customerResults.value = await pos.searchCustomers(customerQuery.value)
  } finally {
    customerLoading.value = false
  }
}

function openCustomerModal() {
  customerMode.value = 'search'
  customerQuery.value = ''
  customerResults.value = []
  customerSearched.value = false
  newCustomer.value = { name: '', phone: '', email: '' }
  showCustomer.value = true
}

function openCreateCustomer() {
  customerMode.value = 'create'
  newCustomer.value = {
    name: customerQuery.value.trim(),
    phone: '',
    email: '',
  }
}

async function submitCreateCustomer() {
  if (!newCustomer.value.name.trim()) return

  creatingCustomer.value = true
  try {
    const created = await pos.createCustomer({
      name: newCustomer.value.name.trim(),
      phone: newCustomer.value.phone.trim() || undefined,
      email: newCustomer.value.email.trim() || undefined,
    })
    emit('selectCustomer', created)
    showCustomer.value = false
    customerQuery.value = ''
    customerResults.value = []
    pos.setStatus(props.labels.customerCreated)
  } catch (e) {
    pos.setStatus(e instanceof Error ? e.message : 'Erreur création client')
  } finally {
    creatingCustomer.value = false
  }
}

function pickCustomer(c: PosCustomerOption) {
  emit('selectCustomer', c)
  showCustomer.value = false
  customerQuery.value = ''
  customerResults.value = []
}

function clearCustomer() {
  emit('selectCustomer', null)
  showCustomer.value = false
}

function applyDiscount() {
  const value = discountType.value === 'fixed'
    ? parseMoneyInput(discountValue.value)
    : discountValue.value

  if (!value || Number(value) <= 0) {
    emit('setDiscount', null)
  } else {
    emit('setDiscount', { type: discountType.value, value })
  }
  showDiscount.value = false
}

function openDiscount() {
  if (props.globalDiscount) {
    discountType.value = props.globalDiscount.type
    discountValue.value = String(props.globalDiscount.value)
  } else {
    discountType.value = 'percent'
    discountValue.value = ''
  }
  showDiscount.value = true
}

function openNote() {
  noteInput.value = props.note ?? ''
  showNote.value = true
}

function saveNote() {
  emit('setNote', noteInput.value.trim() || null)
  showNote.value = false
}

function defaultMixedLines() {
  const total = props.totals.grand_total
  const cash = methods.value.find(method => method.value === 'cash') ?? firstAvailableMethod()
  const mobile = methods.value.find(method => method.value === 'mobile_money' && method.value !== cash?.value)
    ?? firstAvailableMethod([cash?.value ?? ''])
  const firstAmount = Math.floor(total / 2)
  return [
    { method: cash?.value ?? 'cash', amountInput: amountInputFromCents(firstAmount), tenderedInput: '' },
    { method: mobile?.value ?? 'mobile_money', amountInput: amountInputFromCents(total - firstAmount), tenderedInput: '' },
  ]
}

function openPayment() {
  paymentError.value = ''
  paymentMode.value = 'single'
  const first = firstAvailableMethod()
  paymentMethod.value = first?.value ?? 'cash'
  tenderedInput.value = amountInputFromCents(props.totals.grand_total)
  mixedLines.value = defaultMixedLines()
  showPayment.value = true
}

function setPaymentMode(mode: 'single' | 'mixed') {
  paymentMode.value = mode
  paymentError.value = ''
  if (mode === 'mixed') {
    mixedLines.value = defaultMixedLines()
  }
}

function addMixedLine() {
  const used = mixedLines.value.map(l => l.method)
  const next = firstAvailableMethod(used) ?? firstAvailableMethod()
  mixedLines.value.push({
    method: next?.value ?? 'cash',
    amountInput: mixedRemaining.value > 0 ? amountInputFromCents(mixedRemaining.value) : '',
    tenderedInput: '',
  })
}

function removeMixedLine(index: number) {
  if (mixedLines.value.length <= 2) return
  mixedLines.value.splice(index, 1)
}

function fillRemaining(index: number) {
  const line = mixedLines.value[index]
  if (!line) return
  const others = mixedLines.value.reduce((sum, row, i) => (
    i === index ? sum : sum + parseMoneyInput(row.amountInput)
  ), 0)
  const remaining = props.totals.grand_total - others
  line.amountInput = amountInputFromCents(Math.max(0, remaining))
  if (methodMeta(line.method)?.supports_change && !line.tenderedInput) {
    line.tenderedInput = line.amountInput
  }
}

function confirmPayment() {
  paymentError.value = ''

  if (paymentMode.value === 'single') {
    const method = selectedMethod.value
    if (!method) {
      paymentError.value = props.labels.noPaymentMethods || 'Aucun mode de paiement'
      return
    }
    if (method.requires_customer && !props.customer) {
      paymentError.value = props.labels.customerRequired || 'Client requis'
      return
    }
    const tendered = supportsChange.value
      ? parseMoneyInput(tenderedInput.value)
      : props.totals.grand_total
    if (supportsChange.value && tendered < props.totals.grand_total) {
      paymentError.value = 'Montant insuffisant'
      return
    }
    emit('pay', [{
      method: paymentMethod.value,
      amount: props.totals.grand_total,
      tendered: supportsChange.value ? tendered : undefined,
    }])
    showPayment.value = false
    return
  }

  if (mixedLines.value.length < 2) {
    paymentError.value = props.labels.mixedMinLines || 'Ajoutez au moins deux modes'
    return
  }

  const payments: PosPaymentLine[] = []
  for (const line of mixedLines.value) {
    const meta = methodMeta(line.method)
    const amount = parseMoneyInput(line.amountInput)
    if (amount < 1) {
      paymentError.value = 'Chaque ligne doit avoir un montant'
      return
    }
    if (meta?.requires_customer && !props.customer) {
      paymentError.value = props.labels.customerRequired || 'Client requis'
      return
    }
    const tendered = meta?.supports_change
      ? parseMoneyInput(line.tenderedInput || line.amountInput)
      : undefined
    if (meta?.supports_change && (tendered ?? 0) < amount) {
      paymentError.value = 'Montant reçu insuffisant pour les espèces'
      return
    }
    payments.push({ method: line.method, amount, tendered })
  }

  const paid = payments.reduce((s, p) => s + p.amount, 0)
  if (paid !== props.totals.grand_total) {
    paymentError.value = `${props.labels.amountMismatch} (${money(paid)} / ${money(props.totals.grand_total)})`
    return
  }

  emit('pay', payments)
  showPayment.value = false
}

const promoNames = computed(() => {
  const names = [...new Set((props.totals.promotions ?? []).map(row => row.name).filter(Boolean))]
  return names.join(' · ')
})

const discountLabel = () => {
  if (props.totals.discount_total > 0) return `${props.labels.discount} ${money(props.totals.discount_total)}`
  return props.labels.discount
}
</script>

<template>
  <footer class="pos-footer">
    <div class="pos-footer__actions">
      <button type="button" class="pos-chip" @click="openCustomerModal">
        {{ customer?.name ?? labels.customer }}
      </button>
      <button type="button" class="pos-chip" @click="openDiscount">
        {{ discountLabel() }}
      </button>
      <button type="button" class="pos-chip" @click="openNote">
        {{ note ?? labels.note }}
      </button>
    </div>

    <div class="pos-footer__summary">
      <div class="pos-footer__row"><span>{{ labels.subtotal }}</span><span>{{ money(totals.subtotal) }}</span></div>
      <div v-if="totals.line_discounts_total > 0" class="pos-footer__row pos-footer__row--muted">
        <span>{{ labels.lineDiscounts }}</span><span>− {{ money(totals.line_discounts_total) }}</span>
      </div>
      <div v-if="totals.promotion_discounts_total > 0" class="pos-footer__row pos-footer__row--muted">
        <span>{{ promoNames || labels.promoDiscounts }}</span><span>− {{ money(totals.promotion_discounts_total) }}</span>
      </div>
      <div v-if="totals.global_discount_total > 0" class="pos-footer__row pos-footer__row--muted">
        <span>{{ labels.globalDiscount }}</span><span>− {{ money(totals.global_discount_total) }}</span>
      </div>
      <div v-if="totals.fees_total > 0" class="pos-footer__row"><span>{{ labels.fees }}</span><span>{{ money(totals.fees_total) }}</span></div>
      <div class="pos-footer__row"><span>{{ labels.tax }}</span><span>{{ money(totals.tax_total) }}</span></div>
      <div class="pos-footer__total">
        <span>{{ labels.total }}</span>
        <span class="pos-footer__total-amount">
          {{ calculating ? '…' : money(totals.grand_total) }}
        </span>
      </div>
    </div>

    <div class="pos-footer__buttons">
      <button type="button" class="pos-btn pos-btn--outline" :disabled="isEmpty" @click="emit('hold')">
        {{ labels.hold }}
      </button>
      <button type="button" class="pos-btn pos-btn--outline" :disabled="!heldSales.length" @click="showHeld = true">
        {{ labels.retrieve }} ({{ heldSales.length }})
      </button>
      <button type="button" class="pos-btn pos-btn--outline" :disabled="isEmpty" @click="emit('cancel')">
        {{ labels.cancel }}
      </button>
      <button type="button" class="pos-btn pos-btn--pay" :disabled="isEmpty || calculating" @click="openPayment">
        {{ labels.pay }}
      </button>
    </div>

    <!-- Customer modal -->
    <AppModal :open="showCustomer" :title="labels.customer" icon="customers" tone="brand" size="md" @close="showCustomer = false">
      <div class="pos-modal-content">
        <div class="pos-modal__tabs">
          <button
            type="button"
            class="pos-modal__tab"
            :class="{ 'pos-modal__tab--active': customerMode === 'search' }"
            @click="customerMode = 'search'"
          >
            {{ labels.searchCustomer }}
          </button>
          <button
            type="button"
            class="pos-modal__tab"
            :class="{ 'pos-modal__tab--active': customerMode === 'create' }"
            @click="openCreateCustomer"
          >
            {{ labels.createCustomer }}
          </button>
        </div>

        <template v-if="customerMode === 'search'">
          <input
            v-model="customerQuery"
            class="pos-field"
            :placeholder="labels.searchCustomer"
            @input="searchCustomers"
          />
          <div class="pos-modal__list">
            <button v-if="customer" type="button" class="pos-modal__item pos-modal__item--danger" @click="clearCustomer">
              ✕ Retirer le client
            </button>
            <p v-if="customerLoading" class="pos-modal__empty">…</p>
            <p
              v-else-if="customerSearched && !customerResults.length && customerQuery.trim()"
              class="pos-modal__empty"
            >
              {{ labels.noCustomerFound }}
            </p>
            <button
              v-if="customerSearched && !customerResults.length && customerQuery.trim()"
              type="button"
              class="pos-modal__item pos-modal__item--create"
              @click="openCreateCustomer"
            >
              + {{ labels.createCustomer }} « {{ customerQuery.trim() }} »
            </button>
            <button
              v-for="c in customerResults"
              :key="c.id"
              type="button"
              class="pos-modal__item"
              @click="pickCustomer(c)"
            >
              <strong>{{ c.name }}</strong>
              <span v-if="c.phone || c.email">{{ c.phone ?? c.email }}</span>
            </button>
          </div>
        </template>

        <template v-else>
          <label class="pos-label">{{ labels.customerName }}</label>
          <input v-model="newCustomer.name" class="pos-field" required />
          <label class="pos-label">{{ labels.customerPhone }}</label>
          <input v-model="newCustomer.phone" class="pos-field" type="tel" />
          <label class="pos-label">{{ labels.customerEmail }}</label>
          <input v-model="newCustomer.email" class="pos-field" type="email" />
          <div class="pos-modal__actions">
            <button type="button" class="pos-btn pos-btn--outline" @click="customerMode = 'search'">
              {{ labels.cancel }}
            </button>
            <button
              type="button"
              class="pos-btn pos-btn--pay"
              :disabled="!newCustomer.name.trim() || creatingCustomer"
              @click="submitCreateCustomer"
            >
              {{ labels.createCustomer }}
            </button>
          </div>
        </template>
      </div>
    </AppModal>

    <!-- Discount modal -->
    <AppModal :open="showDiscount" :title="labels.discount" icon="percent" tone="accent" size="sm" @close="showDiscount = false">
      <div class="pos-modal-content">
        <div class="pos-modal__row">
          <label><input v-model="discountType" type="radio" value="percent" /> {{ labels.percent }}</label>
          <label><input v-model="discountType" type="radio" value="fixed" /> {{ labels.fixed }}</label>
        </div>
        <input v-model="discountValue" class="pos-field" :placeholder="labels.amount" />
        <div class="pos-modal__actions">
          <button type="button" class="pos-btn pos-btn--outline" @click="showDiscount = false">{{ labels.cancel }}</button>
          <button type="button" class="pos-btn pos-btn--pay" @click="applyDiscount">{{ labels.confirm }}</button>
        </div>
      </div>
    </AppModal>

    <!-- Note modal -->
    <AppModal :open="showNote" :title="labels.note" icon="note" tone="info" size="sm" @close="showNote = false">
      <div class="pos-modal-content">
        <textarea v-model="noteInput" class="pos-field pos-field--area" :placeholder="labels.notePlaceholder" />
        <div class="pos-modal__actions">
          <button type="button" class="pos-btn pos-btn--outline" @click="showNote = false">{{ labels.cancel }}</button>
          <button type="button" class="pos-btn pos-btn--pay" @click="saveNote">{{ labels.confirm }}</button>
        </div>
      </div>
    </AppModal>

    <!-- Held sales modal -->
    <AppModal :open="showHeld" :title="labels.heldSales" icon="pause" tone="warning" size="lg" @close="showHeld = false">
      <div class="pos-modal-content">
        <div v-if="!heldSales.length" class="pos-modal__empty">{{ labels.noHeldSales }}</div>
        <div v-for="sale in heldSales" :key="sale.id" class="pos-held pos-held--detail">
          <div class="pos-held__header">
            <div>
              <strong>{{ sale.label }}</strong>
              <p class="pos-held__date">{{ new Date(sale.heldAt).toLocaleString() }}</p>
              <p v-if="sale.customerName" class="pos-held__meta">{{ sale.customerName }}</p>
            </div>
            <div class="pos-held__total">{{ money(sale.total ?? sale.lines.reduce((sum, line) => sum + line.product.price * line.quantity, 0)) }}</div>
          </div>

          <div v-if="sale.lines.length" class="pos-held__items">
            <p class="pos-held__items-title">{{ labels.heldItems || 'Articles' }}</p>
            <div v-for="line in sale.lines" :key="line.lineId" class="pos-held__item">
              <div>
                <span>{{ line.product.name }}</span>
                <small>{{ line.quantity }} × {{ money(line.product.price) }}</small>
              </div>
              <strong>{{ money(line.product.price * line.quantity) }}</strong>
            </div>
          </div>
          <p v-else class="pos-held__meta">Aucun article chargé</p>

          <div class="pos-held__actions">
            <button
              type="button"
              class="pos-btn pos-btn--outline"
              @click="emit('retrieve', sale.id); showHeld = false"
            >
              {{ labels.modify || 'Modifier' }}
            </button>
            <button
              type="button"
              class="pos-btn pos-btn--outline"
              @click="emit('retrieve', sale.id); showHeld = false"
            >
              {{ labels.addArticles || 'Ajouter articles' }}
            </button>
            <button
              type="button"
              class="pos-btn pos-btn--pay"
              @click="emit('retrieve', sale.id, { openPayment: true }); showHeld = false"
            >
              {{ labels.payHeld || labels.pay }}
            </button>
            <button type="button" class="pos-btn pos-btn--danger pos-btn--icon" @click="emit('deleteHeld', sale.id)">×</button>
          </div>
        </div>
      </div>
    </AppModal>

    <!-- Payment modal -->
    <AppModal :open="showPayment" :title="labels.payment" icon="card" tone="success" size="lg" @close="showPayment = false">
      <div class="pos-modal-content">
        <p class="pos-payment-total">{{ money(totals.grand_total) }}</p>

        <div class="pos-modal__tabs">
          <button
            type="button"
            class="pos-modal__tab"
            :class="{ 'pos-modal__tab--active': paymentMode === 'single' }"
            @click="setPaymentMode('single')"
          >
            {{ labels.paymentSingle || 'Simple' }}
          </button>
          <button
            type="button"
            class="pos-modal__tab"
            :class="{ 'pos-modal__tab--active': paymentMode === 'mixed' }"
            @click="setPaymentMode('mixed')"
          >
            {{ labels.paymentMixed || 'Mixte' }}
          </button>
        </div>

        <template v-if="paymentMode === 'single'">
          <p v-if="!methods.length" class="pos-modal__empty">
            {{ labels.noPaymentMethods || 'Aucun mode de paiement configuré' }}
          </p>
          <div v-else class="pos-modal__methods">
            <label
              v-for="method in methods"
              :key="method.value"
              class="pos-method"
              :class="{
                'pos-method--active': paymentMethod === method.value,
                'pos-method--disabled': method.requires_customer && !customer,
              }"
            >
              <input
                v-model="paymentMethod"
                type="radio"
                :value="method.value"
                :disabled="method.requires_customer && !customer"
              />
              <span>{{ methodLabel(method) }}</span>
              <small v-if="method.requires_customer && !customer">
                {{ labels.customerRequired || 'Client requis' }}
              </small>
            </label>
          </div>
          <div v-if="supportsChange">
            <label class="pos-label">{{ labels.tendered }}</label>
            <input v-model="tenderedInput" class="pos-field" />
            <p v-if="parseMoneyInput(tenderedInput) >= totals.grand_total" class="pos-change">
              {{ labels.change }}: {{ money(parseMoneyInput(tenderedInput) - totals.grand_total) }}
            </p>
          </div>
        </template>

        <template v-else>
          <div class="pos-mixed-summary">
            <span>{{ labels.paid || 'Payé' }}: <strong>{{ money(mixedPaid) }}</strong></span>
            <span :class="{ 'pos-mixed-summary--ok': mixedRemaining === 0, 'pos-mixed-summary--warn': mixedRemaining !== 0 }">
              {{ labels.remaining || 'Reste' }}: <strong>{{ money(mixedRemaining) }}</strong>
            </span>
          </div>

          <div
            v-for="(line, index) in mixedLines"
            :key="index"
            class="pos-mixed-line"
          >
            <select v-model="line.method" class="pos-field pos-field--select">
              <option
                v-for="method in methods"
                :key="method.value"
                :value="method.value"
                :disabled="method.requires_customer && !customer"
              >
                {{ methodLabel(method) }}
              </option>
            </select>
            <input
              v-model="line.amountInput"
              class="pos-field"
              :placeholder="labels.amount"
            />
            <button
              type="button"
              class="pos-btn pos-btn--outline pos-btn--icon"
              :title="labels.fillRemaining || 'Compléter'"
              @click="fillRemaining(index)"
            >
              =
            </button>
            <button
              type="button"
              class="pos-btn pos-btn--danger pos-btn--icon"
              :disabled="mixedLines.length <= 2"
              :title="labels.removeLine || 'Retirer'"
              @click="removeMixedLine(index)"
            >
              ×
            </button>
            <div v-if="methodMeta(line.method)?.supports_change" class="pos-mixed-tendered">
              <label class="pos-label">{{ labels.tendered }}</label>
              <input v-model="line.tenderedInput" class="pos-field" :placeholder="line.amountInput" />
            </div>
          </div>

          <button type="button" class="pos-btn pos-btn--outline pos-btn--block" @click="addMixedLine">
            + {{ labels.addPaymentLine || 'Ajouter un mode' }}
          </button>

          <p v-if="mixedChange > 0" class="pos-change">
            {{ labels.change }}: {{ money(mixedChange) }}
          </p>
        </template>

        <p v-if="paymentError" class="pos-payment-error">{{ paymentError }}</p>
        <div class="pos-modal__actions">
          <button type="button" class="pos-btn pos-btn--outline" @click="showPayment = false">{{ labels.cancel }}</button>
          <button
            type="button"
            class="pos-btn pos-btn--pay"
            :disabled="!methods.length || (paymentMode === 'mixed' && mixedRemaining !== 0)"
            @click="confirmPayment"
          >
            {{ labels.pay }}
          </button>
        </div>
      </div>
    </AppModal>
  </footer>
</template>

<style scoped>
.pos-footer {
  display: grid;
  grid-template-columns: minmax(11rem, 0.8fr) minmax(12rem, 0.9fr) minmax(16rem, 1.1fr);
  gap: 0.75rem;
  align-items: stretch;
  flex: 0 0 auto;
  background: #fff;
  border-top: 1px solid #e7edf3;
  padding: 0.7rem 0.9rem;
  box-shadow: 0 -10px 28px rgba(15, 23, 42, 0.05);
}
.pos-footer__actions {
  display: flex;
  flex-direction: column;
  gap: 0.4rem;
}
.pos-chip {
  width: 100%;
  padding: 0.55rem 0.75rem;
  border: 1px solid #e2e8f0;
  border-radius: 0.75rem;
  background: #f8fafc;
  font-size: 0.8125rem;
  font-weight: 600;
  color: #334155;
  cursor: pointer;
  text-align: left;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
.pos-chip:hover {
  border-color: color-mix(in srgb, var(--color-brand-500, #5c7f96) 40%, white);
  background: #fff;
}
.pos-footer__summary {
  font-size: 0.8rem;
  display: flex;
  flex-direction: column;
  justify-content: center;
  padding: 0.15rem 0.35rem;
}
.pos-footer__row {
  display: flex;
  justify-content: space-between;
  padding: 0.12rem 0;
  color: #334155;
}
.pos-footer__row--muted { color: #64748b; }
.pos-footer__total {
  display: flex;
  justify-content: space-between;
  align-items: baseline;
  margin-top: 0.25rem;
  padding-top: 0.35rem;
  border-top: 1px dashed #e2e8f0;
  font-weight: 750;
  font-size: 0.78rem;
  letter-spacing: 0.06em;
}
.pos-footer__total-amount {
  font-size: 1.45rem;
  letter-spacing: -0.03em;
  font-family: var(--font-mono);
  color: #0f172a;
}
.pos-footer__buttons {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 0.4rem;
}
.pos-btn {
  padding: 0.62rem 0.7rem;
  border-radius: 0.75rem;
  font-size: 0.8rem;
  font-weight: 700;
  cursor: pointer;
  border: none;
}
.pos-btn:disabled { opacity: 0.45; cursor: not-allowed; }
.pos-btn--outline {
  border: 1px solid #dbe3ea;
  background: #fff;
  color: #475569;
}
.pos-btn--outline:hover:not(:disabled) {
  background: #f8fafc;
}
.pos-btn--danger {
  border: 1px solid #fecaca;
  background: #fef2f2;
  color: #dc2626;
}
.pos-btn--danger:hover:not(:disabled) {
  background: #dc2626;
  border-color: #dc2626;
  color: #fff;
}
.pos-btn--pay {
  grid-column: 1 / -1;
  min-height: 3rem;
  background: var(--color-brand-600, #4a6d86);
  color: white;
  font-size: 1rem;
  letter-spacing: 0.04em;
  box-shadow: 0 10px 18px rgba(74, 109, 134, 0.22);
}
.pos-btn--pay:hover:not(:disabled) {
  filter: brightness(1.05);
}

@media (max-width: 760px) {
  .pos-footer {
    grid-template-columns: 1fr;
  }
}
.pos-modal-content {
  display: flex;
  flex-direction: column;
}
.pos-field {
  width: 100%;
  border: 1px solid #cbd5e1;
  border-radius: 0.5rem;
  padding: 0.5rem 0.75rem;
  margin-bottom: 0.75rem;
}
.pos-field--area { min-height: 5rem; resize: vertical; }
.pos-modal__list { display: flex; flex-direction: column; gap: 0.375rem; }
.pos-modal__item {
  display: flex;
  flex-direction: column;
  align-items: flex-start;
  padding: 0.625rem 0.75rem;
  border: 1px solid #e2e8f0;
  border-radius: 0.5rem;
  background: white;
  cursor: pointer;
  text-align: left;
  width: 100%;
}
.pos-modal__item span { font-size: 0.75rem; color: #64748b; }
.pos-modal__item--danger { color: #dc2626; border-color: #fecaca; }
.pos-modal__item--create { color: var(--color-brand-600, #4a6d86); border-color: #c5d4df; font-weight: 600; }
.pos-modal__tabs { display: flex; gap: 0.5rem; margin-bottom: 0.75rem; }
.pos-modal__tab {
  flex: 1;
  padding: 0.5rem;
  border: 1px solid #e2e8f0;
  border-radius: 0.5rem;
  background: #f8fafc;
  font-size: 0.8125rem;
  cursor: pointer;
}
.pos-modal__tab--active {
  background: var(--color-brand-600, #4a6d86);
  color: white;
  border-color: var(--color-brand-600, #4a6d86);
}
.pos-modal__empty { color: #94a3b8; text-align: center; padding: 1rem; }
.pos-modal__row { display: flex; gap: 1rem; margin-bottom: 0.75rem; font-size: 0.875rem; }
.pos-modal__actions { display: flex; gap: 0.5rem; justify-content: flex-end; }
.pos-held {
  display: flex;
  flex-direction: column;
  gap: 0.75rem;
  padding: 0.85rem;
  border: 1px solid #e2e8f0;
  border-radius: 0.75rem;
  margin-bottom: 0.75rem;
}
.pos-held__header {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 0.75rem;
}
.pos-held__date { margin: 0.125rem 0 0; font-size: 0.75rem; color: #94a3b8; }
.pos-held__meta { margin: 0.2rem 0 0; font-size: 0.75rem; color: #64748b; }
.pos-held__total { font-weight: 700; color: #4a6d86; white-space: nowrap; }
.pos-held__items {
  display: flex;
  flex-direction: column;
  gap: 0.4rem;
  padding: 0.6rem 0.7rem;
  border-radius: 0.6rem;
  background: #f8fafc;
}
.pos-held__items-title {
  margin: 0;
  font-size: 0.7rem;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.04em;
  color: #64748b;
}
.pos-held__item {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 0.75rem;
  font-size: 0.82rem;
}
.pos-held__item small {
  display: block;
  margin-top: 0.1rem;
  color: #94a3b8;
}
.pos-held__actions { display: flex; flex-wrap: wrap; gap: 0.375rem; }
.pos-payment-total {
  font-family: var(--font-mono);
  font-size: 1.5rem;
  font-weight: 700;
  text-align: center;
  margin: 0 0 1rem;
  color: var(--color-brand-600, #4a6d86);
}
.pos-label { display: block; font-size: 0.8125rem; margin-bottom: 0.25rem; }
.pos-change { font-size: 0.875rem; color: #16a34a; margin-top: 0.25rem; }
.pos-modal__methods {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 0.5rem;
  margin-bottom: 0.75rem;
}
.pos-method {
  display: flex;
  flex-direction: column;
  gap: 0.125rem;
  padding: 0.625rem 0.75rem;
  border: 1px solid #e2e8f0;
  border-radius: 0.5rem;
  background: #f8fafc;
  cursor: pointer;
  font-size: 0.875rem;
}
.pos-method--active {
  border-color: var(--color-brand-600, #4a6d86);
  background: #e4edf2;
}
.pos-method--disabled {
  opacity: 0.55;
  cursor: not-allowed;
}
.pos-method small { color: #b45309; font-size: 0.7rem; }
.pos-payment-error { color: #dc2626; font-size: 0.8125rem; margin: 0 0 0.5rem; }
.pos-mixed-summary {
  display: flex;
  justify-content: space-between;
  gap: 0.75rem;
  margin-bottom: 0.75rem;
  font-size: 0.875rem;
  color: #334155;
}
.pos-mixed-summary--ok { color: #16a34a; }
.pos-mixed-summary--warn { color: #b45309; }
.pos-mixed-line {
  display: grid;
  grid-template-columns: 1.4fr 1fr auto auto;
  gap: 0.375rem;
  margin-bottom: 0.5rem;
  align-items: start;
}
.pos-mixed-line > .pos-field {
  margin-bottom: 0;
}
.pos-mixed-tendered {
  grid-column: 1 / -1;
}
.pos-mixed-tendered .pos-field {
  margin-bottom: 0.25rem;
}
.pos-btn--icon {
  min-width: 2.25rem;
  padding: 0.5rem;
}
.pos-btn--block {
  width: 100%;
  margin-bottom: 0.75rem;
  justify-content: center;
}
</style>
