<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import { useRoute, useRouter } from 'vue-router'
import PageFrame from '../../../components/layout/PageFrame.vue'
import AppModal from '../../../components/ui/AppModal.vue'
import FieldLabel from '../../../components/ui/FieldLabel.vue'
import Badge from '../../../components/ui/Badge.vue'
import { useBackofficeStore } from '../../../stores/backoffice'
import { useContextStore } from '../../../stores/context'
import type { Company, Sale, SaleReturn, SaleTax } from '../../../types'
import { formatDate, formatMoney } from '../../../utils/format'
import { printSaleDocument, type SaleDocPayload } from '../../../utils/printSaleDocument'
import MergeOrdersModal from '../../../components/pos/MergeOrdersModal.vue'

const { t } = useI18n()
const route = useRoute()
const router = useRouter()
const store = useBackofficeStore()
const context = useContextStore()

const sale = ref<Sale | null>(null)
const company = ref<Company | null>(null)
const returns = ref<SaleReturn[]>([])
const loading = ref(true)
const loadError = ref<string | null>(null)
const docLoading = ref(false)
const showReturnModal = ref(false)
const showMerge = ref(false)
const saving = ref(false)
const returnReasons = ref<{ value: string; label: string }[]>([])
const returnForm = ref({
  reason: '',
  refund_method: 'cash',
  notes: '',
  items: [] as { sale_item_id: string; quantity: number; max: number; label: string }[],
})

const saleId = computed(() => route.params.id as string)
const currency = computed(() => sale.value?.currency)

const itemCount = computed(() =>
  sale.value?.items?.reduce((sum, item) => sum + item.quantity, 0) ?? 0,
)

const vatRegistered = computed(() => {
  const settings = company.value?.settings
  if (typeof settings?.vat_registered === 'boolean') return settings.vat_registered
  return Boolean(company.value?.tax_id)
})

const showVat = computed(() =>
  vatRegistered.value
  || (sale.value?.tax_total ?? 0) > 0
  || Boolean(sale.value?.taxes?.length),
)

const amountHt = computed(() => {
  if (!sale.value) return 0
  return Math.max(0, sale.value.total - (sale.value.tax_total ?? 0))
})

const taxBreakdown = computed(() => {
  const rows = sale.value?.taxes ?? []
  if (!rows.length) {
    if (!showVat.value || !sale.value) return []
    return [{
      key: 'default',
      tax_name: t('sales.tax'),
      tax_rate: null as number | null,
      taxable_amount: amountHt.value,
      tax_amount: sale.value.tax_total ?? 0,
    }]
  }

  const grouped = new Map<string, {
    key: string
    tax_name: string
    tax_rate: number | null
    taxable_amount: number
    tax_amount: number
  }>()

  for (const tax of rows) {
    const rate = normalizeRate(tax.tax_rate)
    const key = `${tax.tax_name ?? 'TVA'}|${rate ?? 'n/a'}`
    const existing = grouped.get(key)
    if (existing) {
      existing.taxable_amount += tax.taxable_amount ?? 0
      existing.tax_amount += tax.tax_amount ?? 0
    } else {
      grouped.set(key, {
        key,
        tax_name: tax.tax_name || t('sales.tax'),
        tax_rate: rate,
        taxable_amount: tax.taxable_amount ?? 0,
        tax_amount: tax.tax_amount ?? 0,
      })
    }
  }

  return [...grouped.values()]
})

onMounted(() => loadAll())

async function loadAll() {
  loading.value = true
  loadError.value = null
  try {
    if (!context.stores.length) await context.loadStores()
    sale.value = await store.loadSale(saleId.value)

    const companyId = context.currentStore?.branch?.company?.id
      ?? context.stores.find(s => s.id === sale.value?.store_id)?.branch?.company?.id
      ?? context.stores.find(s => s.branch?.company)?.branch?.company?.id

    if (companyId) {
      company.value = await store.loadCompanyDetail(companyId)
    } else {
      await store.loadCompanies()
      company.value = store.companies[0] ?? null
    }

    returns.value = await store.loadSaleReturns(saleId.value)
    returnReasons.value = await store.loadReturnReasons()
  } catch (error) {
    loadError.value = error instanceof Error ? error.message : t('sales.notFound')
    sale.value = null
  } finally {
    loading.value = false
  }
}

