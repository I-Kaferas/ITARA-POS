<script setup lang="ts">
import { computed, onBeforeUnmount, ref } from 'vue'
import { debounceFn } from '../../composables/useLiveSearch'
import { useI18n } from 'vue-i18n'
import { api } from '../../api/client'
import AppIcon from '../ui/AppIcon.vue'
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
  /** Compact column layout for the Current Order sidebar */
  compact?: boolean
  /** Hide customer chip when customer UI lives in the cart panel */
  hideCustomerChip?: boolean
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
  pay: [payments: PosPaymentLine[], done: (result: { success: boolean; message?: string }) => void]
}>()

const { locale, t } = useI18n()
const pos = usePosStore()

const showCustomer = ref(false)
const showDiscount = ref(false)
const showNote = ref(false)
const showHeld = ref(false)
const showPayment = ref(false)
const showStay = ref(false)
const stayQuery = ref('')
const stayLoading = ref(false)
const stayError = ref('')
const stayRows = ref<Array<Record<string, string>>>([])
const stayId = ref('')
const paying = ref(false)

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
const paymentCurrency = ref(props.totals.currency)
const tenderedInput = ref('')
const paymentError = ref('')
const mixedLines = ref<{ method: string; amountInput: string; tenderedInput: string; currency: string }[]>([])
const paymentCurrencies = computed(() => {
  const list = pos.currencies?.length ? pos.currencies : [{ code: props.totals.currency }]
  return list
})

function currencyMeta(code: string) {
  const row = paymentCurrencies.value.find(c => c.code === code) as {
    exchange_rate?: number
    decimal_places?: number
  } | undefined
  return {
    rate: Number(row?.exchange_rate ?? 1) || 1,
    decimals: row?.decimal_places ?? (code === 'FBU' ? 0 : 2),
  }
}

/** Convert minor units between currencies using live POS rates (same semantics as backend). */
function convertAmount(amount: number, from: string, to: string) {
  if (!from || !to || from === to || amount === 0) return amount
  const src = currencyMeta(from)
  const dst = currencyMeta(to)
  if (src.rate <= 0 || dst.rate <= 0) return amount
  const scale = dst.decimals - src.decimals
  return Math.round(amount * src.rate / dst.rate * (10 ** scale))
}

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
  const source = props.paymentMethods?.length
    ? props.paymentMethods
    : pos.availablePaymentMethods.length
      ? pos.availablePaymentMethods
      : null
  const list = source
    ? withMobileMoney(source)
    : [
    { value: 'cash', label: props.labels.cash, label_fr: props.labels.cash, requires_customer: false, supports_change: true },
    { value: 'mobile_money', label: 'Mobile Money', label_fr: 'Mobile Money', requires_customer: false, supports_change: false },
    { value: 'card', label: props.labels.card, label_fr: props.labels.card, requires_customer: false, supports_change: false },
    { value: 'bank_transfer', label: 'Bank', label_fr: 'Banque', requires_customer: false, supports_change: false },
    { value: 'credit', label: 'Crédit', label_fr: 'Crédit', requires_customer: true, supports_change: false },
  ] as PosPaymentMethod[]
  return list.filter(method => method.value !== 'room')
})

const selectedMethod = computed(() => methods.value.find(m => m.value === paymentMethod.value) ?? null)
const supportsChange = computed(() => selectedMethod.value?.supports_change ?? paymentMethod.value === 'cash')

const mixedPaid = computed(() =>
  mixedLines.value.reduce((sum, line) => {
    const amount = parseMoneyInput(line.amountInput)
    return sum + convertAmount(amount, line.currency || props.totals.currency, props.totals.currency)
  }, 0),
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
const paymentDue = computed(() =>
  convertAmount(props.totals.grand_total, props.totals.currency, paymentCurrency.value || props.totals.currency),
)
const tenderedChange = computed(() => {
  if (!supportsChange.value) return 0
  const received = parseMoneyInput(tenderedInput.value)
  return received > paymentDue.value ? received - paymentDue.value : 0
})
const paymentSubtitle = computed(() => props.customer?.name || t('pos.paymentHint'))

function methodLabel(method: PosPaymentMethod) {
  return locale.value === 'fr' ? (method.label_fr || method.label) : method.label
}

function methodIcon(value: string) {
  const key = value.toLowerCase()
  if (key.includes('cash') || key.includes('espece')) return 'coins'
  if (key.includes('card')) return 'card'
  if (key.includes('mobile') || key.includes('momo') || key.includes('phone')) return 'phone'
  if (key.includes('bank') || key.includes('transfer') || key.includes('virement')) return 'transfer'
  if (key.includes('credit') || key.includes('wallet') || key.includes('house') || key.includes('account')) return 'customers'
  return 'coins'
}

function money(amount: number) {
  return formatMoney(amount, props.totals.currency)
}

function onPaymentCurrencyChange() {
  const due = convertAmount(props.totals.grand_total, props.totals.currency, paymentCurrency.value || props.totals.currency)
  tenderedInput.value = amountInputFromCents(due)
}

function openPaymentModal() {
  if (props.isEmpty) return
  if (!props.customer) {
    paymentError.value = props.labels.customerRequired || 'Sélectionnez un client'
    showCustomer.value = true
    return
  }
  paymentCurrency.value = props.totals.currency
  showPayment.value = true
}

defineExpose({ openPaymentModal, openCustomerModal, openCreateCustomer })

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

const searchCustomersLive = debounceFn(searchCustomers, 280)
onBeforeUnmount(() => searchCustomersLive.cancel())

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
  showCustomer.value = true
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
    { method: cash?.value ?? 'cash', amountInput: amountInputFromCents(firstAmount), tenderedInput: '', currency: props.totals.currency },
    { method: mobile?.value ?? 'mobile_money', amountInput: amountInputFromCents(total - firstAmount), tenderedInput: '', currency: props.totals.currency },
  ]
}

