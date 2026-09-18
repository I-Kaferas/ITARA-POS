<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import { useRouter } from 'vue-router'
import PageFrame from '../../../components/layout/PageFrame.vue'
import StatusBadge from '../../../components/organization/StatusBadge.vue'
import AppIcon from '../../../components/ui/AppIcon.vue'
import Badge from '../../../components/ui/Badge.vue'
import DataTableShell from '../../../components/ui/DataTableShell.vue'
import FieldLabel from '../../../components/ui/FieldLabel.vue'
import { watchLiveSearch } from '../../../composables/useLiveSearch'
import { realtimeTopics, useRealtimeSync } from '../../../composables/useRealtimeSync'
import { extractApiErrorMessage } from '../../../api/client'
import { useBackofficeStore } from '../../../stores/backoffice'
import { useContextStore } from '../../../stores/context'
import { formatDate, formatMoney } from '../../../utils/format'
import { openPrintWindow, printSaleDocument, type SaleDocPayload } from '../../../utils/printSaleDocument'
import MergeOrdersModal from '../../../components/pos/MergeOrdersModal.vue'

const { t } = useI18n()
const router = useRouter()
const store = useBackofficeStore()
const context = useContextStore()

const storeId = computed(() => context.currentStoreId)
const exporting = ref(false)
const docLoadingId = ref<string | null>(null)
const error = ref('')
const mergeSale = ref<{
  id: string
  reference: string
  total: number
  currency?: string
  customer?: { id: string; name: string } | null
  table?: { id: string; name: string; code?: string } | null
} | null>(null)
const showMerge = ref(false)

const filters = ref({
  q: '',
  status: '',
  payment_status: '',
  customer_id: '',
  from: '',
  to: '',
})

