<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import { useConfirm } from '../../../composables/useConfirm'
import CatalogLayout from '../../../components/catalog/CatalogLayout.vue'
import StatusBadge from '../../../components/organization/StatusBadge.vue'
import AppIcon from '../../../components/ui/AppIcon.vue'
import AppModal from '../../../components/ui/AppModal.vue'
import FieldLabel from '../../../components/ui/FieldLabel.vue'
import ModuleFilters from '../../../components/ui/ModuleFilters.vue'
import { extractApiErrorMessage } from '../../../api/client'
import { useBackofficeStore } from '../../../stores/backoffice'
import { useContextStore } from '../../../stores/context'
import type { Catalog } from '../../../types'
import { emptyListFilters, matchesActive, matchesSearch, type ListFilters } from '../../../utils/listFilters'

const { t } = useI18n()
const { confirm: confirmDialog } = useConfirm()
const store = useBackofficeStore()
const context = useContextStore()

const companyId = ref('')
const showModal = ref(false)
const editing = ref<Catalog | null>(null)
const saving = ref(false)
const formError = ref('')
const filters = ref<ListFilters>(emptyListFilters('all'))
const filtered = computed(() => store.catalogs.filter(catalog =>
  matchesSearch(`${catalog.name} ${catalog.description ?? ''}`, filters.value.search)
  && matchesActive(catalog.is_active, filters.value.active),
))
const defaultCount = computed(() => store.catalogs.filter(catalog => catalog.is_default).length)
const form = ref({ name: '', description: '', is_default: true, is_active: true })
const canCreate = computed(() => Boolean(companyId.value))
const cannotUnsetDefault = computed(() => Boolean(editing.value?.is_default && defaultCount.value <= 1))

async function refreshCatalogs() {
  if (!companyId.value) return
  await store.loadCatalogs(companyId.value, context.currentStoreId)
}

onMounted(async () => {
  await context.loadStores()
  await store.loadCompanies()
  if (store.companies.length) companyId.value = store.companies[0].id
})

watch(companyId, (id) => { if (id) void refreshCatalogs() })
watch(() => context.currentStoreId, () => { void refreshCatalogs() })

function openCreate() {
  editing.value = null
  formError.value = ''
  form.value = { name: '', description: '', is_default: defaultCount.value === 0, is_active: true }
  showModal.value = true
}

function openEdit(catalog: Catalog) {
  editing.value = catalog
  formError.value = ''
  form.value = {
    name: catalog.name,
    description: catalog.description ?? '',
    is_default: catalog.is_default,
    is_active: catalog.is_active,
  }
  showModal.value = true
}

async function save() {
  if (!companyId.value) return
  saving.value = true
  formError.value = ''
  try {
    await store.saveCatalog(companyId.value, form.value, editing.value?.id)
    await refreshCatalogs()
    showModal.value = false
  } catch (e) {
    formError.value = extractApiErrorMessage(e, t('common.error'))
  } finally {
    saving.value = false
  }
}

async function remove(catalog: Catalog) {
  if (!(await confirmDialog(t('org.confirmDelete')))) return
  await store.deleteCatalog(catalog.id)
  await refreshCatalogs()
}
</script>

<template>
  <CatalogLayout>
    <div class="space-y-4">
      <div class="flex flex-wrap items-center justify-between gap-4">
        <div class="space-y-1">
          <p class="m-0 text-sm text-slate-500">{{ t('catalog.maxDefaultCatalogsHint') }}</p>
          <select v-model="companyId" class="rounded-lg border border-slate-300 px-3 py-2 text-sm">
            <option v-for="c in store.companies" :key="c.id" :value="c.id">{{ c.name }}</option>
          </select>
        </div>
        <button class="rounded-lg bg-brand-600 px-4 py-2 text-sm text-white" :disabled="!canCreate" @click="openCreate">
          + {{ t('catalog.addCatalog') }}
        </button>
      </div>

      <ModuleFilters v-model="filters" :show-period="false" show-search show-active />

      <div class="overflow-hidden rounded-xl bg-white shadow-sm ring-1 ring-slate-200">
        <table class="min-w-full divide-y divide-slate-200 text-sm">
          <thead class="bg-slate-50">
            <tr>
              <th class="px-4 py-3 text-left font-medium">{{ t('org.name') }}</th>
              <th class="px-4 py-3 text-left font-medium">{{ t('org.description') }}</th>
              <th class="px-4 py-3 text-left font-medium">{{ t('products.status') }}</th>
              <th class="px-4 py-3 text-right">{{ t('common.edit') }}</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-slate-100">
            <tr v-for="catalog in filtered" :key="catalog.id" class="hover:bg-slate-50">
              <td class="px-4 py-3 font-medium">
                {{ catalog.name }}
                <span v-if="catalog.is_default" class="ml-2 rounded bg-slate-100 px-1.5 py-0.5 text-xs text-slate-500">{{ t('catalog.default') }}</span>
              </td>
              <td class="px-4 py-3 text-slate-500">{{ catalog.description || '—' }}</td>
              <td class="px-4 py-3"><StatusBadge :active="catalog.is_active" /></td>
              <td class="px-4 py-3 text-right space-x-2">
                <button class="text-brand-600" @click="openEdit(catalog)">{{ t('common.edit') }}</button>
                <button class="text-red-600" @click="remove(catalog)">{{ t('common.delete') }}</button>
              </td>
            </tr>
            <tr v-if="!filtered.length">
              <td colspan="4" class="px-4 py-8 text-center text-slate-400">{{ t('org.empty') }}</td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>

    <AppModal
      :open="showModal"
      :title="editing ? t('catalog.editCatalog') : t('catalog.addCatalog')"
      icon="catalog"
      @close="showModal = false"
    >
      <form class="space-y-3" @submit.prevent="save">
        <div>
          <FieldLabel icon="account">{{ t('org.name') }}</FieldLabel>
          <input v-model="form.name" required class="field" />
        </div>
        <div>
          <FieldLabel icon="note">{{ t('org.description') }}</FieldLabel>
          <textarea v-model="form.description" rows="2" class="field" />
        </div>
        <label class="flex items-center gap-2 text-sm">
          <input
            v-model="form.is_default"
            type="checkbox"
            class="rounded"
            :disabled="cannotUnsetDefault"
          />
          {{ t('catalog.default') }}
        </label>
        <p v-if="cannotUnsetDefault" class="m-0 text-xs text-slate-500">{{ t('catalog.singleDefaultHint') }}</p>
        <label class="flex items-center gap-2 text-sm">
          <input v-model="form.is_active" type="checkbox" class="rounded" />
          {{ t('products.active') }}
        </label>
        <p v-if="formError" class="m-0 text-sm text-red-600">{{ formError }}</p>
        <div class="app-modal__actions">
          <button type="button" class="btn-secondary" @click="showModal = false">{{ t('common.cancel') }}</button>
          <button type="submit" class="btn-primary" :disabled="saving">
            <AppIcon v-if="saving" name="spinner" :size="14" class="animate-spin" />
            {{ t('common.save') }}
          </button>
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
