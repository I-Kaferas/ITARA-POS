<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import { useRoute, useRouter } from 'vue-router'
import PageFrame from '../../../components/layout/PageFrame.vue'
import StatusBadge from '../../../components/organization/StatusBadge.vue'
import AppModal from '../../../components/ui/AppModal.vue'
import FieldLabel from '../../../components/ui/FieldLabel.vue'
import { extractApiErrorMessage } from '../../../api/client'
import { useBackofficeStore } from '../../../stores/backoffice'
import type { PurchaseOrderDetail, PurchaseOrderInvoice } from '../../../types'
import { formatDate, formatMoney } from '../../../utils/format'
import { parseMoneyInput } from '../../../utils/money'

const { t } = useI18n()
const route = useRoute()
const router = useRouter()
const store = useBackofficeStore()

const order = ref<PurchaseOrderDetail | null>(null)
const receiveQty = ref<Record<string, number>>({})
const acting = ref(false)
const error = ref('')
const showPay = ref(false)
const paying = ref<PurchaseOrderInvoice | null>(null)
const payAmount = ref('')
const payMethod = ref('bank_transfer')
const payReference = ref('')

const orderId = computed(() => route.params.id as string)
const canReceive = computed(() => ['approved', 'partially_received'].includes(order.value?.status ?? ''))
const steps = computed(() => {
  const status = order.value?.status ?? 'draft'
  const received = (order.value?.goods_receipts?.length ?? 0) > 0
    || ['partially_received', 'received', 'completed'].includes(status)
  const invoiced = (order.value?.invoices?.length ?? 0) > 0
  const paid = status === 'completed' || (invoiced && (order.value?.invoices ?? []).every(invoice => invoice.paid_amount >= invoice.total))
  const current = paid ? 5 : invoiced ? 4 : received ? 3 : canReceive.value ? 1 : 0
  const keys = ['order', 'reception', 'stock', 'invoice', 'payment'] as const
  return keys.map((key, index) => ({ key, done: index < current, active: index === current }))
})

onMounted(() => load())

async function load() {
  error.value = ''
  order.value = await store.loadPurchaseOrder(orderId.value)
  if (order.value.warehouse_id) await store.loadStockBalances(order.value.warehouse_id)
  const next: Record<string, number> = {}
  for (const item of order.value.items ?? []) {
    next[item.id] = item.remaining ?? Math.max(0, (item.quantity_ordered ?? item.quantity) - (item.quantity_received ?? 0))
  }
  receiveQty.value = next
}

async function confirm() {
  acting.value = true
  error.value = ''
  try {
    await store.confirmPurchaseOrderStep(orderId.value)
    await load()
    await store.loadPurchaseOrders()
  } catch (err) {
    error.value = extractApiErrorMessage(err)
  } finally {
    acting.value = false
  }
}

async function cancel() {
  acting.value = true
  error.value = ''
  try {
    await store.cancelPurchaseOrder(orderId.value)
    await load()
    await store.loadPurchaseOrders()
  } catch (err) {
    error.value = extractApiErrorMessage(err)
  } finally {
    acting.value = false
  }
}

async function receive() {
  const items = (order.value?.items ?? [])
    .map(item => ({ purchase_order_item_id: item.id, quantity: Math.trunc(receiveQty.value[item.id] || 0) }))
    .filter(item => item.quantity > 0)
  if (!items.length) return
  acting.value = true
  error.value = ''
  try {
    await store.receivePurchaseOrder(orderId.value, { items })
    await load()
    await store.loadPurchaseOrders()
    await store.loadPurchaseInvoices()
  } catch (err) {
    error.value = extractApiErrorMessage(err)
  } finally {
    acting.value = false
  }
}

function openPay(invoice: PurchaseOrderInvoice) {
  paying.value = invoice
  payAmount.value = String(Math.max(0, invoice.total - invoice.paid_amount) / 100)
  payMethod.value = 'bank_transfer'
  payReference.value = ''
  showPay.value = true
}

async function submitPay() {
  if (!paying.value) return
  acting.value = true
  error.value = ''
  try {
    await store.recordPurchaseInvoicePayment(paying.value.id, {
      amount: parseMoneyInput(payAmount.value),
      payment_method: payMethod.value,
      reference: payReference.value || undefined,
    })
    showPay.value = false
    await load()
    await store.loadPurchaseInvoices()
  } catch (err) {
    error.value = extractApiErrorMessage(err)
  } finally {
    acting.value = false
  }
}

function orderStatusLabel(status: string): string {
  const map: Record<string, string> = {
    draft: t('inventory.statusDraft'),
    pending: t('inventory.statusPending'),
    approved: t('purchases.statuses.approved'),
    partially_received: t('purchases.statuses.partiallyReceived'),
    received: t('purchases.statuses.received'),
    completed: t('purchases.statuses.completed'),
    cancelled: t('purchases.statuses.cancelled'),
  }
  return map[status] ?? status
}

function ordered(item: { quantity: number; quantity_ordered?: number }) {
  return item.quantity_ordered ?? item.quantity
}

