<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import { useRoute, useRouter } from 'vue-router'
import AdminLayout from '../../../components/layout/AdminLayout.vue'
import StatusBadge from '../../../components/organization/StatusBadge.vue'
import { useBackofficeStore } from '../../../stores/backoffice'
import type { PurchaseOrderDetail } from '../../../types'
import { formatDate, formatMoney } from '../../../utils/format'

const { t } = useI18n()
const route = useRoute()
const router = useRouter()
const store = useBackofficeStore()

const order = ref<PurchaseOrderDetail | null>(null)
const acting = ref(false)

const orderId = computed(() => route.params.id as string)

onMounted(() => load())

async function load() {
  order.value = await store.loadPurchaseOrder(orderId.value)
}

async function doAction(action: 'confirm' | 'cancel') {
  acting.value = true
  try {
    if (action === 'confirm') await store.confirmPurchaseOrderStep(orderId.value)
    else if (action === 'cancel') await store.cancelPurchaseOrder(orderId.value)
    await load()
    await store.loadPurchaseOrders()
  } finally {
    acting.value = false
  }
}

function orderStatusLabel(status: string): string {
  const map: Record<string, string> = {
    draft: t('inventory.statusDraft'),
    pending: t('inventory.statusPending'),
    approved: 'Approuvée',
    partially_received: 'Partielle',
    received: 'Reçue',
    completed: 'Terminée',
    cancelled: 'Annulée',
  }
  return map[status] ?? status
}
</script>

<template>
  <AdminLayout>
    <template #title>{{ order?.order_number ?? t('purchases.orderDetail') }}</template>
    <template #subtitle>{{ order?.supplier?.name }}</template>

    <div class="space-y-6">
      <div class="flex flex-wrap items-center justify-between gap-3">
        <button class="btn-secondary" @click="router.push({ name: 'purchase-orders' })">← {{ t('nav.purchases') }}</button>
        <div class="flex flex-wrap gap-2">
          <button v-if="order?.status === 'draft' || order?.status === 'pending'" class="btn-primary" :disabled="acting" @click="doAction('confirm')">
            {{ t('inventory.confirm') }}
          </button>
          <button
            v-if="order && !['cancelled', 'completed', 'received'].includes(order.status)"
            class="btn-danger"
            :disabled="acting"
            @click="doAction('cancel')"
          >
            {{ t('purchases.cancel') }}
          </button>
        </div>
      </div>

      <div v-if="order" class="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <div class="stat-card">
          <p class="stat-label">{{ t('products.status') }}</p>
          <StatusBadge :active="order.status === 'completed'" :label="orderStatusLabel(order.status)" />
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
              <th class="px-4 py-3 text-right font-medium">{{ t('sales.qty') }}</th>
              <th class="px-4 py-3 text-right font-medium">{{ t('purchases.unitCost') }}</th>
              <th class="px-4 py-3 text-right font-medium">{{ t('sales.lineTotal') }}</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-slate-100">
            <tr v-for="item in order.items" :key="item.id">
              <td class="px-4 py-3">{{ item.product?.name ?? '—' }}</td>
              <td class="px-4 py-3 text-right">{{ item.quantity }}</td>
              <td class="px-4 py-3 text-right">{{ formatMoney(item.unit_cost) }}</td>
              <td class="px-4 py-3 text-right font-medium">{{ formatMoney(item.line_total) }}</td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
  </AdminLayout>
</template>

<style scoped>
.btn-primary { border-radius: 0.5rem; padding: 0.5rem 1rem; font-weight: 500; color: white; background-color: var(--color-brand-600); }
.btn-secondary { border-radius: 0.5rem; border: 1px solid #cbd5e1; padding: 0.5rem 1rem; }
.btn-danger { border-radius: 0.5rem; padding: 0.5rem 1rem; font-weight: 500; color: white; background-color: #dc2626; }
.stat-card { border-radius: 0.75rem; background: white; padding: 1rem; box-shadow: 0 1px 2px rgb(0 0 0 / 0.05); ring: 1px solid #e2e8f0; }
.stat-label { margin: 0; font-size: 0.75rem; color: #64748b; }
.stat-value { margin: 0.25rem 0 0; font-size: 1.25rem; font-weight: 700; color: #0f172a; }
</style>
