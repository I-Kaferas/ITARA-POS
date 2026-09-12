<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import { useRouter } from 'vue-router'
import AdminLayout from '../../../components/layout/AdminLayout.vue'
import StatusBadge from '../../../components/organization/StatusBadge.vue'
import AppIcon from '../../../components/ui/AppIcon.vue'
import Badge from '../../../components/ui/Badge.vue'
import SubNav from '../../../components/ui/SubNav.vue'
import { extractApiErrorMessage } from '../../../api/client'
import { useBackofficeStore } from '../../../stores/backoffice'
import { useContextStore } from '../../../stores/context'
import { formatDate, formatMoney } from '../../../utils/format'
import { openPrintWindow, printSaleDocument, type SaleDocPayload } from '../../../utils/printSaleDocument'

const { t } = useI18n()
const router = useRouter()
const store = useBackofficeStore()
const context = useContextStore()

const storeId = computed(() => context.currentStoreId)
const exporting = ref(false)
const docLoadingId = ref<string | null>(null)
const error = ref('')

const filters = ref({
  q: '',
  status: '',
  payment_status: '',
  customer_id: '',
  from: '',
  to: '',
})

const tabs = computed(() => [
  { to: '/admin/pos/orders', label: t('sales.tabs.list'), active: true },
  { to: '/admin/sales/returns', label: t('sales.tabs.returns'), active: false },
])

const statusOptions = computed(() => [
  { value: '', label: t('pointOfSale.orders.filters.allStatuses') },
  { value: 'completed', label: t('pointOfSale.orders.status.completed') },
  { value: 'pending', label: t('pointOfSale.orders.status.pending') },
  { value: 'draft', label: t('pointOfSale.orders.status.draft') },
  { value: 'voided', label: t('pointOfSale.orders.status.voided') },
])

const paymentOptions = computed(() => [
  { value: '', label: t('pointOfSale.orders.filters.allPayments') },
  { value: 'paid', label: t('pointOfSale.orders.payment.paid') },
  { value: 'partial', label: t('pointOfSale.orders.payment.partial') },
  { value: 'on_credit', label: t('pointOfSale.orders.payment.on_credit') },
])

const filterPayload = computed(() => ({
  q: filters.value.q.trim() || undefined,
  status: filters.value.status || undefined,
  payment_status: filters.value.payment_status || undefined,
  customer_id: filters.value.customer_id || undefined,
  from: filters.value.from || undefined,
  to: filters.value.to || undefined,
}))

async function load() {
  if (!storeId.value) return
  error.value = ''
  try {
    if (!store.customers.length) await store.loadCustomers()
    await store.loadSales(storeId.value, filterPayload.value)
  } catch (e) {
    error.value = extractApiErrorMessage(e, t('pointOfSale.orders.loadError'))
  }
}

function resetFilters() {
  filters.value = {
    q: '',
    status: '',
    payment_status: '',
    customer_id: '',
    from: '',
    to: '',
  }
  void load()
}

async function exportCsv() {
  if (!storeId.value) return
  exporting.value = true
  error.value = ''
  try {
    await store.exportSales(storeId.value, filterPayload.value)
  } catch (e) {
    error.value = extractApiErrorMessage(e, t('pointOfSale.orders.exportError'))
  } finally {
    exporting.value = false
  }
}

async function exportReceipt(saleId: string) {
  const popup = openPrintWindow()
  if (!popup) {
    error.value = t('pointOfSale.orders.docError')
    return
  }
  docLoadingId.value = saleId
  error.value = ''
  try {
    const payload = await store.loadSaleReceipt(saleId, 'thermal_80') as SaleDocPayload
    if (!printSaleDocument(payload, t('pointOfSale.orders.receipt'), popup)) {
      error.value = t('pointOfSale.orders.docError')
    }
  } catch (e) {
    popup.close()
    error.value = extractApiErrorMessage(e, t('pointOfSale.orders.docError'))
  } finally {
    docLoadingId.value = null
  }
}

async function exportInvoice(saleId: string) {
  const popup = openPrintWindow()
  if (!popup) {
    error.value = t('pointOfSale.orders.docError')
    return
  }
  docLoadingId.value = saleId
  error.value = ''
  try {
    const payload = await store.loadSaleInvoice(saleId, 'a4') as SaleDocPayload
    if (!printSaleDocument(payload, t('pointOfSale.orders.invoice'), popup)) {
      error.value = t('pointOfSale.orders.docError')
    }
  } catch (e) {
    popup.close()
    error.value = extractApiErrorMessage(e, t('pointOfSale.orders.docError'))
  } finally {
    docLoadingId.value = null
  }
}

