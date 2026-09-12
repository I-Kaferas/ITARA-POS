<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import { useRouter } from 'vue-router'
import SalesLayout from '../../../components/sales/SalesLayout.vue'
import StatusBadge from '../../../components/organization/StatusBadge.vue'
import { useBackofficeStore } from '../../../stores/backoffice'
import { useContextStore } from '../../../stores/context'
import type { SaleReturn } from '../../../types'
import { formatDate, formatMoney } from '../../../utils/format'

const { t } = useI18n()
const router = useRouter()
const store = useBackofficeStore()
const context = useContextStore()

const allReturns = ref<SaleReturn[]>([])

onMounted(async () => {
  if (!context.currentStoreId) return
  allReturns.value = await store.loadStoreSaleReturns(context.currentStoreId)
})
</script>

<template>
  <SalesLayout>
    <div class="overflow-hidden rounded-xl bg-white shadow-sm ring-1 ring-slate-200">
      <div class="flex items-center justify-between border-b border-slate-100 px-4 py-3">
        <h3 class="m-0 text-sm font-semibold text-slate-700">{{ t('sales.tabs.returns') }}</h3>
        <span class="rounded-full bg-slate-100 px-2.5 py-0.5 text-xs font-medium text-slate-600">
          {{ allReturns.length }}
        </span>
      </div>
      <table class="min-w-full divide-y divide-slate-200 text-sm">
        <thead class="bg-slate-50">
          <tr>
            <th class="px-4 py-3 text-left font-medium">#</th>
            <th class="px-4 py-3 text-left font-medium">{{ t('sales.reference') }}</th>
            <th class="px-4 py-3 text-left font-medium">{{ t('nav.customers') }}</th>
            <th class="px-4 py-3 text-left font-medium">{{ t('inventory.reason') }}</th>
            <th class="px-4 py-3 text-left font-medium">{{ t('products.status') }}</th>
            <th class="px-4 py-3 text-right font-medium">{{ t('products.price') }}</th>
            <th class="px-4 py-3 text-left font-medium">{{ t('inventory.date') }}</th>
          </tr>
        </thead>
        <tbody class="divide-y divide-slate-100">
          <tr
            v-for="row in allReturns"
            :key="row.id"
            class="cursor-pointer hover:bg-slate-50"
            @click="row.sale?.id && router.push({ name: 'sale-detail', params: { id: row.sale.id } })"
          >
            <td class="px-4 py-3 font-mono">{{ row.return_number }}</td>
            <td class="px-4 py-3 font-mono text-slate-500">{{ row.sale?.reference ?? '—' }}</td>
            <td class="px-4 py-3">{{ row.customer?.name ?? '—' }}</td>
            <td class="px-4 py-3">{{ row.reason }}</td>
            <td class="px-4 py-3"><StatusBadge :active="row.status === 'completed'" :label="row.status" /></td>
            <td class="px-4 py-3 text-right">{{ formatMoney(row.total) }}</td>
            <td class="px-4 py-3 text-slate-500">{{ formatDate(row.created_at) }}</td>
          </tr>
        </tbody>
      </table>
      <p v-if="!allReturns.length" class="px-4 py-8 text-center text-slate-500">{{ t('org.empty') }}</p>
    </div>
  </SalesLayout>
</template>
