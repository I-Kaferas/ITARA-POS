<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import { useRouter } from 'vue-router'
import PageFrame from '../../../components/layout/PageFrame.vue'
import ModuleFilters from '../../../components/ui/ModuleFilters.vue'
import { useBackofficeStore } from '../../../stores/backoffice'
import { formatDate, formatMoney } from '../../../utils/format'
import { emptyListFilters, inPeriod, listFilterParams, matchesSearch, type ListFilters } from '../../../utils/listFilters'

const { t } = useI18n()
const router = useRouter()
const store = useBackofficeStore()
const activeTab = ref<'accounts' | 'schedule' | 'payments'>('accounts')
const filters = ref<ListFilters>(emptyListFilters())

const scheduleStatuses = computed(() => [
  { value: 'overdue', label: t('payables.overdue') },
])

const methodOptions = computed(() => [
  { value: 'cash', label: paymentMethodLabel('cash') },
  { value: 'bank_transfer', label: paymentMethodLabel('bank_transfer') },
  { value: 'check', label: paymentMethodLabel('check') },
  { value: 'mobile_money', label: paymentMethodLabel('mobile_money') },
  { value: 'card', label: paymentMethodLabel('card') },
  { value: 'other', label: paymentMethodLabel('other') },
])

const summary = computed(() => store.payablesSummary)

const filteredAccounts = computed(() =>
  (summary.value?.suppliers ?? []).filter((row) =>
    matchesSearch([row.supplier_name, row.supplier_code].filter(Boolean).join(' '), filters.value.search),
  ),
)

const filteredSchedule = computed(() =>
  store.payablesSchedule.filter((item) => {
    const haystack = [item.supplier_name, item.supplier_code, item.reference].filter(Boolean).join(' ')
    if (!matchesSearch(haystack, filters.value.search)) return false
    if (!inPeriod(item.due_date, filters.value)) return false
    return true
  }),
)

const filteredPayments = computed(() =>
  store.supplierPayments.filter((payment) => {
    const haystack = [
      payment.payment_number,
      payment.reference,
      payment.supplier?.name,
      payment.payment_method,
    ].filter(Boolean).join(' ')
    if (!matchesSearch(haystack, filters.value.search)) return false
    if (!inPeriod(payment.paid_at, filters.value)) return false
    if (filters.value.payment_method && payment.payment_method !== filters.value.payment_method) return false
    return true
  }),
)

watch(activeTab, () => {
  filters.value = { ...filters.value, status: '', payment_method: '' }
})

onMounted(async () => {
  await Promise.all([
    store.loadPayablesSummary(),
    store.loadPayablesSchedule(),
    store.loadRecentSupplierPayments(),
  ])
})

async function applyFilters() {
  if (activeTab.value === 'schedule') {
    await store.loadPayablesSchedule(filters.value.status === 'overdue')
  } else if (activeTab.value === 'payments') {
    await store.loadRecentSupplierPayments(listFilterParams(filters.value))
  }
}

function openSupplier(supplierId: string) {
  router.push({ name: 'supplier-detail', params: { id: supplierId } })
}

function paymentMethodLabel(method: string): string {
  const map: Record<string, string> = {
    cash: 'Espèces',
    bank_transfer: 'Virement',
    check: 'Chèque',
    mobile_money: 'Mobile money',
    card: 'Carte',
    other: 'Autre',
  }
  return map[method] ?? method
}
</script>

