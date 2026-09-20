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
import type { Category } from '../../../types'
import { emptyListFilters, matchesActive, matchesSearch, type ListFilters } from '../../../utils/listFilters'

const { t } = useI18n()
const { confirm: confirmDialog } = useConfirm()
const store = useBackofficeStore()
const context = useContextStore()

const companyId = ref('')
const catalogId = ref('')
const showModal = ref(false)
const editing = ref<Category | null>(null)
const saving = ref(false)
const form = ref({ name: '', slug: '', parent_id: '' as string | null, sort_order: 0, is_active: true })
const storeIds = ref<string[]>([])

function defaultStoreIds() {
  return context.currentStoreId ? [context.currentStoreId] : context.activeStores.map(store => store.id)
}

async function resolveCatalog() {
  if (!companyId.value) return
  const catalogs = await store.loadCatalogs(companyId.value, context.currentStoreId)
  catalogId.value = catalogs.find(c => c.is_default)?.id ?? catalogs[0]?.id ?? ''
}

async function refreshCategories() {
  if (!catalogId.value || !context.currentStoreId) return
  await store.loadCategories(catalogId.value, context.currentStoreId)
}

onMounted(async () => {
  await context.loadStores()
  await store.loadCompanies()
  if (store.companies.length) {
    companyId.value = store.companies[0].id
    await resolveCatalog()
  }
})

watch(companyId, async (id) => {
  if (!id) return
  await resolveCatalog()
})

watch(() => context.currentStoreId, async () => {
  await resolveCatalog()
})

watch([catalogId, () => context.currentStoreId], () => { void refreshCategories() })

const flatCategories = computed(() => {
  const result: (Category & { depth: number })[] = []
  function walk(items: Category[], depth = 0) {
    for (const item of items) {
      result.push({ ...item, depth })
      if (item.children?.length) walk(item.children, depth + 1)
    }
  }
  walk(store.categories)
  return result
})

const filters = ref<ListFilters>(emptyListFilters('all'))
const filteredCategories = computed(() => flatCategories.value.filter(cat =>
  matchesSearch(`${cat.name} ${cat.slug}`, filters.value.search)
  && matchesActive(cat.is_active, filters.value.active),
))

function openCreate() {
  editing.value = null
  form.value = { name: '', slug: '', parent_id: null, sort_order: 0, is_active: true }
  storeIds.value = defaultStoreIds()
  showModal.value = true
}

function openEdit(category: Category) {
  editing.value = category
  form.value = {
    name: category.name,
    slug: category.slug,
    parent_id: category.parent_id ?? null,
    sort_order: category.sort_order,
    is_active: category.is_active,
  }
  storeIds.value = category.store_id ? [category.store_id] : defaultStoreIds()
  showModal.value = true
}

async function save() {
  if (!catalogId.value || !storeIds.value.length) return
  saving.value = true
  try {
    await store.saveCategory(catalogId.value, {
      ...form.value,
      parent_id: form.value.parent_id || null,
      store_ids: storeIds.value,
    }, editing.value?.id)
    await refreshCategories()
    showModal.value = false
  } finally {
    saving.value = false
  }
}

async function remove(category: Category) {
  if (!(await confirmDialog(t('org.confirmDelete')))) return
  await store.deleteCategory(category.id)
  await refreshCategories()
}
</script>

<template>
  <CatalogLayout>
    <div class="space-y-4">
      <div class="flex flex-wrap items-center justify-between gap-4">
        <div class="flex flex-col gap-1">
          <div class="flex gap-3">
            <select v-model="companyId" class="rounded-lg border border-slate-300 px-3 py-2 text-sm">
              <option v-for="c in store.companies" :key="c.id" :value="c.id">{{ c.name }}</option>
            </select>
            <select v-model="catalogId" class="rounded-lg border border-slate-300 px-3 py-2 text-sm">
              <option v-for="c in store.catalogs" :key="c.id" :value="c.id">{{ c.name }}</option>
            </select>
          </div>
          <p class="m-0 text-xs text-slate-500">{{ t('catalog.storeScopedHint') }}</p>
        </div>
        <button class="rounded-lg bg-brand-600 px-4 py-2 text-sm text-white" :disabled="!context.activeStores.length" @click="openCreate">
          + {{ t('catalog.addCategory') }}
        </button>
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
            <tr v-for="cat in filteredCategories" :key="cat.id" class="hover:bg-slate-50">
              <td class="px-4 py-3 font-medium" :style="{ paddingLeft: `${1 + cat.depth}rem` }">
                {{ cat.depth ? '↳ ' : '' }}{{ cat.name }}
              </td>
              <td class="px-4 py-3 font-mono text-slate-500">{{ cat.slug }}</td>
              <td class="px-4 py-3"><StatusBadge :active="cat.is_active" /></td>
              <td class="px-4 py-3 text-right space-x-2">
                <button class="text-brand-600" @click="openEdit(cat)">{{ t('common.edit') }}</button>
                <button class="text-red-600" @click="remove(cat)">{{ t('common.delete') }}</button>
              </td>
            </tr>
          </tbody>
        </table>
        <p v-if="!filteredCategories.length" class="px-4 py-8 text-center text-slate-500">{{ t('org.empty') }}</p>
      </div>
    </div>

    <AppModal
      :open="showModal"
      :title="editing ? t('catalog.editCategory') : t('catalog.addCategory')"
      icon="layers"
      tone="info"
      @close="showModal = false"
    >
      <form class="space-y-3" @submit.prevent="save">
        <div>
          <FieldLabel icon="account">{{ t('org.name') }}</FieldLabel>
          <input v-model="form.name" required class="field" />
        </div>
        <div>
          <FieldLabel icon="tag">Slug</FieldLabel>
          <input v-model="form.slug" class="field" />
        </div>
        <div>
          <FieldLabel icon="layers">{{ t('catalog.parent') }}</FieldLabel>
          <select v-model="form.parent_id" class="field">
            <option :value="null">—</option>
            <option v-for="cat in flatCategories.filter(c => c.id !== editing?.id)" :key="cat.id" :value="cat.id">
              {{ '  '.repeat(cat.depth) }}{{ cat.name }}
            </option>
          </select>
        </div>
        <StoreMultiSelect v-model="storeIds" />
        <p v-if="!storeIds.length" class="m-0 text-xs text-red-600">{{ t('catalog.selectStoresRequired') }}</p>
        <label class="flex items-center gap-2 text-sm">
          <span class="field-icon"><AppIcon name="check" :size="14" /></span>
          <input v-model="form.is_active" type="checkbox" class="rounded" />
          {{ t('products.active') }}
        </label>
        <div class="app-modal__actions">
          <button type="button" class="btn-secondary" @click="showModal = false">{{ t('common.cancel') }}</button>
          <button type="submit" class="btn-primary" :disabled="saving || !storeIds.length">{{ t('common.save') }}</button>
        </div>
      </form>
    </AppModal>
  </CatalogLayout>
</template>

<style scoped>
.field { width: 100%; border-radius: 0.5rem; border: 1px solid #cbd5e1; padding: 0.5rem 0.75rem; }
.btn-primary { border-radius: 0.5rem; padding: 0.5rem 1rem; font-weight: 500; color: white; background-color: var(--color-brand-600); }
.btn-secondary { border-radius: 0.5rem; border: 1px solid #cbd5e1; padding: 0.5rem 1rem; }
.bg-brand-600 { background-color: var(--color-brand-600); }
.text-brand-600 { color: var(--color-brand-600); }
</style>