function normalizeRate(value: SaleTax['tax_rate']): number | null {
  if (value === null || value === undefined || value === '') return null
  const num = typeof value === 'number' ? value : Number(value)
  return Number.isFinite(num) ? num : null
}

function formatRate(value: number | string | null | undefined): string {
  const rate = normalizeRate(value)
  if (rate === null) return '—'
  return `${rate.toLocaleString('fr-FR', { maximumFractionDigits: 2 })} %`
}

function itemName(item: NonNullable<Sale['items']>[number]): string {
  return item.product_name
    ?? item.product?.name
    ?? item.product_variant?.name
    ?? '—'
}

function itemSku(item: NonNullable<Sale['items']>[number]): string {
  return item.product_sku
    ?? item.product?.sku
    ?? item.product_variant?.sku
    ?? '—'
}

function saleStatusLabel(status: string): string {
  const map: Record<string, string> = {
    completed: t('sales.statusCompleted'),
    voided: t('sales.statusVoided'),
    draft: t('sales.statusDraft'),
  }
  return map[status] ?? status
}

function paymentStatusLabel(status: string): string {
  const map: Record<string, string> = {
    paid: t('sales.statusPaid'),
    partial: t('sales.statusPartial'),
    on_credit: t('sales.statusOnCredit'),
  }
  return map[status] ?? status
}

function paymentStatusVariant(status: string): 'success' | 'warning' | 'brand' | 'neutral' {
  if (status === 'paid') return 'success'
  if (status === 'partial') return 'warning'
  if (status === 'on_credit') return 'brand'
  return 'neutral'
}

function paymentMethodLabel(method: string): string {
  const map: Record<string, string> = {
    cash: t('sales.methodCash'),
    card: t('sales.methodCard'),
    credit: t('sales.methodCredit'),
    mobile_money: t('sales.methodMobileMoney'),
    bank_transfer: t('sales.methodBankTransfer'),
    wallet: t('sales.methodWallet'),
  }
  return map[method] ?? method
}

function openReturnModal() {
  if (!sale.value?.items?.length) return
  returnForm.value = {
    reason: returnReasons.value[0]?.value ?? '',
    refund_method: 'cash',
    notes: '',
    items: sale.value.items.map(item => ({
      sale_item_id: item.id,
      quantity: 0,
      max: item.quantity_returnable ?? item.quantity,
      label: itemName(item),
    })),
  }
  showReturnModal.value = true
}

async function submitReturn() {
  const items = returnForm.value.items.filter(i => i.quantity > 0)
  if (!items.length) return
  saving.value = true
  try {
    await store.createSaleReturn(saleId.value, {
      reason: returnForm.value.reason,
      refund_method: returnForm.value.refund_method,
      notes: returnForm.value.notes || undefined,
      items: items.map(i => ({ sale_item_id: i.sale_item_id, quantity: i.quantity })),
    })
    showReturnModal.value = false
    await loadAll()
  } finally {
    saving.value = false
  }
}

function printSale() {
  window.print()
}

async function printReceipt() {
  if (!sale.value) return
  docLoading.value = true
  try {
    const payload = await store.loadSaleReceipt(sale.value.id, 'thermal_80') as SaleDocPayload
    printSaleDocument(payload, t('pointOfSale.orders.receipt'))
  } finally {
    docLoading.value = false
  }
}

async function printInvoice() {
  if (!sale.value) return
  docLoading.value = true
  try {
    const payload = await store.loadSaleInvoice(sale.value.id, 'a4') as SaleDocPayload
    printSaleDocument(payload, t('pointOfSale.orders.invoice'))
  } finally {
    docLoading.value = false
  }
}
</script>