const statusOptions = computed(() => [
  { value: '', label: t('pointOfSale.orders.filters.allStatuses') },
  { value: 'completed', label: t('pointOfSale.orders.status.completed') },
  { value: 'pending', label: t('pointOfSale.orders.status.pending') },
  { value: 'draft', label: t('pointOfSale.orders.status.draft') },
  { value: 'voided', label: t('pointOfSale.orders.status.voided') },
  { value: 'merged', label: t('pointOfSale.orders.status.merged') },
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

function openMerge(row: typeof store.sales[number]) {
  mergeSale.value = {
    id: row.id,
    reference: row.reference,
    total: row.total,
    currency: row.currency,
    customer: row.customer ?? null,
    table: (row as { table?: { id: string; name: string; code?: string } | null }).table ?? null,
  }
  showMerge.value = true
}

async function onMerged() {
  showMerge.value = false
  mergeSale.value = null
  await load()
}

onMounted(load)
watch(storeId, load)
useRealtimeSync([...realtimeTopics.sales, ...realtimeTopics.payments], load)
watchLiveSearch(() => filters.value.q, load)
watch(
  () => [filters.value.status, filters.value.payment_status, filters.value.customer_id, filters.value.from, filters.value.to],
  load,
)
</script>

<template>
  <PageFrame>
    <template #title>{{ t('nav.posOrders') }}</template>
    <template #subtitle>{{ t('pointOfSale.orders.subtitle') }}</template>

    <div v-if="!storeId" class="ui-toast ui-toast--warning mb-4">
      {{ t('sales.selectStore') }}
    </div>

    <template v-else>
      <div class="ui-toolbar">
        <div class="grid w-full gap-3 md:grid-cols-2 xl:grid-cols-6">
          <div class="xl:col-span-2">
            <FieldLabel icon="search">{{ t('common.search') }}</FieldLabel>
            <div class="relative">
              <AppIcon name="search" :size="15" class="pointer-events-none absolute left-2.5 top-1/2 -translate-y-1/2 text-slate-400" />
              <input
                v-model="filters.q"
                type="search"
                class="ui-input !pl-8 w-full"
                :placeholder="t('pointOfSale.orders.filters.searchPlaceholder')"
              />
            </div>
          </div>
          <div>
            <FieldLabel icon="calendar">{{ t('pointOfSale.orders.filters.from') }}</FieldLabel>
            <input v-model="filters.from" type="date" class="ui-input w-full" />
          </div>
          <div>
            <FieldLabel icon="calendar">{{ t('pointOfSale.orders.filters.to') }}</FieldLabel>
            <input v-model="filters.to" type="date" class="ui-input w-full" />
          </div>
          <div>
            <FieldLabel icon="filter">{{ t('products.status') }}</FieldLabel>
            <select v-model="filters.status" class="ui-select w-full">
              <option v-for="opt in statusOptions" :key="opt.value" :value="opt.value">{{ opt.label }}</option>
            </select>
          </div>
          <div>
            <FieldLabel icon="card">{{ t('sales.paymentStatus') }}</FieldLabel>
            <select v-model="filters.payment_status" class="ui-select w-full">
              <option v-for="opt in paymentOptions" :key="opt.value" :value="opt.value">{{ opt.label }}</option>
            </select>
          </div>
          <div class="xl:col-span-2">
            <FieldLabel icon="customers">{{ t('nav.customers') }}</FieldLabel>
            <select v-model="filters.customer_id" class="ui-select w-full">
              <option value="">{{ t('pointOfSale.orders.filters.allCustomers') }}</option>
              <option v-for="customer in store.customers" :key="customer.id" :value="customer.id">
                {{ customer.name }}
              </option>
            </select>
          </div>
        </div>

        <div class="flex w-full flex-wrap items-center gap-2">
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

      <p v-if="error" class="ui-toast ui-toast--danger mb-4">{{ error }}</p>

      <DataTableShell
        :title="t('pointOfSale.orders.listTitle')"
        :meta="`${store.sales.length} ${t('pointOfSale.orders.results')}`"
        :loading="store.loading"
        :empty="!store.loading && !store.sales.length"
        :empty-title="t('pointOfSale.orders.empty')"
        :empty-description="t('pointOfSale.orders.subtitle')"
        empty-icon="sales"
        :loading-label="t('common.loading')"
      >
        <table class="ui-table">
          <thead>
            <tr>
              <th>{{ t('sales.reference') }}</th>
              <th>{{ t('nav.customers') }}</th>
              <th>{{ t('products.status') }}</th>
              <th>{{ t('sales.paymentStatus') }}</th>
              <th class="num">{{ t('products.price') }}</th>
              <th>{{ t('inventory.date') }}</th>
              <th class="num">{{ t('pointOfSale.orders.documents') }}</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="row in store.sales" :key="row.id">
              <td class="font-mono cursor-pointer" @click="router.push({ name: 'sale-detail', params: { id: row.id } })">
                {{ row.reference }}
              </td>
              <td class="cursor-pointer" @click="router.push({ name: 'sale-detail', params: { id: row.id } })">
                {{ row.customer?.name ?? '—' }}
              </td>
              <td>
                <Badge v-if="row.status === 'pending'" variant="warning">{{ statusLabel(row.status) }}</Badge>
                <Badge v-else-if="row.status === 'merged'" variant="brand">{{ statusLabel(row.status) }}</Badge>
                <StatusBadge v-else :active="row.status === 'completed'" :label="statusLabel(row.status)" />
              </td>
              <td>
                <StatusBadge :active="paymentStatusActive(row.payment_status)" :label="paymentStatusLabel(row.payment_status)" />
              </td>
              <td class="num font-medium">{{ formatMoney(row.total, row.currency) }}</td>
              <td class="text-slate-500">{{ formatDate(row.completed_at ?? row.created_at) }}</td>
              <td>
                <div class="ui-table__actions">
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
                    class="ui-btn ui-btn--secondary ui-btn--sm"
                    @click="openMerge(row)"
                  >
                    {{ t('pointOfSale.merge.action') }}
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
      </DataTableShell>
    </template>

    <MergeOrdersModal
      :open="showMerge"
      :sale="mergeSale"
      @close="showMerge = false"
      @merged="onMerged"
    />
  </PageFrame>
</template>
