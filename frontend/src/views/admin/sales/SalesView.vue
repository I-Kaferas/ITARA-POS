<script setup lang="ts">
import { computed, onMounted, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import { useRouter } from 'vue-router'
import SalesLayout from '../../../components/sales/SalesLayout.vue'
import StatusBadge from '../../../components/organization/StatusBadge.vue'
import { useBackofficeStore } from '../../../stores/backoffice'
import { useContextStore } from '../../../stores/context'
import { formatDate, formatMoney } from '../../../utils/format'

const { t } = useI18n()
const router = useRouter()
const store = useBackofficeStore()
const context = useContextStore()

const storeId = computed(() => context.currentStoreId)

async function load() {
  if (storeId.value) await store.loadSales(storeId.value)
}

onMounted(load)
watch(storeId, load)

function paymentStatusLabel(status: string): string {
  const map: Record<string, string> = {
    paid: 'Payée',
    partial: 'Partielle',
    unpaid: 'Impayée',
    credit: 'Crédit',
    on_credit: 'À crédit',
  }
  return map[status] ?? status
}

function paymentStatusActive(status: string): boolean {
  return status === 'paid'
}
</script>

<template>
  <SalesLayout>
    <div v-if="!storeId" class="rounded-xl bg-amber-50 p-4 text-sm text-amber-800">
      {{ t('sales.selectStore') }}
    </div>

    <div v-else class="overflow-hidden rounded-xl bg-white shadow-sm ring-1 ring-slate-200">
      <div class="flex items-center justify-between border-b border-slate-100 px-4 py-3">
        <h3 class="m-0 text-sm font-semibold text-slate-700">{{ t('sales.tabs.list') }}</h3>
        <span class="rounded-full bg-slate-100 px-2.5 py-0.5 text-xs font-medium text-slate-600">
          {{ store.sales.length }}
        </span>
      </div>
      <table class="min-w-full divide-y divide-slate-200 text-sm">
        <thead class="bg-slate-50">
          <tr>
            <th class="px-4 py-3 text-left font-medium">{{ t('sales.reference') }}</th>
            <th class="px-4 py-3 text-left font-medium">{{ t('nav.customers') }}</th>
            <th class="px-4 py-3 text-left font-medium">{{ t('products.status') }}</th>
            <th class="px-4 py-3 text-left font-medium">{{ t('sales.paymentStatus') }}</th>
            <th class="px-4 py-3 text-right font-medium">{{ t('products.price') }}</th>
            <th class="px-4 py-3 text-left font-medium">{{ t('inventory.date') }}</th>
          </tr>
        </thead>
        <tbody class="divide-y divide-slate-100">
          <tr
            v-for="row in store.sales"
            :key="row.id"
            class="cursor-pointer hover:bg-slate-50"
            @click="router.push({ name: 'sale-detail', params: { id: row.id } })"
          >
            <td class="px-4 py-3 font-mono">{{ row.reference }}</td>
            <td class="px-4 py-3">{{ row.customer?.name ?? '—' }}</td>
            <td class="px-4 py-3"><StatusBadge :active="row.status === 'completed'" :label="row.status" /></td>
            <td class="px-4 py-3">
              <StatusBadge :active="paymentStatusActive(row.payment_status)" :label="paymentStatusLabel(row.payment_status)" />
            </td>
            <td class="px-4 py-3 text-right font-medium">{{ formatMoney(row.total, row.currency) }}</td>
            <td class="px-4 py-3 text-slate-500">{{ formatDate(row.completed_at ?? row.created_at) }}</td>
          </tr>
        </tbody>
      </table>
      <p v-if="!store.sales.length" class="px-4 py-8 text-center text-slate-500">
        {{ t('org.empty') }}
        <span class="mt-1 block text-xs">{{ t('sales.storeHint') }}</span>
      </p>
    </div>
  </SalesLayout>
</template>