<template>
  <PageFrame>
    <template #title>{{ sale?.reference ?? t('sales.detail') }}</template>
    <template #subtitle>{{ t('sales.invoiceTitle') }}</template>

    <div class="sale-detail space-y-6">
      <div class="no-print flex flex-wrap items-center justify-between gap-3">
        <button class="btn-secondary" type="button" @click="router.push({ name: 'pos-orders' })">
          ← {{ t('nav.posOrders') }}
        </button>
        <div class="flex flex-wrap gap-2">
          <button
            v-if="sale?.status === 'pending'"
            class="btn-secondary"
            type="button"
            @click="router.push({ name: 'pos', query: { sale: sale.id } })"
          >
            {{ t('pos.modify') }}
          </button>
          <button
            v-if="sale?.status === 'pending'"
            class="btn-secondary"
            type="button"
            @click="router.push({ name: 'pos', query: { sale: sale.id } })"
          >
            {{ t('pos.addArticles') }}
          </button>
          <button
            v-if="sale?.status === 'pending'"
            class="btn-secondary"
            type="button"
            @click="showMerge = true"
          >
            {{ t('pointOfSale.merge.action') }}
          </button>
          <button
            v-if="sale?.status === 'pending'"
            class="btn-primary"
            type="button"
            @click="router.push({ name: 'pos', query: { sale: sale.id, pay: '1' } })"
          >
            {{ t('pos.payHeld') }}
          </button>
          <button v-if="sale?.status === 'completed'" class="btn-secondary" type="button" :disabled="!sale || docLoading" @click="printReceipt">
            {{ t('pointOfSale.orders.receipt') }}
          </button>
          <button v-if="sale?.status === 'completed'" class="btn-secondary" type="button" :disabled="!sale || docLoading" @click="printInvoice">
            {{ t('pointOfSale.orders.invoice') }}
          </button>
          <button v-if="sale?.status === 'completed'" class="btn-secondary" type="button" :disabled="!sale" @click="printSale">
            {{ t('sales.print') }}
          </button>
          <button
            v-if="sale?.status === 'completed'"
            class="btn-primary"
            type="button"
            @click="openReturnModal"
          >
            {{ t('sales.createReturn') }}
          </button>
        </div>
      </div>

      <div v-if="loading" class="rounded-2xl bg-white p-10 text-center text-slate-500 shadow-sm ring-1 ring-slate-200">
        {{ t('common.loading') }}
      </div>

      <div
        v-else-if="loadError || !sale"
        class="rounded-2xl bg-rose-50 p-8 text-center text-rose-700 ring-1 ring-rose-100"
      >
        {{ loadError ?? t('sales.notFound') }}
      </div>

      <template v-else>
        <section class="sale-hero overflow-hidden rounded-2xl bg-white shadow-sm ring-1 ring-slate-200">
          <div class="sale-hero__banner px-6 py-5 text-white sm:px-8">
            <div class="flex flex-wrap items-start justify-between gap-4">
              <div class="flex items-start gap-3">
                <img
                  v-if="company?.logo_url"
                  :src="company.logo_url"
                  :alt="company.name"
                  class="h-12 w-12 rounded-lg bg-white object-contain p-1"
                />
                <div>
                <p class="m-0 text-xs font-medium uppercase tracking-[0.18em] text-white/70">
                  {{ company?.name || t('sales.invoiceTitle') }}
                </p>
                <h2 class="mt-1 font-mono text-2xl font-bold tracking-tight sm:text-3xl">
                  {{ sale.reference }}
                </h2>
                <p class="mt-2 m-0 text-sm text-white/80">
                  {{ formatDate(sale.completed_at ?? sale.created_at) }}
                  · {{ t('sales.itemCount', { count: itemCount }) }}
                </p>
                <p v-if="showVat && company?.tax_id" class="mt-2 m-0 text-sm text-white/90">
                  {{ t('sales.companyTaxId') }} : <span class="font-mono">{{ company.tax_id }}</span>
                </p>
                <p v-else-if="!showVat" class="mt-2 m-0 text-xs text-white/60">
                  {{ t('sales.vatExempt') }}
                </p>
                </div>
              </div>
              <div class="flex flex-wrap gap-2">
                <Badge :variant="sale.status === 'completed' ? 'success' : (sale.status === 'merged' ? 'brand' : 'neutral')">
                  {{ saleStatusLabel(sale.status) }}
                </Badge>
                <Badge :variant="paymentStatusVariant(sale.payment_status)">
                  {{ paymentStatusLabel(sale.payment_status) }}
                </Badge>
              </div>
            </div>
            <p v-if="sale.status === 'merged' && sale.merged_into" class="mt-3 m-0 text-sm text-white/85">
              {{ t('pointOfSale.merge.action') }} → {{ sale.merged_into.reference }}
            </p>
          </div>

          <div class="grid gap-0 lg:grid-cols-[1.2fr_0.8fr]">
            <div class="space-y-5 border-b border-slate-100 p-6 sm:p-8 lg:border-b-0 lg:border-r">
              <div class="grid gap-5 sm:grid-cols-2">
                <div>
                  <p class="meta-label">{{ t('sales.customer') }}</p>
                  <p class="meta-value">
                    <button
                      v-if="sale.customer?.id"
                      type="button"
                      class="text-brand-600"
                      @click="router.push({ name: 'customer-detail', params: { id: sale.customer.id } })"
                    >
                      {{ sale.customer.name }}
                    </button>
                    <template v-else>{{ t('sales.walkIn') }}</template>
                  </p>
                  <p v-if="sale.customer?.email" class="meta-sub">{{ sale.customer.email }}</p>
                </div>
                <div>
                  <p class="meta-label">{{ t('sales.cashier') }}</p>
                  <p class="meta-value">{{ sale.processed_by?.name ?? '—' }}</p>
                </div>
                <div>
                  <p class="meta-label">{{ t('sales.transaction') }}</p>
                  <p class="meta-value font-mono text-sm">
                    {{ sale.payment_transaction_number ?? '—' }}
                  </p>
                </div>
                <div>
                  <p class="meta-label">{{ t('sales.dueDate') }}</p>
                  <p class="meta-value">{{ formatDate(sale.due_date) }}</p>
                </div>
              </div>

              <div v-if="sale.notes" class="rounded-xl bg-slate-50 px-4 py-3 ring-1 ring-slate-100">
                <p class="meta-label">{{ t('sales.notes') }}</p>
                <p class="mt-1 m-0 text-sm text-slate-700 whitespace-pre-wrap">{{ sale.notes }}</p>
              </div>
            </div>

            <div class="bg-slate-50/80 p-6 sm:p-8">
              <p class="meta-label mb-4">{{ t('sales.summary') }}</p>
              <dl class="space-y-2.5 text-sm">
                <template v-if="showVat">
                  <div class="summary-row">
                    <dt>{{ t('sales.subtotal') }}</dt>
                    <dd>{{ formatMoney(sale.subtotal, currency) }}</dd>
                  </div>
                  <div v-if="sale.discount_total" class="summary-row text-emerald-700">
                    <dt>{{ t('sales.discount') }}</dt>
                    <dd>− {{ formatMoney(sale.discount_total, currency) }}</dd>
                  </div>
                  <div class="summary-row">
                    <dt>{{ t('sales.subtotalHt') }}</dt>
                    <dd>{{ formatMoney(amountHt, currency) }}</dd>
                  </div>
                  <div
                    v-for="tax in taxBreakdown"
                    :key="tax.key"
                    class="summary-row"
                  >
                    <dt>
                      {{ tax.tax_name }}
                      <span v-if="tax.tax_rate !== null" class="text-slate-400">
                        ({{ formatRate(tax.tax_rate) }})
                      </span>
                    </dt>
                    <dd>{{ formatMoney(tax.tax_amount, currency) }}</dd>
                  </div>
                  <div v-if="sale.fees_total" class="summary-row">
                    <dt>{{ t('sales.fees') }}</dt>
                    <dd>{{ formatMoney(sale.fees_total, currency) }}</dd>
                  </div>
                  <div class="summary-row summary-row--total">
                    <dt>{{ t('sales.grandTotal') }}</dt>
                    <dd>{{ formatMoney(sale.total, currency) }}</dd>
                  </div>
                </template>
                <template v-else>
                  <div class="summary-row">
                    <dt>{{ t('sales.subtotal') }}</dt>
                    <dd>{{ formatMoney(sale.subtotal, currency) }}</dd>
                  </div>
                  <div v-if="sale.discount_total" class="summary-row text-emerald-700">
                    <dt>{{ t('sales.discount') }}</dt>
                    <dd>− {{ formatMoney(sale.discount_total, currency) }}</dd>
                  </div>
                  <div v-if="sale.tax_total" class="summary-row">
                    <dt>{{ t('sales.tax') }}</dt>
                    <dd>{{ formatMoney(sale.tax_total, currency) }}</dd>
                  </div>
                  <div v-if="sale.fees_total" class="summary-row">
                    <dt>{{ t('sales.fees') }}</dt>
                    <dd>{{ formatMoney(sale.fees_total, currency) }}</dd>
                  </div>
                  <div class="summary-row summary-row--total">
                    <dt>{{ t('sales.amountTtc') }}</dt>
                    <dd>{{ formatMoney(sale.total, currency) }}</dd>
                  </div>
                </template>
                <div class="summary-row">
                  <dt>{{ t('sales.paid') }}</dt>
                  <dd class="text-emerald-700">{{ formatMoney(sale.paid_amount, currency) }}</dd>
                </div>
                <div class="summary-row">
                  <dt>{{ t('sales.outstanding') }}</dt>
                  <dd :class="(sale.outstanding_amount ?? 0) > 0 ? 'text-amber-700' : ''">
                    {{ formatMoney(sale.outstanding_amount ?? 0, currency) }}
                  </dd>
                </div>
              </dl>
            </div>
          </div>
        </section>

        <section class="overflow-hidden rounded-2xl bg-white shadow-sm ring-1 ring-slate-200">
          <div class="flex items-center justify-between border-b border-slate-100 px-5 py-3.5">
            <h3 class="m-0 text-sm font-semibold text-slate-800">{{ t('sales.items') }}</h3>
            <span class="rounded-full bg-slate-100 px-2.5 py-0.5 text-xs font-medium text-slate-600">
              {{ sale.items?.length ?? 0 }}
            </span>
          </div>
          <div class="overflow-x-auto">
            <table class="min-w-full divide-y divide-slate-200 text-sm">
              <thead class="bg-slate-50 text-slate-600">
                <tr>
                  <th class="px-5 py-3 text-left font-medium">{{ t('sales.sku') }}</th>
                  <th class="px-5 py-3 text-left font-medium">{{ t('products.name') }}</th>
                  <th class="px-5 py-3 text-right font-medium">{{ t('sales.qty') }}</th>
                  <th class="px-5 py-3 text-right font-medium">{{ t('sales.unitPrice') }}</th>
                  <th v-if="showVat" class="px-5 py-3 text-right font-medium">{{ t('sales.taxRate') }}</th>
                  <th v-if="showVat" class="px-5 py-3 text-right font-medium">{{ t('sales.lineTax') }}</th>
                  <th class="px-5 py-3 text-right font-medium">
                    {{ showVat ? t('sales.amountTtc') : t('sales.lineTotal') }}
                  </th>
                </tr>
              </thead>
              <tbody class="divide-y divide-slate-100">
                <tr v-for="item in sale.items" :key="item.id" class="hover:bg-slate-50/70">
                  <td class="px-5 py-3 font-mono text-xs text-slate-500">{{ itemSku(item) }}</td>
                  <td class="px-5 py-3 font-medium text-slate-900">{{ itemName(item) }}</td>
                  <td class="px-5 py-3 text-right tabular-nums">{{ item.quantity }}</td>
                  <td class="px-5 py-3 text-right tabular-nums">{{ formatMoney(item.unit_price, currency) }}</td>
                  <td v-if="showVat" class="px-5 py-3 text-right tabular-nums text-slate-500">
                    {{ formatRate(item.tax_rate) }}
                  </td>
                  <td v-if="showVat" class="px-5 py-3 text-right tabular-nums text-slate-500">
                    {{ formatMoney(item.line_tax ?? 0, currency) }}
                  </td>
                  <td class="px-5 py-3 text-right font-semibold tabular-nums">
                    {{ formatMoney(item.line_total, currency) }}
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </section>

        <section
          v-if="showVat"
          class="overflow-hidden rounded-2xl bg-white shadow-sm ring-1 ring-slate-200"
        >
          <div class="border-b border-slate-100 px-5 py-3.5">
            <h3 class="m-0 text-sm font-semibold text-slate-800">{{ t('sales.taxDetail') }}</h3>
          </div>
          <table class="min-w-full divide-y divide-slate-200 text-sm">
            <thead class="bg-slate-50 text-slate-600">
              <tr>
                <th class="px-5 py-3 text-left font-medium">{{ t('sales.tax') }}</th>
                <th class="px-5 py-3 text-right font-medium">{{ t('sales.taxRate') }}</th>
                <th class="px-5 py-3 text-right font-medium">{{ t('sales.taxBase') }}</th>
                <th class="px-5 py-3 text-right font-medium">{{ t('sales.taxAmount') }}</th>
              </tr>
            </thead>
            <tbody class="divide-y divide-slate-100">
              <tr v-for="tax in taxBreakdown" :key="tax.key">
                <td class="px-5 py-3 font-medium">{{ tax.tax_name }}</td>
                <td class="px-5 py-3 text-right tabular-nums">{{ formatRate(tax.tax_rate) }}</td>
                <td class="px-5 py-3 text-right tabular-nums">{{ formatMoney(tax.taxable_amount, currency) }}</td>
                <td class="px-5 py-3 text-right font-semibold tabular-nums">
                  {{ formatMoney(tax.tax_amount, currency) }}
                </td>
              </tr>
            </tbody>
            <tfoot class="bg-slate-50">
              <tr>
                <td class="px-5 py-3 font-semibold" colspan="2">{{ t('sales.tax') }}</td>
                <td class="px-5 py-3 text-right font-semibold tabular-nums">
                  {{ formatMoney(amountHt, currency) }}
                </td>
                <td class="px-5 py-3 text-right font-semibold tabular-nums">
                  {{ formatMoney(sale.tax_total ?? 0, currency) }}
                </td>
              </tr>
            </tfoot>
          </table>
        </section>

        <div class="grid gap-6 lg:grid-cols-2">
          <section class="overflow-hidden rounded-2xl bg-white shadow-sm ring-1 ring-slate-200">
            <div class="border-b border-slate-100 px-5 py-3.5">
              <h3 class="m-0 text-sm font-semibold text-slate-800">{{ t('sales.payments') }}</h3>
            </div>
            <table v-if="sale.payments?.length" class="min-w-full divide-y divide-slate-200 text-sm">
              <thead class="bg-slate-50 text-slate-600">
                <tr>
                  <th class="px-5 py-3 text-left font-medium">{{ t('sales.paymentMethod') }}</th>
                  <th class="px-5 py-3 text-left font-medium">{{ t('sales.transaction') }}</th>
                  <th class="px-5 py-3 text-right font-medium">{{ t('products.price') }}</th>
                </tr>
              </thead>
              <tbody class="divide-y divide-slate-100">
                <tr v-for="payment in sale.payments" :key="payment.id">
                  <td class="px-5 py-3">
                    <Badge variant="brand">{{ paymentMethodLabel(payment.payment_method) }}</Badge>
                  </td>
                  <td class="px-5 py-3 font-mono text-xs text-slate-500">
                    {{ payment.payment_transaction?.transaction_number ?? '—' }}
                  </td>
                  <td class="px-5 py-3 text-right font-semibold tabular-nums">
                    {{ formatMoney(payment.amount, payment.currency ?? currency) }}
                  </td>
                </tr>
              </tbody>
            </table>
            <p v-else class="px-5 py-8 text-center text-slate-500">—</p>
          </section>

          <section
            v-if="sale.installments?.length"
            class="overflow-hidden rounded-2xl bg-white shadow-sm ring-1 ring-slate-200"
          >
            <div class="border-b border-slate-100 px-5 py-3.5">
              <h3 class="m-0 text-sm font-semibold text-slate-800">{{ t('sales.installments') }}</h3>
            </div>
            <table class="min-w-full divide-y divide-slate-200 text-sm">
              <thead class="bg-slate-50 text-slate-600">
                <tr>
                  <th class="px-5 py-3 text-left font-medium">{{ t('sales.installmentNumber') }}</th>
                  <th class="px-5 py-3 text-left font-medium">{{ t('sales.dueDate') }}</th>
                  <th class="px-5 py-3 text-left font-medium">{{ t('sales.status') }}</th>
                  <th class="px-5 py-3 text-right font-medium">{{ t('products.price') }}</th>
                </tr>
              </thead>
              <tbody class="divide-y divide-slate-100">
                <tr v-for="row in sale.installments" :key="row.id">
                  <td class="px-5 py-3 font-mono">#{{ row.installment_number }}</td>
                  <td class="px-5 py-3">{{ formatDate(row.due_date) }}</td>
                  <td class="px-5 py-3">
                    <Badge :variant="row.status === 'paid' ? 'success' : row.status === 'overdue' ? 'warning' : 'neutral'">
                      {{ row.status }}
                    </Badge>
                  </td>
                  <td class="px-5 py-3 text-right tabular-nums">
                    {{ formatMoney(row.amount, currency) }}
                  </td>
                </tr>
              </tbody>
            </table>
          </section>
        </div>

        <section
          v-if="returns.length"
          class="overflow-hidden rounded-2xl bg-white shadow-sm ring-1 ring-slate-200"
        >
          <div class="border-b border-slate-100 px-5 py-3.5">
            <h3 class="m-0 text-sm font-semibold text-slate-800">{{ t('sales.tabs.returns') }}</h3>
          </div>
          <table class="min-w-full divide-y divide-slate-200 text-sm">
            <thead class="bg-slate-50 text-slate-600">
              <tr>
                <th class="px-5 py-3 text-left font-medium">#</th>
                <th class="px-5 py-3 text-left font-medium">{{ t('inventory.reason') }}</th>
                <th class="px-5 py-3 text-left font-medium">{{ t('sales.status') }}</th>
                <th class="px-5 py-3 text-right font-medium">{{ t('products.price') }}</th>
                <th class="px-5 py-3 text-left font-medium">{{ t('inventory.date') }}</th>
              </tr>
            </thead>
            <tbody class="divide-y divide-slate-100">
              <tr v-for="row in returns" :key="row.id">
                <td class="px-5 py-3 font-mono">{{ row.return_number }}</td>
                <td class="px-5 py-3">{{ row.reason }}</td>
                <td class="px-5 py-3">
                  <Badge :variant="row.status === 'completed' ? 'success' : 'neutral'">
                    {{ row.status }}
                  </Badge>
                </td>
                <td class="px-5 py-3 text-right tabular-nums">{{ formatMoney(row.total, currency) }}</td>
                <td class="px-5 py-3 text-slate-500">{{ formatDate(row.created_at) }}</td>
              </tr>
            </tbody>
          </table>
        </section>
      </template>
    </div>

    <AppModal
      :open="showReturnModal"
      :title="t('sales.createReturn')"
      icon="receipt"
      tone="warning"
      size="xl"
      @close="showReturnModal = false"
    >
      <form class="space-y-3 no-print" @submit.prevent="submitReturn">
        <div>
          <FieldLabel icon="note">{{ t('inventory.reason') }}</FieldLabel>
          <select v-model="returnForm.reason" required class="field">
            <option v-for="r in returnReasons" :key="r.value" :value="r.value">{{ r.label }}</option>
          </select>
        </div>
        <div>
          <FieldLabel icon="card">{{ t('sales.refundMethod') }}</FieldLabel>
          <select v-model="returnForm.refund_method" class="field">
            <option value="cash">{{ t('sales.methodCash') }}</option>
            <option value="card">{{ t('sales.methodCard') }}</option>
            <option value="mobile_money">Mobile Money</option>
            <option value="bank_transfer">{{ t('sales.methodBankTransfer') }}</option>
            <option value="credit">{{ t('sales.refundStoreCredit') }}</option>
            <option value="original">{{ t('sales.refundOriginal') }}</option>
          </select>
        </div>
        <div class="space-y-2">
          <p class="text-sm font-medium">{{ t('sales.items') }}</p>
          <p class="text-xs text-slate-500">{{ t('pos.stockCorrected') }} · {{ t('pos.partialHint') }}</p>
          <div v-for="item in returnForm.items" :key="item.sale_item_id" class="flex items-center gap-3">
            <span class="flex-1 truncate text-sm">{{ item.label }}</span>
            <input
              v-model.number="item.quantity"
              type="number"
              min="0"
              :max="item.max"
              class="field w-20"
            />
            <span class="text-xs text-slate-500">/ {{ item.max }}</span>
          </div>
        </div>
        <div class="app-modal__actions">
          <button type="button" class="btn-secondary" @click="showReturnModal = false">{{ t('common.cancel') }}</button>
          <button type="submit" class="btn-primary" :disabled="saving">{{ t('common.save') }}</button>
        </div>
      </form>
    </AppModal>

    <MergeOrdersModal
      :open="showMerge && sale?.status === 'pending'"
      :sale="sale ? {
        id: sale.id,
        reference: sale.reference,
        total: sale.total,
        currency: sale.currency,
        customer: sale.customer ?? null,
        table: (sale as Sale & { table?: { id: string; name: string } | null }).table ?? null,
      } : null"
      @close="showMerge = false"
      @merged="async () => { showMerge = false; await loadAll() }"
    />
  </PageFrame>