function paymentStatusLabel(status: string): string {
  const key = `pointOfSale.orders.payment.${status}`
  const label = t(key)
  return label === key ? status : label
}

function paymentStatusActive(status: string): boolean {
  return status === 'paid'
}

function statusLabel(status: string): string {
  const key = `pointOfSale.orders.status.${status}`
  const label = t(key)
  return label === key ? status : label
}

onMounted(load)
watch(storeId, load)
</script>

<template>
  <AdminLayout>
    <template #title>{{ t('nav.posOrders') }}</template>
    <template #subtitle>{{ t('pointOfSale.orders.subtitle') }}</template>

    <SubNav :tabs="tabs" />

    <div v-if="!storeId" class="rounded-xl bg-amber-50 p-4 text-sm text-amber-800">
      {{ t('sales.selectStore') }}
    </div>

    <template v-else>
      <div class="mb-4 rounded-xl border border-slate-200 bg-white p-4">
        <div class="grid gap-3 md:grid-cols-2 xl:grid-cols-6">
          <div class="xl:col-span-2">
            <label class="mb-1 block text-xs font-medium text-slate-500">{{ t('common.search') }}</label>
            <div class="relative">
              <AppIcon name="search" :size="15" class="pointer-events-none absolute left-2.5 top-1/2 -translate-y-1/2 text-slate-400" />
              <input
                v-model="filters.q"
                type="search"
                class="ui-input !pl-8 w-full"
                :placeholder="t('pointOfSale.orders.filters.searchPlaceholder')"
                @keyup.enter="load"
              />
            </div>
          </div>
          <div>
            <label class="mb-1 block text-xs font-medium text-slate-500">{{ t('pointOfSale.orders.filters.from') }}</label>
            <input v-model="filters.from" type="date" class="ui-input w-full" />
          </div>
          <div>
            <label class="mb-1 block text-xs font-medium text-slate-500">{{ t('pointOfSale.orders.filters.to') }}</label>
            <input v-model="filters.to" type="date" class="ui-input w-full" />
          </div>
          <div>
            <label class="mb-1 block text-xs font-medium text-slate-500">{{ t('products.status') }}</label>
            <select v-model="filters.status" class="ui-select w-full">
              <option v-for="opt in statusOptions" :key="opt.value" :value="opt.value">{{ opt.label }}</option>
            </select>
          </div>
          <div>
            <label class="mb-1 block text-xs font-medium text-slate-500">{{ t('sales.paymentStatus') }}</label>
            <select v-model="filters.payment_status" class="ui-select w-full">
              <option v-for="opt in paymentOptions" :key="opt.value" :value="opt.value">{{ opt.label }}</option>
            </select>
          </div>
          <div class="xl:col-span-2">
            <label class="mb-1 block text-xs font-medium text-slate-500">{{ t('nav.customers') }}</label>
            <select v-model="filters.customer_id" class="ui-select w-full">
              <option value="">{{ t('pointOfSale.orders.filters.allCustomers') }}</option>
              <option v-for="customer in store.customers" :key="customer.id" :value="customer.id">
                {{ customer.name }}
              </option>
            </select>
          </div>
        </div>

        <div class="mt-3 flex flex-wrap items-center gap-2">
          <button type="button" class="ui-btn ui-btn--primary" :disabled="store.loading" @click="load">
            {{ t('pointOfSale.orders.filters.apply') }}
          </button>
          <button type="button" class="ui-btn ui-btn--secondary" @click="resetFilters">
            {{ t('pointOfSale.orders.filters.reset') }}
          </button>
          <button type="button" class="ui-btn ui-btn--secondary" :disabled="exporting" @click="exportCsv">
            {{ exporting ? t('common.loading') : t('pointOfSale.orders.exportCsv') }}
          </button>
          <span class="ml-auto text-xs text-slate-500">
            {{ store.sales.length }} {{ t('pointOfSale.orders.results') }}
          </span>
        </div>
      </div>

      <p v-if="error" class="mb-4 rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700">{{ error }}</p>

      <div class="overflow-hidden rounded-xl bg-white shadow-sm ring-1 ring-slate-200">
        <div class="flex items-center justify-between border-b border-slate-100 px-4 py-3">
          <h3 class="m-0 text-sm font-semibold text-slate-700">{{ t('pointOfSale.orders.listTitle') }}</h3>
        </div>

        <div v-if="store.loading" class="px-4 py-10 text-center text-sm text-slate-500">
          {{ t('common.loading') }}
        </div>

        <table v-else-if="store.sales.length" class="min-w-full divide-y divide-slate-200 text-sm">
          <thead class="bg-slate-50">
            <tr>
              <th class="px-4 py-3 text-left font-medium">{{ t('sales.reference') }}</th>
              <th class="px-4 py-3 text-left font-medium">{{ t('nav.customers') }}</th>
              <th class="px-4 py-3 text-left font-medium">{{ t('products.status') }}</th>
              <th class="px-4 py-3 text-left font-medium">{{ t('sales.paymentStatus') }}</th>
              <th class="px-4 py-3 text-right font-medium">{{ t('products.price') }}</th>
              <th class="px-4 py-3 text-left font-medium">{{ t('inventory.date') }}</th>
              <th class="px-4 py-3 text-right font-medium">{{ t('pointOfSale.orders.documents') }}</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-slate-100">
            <tr v-for="row in store.sales" :key="row.id" class="hover:bg-slate-50">
              <td class="px-4 py-3 font-mono cursor-pointer" @click="router.push({ name: 'sale-detail', params: { id: row.id } })">
                {{ row.reference }}
              </td>
              <td class="px-4 py-3 cursor-pointer" @click="router.push({ name: 'sale-detail', params: { id: row.id } })">
                {{ row.customer?.name ?? '—' }}
              </td>
              <td class="px-4 py-3">
                <Badge v-if="row.status === 'pending'" variant="warning">{{ statusLabel(row.status) }}</Badge>
                <StatusBadge v-else :active="row.status === 'completed'" :label="statusLabel(row.status)" />
              </td>
              <td class="px-4 py-3">
                <StatusBadge :active="paymentStatusActive(row.payment_status)" :label="paymentStatusLabel(row.payment_status)" />
              </td>
              <td class="px-4 py-3 text-right font-medium">{{ formatMoney(row.total, row.currency) }}</td>
              <td class="px-4 py-3 text-slate-500">{{ formatDate(row.completed_at ?? row.created_at) }}</td>
              <td class="px-4 py-3">
                <div class="flex flex-wrap items-center justify-end gap-1">
                  <button
                    v-if="row.status === 'completed'"
                    type="button"
                    class="ui-btn ui-btn--ghost ui-btn--sm"
                    :disabled="docLoadingId === row.id"
                    @click="exportReceipt(row.id)"
                  >
                    {{ t('pointOfSale.orders.receipt') }}
                  </button>
                  <button
                    v-if="row.status === 'completed'"
                    type="button"
                    class="ui-btn ui-btn--ghost ui-btn--sm"
                    :disabled="docLoadingId === row.id"
                    @click="exportInvoice(row.id)"
                  >
                    {{ t('pointOfSale.orders.invoice') }}
                  </button>
                  <button
                    v-if="row.status === 'pending'"
                    type="button"
                    class="ui-btn ui-btn--secondary ui-btn--sm"
                    @click="router.push({ name: 'pos', query: { sale: row.id } })"
                  >
                    {{ t('pos.modify') }}
                  </button>
                  <button
                    v-if="row.status === 'pending'"
                    type="button"
                    class="ui-btn ui-btn--primary ui-btn--sm"
                    @click="router.push({ name: 'pos', query: { sale: row.id, pay: '1' } })"
                  >
                    {{ t('pos.payHeld') }}
                  </button>
                  <button
                    type="button"
                    class="ui-btn ui-btn--ghost ui-btn--sm"
                    @click="router.push({ name: 'sale-detail', params: { id: row.id } })"
                  >
                    {{ t('common.view') }}
                  </button>
                </div>
              </td>
            </tr>
          </tbody>
        </table>

        <p v-else class="px-4 py-8 text-center text-slate-500">
          {{ t('pointOfSale.orders.empty') }}
        </p>
      </div>
    </template>
  </AdminLayout>
</template>
