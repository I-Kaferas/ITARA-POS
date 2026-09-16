<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import InventoryLayout from '../../../components/inventory/InventoryLayout.vue'
import StatusBadge from '../../../components/organization/StatusBadge.vue'
import ModuleFilters from '../../../components/ui/ModuleFilters.vue'
import { useBackofficeStore } from '../../../stores/backoffice'
import { formatDate } from '../../../utils/format'
import { emptyListFilters, matchesSearch, type ListFilters } from '../../../utils/listFilters'

const { t } = useI18n()
const store = useBackofficeStore()
const refreshing = ref(false)
const filters = ref<ListFilters>(emptyListFilters('all'))
const statusOptions = [
  { value: 'open', label: 'open' },
  { value: 'acknowledged', label: 'acknowledged' },
  { value: 'resolved', label: 'resolved' },
]
const filtered = computed(() => store.inventoryAlerts.filter(row =>
  matchesSearch(
    `${row.alert_type} ${row.product?.name ?? ''} ${row.product?.sku ?? ''} ${row.warehouse?.name ?? ''} ${row.message ?? ''}`,
    filters.value.search,
  )
  && (!filters.value.status || row.status === filters.value.status),
))

onMounted(() => store.loadInventoryAlerts())

async function refresh() {
  refreshing.value = true
  try {
    await store.refreshInventoryAlerts()
  } finally {
    refreshing.value = false
  }
}

async function acknowledge(id: string) {
  await store.acknowledgeInventoryAlert(id)
  await store.loadInventoryAlerts()
}

async function resolve(id: string) {
  await store.resolveInventoryAlert(id)
  await store.loadInventoryAlerts()
}
</script>

<template>
  <InventoryLayout>
    <div class="mb-4 space-y-3">
      <div class="flex justify-end">
        <button class="btn-secondary" :disabled="refreshing" @click="refresh">
          {{ t('inventory.refreshAlerts') }}
        </button>
      </div>
      <ModuleFilters
        v-model="filters"
        :statuses="statusOptions"
        :show-period="false"
        show-search
        show-status
      />
    </div>

    <div class="overflow-hidden rounded-xl bg-white shadow-sm ring-1 ring-slate-200">
      <table class="min-w-full divide-y divide-slate-200 text-sm">
        <thead class="bg-slate-50">
          <tr>
            <th class="px-4 py-3 text-left font-medium">{{ t('inventory.alertType') }}</th>
            <th class="px-4 py-3 text-left font-medium">{{ t('products.name') }}</th>
            <th class="px-4 py-3 text-left font-medium">{{ t('inventory.warehouse') }}</th>
            <th class="px-4 py-3 text-left font-medium">{{ t('products.status') }}</th>
            <th class="px-4 py-3 text-left font-medium">{{ t('inventory.date') }}</th>
            <th class="px-4 py-3 text-right font-medium">{{ t('common.edit') }}</th>
          </tr>
        </thead>
        <tbody class="divide-y divide-slate-100">
          <tr v-for="row in filtered" :key="row.id" class="hover:bg-slate-50">
            <td class="px-4 py-3">{{ row.alert_type }}</td>
            <td class="px-4 py-3 font-medium">{{ row.product?.name ?? '—' }}</td>
            <td class="px-4 py-3">{{ row.warehouse?.name ?? '—' }}</td>
            <td class="px-4 py-3"><StatusBadge :active="row.status === 'resolved'" :label="row.status" /></td>
            <td class="px-4 py-3 text-slate-500">{{ formatDate(row.created_at) }}</td>
            <td class="px-4 py-3 space-x-2 text-right">
              <button v-if="row.status === 'open'" class="text-brand-600" @click="acknowledge(row.id)">
                {{ t('inventory.acknowledge') }}
              </button>
              <button v-if="row.status !== 'resolved'" class="text-emerald-600" @click="resolve(row.id)">
                {{ t('inventory.resolve') }}
              </button>
            </td>
          </tr>
        </tbody>
      </table>
      <p v-if="!filtered.length" class="px-4 py-8 text-center text-slate-500">{{ t('org.empty') }}</p>
    </div>
  </InventoryLayout>
</template>

<style scoped>
.btn-secondary { border-radius: 0.5rem; border: 1px solid #cbd5e1; padding: 0.5rem 1rem; }
.text-brand-600 { color: var(--color-brand-600); }
.text-emerald-600 { color: #059669; }
</style>
