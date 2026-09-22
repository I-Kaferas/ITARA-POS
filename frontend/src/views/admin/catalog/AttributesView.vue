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
import type { CatalogAttribute } from '../../../types'
import { emptyListFilters, matchesActive, matchesSearch, type ListFilters } from '../../../utils/listFilters'

const { t } = useI18n()
const { confirm: confirmDialog } = useConfirm()
const store = useBackofficeStore()
const context = useContextStore()
const showModal = ref(false)
const editing = ref<CatalogAttribute | null>(null)
const saving = ref(false)
const filters = ref<ListFilters>(emptyListFilters('all'))
const filtered = computed(() => store.catalogAttributes.filter(attribute =>
  matchesSearch(`${attribute.name} ${attribute.code} ${(attribute.values ?? []).join(' ')}`, filters.value.search)
  && matchesActive(attribute.is_active, filters.value.active),
))
const form = ref({ name: '', code: '', valuesText: '', is_active: true })
const storeIds = ref<string[]>([])

function defaultStoreIds() {
  return context.currentStoreId ? [context.currentStoreId] : context.activeStores.map(store => store.id)
}

async function refreshAttributes() {
  if (!context.currentStoreId) return
  await store.loadCatalogAttributes(true, context.currentStoreId)
}

onMounted(async () => {
  await context.loadStores()
  await refreshAttributes()
})

watch(() => context.currentStoreId, () => { void refreshAttributes() })

function openCreate() {
  editing.value = null
  form.value = { name: '', code: '', valuesText: '', is_active: true }
  storeIds.value = defaultStoreIds()
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
  storeIds.value = attribute.store_id ? [attribute.store_id] : defaultStoreIds()
  showModal.value = true
}

function valuesFromText(text: string) {
  return [...new Set(text.split(',').map(value => value.trim()).filter(Boolean))]
}

async function save() {
  if (!storeIds.value.length) return
  const values = valuesFromText(form.value.valuesText)
  if (!values.length) return
  saving.value = true
  try {
    await store.saveCatalogAttribute({
      name: form.value.name,
      code: form.value.code || undefined,
      values,
      is_active: form.value.is_active,
      store_ids: storeIds.value,
    }, editing.value?.id)
    await refreshAttributes()
    showModal.value = false
  } finally {
    saving.value = false
  }
}

async function remove(attribute: CatalogAttribute) {
  if (!(await confirmDialog(t('org.confirmDelete')))) return
  await store.deleteCatalogAttribute(attribute.id)
  await refreshAttributes()
}
</script>

<template>
  <CatalogLayout>
    <div class="space-y-4">
      <div class="flex flex-wrap items-center justify-between gap-3">
        <p class="m-0 max-w-2xl text-sm text-slate-500">{{ t('catalog.attributesHint') }} · {{ t('catalog.storeScopedHint') }}</p>
        <button class="rounded-lg bg-brand-600 px-4 py-2 text-sm text-white" :disabled="!context.activeStores.length" @click="openCreate">+ {{ t('catalog.addAttribute') }}</button>
      </div>
      <ModuleFilters v-model="filters" :show-period="false" show-search show-active />
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
            <tr v-for="attribute in filtered" :key="attribute.id" class="hover:bg-slate-50">
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
        <p v-if="!filtered.length" class="px-4 py-8 text-center text-slate-500">{{ t('org.empty') }}</p>
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
        <div><FieldLabel icon="account">{{ t('org.name') }}</FieldLabel><input v-model="form.name" required class="field" placeholder="Couleur" /></div>
        <div><FieldLabel icon="tag">{{ t('catalog.attributeCode') }}</FieldLabel><input v-model="form.code" class="field" placeholder="color" /></div>
        <div>
          <FieldLabel icon="layers">{{ t('catalog.attributeValues') }}</FieldLabel>
          <input v-model="form.valuesText" required class="field" :placeholder="t('catalog.attributeValuesHint')" />
        </div>
        <label class="flex items-center gap-2 text-sm"><span class="field-icon"><AppIcon name="check" :size="14" /></span><input v-model="form.is_active" type="checkbox" class="rounded" />{{ t('products.active') }}</label>
        <StoreMultiSelect v-model="storeIds" />
        <p v-if="!storeIds.length" class="m-0 text-xs text-red-600">{{ t('catalog.selectStoresRequired') }}</p>
        <div class="app-modal__actions">
          <button type="button" class="btn-secondary" @click="showModal = false">{{ t('common.cancel') }}</button>
          <button type="submit" class="btn-primary" :disabled="saving || !storeIds.length">{{ t('common.save') }}</button>
        </div>
      </form>
    </AppModal>
  </CatalogLayout>
</template>

<style scoped>


.btn-secondary { border-radius: 0.5rem; border: 1px solid #cbd5e1; padding: 0.5rem 1rem; }
.bg-brand-600 { background-color: var(--color-brand-600); }
.text-brand-600 { color: var(--color-brand-600); }
</style>