</template>

<style scoped>
.sale-hero__banner {
  background: #0f172a;
}

.meta-label {
  margin: 0;
  font-size: 0.7rem;
  font-weight: 600;
  letter-spacing: 0.06em;
  text-transform: uppercase;
  color: #64748b;
}

.meta-value {
  margin: 0.35rem 0 0;
  font-size: 0.95rem;
  font-weight: 600;
  color: #0f172a;
}

.meta-sub {
  margin: 0.15rem 0 0;
  font-size: 0.8rem;
  color: #64748b;
}

.summary-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 1rem;
  color: #475569;
}

.summary-row dd {
  margin: 0;
  font-weight: 600;
  font-variant-numeric: tabular-nums;
  color: #0f172a;
}

.summary-row--total {
  margin-top: 0.35rem;
  padding-top: 0.75rem;
  border-top: 1px solid #e2e8f0;
  font-size: 1rem;
  color: #0f172a;
}

.summary-row--total dt,
.summary-row--total dd {
  font-weight: 700;
  font-size: 1.05rem;
}

.field {
  width: 100%;
  border-radius: 0.5rem;
  border: 1px solid #cbd5e1;
  padding: 0.5rem 0.75rem;
}

.btn-primary {
  border-radius: 0.5rem;
  padding: 0.5rem 1rem;
  font-weight: 500;
  color: white;
  background-color: var(--color-brand-600);
}

.btn-secondary {
  border-radius: 0.5rem;
  border: 1px solid #cbd5e1;
  padding: 0.5rem 1rem;
  background: white;
}

@media print {
  .no-print {
    display: none !important;
  }

  .sale-detail {
    padding: 0;
  }

  .sale-hero,
  section {
    box-shadow: none !important;
    break-inside: avoid;
  }
}
</style>
