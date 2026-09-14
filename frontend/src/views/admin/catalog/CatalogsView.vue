<script setup lang="ts">
import { onMounted, ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import { useConfirm } from '../../../composables/useConfirm'
import CatalogLayout from '../../../components/catalog/CatalogLayout.vue'
import StatusBadge from '../../../components/organization/StatusBadge.vue'
import AppIcon from '../../../components/ui/AppIcon.vue'
import AppModal from '../../../components/ui/AppModal.vue'
import FieldLabel from '../../../components/ui/FieldLabel.vue'
import { useBackofficeStore } from '../../../stores/backoffice'
import type { Catalog } from '../../../types'

const { t } = useI18n()
const { confirm: confirmDialog } = useConfirm()
const store = useBackofficeStore()

const companyId = ref('')
const showModal = ref(false)
const editing = ref<Catalog | null>(null)
const saving = ref(false)
const form = ref({ name: '', description: '', is_default: false, is_active: true })

onMounted(async () => {
  await store.loadCompanies()
  if (store.companies.length) companyId.value = store.companies[0].id
})

watch(companyId, (id) => { if (id) store.loadCatalogs(id) })

function openCreate() {
  editing.value = null
  form.value = { name: '', description: '', is_default: false, is_active: true }
  showModal.value = true
}

function openEdit(catalog: Catalog) {
  editing.value = catalog
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
  try {
    await store.saveCatalog(companyId.value, form.value, editing.value?.id)
    await store.loadCatalogs(companyId.value)
    showModal.value = false
  } finally {
    saving.value = false
  }
}

async function remove(catalog: Catalog) {
  if (!(await confirmDialog(t('org.confirmDelete')))) return
  await store.deleteCatalog(catalog.id)
  await store.loadCatalogs(companyId.value)
}
</script>

<template>
  <CatalogLayout>
    <div class="space-y-4">
      <div class="flex flex-wrap items-center justify-between gap-4">
        <select v-model="companyId" class="rounded-lg border border-slate-300 px-3 py-2 text-sm">
          <option v-for="c in store.companies" :key="c.id" :value="c.id">{{ c.name }}</option>
        </select>
        <button class="rounded-lg bg-brand-600 px-4 py-2 text-sm text-white" @click="openCreate">
          + {{ t('catalog.addCatalog') }}
        </button>
      </div>

      <div class="overflow-hidden rounded-xl bg-white shadow-sm ring-1 ring-slate-200">
        <table class="min-w-full divide-y divide-slate-200 text-sm">
          <thead class="bg-slate-50">
            <tr>
              <th class="px-4 py-3 text-left font-medium">{{ t('org.name') }}</th>
              <th class="px-4 py-3 text-left font-medium">{{ t('products.description') }}</th>
              <th class="px-4 py-3 text-left font-medium">{{ t('catalog.default') }}</th>
              <th class="px-4 py-3 text-left font-medium">{{ t('products.status') }}</th>
              <th class="px-4 py-3 text-right">{{ t('common.edit') }}</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-slate-100">
            <tr v-for="catalog in store.catalogs" :key="catalog.id" class="hover:bg-slate-50">
              <td class="px-4 py-3 font-medium">{{ catalog.name }}</td>
              <td class="px-4 py-3 text-slate-500">{{ catalog.description || '—' }}</td>
              <td class="px-4 py-3">{{ catalog.is_default ? '★' : '—' }}</td>
              <td class="px-4 py-3"><StatusBadge :active="catalog.is_active" /></td>
              <td class="px-4 py-3 text-right space-x-2">
                <button class="text-brand-600 hover:text-brand-700" @click="openEdit(catalog)">{{ t('common.edit') }}</button>
                <button class="text-red-600 hover:text-red-700" @click="remove(catalog)">{{ t('common.delete') }}</button>
              </td>
            </tr>
          </tbody>
        </table>
        <p v-if="!store.catalogs.length" class="px-4 py-8 text-center text-slate-500">{{ t('org.empty') }}</p>
      </div>
    </div>

    <AppModal
      :open="showModal"
      :title="editing ? t('catalog.editCatalog') : t('catalog.addCatalog')"
      icon="layers"
      tone="brand"
      @close="showModal = false"
    >
      <form class="space-y-3" @submit.prevent="save">
        <div>
          <FieldLabel icon="account">{{ t('org.name') }}</FieldLabel>
          <input v-model="form.name" required class="field" />
        </div>
        <div>
          <FieldLabel icon="note">{{ t('products.description') }}</FieldLabel>
          <textarea v-model="form.description" rows="2" class="field" />
        </div>
        <label class="flex items-center gap-2 text-sm">
          <span class="field-icon"><AppIcon name="check" :size="14" /></span>
          <input v-model="form.is_default" type="checkbox" class="rounded" />
          {{ t('catalog.default') }}
        </label>
        <label class="flex items-center gap-2 text-sm">
          <span class="field-icon"><AppIcon name="check" :size="14" /></span>
          <input v-model="form.is_active" type="checkbox" class="rounded" />
          {{ t('products.active') }}
        </label>
        <div class="app-modal__actions">
          <button type="button" class="btn-secondary" @click="showModal = false">{{ t('common.cancel') }}</button>
          <button type="submit" class="btn-primary" :disabled="saving">{{ t('common.save') }}</button>
        </div>
      </form>
    </AppModal>
  </CatalogLayout>
</template>

<style scoped>
.field { width: 100%; border-radius: 0.5rem; border: 1px solid #cbd5e1; padding: 0.5rem 0.75rem; }
.btn-primary { border-radius: 0.5rem; padding: 0.5rem 1rem; font-weight: 500; color: white; background-color: var(--color-brand-600); }
.btn-secondary { border-radius: 0.5rem; border: 1px solid #cbd5e1; padding: 0.5rem 1rem; font-weight: 500; }
.bg-brand-600 { background-color: var(--color-brand-600); }
.text-brand-600 { color: var(--color-brand-600); }
</style>
