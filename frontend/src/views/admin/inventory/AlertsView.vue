<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import { extractApiErrorMessage } from '../../../api/client'
import InventoryLayout from '../../../components/inventory/InventoryLayout.vue'
import StatusBadge from '../../../components/organization/StatusBadge.vue'
import ModuleFilters from '../../../components/ui/ModuleFilters.vue'
import ListPager from '../../../components/ui/ListPager.vue'
import { useClientPager } from '../../../composables/useClientPager'
import { useConfirm } from '../../../composables/useConfirm'
import { useBackofficeStore } from '../../../stores/backoffice'
import { useContextStore } from '../../../stores/context'
import type { Warehouse } from '../../../types'
import { formatDate } from '../../../utils/format'
import { emptyListFilters, matchesSearch, type ListFilters } from '../../../utils/listFilters'
import AppIcon from '../../../components/ui/AppIcon.vue'

const { t } = useI18n()
const store = useBackofficeStore()
const context = useContextStore()
const { notify } = useConfirm()
const refreshing = ref(false)
const busyId = ref<string | null>(null)
const warehouses = ref<Warehouse[]>([])
const filters = ref<ListFilters>(emptyListFilters('all'))

const currentWarehouse = computed(() =>
  warehouses.value.find(w => w.store_id && w.store_id === context.currentStoreId) ?? null,
)
const statusOptions = computed(() =>
  ['active', 'acknowledged', 'resolved'].map(value => ({ value, label: statusLabel(value) })),
)
const filtered = computed(() => store.inventoryAlerts.filter(row =>
  matchesSearch(
    `${typeLabel(row.alert_type)} ${row.product?.name ?? ''} ${row.product?.sku ?? ''} ${row.warehouse?.name ?? ''} ${row.message ?? ''}`,
    filters.value.search,
  )
  && (!filters.value.status || row.status === filters.value.status),
))

const { page, lastPage, total, perPage, paged, setPage } = useClientPager(filtered)

function translated(key: string, fallback: string) {
  const value = t(key)
  return value === key ? fallback : value
}

function typeLabel(type: string) {
  return translated(`inventory.alertTypes.${type}`, type)
}

function statusLabel(status: string) {
  return translated(`inventory.alertStatus.${status}`, status)
}

function quantityLabel(row: { quantity_on_hand?: number | null; threshold_value?: number | null }) {
  if (row.quantity_on_hand == null) return '—'
  if (row.threshold_value == null) return String(row.quantity_on_hand)
  return t('inventory.alertQuantity', { qty: row.quantity_on_hand, threshold: row.threshold_value })
}

function load() {
  return store.loadInventoryAlerts(filters.value.status === 'resolved' ? 'resolved' : '')
}

onMounted(async () => {
  await load()
  warehouses.value = await store.loadAllWarehouses()
})

watch(() => filters.value.status, () => {
  void load()
})

async function refresh() {
  refreshing.value = true
  try {
    await store.refreshInventoryAlerts(currentWarehouse.value?.id, filters.value.status === 'resolved' ? 'resolved' : '')
  } catch (error) {
    await notify(extractApiErrorMessage(error))
  } finally {
    refreshing.value = false
  }
}

async function run(id: string, action: (id: string) => Promise<unknown>) {
  busyId.value = id
  try {
    await action(id)
    await load()
  } catch (error) {
    await notify(extractApiErrorMessage(error))
  } finally {
    busyId.value = null
  }
}
</script>

<template>
  <InventoryLayout>
    <div class="mb-4 space-y-3">
      <div class="flex flex-wrap items-center justify-between gap-3">
        <p class="m-0 text-sm text-slate-500">{{ t('inventory.alertsHint') }}</p>
        <button class="btn-secondary" :class="{ 'is-busy': refreshing }" :disabled="refreshing" @click="refresh">
          <AppIcon name="refresh" :size="16" />
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
            <th class="px-4 py-3 text-left font-medium">{{ t('inventory.alertStock') }}</th>
            <th class="px-4 py-3 text-left font-medium">{{ t('products.status') }}</th>
            <th class="px-4 py-3 text-left font-medium">{{ t('inventory.date') }}</th>
            <th class="px-4 py-3 text-right font-medium">{{ t('common.actions') }}</th>
          </tr>
        </thead>
        <tbody class="divide-y divide-slate-100">
          <tr v-for="row in paged" :key="row.id" class="hover:bg-slate-50">
            <td class="px-4 py-3">
              <span class="alert-type" :class="`alert-type--${row.alert_type.toLowerCase()}`">{{ typeLabel(row.alert_type) }}</span>
            </td>
            <td class="px-4 py-3">
              <span class="block font-medium">{{ row.product?.name ?? '—' }}</span>
              <span v-if="row.product?.sku" class="text-xs text-slate-500">{{ row.product.sku }}</span>
            </td>
            <td class="px-4 py-3">{{ row.warehouse?.name ?? '—' }}</td>
            <td class="whitespace-nowrap px-4 py-3 font-mono">{{ quantityLabel(row) }}</td>
            <td class="px-4 py-3"><StatusBadge :active="row.status === 'resolved'" :label="statusLabel(row.status)" /></td>
            <td class="px-4 py-3 text-slate-500">{{ formatDate(row.created_at) }}</td>
            <td class="px-4 py-3">
              <div v-if="row.status !== 'resolved'" class="row-actions">
                <button
                  v-if="row.status === 'active'"
                  class="row-action row-action--edit"
                  :disabled="busyId === row.id"
                  :title="t('inventory.acknowledgeHint')"
                  @click="run(row.id, store.acknowledgeInventoryAlert)"
                >
                  <AppIcon name="eye" :size="16" /> {{ t('inventory.acknowledge') }}
                </button>
                <button
                  class="row-action row-action--approve"
                  :disabled="busyId === row.id"
                  :title="t('inventory.resolveHint')"
                  @click="run(row.id, store.resolveInventoryAlert)"
                >
                  <AppIcon name="check" :size="16" /> {{ t('inventory.resolve') }}
                </button>
              </div>
            </td>
          </tr>
        </tbody>
      </table>
      <p v-if="!filtered.length" class="px-4 py-8 text-center text-slate-500">{{ t('org.empty') }}</p>
      <ListPager
        :page="page"
        :last-page="lastPage"
        :total="total"
        :per-page="perPage"
        @change="setPage"
      />
    </div>
  </InventoryLayout>
</template>

<style scoped>
.alert-type {
  display: inline-flex;
  align-items: center;
  padding: 0.15rem 0.55rem;
  border-radius: 999px;
  font-size: 0.75rem;
  font-weight: 600;
  white-space: nowrap;
  background: var(--color-brand-50);
  color: var(--color-ink-brand, var(--color-brand-700));
}
.alert-type--out_of_stock,
.alert-type--expired {
  background: var(--color-danger-bg);
  color: light-dark(#b91c1c, #f6c2be);
}
.alert-type--low_stock,
.alert-type--expiring_soon {
  background: var(--color-warning-bg);
  color: light-dark(var(--color-warning), #f3cf94);
}
</style>
