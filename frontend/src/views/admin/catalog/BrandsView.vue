<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import { useConfirm } from '../../../composables/useConfirm'
import CatalogLayout from '../../../components/catalog/CatalogLayout.vue'
import StoreMultiSelect from '../../../components/catalog/StoreMultiSelect.vue'
import StatusBadge from '../../../components/organization/StatusBadge.vue'
import AppIcon from '../../../components/ui/AppIcon.vue'
import AppModal from '../../../components/ui/AppModal.vue'
import FieldLabel from '../../../components/ui/FieldLabel.vue'
import ModuleFilters from '../../../components/ui/ModuleFilters.vue'
import { useBackofficeStore } from '../../../stores/backoffice'
import { useContextStore } from '../../../stores/context'
import type { Brand } from '../../../types'
import { emptyListFilters, matchesActive, matchesSearch, type ListFilters } from '../../../utils/listFilters'

const { t } = useI18n()
const { confirm: confirmDialog } = useConfirm()
const store = useBackofficeStore()
const context = useContextStore()
const showModal = ref(false)
const editing = ref<Brand | null>(null)
const saving = ref(false)
const filters = ref<ListFilters>(emptyListFilters('all'))
const filtered = computed(() => store.brands.filter(brand =>
  matchesSearch(`${brand.name} ${brand.slug}`, filters.value.search)
  && matchesActive(brand.is_active, filters.value.active),
))
const form = ref({ name: '', slug: '', description: '', is_active: true })
const storeIds = ref<string[]>([])

function defaultStoreIds() {
  return context.currentStoreId ? [context.currentStoreId] : context.activeStores.map(store => store.id)
}

async function refreshBrands() {
  if (!context.currentStoreId) return
  await store.loadBrands(context.currentStoreId)
}

onMounted(async () => {
  await context.loadStores()
  await refreshBrands()
})

watch(() => context.currentStoreId, () => { void refreshBrands() })

function openCreate() {
  editing.value = null
  form.value = { name: '', slug: '', description: '', is_active: true }
  storeIds.value = defaultStoreIds()
  showModal.value = true
}

function openEdit(brand: Brand) {
  editing.value = brand
  form.value = { name: brand.name, slug: brand.slug, description: brand.description ?? '', is_active: brand.is_active }
  storeIds.value = brand.store_id ? [brand.store_id] : defaultStoreIds()
  showModal.value = true
}

async function save() {
  if (!storeIds.value.length) return
  saving.value = true
  try {
    await store.saveBrand({
      ...form.value,
      store_ids: storeIds.value,
    }, editing.value?.id)
    await refreshBrands()
    showModal.value = false
  } finally {
    saving.value = false
  }
}

async function remove(brand: Brand) {
  if (!(await confirmDialog(t('org.confirmDelete')))) return
  await store.deleteBrand(brand.id)
  await refreshBrands()
}
</script>

<template>
  <CatalogLayout>
    <div class="space-y-4">
      <div class="flex flex-wrap items-center justify-between gap-3">
        <p class="m-0 text-sm text-slate-500">{{ t('catalog.storeScopedHint') }}</p>
        <button class="rounded-lg bg-brand-600 px-4 py-2 text-sm text-white" :disabled="!context.activeStores.length" @click="openCreate">+ {{ t('catalog.addBrand') }}</button>
      </div>
      <ModuleFilters v-model="filters" :show-period="false" show-search show-active />
      <div class="overflow-hidden rounded-xl bg-white shadow-sm ring-1 ring-slate-200">
        <table class="min-w-full divide-y divide-slate-200 text-sm">
          <thead class="bg-slate-50">
            <tr>
              <th class="px-4 py-3 text-left font-medium">{{ t('org.name') }}</th>
              <th class="px-4 py-3 text-left font-medium">Slug</th>
              <th class="px-4 py-3 text-left font-medium">{{ t('products.status') }}</th>
              <th class="px-4 py-3 text-right">{{ t('common.edit') }}</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-slate-100">
            <tr v-for="brand in filtered" :key="brand.id" class="hover:bg-slate-50">
              <td class="px-4 py-3 font-medium">{{ brand.name }}</td>
              <td class="px-4 py-3 font-mono text-slate-500">{{ brand.slug }}</td>
              <td class="px-4 py-3"><StatusBadge :active="brand.is_active" /></td>
              <td class="px-4 py-3 text-right space-x-2">
                <button class="text-brand-600" @click="openEdit(brand)">{{ t('common.edit') }}</button>
                <button class="text-red-600" @click="remove(brand)">{{ t('common.delete') }}</button>
              </td>
            </tr>
          </tbody>
        </table>
        <p v-if="!filtered.length" class="px-4 py-8 text-center text-slate-500">{{ t('org.empty') }}</p>
      </div>
    </div>

    <AppModal
      :open="showModal"
      :title="editing ? t('catalog.editBrand') : t('catalog.addBrand')"
      icon="sparkles"
      tone="accent"
      @close="showModal = false"
    >
      <form class="space-y-3" @submit.prevent="save">
        <div>
          <FieldLabel icon="tag">{{ t('org.name') }}</FieldLabel>
          <input v-model="form.name" required class="field" />
        </div>
        <div>
          <FieldLabel icon="layers">Slug</FieldLabel>
          <input v-model="form.slug" class="field font-mono" />
        </div>
        <div>
          <FieldLabel icon="note">{{ t('org.description') }}</FieldLabel>
          <textarea v-model="form.description" rows="2" class="field" />
        </div>
        <StoreMultiSelect v-model="storeIds" />
        <p v-if="!storeIds.length" class="m-0 text-xs text-red-600">{{ t('catalog.selectStoresRequired') }}</p>
        <label class="flex items-center gap-2 text-sm">
          <input v-model="form.is_active" type="checkbox" class="rounded border-slate-300" />
          {{ t('products.active') }}
        </label>
        <div class="flex justify-end gap-2 pt-2">
          <button type="button" class="rounded-lg border border-slate-300 px-4 py-2 text-sm" @click="showModal = false">{{ t('common.cancel') }}</button>
          <button type="submit" class="rounded-lg bg-brand-600 px-4 py-2 text-sm text-white" :disabled="saving || !storeIds.length">
            <AppIcon v-if="saving" name="spinner" :size="14" class="inline animate-spin" />
            {{ t('common.save') }}
          </button>
        </div>
      </form>
    </AppModal>
  </CatalogLayout>
</template>
