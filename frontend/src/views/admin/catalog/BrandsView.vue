<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import { useConfirm } from '../../../composables/useConfirm'
import CatalogLayout from '../../../components/catalog/CatalogLayout.vue'
import StatusBadge from '../../../components/organization/StatusBadge.vue'
import AppIcon from '../../../components/ui/AppIcon.vue'
import AppModal from '../../../components/ui/AppModal.vue'
import FieldLabel from '../../../components/ui/FieldLabel.vue'
import { useBackofficeStore } from '../../../stores/backoffice'
import type { Brand } from '../../../types'

const { t } = useI18n()
const { confirm: confirmDialog } = useConfirm()
const store = useBackofficeStore()
const showModal = ref(false)
const editing = ref<Brand | null>(null)
const saving = ref(false)
const form = ref({ name: '', slug: '', description: '', is_active: true })

onMounted(() => store.loadBrands())

function openCreate() {
  editing.value = null
  form.value = { name: '', slug: '', description: '', is_active: true }
  showModal.value = true
}

function openEdit(brand: Brand) {
  editing.value = brand
  form.value = { name: brand.name, slug: brand.slug, description: brand.description ?? '', is_active: brand.is_active }
  showModal.value = true
}

async function save() {
  saving.value = true
  try {
    await store.saveBrand(form.value, editing.value?.id)
    await store.loadBrands()
    showModal.value = false
  } finally {
    saving.value = false
  }
}

async function remove(brand: Brand) {
  if (!(await confirmDialog(t('org.confirmDelete')))) return
  await store.deleteBrand(brand.id)
  await store.loadBrands()
}
</script>

<template>
  <CatalogLayout>
    <div class="space-y-4">
      <div class="flex justify-end">
        <button class="rounded-lg bg-brand-600 px-4 py-2 text-sm text-white" @click="openCreate">+ {{ t('catalog.addBrand') }}</button>
      </div>
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
            <tr v-for="brand in store.brands" :key="brand.id" class="hover:bg-slate-50">
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
        <p v-if="!store.brands.length" class="px-4 py-8 text-center text-slate-500">{{ t('org.empty') }}</p>
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
        <div><FieldLabel icon="account">{{ t('org.name') }}</FieldLabel><input v-model="form.name" required class="field" /></div>
        <div><FieldLabel icon="tag">Slug</FieldLabel><input v-model="form.slug" class="field" /></div>
        <div><FieldLabel icon="note">{{ t('products.description') }}</FieldLabel><textarea v-model="form.description" rows="2" class="field" /></div>
        <label class="flex items-center gap-2 text-sm"><span class="field-icon"><AppIcon name="check" :size="14" /></span><input v-model="form.is_active" type="checkbox" class="rounded" />{{ t('products.active') }}</label>
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
.btn-secondary { border-radius: 0.5rem; border: 1px solid #cbd5e1; padding: 0.5rem 1rem; }
.bg-brand-600 { background-color: var(--color-brand-600); }
.text-brand-600 { color: var(--color-brand-600); }
</style>
