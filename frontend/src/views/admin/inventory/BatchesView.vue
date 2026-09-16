<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import InventoryLayout from '../../../components/inventory/InventoryLayout.vue'
import AppModal from '../../../components/ui/AppModal.vue'
import FieldLabel from '../../../components/ui/FieldLabel.vue'
import ModuleFilters from '../../../components/ui/ModuleFilters.vue'
import { useBackofficeStore } from '../../../stores/backoffice'
import type { Product, Warehouse } from '../../../types'
import { isStockableProduct } from '../../../utils/product'
import { formatDate, formatMoney } from '../../../utils/format'
import { emptyListFilters, matchesSearch, type ListFilters } from '../../../utils/listFilters'

const { t } = useI18n()
const store = useBackofficeStore()

const products = ref<Product[]>([])
const warehouses = ref<Warehouse[]>([])
const productId = ref('')
const showModal = ref(false)
const saving = ref(false)
const filters = ref<ListFilters>(emptyListFilters('all'))
const filtered = computed(() => store.productBatches.filter(row =>
  matchesSearch(`${row.batch_number} ${row.expires_at ?? ''} ${row.unit_cost ?? ''}`, filters.value.search),
))
const form = ref({
  batch_number: '',
  quantity: 1,
  warehouse_id: '',
  expires_at: '',
  unit_cost: 0,
})

onMounted(async () => {
  products.value = (await store.loadAllProducts()).filter(isStockableProduct)
  warehouses.value = await store.loadAllWarehouses()
  productId.value = products.value[0]?.id ?? ''
})

watch(productId, async (id) => {
  if (id) await store.loadProductBatches(id)
})

function openCreate() {
  form.value = {
    batch_number: '',
    quantity: 1,
    warehouse_id: warehouses.value[0]?.id ?? '',
    expires_at: '',
    unit_cost: 0,
  }
  showModal.value = true
}

async function save() {
  if (!productId.value) return
  saving.value = true
  try {
    await store.createProductBatch(productId.value, {
      batch_number: form.value.batch_number,
      quantity: form.value.quantity,
      warehouse_id: form.value.warehouse_id || undefined,
      expires_at: form.value.expires_at || undefined,
      unit_cost: form.value.unit_cost || undefined,
    })
    showModal.value = false
    await store.loadProductBatches(productId.value)
  } finally {
    saving.value = false
  }
}
</script>

<template>
  <InventoryLayout>
    <div class="mb-4 flex flex-wrap items-end justify-between gap-3">
      <div>
        <FieldLabel icon="products">{{ t('products.name') }}</FieldLabel>
        <select v-model="productId" class="field min-w-64">
          <option v-for="p in products" :key="p.id" :value="p.id">{{ p.sku }} — {{ p.name }}</option>
        </select>
      </div>
      <button class="btn-primary" :disabled="!productId" @click="openCreate">+ {{ t('inventory.addBatch') }}</button>
    </div>

    <ModuleFilters v-model="filters" class="mb-4" :show-period="false" show-search />

    <div class="overflow-hidden rounded-xl bg-white shadow-sm ring-1 ring-slate-200">
      <table class="min-w-full divide-y text-sm">
        <thead class="bg-slate-50">
          <tr>
            <th class="px-4 py-3 text-left font-medium">{{ t('inventory.batch') }}</th>
            <th class="px-4 py-3 text-left font-medium">{{ t('inventory.expires') }}</th>
            <th class="px-4 py-3 text-right font-medium">{{ t('purchases.unitCost') }}</th>
            <th class="px-4 py-3 text-left font-medium">{{ t('inventory.date') }}</th>
          </tr>
        </thead>
        <tbody class="divide-y">
          <tr v-for="row in filtered" :key="row.id">
            <td class="px-4 py-3 font-mono">{{ row.batch_number }}</td>
            <td class="px-4 py-3">{{ formatDate(row.expires_at) }}</td>
            <td class="px-4 py-3 text-right">{{ row.unit_cost != null ? formatMoney(row.unit_cost) : '—' }}</td>
            <td class="px-4 py-3 text-slate-500">{{ formatDate(row.received_at) }}</td>
          </tr>
        </tbody>
      </table>
      <p v-if="!filtered.length" class="px-4 py-8 text-center text-slate-500">{{ t('org.empty') }}</p>
    </div>

    <AppModal
      :open="showModal"
      :title="t('inventory.addBatch')"
      icon="package"
      tone="info"
      @close="showModal = false"
    >
      <form class="space-y-3" @submit.prevent="save">
        <div><FieldLabel icon="tag">{{ t('inventory.batch') }}</FieldLabel><input v-model="form.batch_number" required class="field w-full" /></div>
        <div><FieldLabel icon="package">{{ t('sales.qty') }}</FieldLabel><input v-model.number="form.quantity" type="number" min="1" class="field w-full" /></div>
        <div>
          <FieldLabel icon="inventory">{{ t('inventory.warehouse') }}</FieldLabel>
          <select v-model="form.warehouse_id" class="field w-full">
            <option v-for="w in warehouses" :key="w.id" :value="w.id">{{ w.name }}</option>
          </select>
        </div>
        <div><FieldLabel icon="calendar">{{ t('inventory.expires') }}</FieldLabel><input v-model="form.expires_at" type="date" class="field w-full" /></div>
        <div class="app-modal__actions">
          <button type="button" class="btn-secondary" @click="showModal = false">{{ t('common.cancel') }}</button>
          <button type="submit" class="btn-primary" :disabled="saving">{{ t('common.save') }}</button>
        </div>
      </form>
    </AppModal>
  </InventoryLayout>
</template>

<style scoped>
.field { border-radius: 0.5rem; border: 1px solid #cbd5e1; padding: 0.5rem 0.75rem; }
.btn-primary { border-radius: 0.5rem; padding: 0.5rem 1rem; font-weight: 500; color: white; background-color: var(--color-brand-600); }
.btn-secondary { border-radius: 0.5rem; border: 1px solid #cbd5e1; padding: 0.5rem 1rem; }
</style>