function openPayment() {
  paymentError.value = ''
  if (!props.customer) {
    showCustomer.value = true
    return
  }
  paymentMode.value = 'single'
  const first = firstAvailableMethod()
  paymentMethod.value = first?.value ?? 'cash'
  paymentCurrency.value = props.totals.currency
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
    currency: props.totals.currency,
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
  if (paying.value) return
  if (!props.customer) {
    paymentError.value = props.labels.customerRequired || 'Sélectionnez un client'
    showPayment.value = false
    showCustomer.value = true
    return
  }

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
    const saleCurrency = props.totals.currency
    const payCurrency = paymentCurrency.value || saleCurrency
    const amountInPayCurrency = convertAmount(props.totals.grand_total, saleCurrency, payCurrency)
    const tendered = supportsChange.value
      ? parseMoneyInput(tenderedInput.value)
      : amountInPayCurrency
    if (supportsChange.value && tendered < amountInPayCurrency) {
      paymentError.value = 'Montant insuffisant'
      return
    }
    paying.value = true
    emit('pay', [{
      method: paymentMethod.value,
      amount: amountInPayCurrency,
      currency: payCurrency,
      tendered: supportsChange.value ? tendered : undefined,
    }], (result) => {
      paying.value = false
      if (!result.success) {
        paymentError.value = result.message || 'Paiement refusé'
        return
      }
      showPayment.value = false
    })
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
    const lineCurrency = line.currency || props.totals.currency
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
    payments.push({ method: line.method, amount, tendered, currency: lineCurrency })
  }

  if (mixedPaid.value !== props.totals.grand_total) {
    paymentError.value = `${props.labels.amountMismatch} (${money(mixedPaid.value)} / ${money(props.totals.grand_total)})`
    return
  }

  paying.value = true
  emit('pay', payments, (result) => {
    paying.value = false
    if (!result.success) {
      paymentError.value = result.message || 'Paiement refusé'
      return
    }
    showPayment.value = false
  })
}

const filteredStays = computed(() => {
  const q = stayQuery.value.trim().toLowerCase()
  if (!q) return stayRows.value
  return stayRows.value.filter(row =>
    `${row.guest_name} ${row.room_number} ${row.store_name}`.toLowerCase().includes(q),
  )
})

const selectedStay = computed(() => stayRows.value.find(row => row.key === stayId.value) ?? null)

async function openStayCharge() {
  if (!props.customer) {
    paymentError.value = props.labels.customerRequired || 'Sélectionnez un client'
    showCustomer.value = true
    return
  }
  showStay.value = true
  stayError.value = ''
  stayLoading.value = true
  try {
    const stays = (await api.get<{ data: Array<Record<string, unknown>> }>('/hospitality/open-stays')).data
    stayRows.value = stays
      .map(stay => ({
        key: `${stay.store_id ?? ''}:${stay.id ?? ''}`,
        id: String(stay.id ?? ''),
        guest_name: String(stay.guest_name ?? ''),
        room_number: String(stay.room_number ?? ''),
        arrive_on: String(stay.arrive_on ?? ''),
        depart_on: String(stay.depart_on ?? ''),
        store_id: String(stay.store_id ?? ''),
        store_name: stay.same_store ? '' : String(stay.store_name ?? ''),
      }))
      .filter(row => row.id !== '')
    if (!stayRows.value.some(row => row.key === stayId.value)) {
      stayId.value = stayRows.value[0]?.key ?? ''
    }
  } catch (error) {
    stayRows.value = []
    stayError.value = error instanceof Error ? error.message : 'Séjours indisponibles'
  } finally {
    stayLoading.value = false
  }
}

