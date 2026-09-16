<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { watchLiveSearch } from '../../../composables/useLiveSearch'
import { useI18n } from 'vue-i18n'
import { useConfirm } from '../../../composables/useConfirm'
import InventoryLayout from '../../../components/inventory/InventoryLayout.vue'
import StatusBadge from '../../../components/organization/StatusBadge.vue'
import AppModal from '../../../components/ui/AppModal.vue'
import FieldLabel from '../../../components/ui/FieldLabel.vue'
import { useBackofficeStore } from '../../../stores/backoffice'
import type { Product, Warehouse } from '../../../types'
import { isStockableProduct } from '../../../utils/product'

const { t } = useI18n()
const { confirm: confirmDialog } = useConfirm()
const store = useBackofficeStore()

const products = ref<Product[]>([])
const warehouses = ref<Warehouse[]>([])
const search = ref('')
const status = ref('')
const showModal = ref(false)
const saving = ref(false)
const form = ref({
  product_id: '',
  serial_number: '',
  warehouse_id: '',
  status: 'available',
})

async function load() {
  const params: Record<string, string> = {}
  if (search.value) params.search = search.value
  if (status.value) params.status = status.value
  await store.loadSerialNumbers(params)
}

async function openCreate() {
  if (!products.value.length) products.value = (await store.loadAllProducts()).filter(isStockableProduct)
  if (!warehouses.value.length) warehouses.value = await store.loadAllWarehouses()
  form.value = {
    product_id: products.value[0]?.id ?? '',
    serial_number: '',
    warehouse_id: warehouses.value[0]?.id ?? '',
    status: 'available',
  }
  showModal.value = true
}

async function save() {
  saving.value = true
  try {
    await store.saveSerialNumber({
      product_id: form.value.product_id,
      serial_number: form.value.serial_number,
      warehouse_id: form.value.warehouse_id || null,
      status: form.value.status,
    })
    showModal.value = false
    await load()
  } finally {
    saving.value = false
  }
}

async function remove(id: string) {
  if (!(await confirmDialog(t('org.confirmDelete')))) return
  await store.deleteSerialNumber(id)
  await load()
}

watchLiveSearch([search, status], load)
onMounted(load)
</script>

<template>
  <InventoryLayout>
    <div class="mb-4 flex flex-wrap items-center justify-between gap-3">
      <div class="flex gap-2">
        <input v-model="search" type="search" :placeholder="t('common.search')" class="field" />
        <select v-model="status" class="field">
          <option value="">{{ t('products.status') }}</option>
          <option value="available">available</option>
          <option value="reserved">reserved</option>
          <option value="sold">sold</option>
          <option value="damaged">damaged</option>
          <option value="lost">lost</option>
        </select>
      </div>
      <button class="btn-primary" @click="openCreate">+ {{ t('inventory.addSerial') }}</button>
    </div>

    <div class="overflow-hidden rounded-xl bg-white shadow-sm ring-1 ring-slate-200">
      <table class="min-w-full divide-y text-sm">
        <thead class="bg-slate-50">
          <tr>
            <th class="px-4 py-3 text-left font-medium">{{ t('inventory.serial') }}</th>
            <th class="px-4 py-3 text-left font-medium">{{ t('products.name') }}</th>
            <th class="px-4 py-3 text-left font-medium">{{ t('inventory.warehouse') }}</th>
            <th class="px-4 py-3 text-left font-medium">{{ t('products.status') }}</th>
            <th class="px-4 py-3 text-right">{{ t('common.delete') }}</th>
          </tr>
        </thead>
        <tbody class="divide-y">
          <tr v-for="row in store.serialNumbers" :key="row.id">
            <td class="px-4 py-3 font-mono">{{ row.serial_number }}</td>
            <td class="px-4 py-3">{{ row.product?.name ?? '—' }}</td>
            <td class="px-4 py-3">{{ row.warehouse?.name ?? '—' }}</td>
            <td class="px-4 py-3"><StatusBadge :active="row.status === 'available'" :label="row.status" /></td>
            <td class="px-4 py-3 text-right"><button class="text-red-600" @click="remove(row.id)">{{ t('common.delete') }}</button></td>
          </tr>
        </tbody>
      </table>
      <p v-if="!store.serialNumbers.length" class="px-4 py-8 text-center text-slate-500">{{ t('org.empty') }}</p>
    </div>

    <AppModal
      :open="showModal"
      :title="t('inventory.addSerial')"
      icon="tag"
      tone="info"
      @close="showModal = false"
    >
      <form class="space-y-3" @submit.prevent="save">
        <div>
          <FieldLabel icon="products">{{ t('products.name') }}</FieldLabel>
          <select v-model="form.product_id" required class="field w-full">
            <option v-for="p in products" :key="p.id" :value="p.id">{{ p.name }}</option>
          </select>
        </div>
        <div>
          <FieldLabel icon="tag">{{ t('inventory.serial') }}</FieldLabel>
          <input v-model="form.serial_number" required class="field w-full" />
        </div>
        <div>
          <FieldLabel icon="inventory">{{ t('inventory.warehouse') }}</FieldLabel>
          <select v-model="form.warehouse_id" class="field w-full">
            <option value="">—</option>
            <option v-for="w in warehouses" :key="w.id" :value="w.id">{{ w.name }}</option>
          </select>
        </div>
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
