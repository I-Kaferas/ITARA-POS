<script setup lang="ts">
import { onMounted, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import { useConfirm } from '../../../composables/useConfirm'
import CatalogLayout from '../../../components/catalog/CatalogLayout.vue'
import StatusBadge from '../../../components/organization/StatusBadge.vue'
import AppModal from '../../../components/ui/AppModal.vue'
import { useBackofficeStore } from '../../../stores/backoffice'
import type { CatalogAttribute } from '../../../types'

const { t } = useI18n()
const { confirm: confirmDialog } = useConfirm()
const store = useBackofficeStore()
const showModal = ref(false)
const editing = ref<CatalogAttribute | null>(null)
const saving = ref(false)
const form = ref({ name: '', code: '', valuesText: '', is_active: true })

onMounted(() => store.loadCatalogAttributes(true))

function openCreate() {
  editing.value = null
  form.value = { name: '', code: '', valuesText: '', is_active: true }
  showModal.value = true
}

function openEdit(attribute: CatalogAttribute) {
  editing.value = attribute
  form.value = {
    name: attribute.name,
    code: attribute.code,
    valuesText: (attribute.values ?? []).join(', '),
    is_active: attribute.is_active,
  }
  showModal.value = true
}

function valuesFromText(text: string) {
  return [...new Set(text.split(',').map(value => value.trim()).filter(Boolean))]
}

async function save() {
  const values = valuesFromText(form.value.valuesText)
  if (!values.length) return
  saving.value = true
  try {
    await store.saveCatalogAttribute({
      name: form.value.name,
      code: form.value.code || undefined,
      values,
      is_active: form.value.is_active,
    }, editing.value?.id)
    await store.loadCatalogAttributes()
    showModal.value = false
  } finally {
    saving.value = false
  }
}

async function remove(attribute: CatalogAttribute) {
  if (!(await confirmDialog(t('org.confirmDelete')))) return
  await store.deleteCatalogAttribute(attribute.id)
  await store.loadCatalogAttributes()
}
</script>

<template>
  <CatalogLayout>
    <div class="space-y-4">
      <div class="flex flex-wrap items-center justify-between gap-3">
        <p class="m-0 max-w-2xl text-sm text-slate-500">{{ t('catalog.attributesHint') }}</p>
        <button class="rounded-lg bg-brand-600 px-4 py-2 text-sm text-white" @click="openCreate">+ {{ t('catalog.addAttribute') }}</button>
      </div>
      <div class="overflow-hidden rounded-xl bg-white shadow-sm ring-1 ring-slate-200">
        <table class="min-w-full divide-y divide-slate-200 text-sm">
          <thead class="bg-slate-50">
            <tr>
              <th class="px-4 py-3 text-left font-medium">{{ t('org.name') }}</th>
              <th class="px-4 py-3 text-left font-medium">{{ t('catalog.attributeValues') }}</th>
              <th class="px-4 py-3 text-left font-medium">{{ t('products.status') }}</th>
              <th class="px-4 py-3 text-right">{{ t('common.edit') }}</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-slate-100">
            <tr v-for="attribute in store.catalogAttributes" :key="attribute.id" class="hover:bg-slate-50">
              <td class="px-4 py-3">
                <span class="block font-medium">{{ attribute.name }}</span>
                <span class="font-mono text-xs text-slate-400">{{ attribute.code }}</span>
              </td>
              <td class="px-4 py-3 text-slate-600">{{ attribute.values.join(', ') }}</td>
              <td class="px-4 py-3"><StatusBadge :active="attribute.is_active" /></td>
              <td class="px-4 py-3 text-right space-x-2">
                <button class="text-brand-600" @click="openEdit(attribute)">{{ t('common.edit') }}</button>
                <button class="text-red-600" @click="remove(attribute)">{{ t('common.delete') }}</button>
              </td>
            </tr>
          </tbody>
        </table>
        <p v-if="!store.catalogAttributes.length" class="px-4 py-8 text-center text-slate-500">{{ t('org.empty') }}</p>
      </div>
    </div>

    <AppModal
      :open="showModal"
      :title="editing ? t('catalog.editAttribute') : t('catalog.addAttribute')"
      icon="catalog"
      tone="accent"
      @close="showModal = false"
    >
      <form class="space-y-3" @submit.prevent="save">
        <div><label class="mb-1 block text-sm font-medium">{{ t('org.name') }}</label><input v-model="form.name" required class="field" placeholder="Couleur" /></div>
        <div><label class="mb-1 block text-sm font-medium">{{ t('catalog.attributeCode') }}</label><input v-model="form.code" class="field" placeholder="color" /></div>
        <div>
          <label class="mb-1 block text-sm font-medium">{{ t('catalog.attributeValues') }}</label>
          <input v-model="form.valuesText" required class="field" :placeholder="t('catalog.attributeValuesHint')" />
        </div>
        <label class="flex items-center gap-2 text-sm"><input v-model="form.is_active" type="checkbox" class="rounded" />{{ t('products.active') }}</label>
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