<template>
  <PageFrame>
    <template #title>{{ t('payables.title') }}</template>
    <template #subtitle>{{ t('payables.subtitle') }}</template>

    <div class="space-y-6">
      <div v-if="summary" class="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <div class="stat-card">
          <p class="stat-label">{{ t('payables.totalDebt') }}</p>
          <p class="stat-value">{{ formatMoney(summary.total_debt) }}</p>
        </div>
        <div class="stat-card">
          <p class="stat-label">{{ t('payables.totalOverdue') }}</p>
          <p class="stat-value text-red-600">{{ formatMoney(summary.total_overdue) }}</p>
        </div>
        <div class="stat-card">
          <p class="stat-label">{{ t('payables.openInvoices') }}</p>
          <p class="stat-value">{{ summary.open_invoices }}</p>
        </div>
        <div class="stat-card">
          <p class="stat-label">{{ t('payables.suppliersWithDebt') }}</p>
          <p class="stat-value">{{ summary.suppliers_with_debt }}</p>
        </div>
      </div>

      <div class="flex gap-2 border-b border-slate-200">
        <button
          v-for="tab in (['accounts', 'schedule', 'payments'] as const)"
          :key="tab"
          class="tab-btn"
          :class="{ active: activeTab === tab }"
          @click="activeTab = tab"
        >
          {{ t(`payables.tabs.${tab}`) }}
        </button>
      </div>

      <ModuleFilters
        v-model="filters"
        :statuses="scheduleStatuses"
        :methods="methodOptions"
        show-search
        :show-period="activeTab === 'schedule' || activeTab === 'payments'"
        :show-status="activeTab === 'schedule'"
        :show-method="activeTab === 'payments'"
        @apply="applyFilters"
      />

      <div v-if="activeTab === 'accounts'" class="overflow-hidden rounded-xl bg-white shadow-sm ring-1 ring-slate-200">
        <table class="min-w-full divide-y divide-slate-200 text-sm">
          <thead class="bg-slate-50">
            <tr>
              <th class="px-4 py-3 text-left font-medium">{{ t('org.code') }}</th>
              <th class="px-4 py-3 text-left font-medium">{{ t('org.name') }}</th>
              <th class="px-4 py-3 text-right font-medium">{{ t('payables.outstanding') }}</th>
              <th class="px-4 py-3 text-right font-medium">{{ t('payables.overdue') }}</th>
              <th class="px-4 py-3 text-right font-medium">{{ t('payables.openInvoices') }}</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-slate-100">
            <tr
              v-for="row in filteredAccounts"
              :key="row.supplier_id"
              class="cursor-pointer hover:bg-slate-50"
              @click="openSupplier(row.supplier_id)"
            >
              <td class="px-4 py-3 font-mono text-slate-500">{{ row.supplier_code }}</td>
              <td class="px-4 py-3 font-medium">{{ row.supplier_name }}</td>
              <td class="px-4 py-3 text-right font-medium">{{ formatMoney(row.debt) }}</td>
              <td class="px-4 py-3 text-right" :class="row.overdue_amount > 0 ? 'text-red-600' : 'text-slate-500'">
                {{ formatMoney(row.overdue_amount) }}
              </td>
              <td class="px-4 py-3 text-right text-slate-600">{{ row.open_invoices }}</td>
            </tr>
          </tbody>
        </table>
        <p v-if="!filteredAccounts.length" class="px-4 py-8 text-center text-slate-500">{{ t('payables.noDebt') }}</p>
      </div>

      <div v-else-if="activeTab === 'schedule'" class="overflow-hidden rounded-xl bg-white shadow-sm ring-1 ring-slate-200">
        <table class="min-w-full divide-y divide-slate-200 text-sm">
          <thead class="bg-slate-50">
            <tr>
              <th class="px-4 py-3 text-left font-medium">{{ t('payables.dueDate') }}</th>
              <th class="px-4 py-3 text-left font-medium">{{ t('nav.suppliers') }}</th>
              <th class="px-4 py-3 text-left font-medium">{{ t('payables.reference') }}</th>
              <th class="px-4 py-3 text-right font-medium">{{ t('payables.outstanding') }}</th>
              <th class="px-4 py-3 text-left font-medium">{{ t('products.status') }}</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-slate-100">
            <tr
              v-for="item in filteredSchedule"
              :key="item.id"
              class="cursor-pointer hover:bg-slate-50"
              @click="openSupplier(item.supplier_id)"
            >
              <td class="px-4 py-3">{{ formatDate(item.due_date) }}</td>
              <td class="px-4 py-3">{{ item.supplier_name }}</td>
              <td class="px-4 py-3 font-mono text-slate-500">{{ item.reference ?? '—' }}</td>
              <td class="px-4 py-3 text-right font-medium">{{ formatMoney(item.outstanding) }}</td>
              <td class="px-4 py-3">
                <span v-if="item.is_overdue" class="badge-overdue">{{ t('payables.overdue') }}</span>
                <span v-else class="badge-open">{{ t('payables.open') }}</span>
              </td>
            </tr>
          </tbody>
        </table>
        <p v-if="!filteredSchedule.length" class="px-4 py-8 text-center text-slate-500">{{ t('org.empty') }}</p>
      </div>

      <div v-else class="overflow-hidden rounded-xl bg-white shadow-sm ring-1 ring-slate-200">
        <table class="min-w-full divide-y divide-slate-200 text-sm">
          <thead class="bg-slate-50">
            <tr>
              <th class="px-4 py-3 text-left font-medium">{{ t('payables.paymentNumber') }}</th>
              <th class="px-4 py-3 text-left font-medium">{{ t('nav.suppliers') }}</th>
              <th class="px-4 py-3 text-left font-medium">{{ t('payables.method') }}</th>
              <th class="px-4 py-3 text-right font-medium">{{ t('products.price') }}</th>
              <th class="px-4 py-3 text-left font-medium">{{ t('inventory.date') }}</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-slate-100">
            <tr v-for="payment in filteredPayments" :key="payment.id" class="hover:bg-slate-50">
              <td class="px-4 py-3 font-mono">{{ payment.payment_number }}</td>
              <td class="px-4 py-3">{{ payment.supplier?.name ?? '—' }}</td>
              <td class="px-4 py-3 text-slate-600">{{ paymentMethodLabel(payment.payment_method) }}</td>
              <td class="px-4 py-3 text-right font-medium">{{ formatMoney(payment.amount) }}</td>
              <td class="px-4 py-3 text-slate-500">{{ formatDate(payment.paid_at) }}</td>
            </tr>
          </tbody>
        </table>
        <p v-if="!filteredPayments.length" class="px-4 py-8 text-center text-slate-500">{{ t('org.empty') }}</p>
      </div>
    </div>
  </PageFrame>
</template>

<style scoped>
.stat-card { border-radius: 0.75rem; background: white; padding: 1rem 1.25rem; box-shadow: 0 1px 2px rgb(0 0 0 / 0.05); border: 1px solid #e2e8f0; }
.stat-label { font-size: 0.875rem; color: #64748b; }
.stat-value { margin-top: 0.25rem; font-size: 1.5rem; font-weight: 600; }
.tab-btn { padding: 0.5rem 1rem; font-size: 0.875rem; font-weight: 500; color: #64748b; border-bottom: 2px solid transparent; }
.tab-btn.active { color: var(--color-brand-600); border-bottom-color: var(--color-brand-600); }
.badge-overdue { border-radius: 9999px; background: #fef2f2; padding: 0.125rem 0.625rem; font-size: 0.75rem; font-weight: 500; color: #dc2626; }
.badge-open { border-radius: 9999px; background: #f0fdf4; padding: 0.125rem 0.625rem; font-size: 0.75rem; font-weight: 500; color: #16a34a; }
</style>
