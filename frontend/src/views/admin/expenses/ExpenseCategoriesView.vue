<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import AdminLayout from '../../../components/layout/AdminLayout.vue'
import AppModal from '../../../components/ui/AppModal.vue'
import FieldLabel from '../../../components/ui/FieldLabel.vue'
import ModuleFilters from '../../../components/ui/ModuleFilters.vue'
import { useBackofficeStore } from '../../../stores/backoffice'
import { emptyListFilters, matchesActive, matchesSearch, type ListFilters } from '../../../utils/listFilters'

type ExpenseCategory = {
  id: string
  code: string
  name: string
  color?: string | null
  description?: string | null
  is_active?: boolean
}

const DEFAULT_COLOR = '#6366F1'

const { t } = useI18n()
const store = useBackofficeStore()

const categories = ref<ExpenseCategory[]>([])
const filters = ref<ListFilters>(emptyListFilters('all'))
const showModal = ref(false)
const editing = ref<ExpenseCategory | null>(null)
const saving = ref(false)
const form = ref({
  name: '',
  color: DEFAULT_COLOR,
  description: '',
})

const previewName = computed(() => form.value.name.trim() || t('expenses.category'))
const modalHint = computed(() => editing.value ? t('expenses.editCategoryHint') : t('expenses.newCategoryHint'))

const filteredCategories = computed(() =>
  categories.value.filter((category) => {
    const haystack = [category.name, category.code, category.description].filter(Boolean).join(' ')
    if (!matchesSearch(haystack, filters.value.search)) return false
    if (!matchesActive(category.is_active ?? true, filters.value.active)) return false
    return true
  }),
)

onMounted(load)

async function load() {
  categories.value = (await store.loadExpenseCategories()) as ExpenseCategory[]
}

function openCreate() {
  editing.value = null
  form.value = { name: '', color: DEFAULT_COLOR, description: '' }
  showModal.value = true
}

function openEdit(category: ExpenseCategory) {
  editing.value = category
  form.value = {
    name: category.name,
    color: category.color || DEFAULT_COLOR,
    description: category.description ?? '',
  }
  showModal.value = true
}