function confirmStayCharge() {
  const stay = selectedStay.value
  if (!stay || paying.value) {
    stayError.value = 'Choisissez le séjour à facturer.'
    return
  }
  paying.value = true
  stayError.value = ''
  emit('pay', [{
    method: 'room',
    amount: props.totals.grand_total,
    currency: props.totals.currency,
    metadata: { reservation_id: stay.id, hotel_store_id: stay.store_id },
  }], (result) => {
    paying.value = false
    if (!result.success) {
      stayError.value = result.message || 'Imputation refusée'
      return
    }
    showStay.value = false
  })
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
  <footer class="pos-footer" :class="{ 'pos-footer--compact': compact }">
    <div class="pos-footer__actions">
      <button v-if="!hideCustomerChip" type="button" class="pos-chip" @click="openCustomerModal">
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
      <button type="button" class="pos-btn pos-btn--outline pos-btn--stay" :disabled="isEmpty || calculating || !customer" @click="openStayCharge">
        {{ t('desk.chargeStay') }}
      </button>
      <button type="button" class="pos-btn pos-btn--pay" :disabled="isEmpty || calculating || !customer" @click="openPayment">
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
            @input="searchCustomersLive"
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
    <AppModal
      :open="showPayment"
      :title="labels.payment"
      :subtitle="paymentSubtitle"
      icon="card"
      tone="success"
      size="md"
      @close="showPayment = false"
    >
      <div class="pay-sheet">
        <div class="pay-sheet__total">
          <div class="pay-sheet__row">
            <span>{{ labels.subtotal }}</span>
            <strong>{{ money(totals.subtotal) }}</strong>
          </div>
          <div class="pay-sheet__row pay-sheet__row--due">
            <span>{{ t('pos.amountDue') }}</span>
            <strong>{{ money(totals.grand_total) }}</strong>
          </div>
        </div>

        <p class="pay-sheet__label">{{ t('pos.paymentType') }}</p>
        <div class="pay-sheet__modes" role="tablist">
          <button
            type="button"
            class="pay-sheet__mode"
            :class="{ 'pay-sheet__mode--active': paymentMode === 'single' }"
            @click="setPaymentMode('single')"
          >
            {{ labels.paymentSingle || 'Simple' }}
          </button>
          <button
            type="button"
            class="pay-sheet__mode"
            :class="{ 'pay-sheet__mode--active': paymentMode === 'mixed' }"
            @click="setPaymentMode('mixed')"
          >
            {{ labels.paymentMixed || 'Mixte' }}
          </button>
        </div>

        <template v-if="paymentMode === 'single'">
          <p class="pay-sheet__label">{{ t('pos.paymentMethod') }}</p>
          <p v-if="!methods.length" class="pos-modal__empty">
            {{ labels.noPaymentMethods || 'Aucun mode de paiement configuré' }}
          </p>
          <div v-else class="pay-sheet__methods">
            <label
              v-for="method in methods"
              :key="method.value"
              class="pay-method"
              :class="{
                'pay-method--active': paymentMethod === method.value,
                'pay-method--disabled': method.requires_customer && !customer,
              }"
            >
              <input
                v-model="paymentMethod"
                class="pay-method__input"
                type="radio"
                :value="method.value"
                :disabled="method.requires_customer && !customer"
              />
              <AppIcon :name="methodIcon(method.value)" :size="18" />
              <span class="pay-method__text">
                <strong>{{ methodLabel(method) }}</strong>
                <small v-if="method.requires_customer && !customer">{{ labels.customerRequired || 'Client requis' }}</small>
              </span>
              <AppIcon v-if="paymentMethod === method.value" name="check" :size="16" />
            </label>
          </div>

          <template v-if="supportsChange">
            <p class="pay-sheet__label">{{ labels.tendered }} ({{ paymentCurrency || totals.currency }})</p>
            <input v-model="tenderedInput" class="pay-sheet__amount" inputmode="decimal" />
            <p v-if="tenderedChange > 0" class="pay-sheet__change">
              <AppIcon name="transfer" :size="16" />
              <span>{{ labels.change }}</span>
              <strong>{{ formatMoney(tenderedChange, paymentCurrency || totals.currency) }}</strong>
            </p>
          </template>

          <div v-if="paymentCurrencies.length > 1" class="pos-pay-currency">
            <label class="pos-label">{{ $t('org.payInCurrency') }}</label>
            <select v-model="paymentCurrency" class="pos-field" @change="onPaymentCurrencyChange">
              <option v-for="c in paymentCurrencies" :key="c.code" :value="c.code">{{ c.code }}</option>
            </select>
            <p v-if="paymentCurrency !== totals.currency" class="pos-fx-hint">
              {{ formatMoney(paymentDue, paymentCurrency) }}
              ≈ {{ money(totals.grand_total) }}
            </p>
          </div>
        </template>

        <template v-else>
          <div class="pay-sheet__stats">
            <div class="pay-sheet__stat" :class="{ 'pay-sheet__stat--ok': mixedRemaining === 0 }">
              <span>{{ labels.paid || 'Payé' }}</span>
              <strong>{{ money(mixedPaid) }}</strong>
            </div>
            <div class="pay-sheet__stat" :class="{ 'pay-sheet__stat--ok': mixedRemaining === 0 }">
              <span>{{ labels.remaining || 'Reste' }}</span>
              <strong>{{ money(mixedRemaining) }}</strong>
            </div>
          </div>

          <article v-for="(line, index) in mixedLines" :key="index" class="pay-mix">
            <div class="pay-mix__row">
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
              <input v-model="line.amountInput" class="pos-field" :placeholder="labels.amount" />
            </div>
            <div class="pay-mix__tools">
              <button type="button" class="pay-mix__fill" @click="fillRemaining(index)">
                = {{ labels.remaining || 'Reste' }}
              </button>
              <button
                type="button"
                class="pay-mix__remove"
                :disabled="mixedLines.length <= 2"
                :title="labels.removeLine || 'Retirer'"
                @click="removeMixedLine(index)"
              >
                <AppIcon name="trash" :size="16" />
              </button>
            </div>
            <label v-if="methodMeta(line.method)?.supports_change" class="pay-mix__tendered">
              <span>{{ labels.tendered }}</span>
              <input v-model="line.tenderedInput" class="pos-field" :placeholder="line.amountInput" />
            </label>
          </article>

          <button type="button" class="pay-sheet__add" @click="addMixedLine">
            <AppIcon name="plus" :size="16" />
            {{ labels.addPaymentLine || 'Ajouter un mode' }}
          </button>

          <p v-if="mixedChange > 0" class="pay-sheet__change">
            <AppIcon name="transfer" :size="16" />
            <span>{{ labels.change }}</span>
            <strong>{{ money(mixedChange) }}</strong>
          </p>
        </template>

        <p v-if="paymentError" class="pay-sheet__error">
          <AppIcon name="alert" :size="16" />
          <span>{{ paymentError }}</span>
        </p>
      </div>

      <template #footer>
        <div class="pay-sheet__footer">
          <button type="button" class="pos-btn pos-btn--outline" :disabled="paying" @click="showPayment = false">{{ labels.cancel }}</button>
          <button
            type="button"
            class="pos-btn pos-btn--pay"
            :disabled="paying || !methods.length || (paymentMode === 'mixed' && mixedRemaining !== 0)"
            @click="confirmPayment"
          >
            {{ paying ? '…' : labels.pay }}
          </button>
        </div>
      </template>
    </AppModal>

    <AppModal :open="showStay" :title="t('desk.chargeStay')" icon="card" tone="brand" size="md" @close="showStay = false">
      <div class="pos-modal-content">
        <p class="pos-payment-total">{{ money(totals.grand_total) }}</p>
        <input v-model="stayQuery" class="pos-field" :placeholder="t('desk.guest')" />
        <p v-if="stayLoading" class="pos-modal__empty">…</p>
        <div v-else class="pos-modal__methods">
          <label
            v-for="stay in filteredStays"
            :key="stay.key"
            class="pos-method"
            :class="{ 'pos-method--active': stayId === stay.key }"
          >
            <input v-model="stayId" type="radio" :value="stay.key" />
            <span>{{ stay.room_number }} · {{ stay.guest_name }}</span>
            <small>
              <template v-if="stay.store_name">{{ stay.store_name }} · </template>{{ stay.arrive_on }} – {{ stay.depart_on }}
            </small>
          </label>
        </div>
        <p v-if="!stayLoading && !filteredStays.length" class="pos-modal__empty">{{ t('desk.noOpenStay') }}</p>
        <p v-if="stayError" class="pos-payment-error">{{ stayError }}</p>
        <div class="pos-modal__actions">
          <button type="button" class="pos-btn pos-btn--outline" :disabled="paying" @click="showStay = false">{{ labels.cancel }}</button>
          <button type="button" class="pos-btn pos-btn--pay" :disabled="paying || !selectedStay" @click="confirmStayCharge">
            {{ paying ? '…' : t('desk.chargeStay') }}
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
  background: var(--color-surface);
  border-top: 1px solid #e7edf3;
  padding: 0.7rem 0.9rem;
  box-shadow: 0 -10px 28px rgba(15, 23, 42, 0.05);}
