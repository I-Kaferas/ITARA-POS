<script setup lang="ts">
import { onMounted, ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import AdminLayout from '../../components/layout/AdminLayout.vue'
import AppModal from '../../components/ui/AppModal.vue'
import { useBackofficeStore } from '../../stores/backoffice'
import { useContextStore } from '../../stores/context'
import type { Product, StoreProductItem } from '../../types'

const { t } = useI18n()
const store = useBackofficeStore()
const context = useContextStore()

const catalogId = ref('')
const availableProducts = ref<Product[]>([])
const selectedIds = ref<string[]>([])
const importing = ref(false)
const editingItem = ref<StoreProductItem | null>(null)
const priceOverride = ref<number | null>(null)

onMounted(async () => {
  await context.loadStores()
  await store.loadCompanies()
  if (!store.companies.length) return

  const catalogs = await store.loadCatalogs(store.companies[0].id)
  catalogId.value = catalogs.find(c => c.is_default)?.id ?? catalogs[0]?.id ?? ''
  if (catalogId.value) {
    availableProducts.value = await store.loadProducts(catalogId.value)
  }

  if (context.currentStoreId) {
    await store.loadStoreProducts(context.currentStoreId)
  }
})

watch(() => context.currentStoreId, async (id) => {
  if (id) await store.loadStoreProducts(id)
})

const importedIds = () => new Set(store.storeProducts.map(sp => sp.product_id))
const notImported = () => availableProducts.value.filter(p => !importedIds().has(p.id))

function toggle(id: string) {
  selectedIds.value = selectedIds.value.includes(id)
    ? selectedIds.value.filter(x => x !== id)
    : [...selectedIds.value, id]
}

async function importSelected() {
  if (!context.currentStoreId || !selectedIds.value.length) return
  importing.value = true
  try {
    await store.importToStore(context.currentStoreId, selectedIds.value)
    selectedIds.value = []
    await store.loadStoreProducts(context.currentStoreId)
  } finally {
    importing.value = false
  }
}

async function remove(productId: string) {
  if (!context.currentStoreId) return
  await store.removeFromStore(context.currentStoreId, productId)
  await store.loadStoreProducts(context.currentStoreId)
}

function openPriceEdit(item: StoreProductItem) {
  editingItem.value = item
  priceOverride.value = item.price_override != null ? item.price_override / 100 : null
}

async function savePriceOverride() {
  if (!context.currentStoreId || !editingItem.value) return
  await store.updateStoreProduct(context.currentStoreId, editingItem.value.product_id, {
    price_override: priceOverride.value != null ? Math.round(priceOverride.value * 100) : null,
  })
  editingItem.value = null
  await store.loadStoreProducts(context.currentStoreId)
}

function formatPrice(cents: number) {
  return (cents / 100).toFixed(2)
}
</script>

<template>
  <AdminLayout>
    <template #title>{{ t('stores.title') }}</template>

    <p v-if="context.currentStore" class="mb-6 text-sm text-slate-600">
      {{ t('context.currentStore') }} :
      <strong>{{ context.storeLabel(context.currentStore) }}</strong>
    </p>
    <p v-else class="mb-6 rounded-lg bg-amber-50 px-4 py-3 text-sm text-amber-800">
      {{ t('org.empty') }}
    </p>

    <div class="grid gap-8 lg:grid-cols-2">
      <div class="rounded-xl bg-white p-6 shadow-sm ring-1 ring-slate-200">
        <h3 class="mb-4 font-semibold">{{ t('stores.importFromCatalog') }}</h3>
        <div class="max-h-96 space-y-2 overflow-y-auto">
          <label v-for="product in notImported()" :key="product.id" class="flex cursor-pointer items-center gap-3 rounded-lg border border-slate-200 px-3 py-2 hover:bg-slate-50">
            <input type="checkbox" :checked="selectedIds.includes(product.id)" @change="toggle(product.id)" />
            <div>
              <p class="font-medium">{{ product.name }}</p>
              <p class="text-xs text-slate-500">{{ product.sku }} — {{ formatPrice(product.base_price) }}</p>
            </div>
          </label>
          <p v-if="!notImported().length" class="text-sm text-slate-500">{{ t('stores.allImported') }}</p>
        </div>
        <button class="btn-primary mt-4 w-full" :disabled="!selectedIds.length || importing" @click="importSelected">
          {{ importing ? t('common.loading') : t('stores.importSelected') }}
        </button>
      </div>

      <div class="rounded-xl bg-white p-6 shadow-sm ring-1 ring-slate-200">
        <h3 class="mb-4 font-semibold">{{ t('stores.imported') }} ({{ store.storeProducts.length }})</h3>
        <div class="max-h-96 space-y-2 overflow-y-auto">
          <div v-for="item in store.storeProducts" :key="item.id" class="flex items-center justify-between rounded-lg border border-slate-200 px-3 py-2">
            <div>
              <p class="font-medium">{{ item.product.name }}</p>
              <p class="text-xs text-slate-500">
                {{ formatPrice(item.effective_price) }}
                <span v-if="item.price_override" class="text-brand-600">({{ t('stores.override') }})</span>
              </p>
            </div>
            <div class="flex gap-2">
              <button class="text-sm text-brand-600" @click="openPriceEdit(item)">{{ t('products.price') }}</button>
              <button class="text-sm text-red-600" @click="remove(item.product_id)">{{ t('common.delete') }}</button>
            </div>
          </div>
          <p v-if="!store.storeProducts.length" class="text-sm text-slate-500">{{ t('stores.none') }}</p>
        </div>
      </div>
    </div>

    <AppModal
      :open="!!editingItem"
      :title="t('stores.priceOverride')"
      icon="coins"
      tone="accent"
      @close="editingItem = null"
    >
      <form class="space-y-3" @submit.prevent="savePriceOverride">
        <p class="text-sm text-slate-600">{{ editingItem?.product.name }}</p>
        <input v-model.number="priceOverride" type="number" step="0.01" min="0" class="field" :placeholder="t('stores.leaveEmptyForDefault')" />
        <div class="app-modal__actions">
          <button type="button" class="btn-secondary" @click="editingItem = null">{{ t('common.cancel') }}</button>
          <button type="submit" class="btn-primary">{{ t('common.save') }}</button>
        </div>
      </form>
    </AppModal>
  </AdminLayout>
</template>

<style scoped>
.field { width: 100%; border-radius: 0.5rem; border: 1px solid #cbd5e1; padding: 0.5rem 0.75rem; }
.btn-primary { width: 100%; margin-top: 1rem; border-radius: 0.5rem; padding: 0.5rem; font-weight: 500; color: white; background-color: var(--color-brand-600); }
.btn-primary:disabled { opacity: 0.5; }
.btn-secondary { border-radius: 0.5rem; border: 1px solid #cbd5e1; padding: 0.5rem 1rem; }
.text-brand-600 { color: var(--color-brand-600); }
</style>