function normalizeColor(value: string) {
  const hex = value.trim()
  if (/^#[0-9A-Fa-f]{6}$/.test(hex)) return hex.toUpperCase()
  if (/^[0-9A-Fa-f]{6}$/.test(hex)) return `#${hex.toUpperCase()}`
  return DEFAULT_COLOR
}

async function save() {
  const name = form.value.name.trim()
  if (!name) return
  saving.value = true
  try {
    await store.saveExpenseCategory({
      name,
      color: normalizeColor(form.value.color),
      description: form.value.description.trim() || null,
    }, editing.value?.id)
    showModal.value = false
    await load()
  } finally {
    saving.value = false
  }
}
</script>

<template>
  <AdminLayout>
    <template #title>{{ t('expenses.tabs.categories') }}</template>
    <template #subtitle>{{ t('expenses.linksHint') }}</template>

    <div class="mb-4 space-y-3">
      <div class="flex justify-end">
        <button class="btn-primary" type="button" @click="openCreate">+ {{ t('expenses.newCategory') }}</button>
      </div>
      <ModuleFilters
        v-model="filters"
        :search-placeholder="t('expenses.search')"
        :show-period="false"
        show-active
      />
    </div>

    <div class="overflow-hidden rounded-xl bg-white shadow-sm ring-1 ring-slate-200">
      <table class="min-w-full divide-y divide-slate-200 text-sm">
        <thead class="bg-slate-50">
          <tr>
            <th class="px-4 py-3 text-left font-medium">{{ t('expenses.color') }}</th>
            <th class="px-4 py-3 text-left font-medium">{{ t('expenses.name') }}</th>
            <th class="px-4 py-3 text-left font-medium">{{ t('expenses.code') }}</th>
            <th class="px-4 py-3 text-left font-medium">{{ t('expenses.description') }}</th>
            <th class="px-4 py-3 text-right font-medium">{{ t('common.edit') }}</th>
          </tr>
        </thead>
        <tbody class="divide-y divide-slate-100">
          <tr v-for="category in filteredCategories" :key="category.id" class="hover:bg-slate-50">
            <td class="px-4 py-3">
              <span
                class="inline-block h-5 w-5 rounded-full ring-1 ring-slate-200"
                :style="{ backgroundColor: category.color || DEFAULT_COLOR }"
                :title="category.color || DEFAULT_COLOR"
              />
            </td>
            <td class="px-4 py-3">
              <span
                class="inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium text-white"
                :style="{ backgroundColor: category.color || DEFAULT_COLOR }"
              >
                {{ category.name }}
              </span>
            </td>
            <td class="px-4 py-3 font-mono text-slate-500">{{ category.code }}</td>
            <td class="px-4 py-3 text-slate-500">{{ category.description || '—' }}</td>
            <td class="px-4 py-3 text-right">
              <button type="button" class="text-brand-600" @click="openEdit(category)">{{ t('common.edit') }}</button>
            </td>
          </tr>
        </tbody>
      </table>
      <p v-if="!filteredCategories.length" class="px-4 py-8 text-center text-slate-500">{{ t('org.empty') }}</p>
    </div>

    <AppModal
      :open="showModal"
      :title="editing ? t('expenses.editCategory') : t('expenses.newCategory')"
      icon="layers"
      tone="info"
      size="md"
      @close="showModal = false"
    >
      <form class="space-y-4" @submit.prevent="save">
        <p class="m-0 text-sm text-slate-500">{{ modalHint }}</p>

        <div>
          <FieldLabel icon="sparkles">{{ t('expenses.color') }}</FieldLabel>
          <div class="flex items-center gap-3">
            <input v-model="form.color" type="color" class="color-swatch" :aria-label="t('expenses.color')" />
            <input
              v-model="form.color"
              class="field font-mono uppercase"
              maxlength="7"
              pattern="^#[0-9A-Fa-f]{6}$"
              placeholder="#6366F1"
            />
          </div>
          <div class="mt-3 flex items-center gap-2 text-sm text-slate-600">
            <span>{{ t('expenses.preview') }} :</span>
            <span
              class="inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium text-white"
              :style="{ backgroundColor: normalizeColor(form.color) }"
            >
              {{ previewName }}
            </span>
          </div>
        </div>

        <div>
          <FieldLabel icon="tag">{{ t('expenses.categoryName') }}*</FieldLabel>
          <input
            v-model="form.name"
            class="field"
            required
            maxlength="120"
            :placeholder="t('expenses.categoryNamePlaceholder')"
          />
        </div>

        <div>
          <FieldLabel icon="note">{{ t('expenses.description') }}</FieldLabel>
          <textarea
            v-model="form.description"
            class="field"
            rows="3"
            maxlength="500"
            :placeholder="t('expenses.categoryDescriptionPlaceholder')"
          />
        </div>

        <div class="app-modal__actions">
          <button type="button" class="btn-secondary" @click="showModal = false">{{ t('common.cancel') }}</button>
          <button type="submit" class="btn-primary" :disabled="saving">{{ t('common.save') }}</button>
        </div>
      </form>
    </AppModal>
  </AdminLayout>
</template>

<style scoped>
.field { width: 100%; border-radius: 0.5rem; border: 1px solid #cbd5e1; padding: 0.5rem 0.75rem; }
.color-swatch { height: 2.5rem; width: 3rem; cursor: pointer; border-radius: 0.5rem; border: 1px solid #cbd5e1; background: transparent; padding: 0.15rem; }
.btn-primary { border-radius: 0.5rem; padding: 0.5rem 1rem; font-weight: 500; color: white; background-color: var(--color-brand-600); }
.btn-secondary { border-radius: 0.5rem; padding: 0.5rem 1rem; font-weight: 500; background: white; border: 1px solid #cbd5e1; }
.text-brand-600 { color: var(--color-brand-600); }
</style>