.pos-footer--compact {
  display: grid;
  grid-template-columns: auto minmax(0, 1fr);
  grid-template-areas:
    "actions summary"
    "buttons buttons";
  align-items: center;
  column-gap: 0.65rem;
  row-gap: 0.4rem;
  padding: 0.4rem 0.85rem 0.55rem;
  border-top: 1px solid var(--color-border, #e7edf3);
  background: var(--color-surface, #fff);
  box-shadow: none;
}
.pos-footer--compact .pos-footer__actions {
  grid-area: actions;
  display: flex;
  flex-direction: column;
  flex-wrap: nowrap;
  gap: 0.25rem;
}
.pos-footer--compact .pos-chip {
  width: auto;
  flex: 0 0 auto;
  min-width: 0;
  min-height: 0;
  padding: 0.22rem 0.55rem;
  border-radius: 999px;
  font-size: 0.7rem;
  line-height: 1.2;
  background: var(--color-canvas, #eef1f5);
}
.pos-footer--compact .pos-footer__summary {
  grid-area: summary;
  display: flex;
  flex-direction: column;
  gap: 0.08rem;
  padding: 0;
  font-size: 0.72rem;
  line-height: 1.2;
}
.pos-footer--compact .pos-footer__row,
.pos-footer--compact .pos-footer__total {
  width: 100%;
  display: flex;
  justify-content: space-between;
  gap: 0.5rem;
  margin: 0;
  padding: 0;
  border: 0;
  line-height: 1.2;
  font-size: 0.72rem;
}
.pos-footer--compact .pos-footer__total {
  margin-top: 0.1rem;
  padding-top: 0.2rem;
  border-top: 1px solid var(--color-border, #e7edf3);
  font-weight: 750;
  font-size: 0.78rem;
}
.pos-footer--compact .pos-footer__total-amount {
  font-size: 0.95rem;
  font-weight: 800;
  letter-spacing: -0.02em;
  color: var(--color-brand-600, #12243c);
}
.pos-footer--compact .pos-footer__buttons {
  grid-area: buttons;
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  gap: 0.3rem;
}
.pos-footer--compact .pos-btn {
  padding: 0.38rem 0.25rem;
  font-size: 0.7rem;
  border-radius: 8px;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
.pos-footer--compact .pos-btn--stay {
  grid-column: auto;
}
.pos-footer--compact .pos-btn--pay {
  grid-column: 1 / -1;
  min-height: 2.25rem;
  border: 0;
  border-radius: 10px;
  background: var(--color-accent, #e39b2b);
  color: #12243c;
  font-size: 0.88rem;
  font-weight: 800;
  letter-spacing: 0.01em;
  box-shadow: 0 6px 14px rgba(227, 155, 43, 0.22);
}
.pos-footer--compact .pos-btn--pay:hover:not(:disabled) {
  background: #d89020;
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
  background: var(--color-table-header);
  font-size: 0.8125rem;
  font-weight: 600;
  color: var(--color-text-secondary);
  cursor: pointer;
  text-align: left;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;}
.pos-chip:hover {
  border-color: color-mix(in srgb, var(--color-brand-500, var(--color-brand-500)) 40%, white);
  background: var(--color-surface);}
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
  color: var(--color-text-secondary);}
.pos-footer__row--muted { color: var(--color-text-muted);}
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
  color: var(--color-text-primary);}
.pos-footer__buttons {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 0.4rem;
}
.pos-btn {
  padding: 0.62rem 0.7rem;
  border-radius: var(--radius-lg);
  font-size: 0.8rem;
  font-weight: 600;
  cursor: pointer;
  border: 1px solid transparent;
  transition:
    background var(--motion-fast) var(--ease-out),
    border-color var(--motion-fast) var(--ease-out),
    color var(--motion-fast) var(--ease-out),
    box-shadow var(--motion-fast) var(--ease-out),
    transform var(--motion-spring) var(--ease-spring);
}
.pos-btn:disabled { opacity: 0.45; cursor: not-allowed; }
.pos-btn:active:not(:disabled) {
  transform: perspective(28rem) translate3d(0, 2px, 0) scale(0.96);
  transition-duration: var(--motion-sink);
  transition-timing-function: var(--ease-press);
}
.pos-btn--outline {
  border: 1px solid color-mix(in srgb, #fff 40%, #dbe3ea);
  background: color-mix(in srgb, var(--color-surface) 86%, transparent);
  color: var(--color-text-secondary);
  box-shadow: inset 0 1px 0 color-mix(in srgb, #fff 70%, transparent);
}
.pos-btn--outline:hover:not(:disabled) {
  background: color-mix(in srgb, var(--color-surface) 96%, transparent);
  box-shadow:
    inset 0 1px 0 #fff,
    0 6px 14px rgba(20, 32, 43, 0.06);
}
:global(html[data-theme="dark"]) .pos-btn--outline {
  border-color: color-mix(in srgb, #fff 14%, var(--color-border-strong, #3a4a5a));
  box-shadow: inset 0 1px 0 color-mix(in srgb, #fff 10%, transparent);
}
:global(html[data-theme="dark"]) .pos-btn--outline:hover:not(:disabled) {
  box-shadow:
    inset 0 1px 0 color-mix(in srgb, #fff 14%, transparent),
    0 6px 14px rgba(0, 0, 0, 0.22);
}
.pos-btn--danger {
  border: 1px solid #fecaca;
  background: var(--color-danger-bg);
  color: light-dark(#dc2626, #f0a4a4);}
.pos-btn--danger:hover:not(:disabled) {
  background: #dc2626;
  border-color: #dc2626;
  color: #fff;
}
.pos-btn--pay {
  grid-column: 1 / -1;
  min-height: 3rem;
  border-color: color-mix(in srgb, #fff 24%, var(--color-brand-700, #0f1f34));
  background-color: var(--color-brand-700, #0f1f34);
  background-image: none;
  color: white;
  font-size: 1rem;
  font-weight: 600;
  letter-spacing: 0.04em;
  box-shadow:
    inset 0 1px 0 color-mix(in srgb, #fff 32%, transparent),
    0 8px 18px rgba(15, 31, 52, 0.12);
}
.pos-btn--pay:hover:not(:disabled) {
  background-color: var(--color-brand-800, #0d1a2b);
  background-image: none;
}

@media (max-width: 1100px) {
  .pos-footer {
    grid-template-columns: minmax(0, 1fr) minmax(14rem, 0.9fr);
    grid-template-areas:
      "actions buttons"
      "summary buttons";
  }
  .pos-footer__actions { grid-area: actions; }
  .pos-footer__summary { grid-area: summary; }
  .pos-footer__buttons { grid-area: buttons; align-self: stretch; }
}
@media (max-width: 900px) {
  .pos-footer {
    display: grid;
    grid-template-columns: minmax(0, 1fr) auto;
    grid-template-areas:
      "actions total"
      "buttons buttons";
    gap: 0.4rem;
    padding: 0.45rem 0.65rem;
  }
  .pos-footer__actions {
    grid-area: actions;
    flex-direction: row;
  }
  .pos-chip {
    width: auto;
    flex: 1;
    min-width: 0;
    padding: 0.4rem 0.5rem;
    font-size: 0.75rem;
  }
  .pos-footer__summary {
    grid-area: total;
    justify-content: center;
    padding: 0 0.2rem;
  }
  .pos-footer__row {
    display: none;
  }
  .pos-footer__total {
    margin: 0;
    padding: 0;
    border: 0;
    gap: 0.45rem;
  }
  .pos-footer__total-amount {
    font-size: 1.15rem;
  }
  .pos-footer__buttons {
    grid-area: buttons;
    grid-template-columns: repeat(4, minmax(0, 1fr));
  }
  .pos-btn {
    padding: 0.48rem 0.35rem;
    font-size: 0.74rem;
  }
  .pos-btn--pay {
    grid-column: auto;
    min-height: 2.45rem;
    font-size: 0.86rem;
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
  background: var(--color-surface);
  cursor: pointer;
  text-align: left;
  width: 100%;}
.pos-modal__item span { font-size: 0.75rem; color: var(--color-text-muted);}
.pos-modal__item--danger { color: light-dark(#dc2626, #f0a4a4); border-color: #fecaca;}
.pos-modal__item--create { color: var(--color-ink-brand, var(--color-brand-600, var(--color-brand-600))); border-color: #c5d4df; font-weight: 600;}
.pos-modal__tabs {
  display: flex;
  gap: 2px;
  margin-bottom: 0.75rem;
  padding: 4px;
  border: 1px solid color-mix(in srgb, var(--color-border) 78%, transparent);
  border-radius: 12px;
  background: color-mix(in srgb, var(--color-surface) 72%, transparent);
  backdrop-filter: blur(12px);
}
.pos-modal__tab {
  flex: 1;
  padding: 0.45rem 0.7rem;
  border: 0;
  border-radius: 9px;
  background: transparent;
  color: var(--color-text-muted);
  font-size: 0.8125rem;
  font-weight: 500;
  white-space: nowrap;
  cursor: pointer;
  transition: background-color 180ms var(--ease-out), color 180ms var(--ease-out), box-shadow 180ms var(--ease-out);
}
.pos-modal__tab:hover { color: var(--color-text-primary); background: color-mix(in srgb, var(--color-canvas) 80%, transparent); }
.pos-modal__tab:focus-visible { outline: none; box-shadow: 0 0 0 2px var(--color-surface), 0 0 0 4px var(--color-focus-ring); }
.pos-modal__tab--active {
  background: color-mix(in srgb, var(--color-surface) 88%, var(--color-brand-50));
  color: var(--color-ink-brand, var(--color-brand-700));
  font-weight: 600;
  box-shadow: inset 0 1px 0 color-mix(in srgb, #fff 78%, transparent), 0 1px 2px rgba(20, 32, 43, 0.06);
}
.pos-modal__empty { color: var(--color-text-faint); text-align: center; padding: 1rem;}
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
.pos-held__date { margin: 0.125rem 0 0; font-size: 0.75rem; color: var(--color-text-faint);}
.pos-held__meta { margin: 0.2rem 0 0; font-size: 0.75rem; color: var(--color-text-muted);}
.pos-held__total { font-weight: 700; color: var(--color-ink-brand, var(--color-brand-600)); white-space: nowrap;}
.pos-held__items {
  display: flex;
  flex-direction: column;
  gap: 0.4rem;
  padding: 0.6rem 0.7rem;
  border-radius: 0.6rem;
  background: var(--color-table-header);}
.pos-held__items-title {
  margin: 0;
  font-size: 0.7rem;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.04em;
  color: var(--color-text-muted);}
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
  color: var(--color-text-faint);}
.pos-held__actions { display: flex; flex-wrap: wrap; gap: 0.375rem; }
.pos-payment-total {
  font-family: var(--font-mono);
  font-size: 1.5rem;
  font-weight: 700;
  text-align: center;
  margin: 0 0 1rem;
  color: var(--color-ink-brand, var(--color-brand-600, var(--color-brand-600)));}
.pos-label { display: block; font-size: 0.8125rem; margin-bottom: 0.25rem; }
.pos-change { font-size: 0.875rem; color: light-dark(#16a34a, #78ca96); margin-top: 0.25rem;}
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
  background: var(--color-table-header);
  cursor: pointer;
  font-size: 0.875rem;}
.pos-method--active {
  border-color: var(--color-brand-600, var(--color-brand-600));
  background: #e4edf2;
}
.pos-method--disabled {
  opacity: 0.55;
  cursor: not-allowed;
}
.pos-method small { color: light-dark(#b45309, #d49b70); font-size: 0.7rem;}
.pos-payment-error { color: light-dark(#dc2626, #f0a4a4); font-size: 0.8125rem; margin: 0 0 0.5rem;}
.pos-mixed-summary {
  display: flex;
  justify-content: space-between;
  gap: 0.75rem;
  margin-bottom: 0.75rem;
  font-size: 0.875rem;
  color: var(--color-text-secondary);}
.pos-mixed-summary--ok { color: light-dark(#16a34a, #78ca96);}
.pos-mixed-summary--warn { color: light-dark(#b45309, #d49b70);}
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

.pay-sheet { display: flex; flex-direction: column; gap: 0.5rem; }
.pay-sheet__total {
  display: grid;
  gap: 0.35rem;
  padding: 0.65rem 0.85rem;
  border: 1px solid var(--color-border);
  border-radius: 1rem;
  background: var(--color-surface-muted, var(--color-canvas));
}
.pay-sheet__row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 0.75rem;
  color: var(--color-text-muted);
  font-size: 0.84rem;
}
.pay-sheet__row strong { color: var(--color-text-primary); font-weight: 700; }
.pay-sheet__row--due {
  padding-top: 0.55rem;
  border-top: 1px solid var(--color-border);
  color: var(--color-text-primary);
  font-size: 0.95rem;
  font-weight: 800;
}
.pay-sheet__row--due strong {
  color: var(--color-accent, #e39b2b);
  font-size: 1.35rem;
  font-weight: 800;
}
.pay-sheet__label {
  margin: 0.15rem 0 0;
  color: var(--color-text-muted);
  font-size: 0.78rem;
  font-weight: 700;
}
.pay-sheet__modes {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 0.2rem;
  padding: 0.2rem;
  border: 1px solid var(--color-border);
  border-radius: 0.8rem;
  background: var(--color-surface-muted, var(--color-canvas));
}
.pay-sheet__mode {
  min-height: 2.4rem;
  border: 0;
  border-radius: 0.6rem;
  background: transparent;
  color: var(--color-text-muted);
  font-size: 0.8rem;
  font-weight: 700;
  cursor: pointer;
}
.pay-sheet__mode--active {
  background: var(--color-accent, #e39b2b);
  color: var(--color-brand-700, #0f1f34);
}
.pay-sheet__methods {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 0.5rem;
}
.pay-method {
  position: relative;
  display: flex;
  align-items: center;
  gap: 0.45rem;
  min-height: 2.65rem;
  padding: 0.45rem 0.65rem;
  border: 1px solid var(--color-border);
  border-radius: 0.75rem;
  background: var(--color-surface-muted, var(--color-canvas));
  color: var(--color-text-muted);
  cursor: pointer;
}
.pay-method__input { position: absolute; opacity: 0; pointer-events: none; }
.pay-method__text { display: grid; flex: 1; min-width: 0; }
.pay-method__text strong {
  color: var(--color-text-primary);
  font-size: 0.82rem;
  font-weight: 700;
}
.pay-method__text small { color: var(--color-warning, #b45309); font-size: 0.68rem; }
.pay-method--active {
  border-color: color-mix(in srgb, var(--color-accent, #e39b2b) 55%, var(--color-border));
  background: var(--color-surface);
  color: var(--color-accent, #e39b2b);
}
.pay-method--disabled { opacity: 0.45; cursor: not-allowed; }
.pay-sheet__amount {
  width: 100%;
  min-height: 2.75rem;
  border: 1px solid var(--color-border);
  border-radius: 0.9rem;
  background: var(--color-surface-muted, var(--color-canvas));
  color: var(--color-text-primary);
  font-size: 1.6rem;
  font-weight: 800;
  text-align: center;
}
.pay-sheet__amount:focus {
  outline: none;
  border-color: var(--color-accent, #e39b2b);
}
.pay-sheet__change,
.pay-sheet__error {
  display: flex;
  align-items: center;
  gap: 0.45rem;
  margin: 0;
  padding: 0.6rem 0.75rem;
  border-radius: 0.7rem;
  font-size: 0.8rem;
  font-weight: 650;
}
.pay-sheet__change {
  border: 1px solid color-mix(in srgb, var(--color-success) 25%, transparent);
  background: var(--color-success-bg);
  color: var(--color-success);
}
.pay-sheet__change strong { margin-left: auto; font-size: 0.9rem; }
.pay-sheet__error {
  border: 1px solid color-mix(in srgb, var(--color-danger) 25%, transparent);
  background: var(--color-danger-bg);
  color: var(--color-danger);
}
.pay-sheet__stats { display: grid; grid-template-columns: 1fr 1fr; gap: 0.5rem; }
.pay-sheet__stat {
  display: grid;
  gap: 0.1rem;
  padding: 0.6rem 0.7rem;
  border: 1px solid color-mix(in srgb, var(--color-warning, #b45309) 22%, transparent);
  border-radius: 0.75rem;
  background: var(--color-warning-bg, #fff7ed);
  color: var(--color-warning, #b45309);
}
.pay-sheet__stat span { font-size: 0.72rem; font-weight: 650; }
.pay-sheet__stat strong { font-size: 0.9rem; font-weight: 800; }
.pay-sheet__stat--ok {
  border-color: color-mix(in srgb, var(--color-success) 22%, transparent);
  background: var(--color-success-bg);
  color: var(--color-success);
}
.pay-mix {
  display: grid;
  gap: 0.35rem;
  padding: 0.7rem;
  border: 1px solid var(--color-border);
  border-radius: 0.9rem;
  background: var(--color-surface-muted, var(--color-canvas));
}
.pay-mix__row { display: grid; grid-template-columns: 1.2fr 0.8fr; gap: 0.45rem; }
.pay-mix__tools { display: flex; align-items: center; justify-content: space-between; }
.pay-mix__fill,
.pay-mix__remove,
.pay-sheet__add {
  border: 0;
  background: transparent;
  color: var(--color-accent, #e39b2b);
  font-weight: 700;
  cursor: pointer;
}
.pay-mix__remove { color: var(--color-text-muted); }
.pay-mix__remove:disabled { opacity: 0.35; cursor: not-allowed; }
.pay-mix__tendered { display: grid; gap: 0.25rem; font-size: 0.75rem; color: var(--color-text-muted); }
.pay-sheet__add {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: 0.35rem;
  min-height: 2.6rem;
  border: 1px solid var(--color-border);
  border-radius: 0.75rem;
  color: var(--color-text-primary);
}
.pay-sheet__footer {
  display: grid;
  grid-template-columns: 1fr 2fr;
  gap: 0.6rem;
  width: 100%;
}
.pay-sheet__footer .pos-btn { min-height: 3rem; justify-content: center; }
.pay-sheet__footer .pos-btn--pay { grid-column: auto; letter-spacing: 0.04em; }
@media (max-width: 640px) {
  .pay-sheet__methods { grid-template-columns: 1fr; }
}
</style>