function received(item: { quantity_received?: number; received_quantity?: number }) {
  return item.quantity_received ?? item.received_quantity ?? 0
}

function onHand(productId?: string) {
  if (!productId) return null
  const row = store.stockBalances.find(balance => balance.product_id === productId)
  return row?.quantity_on_hand ?? null
}
</script>

<template>
  <PageFrame>
    <template #title>{{ order?.order_number ?? t('purchases.orderDetail') }}</template>
    <template #subtitle>{{ order?.supplier?.name }}</template>

    <div class="space-y-6">
      <div class="flex flex-wrap items-center justify-between gap-3">
        <button class="btn-secondary" @click="router.push({ name: 'purchase-orders' })">← {{ t('nav.purchases') }}</button>
        <div class="flex flex-wrap gap-2">
          <button v-if="order?.status === 'draft' || order?.status === 'pending'" class="btn-primary" :disabled="acting" @click="confirm">
            {{ order?.status === 'draft' ? t('purchases.submit') : t('purchases.approve') }}
          </button>
          <button
            v-if="order && !['cancelled', 'completed', 'received'].includes(order.status)"
            class="btn-danger"
            :disabled="acting"
            @click="cancel"
          >
            {{ t('purchases.cancel') }}
          </button>
        </div>
      </div>

      <ol class="grid gap-2 sm:grid-cols-5">
        <li
          v-for="step in steps"
          :key="step.key"
          class="rounded-lg px-3 py-2 text-sm"
          :class="step.done ? 'bg-emerald-50 text-emerald-800' : 'bg-slate-100 text-slate-500'"
        >
          <span class="font-medium">{{ t(`purchases.workflow.${step.key}`) }}</span>
        </li>
      </ol>
      <p class="m-0 text-xs text-slate-500">{{ t('purchases.workflowHint') }}</p>
      <p v-if="order?.requisition || order?.proforma" class="m-0 text-xs text-slate-500">
        {{ t('purchases.hub.origin') }}:
        <span v-if="order.requisition">{{ t('purchases.hub.requisitions') }} {{ order.requisition.number }}</span>
        <span v-if="order.requisition && order.proforma"> · </span>
        <span v-if="order.proforma">{{ t('purchases.hub.proformas') }} {{ order.proforma.number }}</span>
      </p>
      <p v-if="error" class="m-0 rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700">{{ error }}</p>
      <p v-if="order && !order.supplier" class="m-0 rounded-lg bg-amber-50 px-3 py-2 text-sm text-amber-800">{{ t('purchases.supplierRequired') }}</p>

      <div v-if="order" class="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <div class="stat-card">
          <p class="stat-label">{{ t('products.status') }}</p>
          <StatusBadge :active="order.status === 'completed' || order.status === 'received'" :label="orderStatusLabel(order.status)" />
        </div>
        <div class="stat-card">
          <p class="stat-label">{{ t('inventory.warehouse') }}</p>
          <p class="stat-value text-base">{{ order.warehouse?.name ?? '—' }}</p>
        </div>
        <div class="stat-card">
          <p class="stat-label">{{ t('products.price') }}</p>
          <p class="stat-value">{{ formatMoney(order.total) }}</p>
        </div>
        <div class="stat-card">
          <p class="stat-label">{{ t('inventory.date') }}</p>
          <p class="stat-value text-base">{{ formatDate(order.created_at) }}</p>
        </div>
      </div>

      <div v-if="order?.items?.length" class="overflow-hidden rounded-xl bg-white shadow-sm ring-1 ring-slate-200">
        <div class="border-b border-slate-100 px-4 py-3">
          <h3 class="m-0 text-sm font-semibold text-slate-700">{{ t('sales.items') }}</h3>
        </div>
        <table class="min-w-full divide-y divide-slate-200 text-sm">
          <thead class="bg-slate-50">
            <tr>
              <th class="px-4 py-3 text-left font-medium">{{ t('products.name') }}</th>
              <th class="px-4 py-3 text-right font-medium">{{ t('purchases.qtyOrdered') }}</th>
              <th class="px-4 py-3 text-right font-medium">{{ t('purchases.qtyReceived') }}</th>
              <th class="px-4 py-3 text-right font-medium">{{ t('purchases.unitCost') }}</th>
              <th v-if="canReceive" class="px-4 py-3 text-right font-medium">{{ t('purchases.receive') }}</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-slate-100">
            <tr v-for="item in order.items" :key="item.id">
              <td class="px-4 py-3">{{ item.product?.name ?? '—' }}</td>
              <td class="px-4 py-3 text-right">{{ ordered(item) }}</td>
              <td class="px-4 py-3 text-right">{{ received(item) }}</td>
              <td class="px-4 py-3 text-right">{{ formatMoney(item.unit_cost) }}</td>
              <td v-if="canReceive" class="px-4 py-3 text-right">
                <input
                  v-if="(item.remaining ?? 0) > 0"
                  v-model.number="receiveQty[item.id]"
                  type="number"
                  min="0"
                  :max="item.remaining"
                  class="field w-20 text-right"
                />
                <span v-else>—</span>
              </td>
            </tr>
          </tbody>
        </table>
        <div v-if="canReceive" class="flex items-center justify-between gap-3 border-t border-slate-100 px-4 py-3">
          <p class="m-0 text-xs text-slate-500">{{ t('purchases.receiveHint') }}</p>
          <button class="btn-primary" :disabled="acting || !order.supplier" @click="receive">{{ t('purchases.receive') }}</button>
        </div>
      </div>

      <div v-if="order?.goods_receipts?.length" class="overflow-hidden rounded-xl bg-white shadow-sm ring-1 ring-slate-200">
        <div class="border-b border-slate-100 px-4 py-3">
          <h3 class="m-0 text-sm font-semibold text-slate-700">{{ t('purchases.receipts') }}</h3>
          <p class="m-0 mt-1 text-xs text-slate-500">{{ t('purchases.stockIncreased') }}</p>
        </div>
        <table class="min-w-full divide-y divide-slate-200 text-sm">
          <thead class="bg-slate-50">
            <tr>
              <th class="px-4 py-3 text-left font-medium">#</th>
              <th class="px-4 py-3 text-left font-medium">{{ t('inventory.date') }}</th>
              <th class="px-4 py-3 text-left font-medium">{{ t('sales.items') }}</th>
              <th class="px-4 py-3 text-left font-medium">{{ t('purchases.tabs.invoices') }}</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-slate-100">
            <tr v-for="receipt in order.goods_receipts" :key="receipt.id">
              <td class="px-4 py-3 font-mono">{{ receipt.receipt_number }}</td>
              <td class="px-4 py-3">{{ formatDate(receipt.received_at) }}</td>
              <td class="px-4 py-3">
                <span v-for="line in receipt.items ?? []" :key="line.id" class="mr-3">
                  {{ line.product?.name ?? '—' }} PURCHASE +{{ line.quantity_received }}
                  <span v-if="onHand(line.product?.id) != null" class="text-slate-500">
                    · {{ t('inventory.onHand') }} {{ onHand(line.product?.id) }}
                  </span>
                </span>
              </td>
              <td class="px-4 py-3 font-mono">{{ receipt.invoice?.invoice_number ?? '—' }}</td>
            </tr>
          </tbody>
        </table>
      </div>

      <div v-if="order?.invoices?.length" class="overflow-hidden rounded-xl bg-white shadow-sm ring-1 ring-slate-200">
        <div class="border-b border-slate-100 px-4 py-3">
          <h3 class="m-0 text-sm font-semibold text-slate-700">{{ t('purchases.tabs.invoices') }}</h3>
        </div>
        <table class="min-w-full divide-y divide-slate-200 text-sm">
          <thead class="bg-slate-50">
            <tr>
              <th class="px-4 py-3 text-left font-medium">#</th>
              <th class="px-4 py-3 text-left font-medium">{{ t('products.status') }}</th>
              <th class="px-4 py-3 text-right font-medium">{{ t('products.price') }}</th>
              <th class="px-4 py-3 text-right font-medium">{{ t('purchases.outstanding') }}</th>
              <th class="px-4 py-3 text-right font-medium"></th>
            </tr>
          </thead>
          <tbody class="divide-y divide-slate-100">
            <tr v-for="invoice in order.invoices" :key="invoice.id">
              <td class="px-4 py-3 font-mono">{{ invoice.invoice_number }}</td>
              <td class="px-4 py-3">{{ invoice.status }}</td>
              <td class="px-4 py-3 text-right">{{ formatMoney(invoice.total) }}</td>
              <td class="px-4 py-3 text-right">{{ formatMoney(invoice.total - invoice.paid_amount) }}</td>
              <td class="px-4 py-3 text-right">
                <button v-if="invoice.paid_amount < invoice.total" class="text-brand-600" @click="openPay(invoice)">
                  {{ t('purchases.pay') }}
                </button>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>

    <AppModal :open="showPay" :title="t('purchases.payInvoice')" icon="card" tone="success" @close="showPay = false">
      <form class="space-y-3" @submit.prevent="submitPay">
        <p class="text-sm text-slate-600">{{ paying?.invoice_number }}</p>
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
          <button type="submit" class="btn-primary" :disabled="acting">{{ t('purchases.pay') }}</button>
        </div>
      </form>
    </AppModal>
  </PageFrame>
</template>

<style scoped>


.btn-secondary { border-radius: 0.5rem; border: 1px solid #cbd5e1; padding: 0.5rem 1rem; }
.btn-danger { border-radius: 0.5rem; padding: 0.5rem 1rem; font-weight: 500; color: white; background-color: #dc2626; }
.stat-card { border-radius: var(--radius-lg); background: white; padding: 1rem; box-shadow: none; border: 1px solid var(--color-border); }
.stat-label { margin: 0; font-size: 0.75rem; color: #64748b; }
.stat-value { margin: 0.25rem 0 0; font-size: 1.25rem; font-weight: 700; color: #0f172a; }
.text-brand-600 { color: var(--color-brand-600); }
</style>
