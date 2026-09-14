<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import AppModal from '../ui/AppModal.vue'
import FieldLabel from '../ui/FieldLabel.vue'
import WarehouseOptions from './WarehouseOptions.vue'
import { extractApiErrorMessage } from '../../api/client'
import { useBackofficeStore } from '../../stores/backoffice'
import type { Category, CycleDashboard, CycleSuggestion, Product, Warehouse } from '../../types'
import { formatDate } from '../../utils/format'
import { isStockableProduct } from '../../utils/product'

const props = defineProps<{
  open: boolean
  warehouses: Warehouse[]
  categories: Category[]
  products: Product[]
  users: { id: string; name: string }[]
  warehouseId?: string
}>()

const emit = defineEmits<{
  close: []
  created: [id: string]
}>()

const { t } = useI18n()
const store = useBackofficeStore()

const saving = ref(false)
const loading = ref(false)
const error = ref('')
const query = ref('')
const suggestions = ref<CycleSuggestion[]>([])
const dashboard = ref<CycleDashboard | null>(null)
const selected = ref<Record<string, boolean>>({})

const form = ref(blankForm())

function today() {
  const now = new Date()
  const month = String(now.getMonth() + 1).padStart(2, '0')
  const day = String(now.getDate()).padStart(2, '0')
  return `${now.getFullYear()}-${month}-${day}`
}

function blankForm() {
  return {
    warehouse_id: '',
    counted_at: today(),
    category_id: '',
    inventory_class: '',
    zone: '',
    responsible_id: '',
    notes: '',
  }
}

const selectedIds = computed(() => Object.entries(selected.value).filter(([, on]) => on).map(([id]) => id))

const extraProducts = computed(() => {
  const suggested = new Set(suggestions.value.map((row) => row.product_id))
  const term = query.value.trim().toLowerCase()
  return props.products.filter((product) => {
    if (!isStockableProduct(product) || suggested.has(product.id)) return false
    if (form.value.category_id && product.category_id !== form.value.category_id) return false
    if (!term) return false
    return product.name.toLowerCase().includes(term) || product.sku.toLowerCase().includes(term)
  }).slice(0, 20)
})

const visibleSuggestions = computed(() => {
  const term = query.value.trim().toLowerCase()
  return suggestions.value.filter((row) => {
    if (!term) return true
    return `${row.name} ${row.sku} ${row.category ?? ''}`.toLowerCase().includes(term)
  })
})

watch(() => props.open, (open) => {
  if (!open) return
  error.value = ''
  query.value = ''
  selected.value = {}
  suggestions.value = []
  dashboard.value = null
  form.value = {
    ...blankForm(),
    warehouse_id: props.warehouseId || props.warehouses[0]?.id || '',
  }
  void refresh()
})

watch(() => [form.value.warehouse_id, form.value.category_id, form.value.inventory_class] as const, () => {
  if (props.open) void refresh()
})

async function refresh() {
  if (!form.value.warehouse_id) {
    suggestions.value = []
    dashboard.value = null
    return
  }
  loading.value = true
  error.value = ''
  try {
    const [rows, stats] = await Promise.all([
      store.suggestCycleCounts(
        form.value.warehouse_id,
        form.value.category_id || undefined,
        form.value.inventory_class || undefined,
      ),
      store.loadCycleDashboard(form.value.warehouse_id),
    ])
    suggestions.value = rows
    dashboard.value = stats
  } catch (err) {
    error.value = extractApiErrorMessage(err)
  } finally {
    loading.value = false
  }
}

function toggleVisible(checked: boolean) {
  const next = { ...selected.value }
  for (const row of visibleSuggestions.value) next[row.product_id] = checked
  selected.value = next
}

function classLabel(value?: string | null) {
  if (value === 'A') return `A · ${t('inventory.classA')}`
  if (value === 'B') return `B · ${t('inventory.classB')}`
  if (value === 'C') return `C · ${t('inventory.classC')}`
  return value || '—'
}

function frequencyLabel(value?: string | null) {
  if (!value) return ''
  const key = `inventory.freq.${value}`
  const translated = t(key)
  return translated === key ? value : translated
}

async function plan() {
  if (!form.value.warehouse_id) return
  if (!selectedIds.value.length && !suggestions.value.length) {
    error.value = t('inventory.cycleNoneDue')
    return
  }
  saving.value = true
  error.value = ''
  try {
    const result = await store.planCycleCount({
      warehouse_id: form.value.warehouse_id,
      counted_at: form.value.counted_at,
      zone: form.value.zone || undefined,
      category_id: form.value.category_id || undefined,
      inventory_class: form.value.inventory_class || undefined,
      product_ids: selectedIds.value.length ? selectedIds.value : undefined,
      notes: form.value.notes || undefined,
      responsible_id: form.value.responsible_id || undefined,
    })
    const id = result.data?.id
    if (!id) throw new Error(t('inventory.noArticles'))
    emit('created', id)
  } catch (err) {
    error.value = extractApiErrorMessage(err)
  } finally {
    saving.value = false
  }
}

async function generate() {
  if (!form.value.warehouse_id) return
  saving.value = true
  error.value = ''
  try {
    const result = await store.generateCycleCounts(form.value.warehouse_id)
    const id = result.data?.count?.id
    if (!id) {
      error.value = t('inventory.cycleNoneDue')
      await refresh()
      return
    }
    emit('created', id)
  } catch (err) {
    error.value = extractApiErrorMessage(err)
  } finally {
    saving.value = false
  }
}
</script>

<template>
  <AppModal :open="open" :title="t('inventory.cycleTitle')" icon="inventory" tone="info" size="xl" @close="emit('close')">
    <form class="space-y-3" @submit.prevent="plan">
      <p class="text-sm text-slate-600">{{ t('inventory.cycleHint') }}</p>
      <p v-if="error" class="rounded-lg bg-red-50 px-3 py-2 text-sm text-red-700">{{ error }}</p>

      <div v-if="dashboard" class="grid grid-cols-2 gap-2 sm:grid-cols-4">
        <div class="rounded-lg bg-slate-50 px-3 py-2 text-sm">
          <p class="text-xs text-slate-500">{{ t('inventory.cyclePlanned') }}</p>
          <p class="font-semibold">{{ dashboard.planned }}</p>
        </div>
        <div class="rounded-lg bg-slate-50 px-3 py-2 text-sm">
          <p class="text-xs text-slate-500">{{ t('inventory.cycleCompleted') }}</p>
          <p class="font-semibold">{{ dashboard.completed }}</p>
        </div>
        <div class="rounded-lg bg-slate-50 px-3 py-2 text-sm">
          <p class="text-xs text-slate-500">{{ t('inventory.cycleOverdue') }}</p>
          <p class="font-semibold text-red-700">{{ dashboard.overdue }}</p>
        </div>
        <div class="rounded-lg bg-slate-50 px-3 py-2 text-sm">
          <p class="text-xs text-slate-500">{{ t('inventory.cycleAccuracy') }}</p>
          <p class="font-semibold">{{ dashboard.accuracy }}%</p>
        </div>
      </div>

      <div class="grid gap-3 sm:grid-cols-2">
        <div>
          <FieldLabel icon="inventory">{{ t('inventory.warehouse') }}</FieldLabel>
          <WarehouseOptions v-model="form.warehouse_id" :warehouses="warehouses" />
        </div>
        <div>
          <FieldLabel icon="calendar">{{ t('inventory.plannedDate') }}</FieldLabel>
          <input v-model="form.counted_at" type="date" required class="field" />
        </div>
        <div>
          <FieldLabel icon="layers">{{ t('inventory.category') }}</FieldLabel>
          <select v-model="form.category_id" class="field">
            <option value="">{{ t('inventory.allCategories') }}</option>
            <option v-for="category in categories" :key="category.id" :value="category.id">{{ category.name }}</option>
          </select>
        </div>
        <div>
          <FieldLabel icon="catalog">{{ t('inventory.abcClass') }}</FieldLabel>
          <select v-model="form.inventory_class" class="field">
            <option value="">{{ t('inventory.allClasses') }}</option>
            <option value="A">A · {{ t('inventory.classA') }}</option>
            <option value="B">B · {{ t('inventory.classB') }}</option>
            <option value="C">C · {{ t('inventory.classC') }}</option>
          </select>
        </div>
        <div>
          <FieldLabel icon="pin">{{ t('inventory.zone') }}</FieldLabel>
          <input v-model="form.zone" class="field" :placeholder="t('inventory.zoneHint')" />
        </div>
        <div>
          <FieldLabel icon="account">{{ t('inventory.responsible') }}</FieldLabel>
          <select v-model="form.responsible_id" class="field">
            <option value="">{{ t('inventory.currentUser') }}</option>
            <option v-for="user in users" :key="user.id" :value="user.id">{{ user.name }}</option>
          </select>
        </div>
        <div class="sm:col-span-2">
          <FieldLabel icon="note">{{ t('inventory.notes') }}</FieldLabel>
          <textarea v-model="form.notes" rows="2" class="field" />
        </div>
      </div>

      <div class="flex flex-wrap items-center gap-2">
        <input v-model="query" class="field max-w-xs" :placeholder="t('inventory.searchProduct')" />
        <button type="button" class="btn-secondary" @click="toggleVisible(true)">{{ t('inventory.selectVisible') }}</button>
        <button type="button" class="btn-secondary" @click="toggleVisible(false)">{{ t('inventory.clearSelection') }}</button>
      </div>

      <div class="max-h-72 overflow-auto rounded-xl ring-1 ring-slate-200">
        <table class="min-w-full text-sm">
          <thead class="sticky top-0 bg-slate-50 text-left text-slate-500">
            <tr>
              <th class="px-3 py-2" />
              <th class="px-3 py-2 font-medium">{{ t('inventory.suggestedProducts') }}</th>
              <th class="px-3 py-2 font-medium">{{ t('inventory.abcClass') }}</th>
              <th class="px-3 py-2 font-medium">{{ t('inventory.nextCount') }}</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="row in visibleSuggestions" :key="row.product_id" class="border-t border-slate-100">
              <td class="px-3 py-2">
                <input v-model="selected[row.product_id]" type="checkbox" />
              </td>
              <td class="px-3 py-2">
                <span class="block font-medium">{{ row.name }}</span>
                <span class="text-xs text-slate-500">
                  {{ row.sku }}
                  <template v-if="frequencyLabel(row.count_frequency)"> · {{ frequencyLabel(row.count_frequency) }}</template>
                  <template v-if="row.priority === 'high'"> · {{ t('inventory.priorityHigh') }}</template>
                </span>
              </td>
              <td class="px-3 py-2">{{ classLabel(row.inventory_class) }}</td>
              <td class="px-3 py-2 text-slate-500">{{ formatDate(row.next_count_at) }}</td>
            </tr>
            <tr v-for="product in extraProducts" :key="product.id" class="border-t border-slate-100">
              <td class="px-3 py-2">
                <input v-model="selected[product.id]" type="checkbox" />
              </td>
              <td class="px-3 py-2" colspan="3">
                <span class="block font-medium">{{ product.name }}</span>
                <span class="text-xs text-slate-500">{{ product.sku }}</span>
              </td>
            </tr>
          </tbody>
        </table>
        <p v-if="!loading && !visibleSuggestions.length && !extraProducts.length" class="px-3 py-6 text-center text-sm text-slate-500">{{ t('inventory.cycleNoneDue') }}</p>
      </div>

      <div v-if="dashboard?.top_variances?.length" class="text-sm text-slate-600">
        <p class="mb-1 font-medium">{{ t('inventory.topVariances') }}</p>
        <p>{{ dashboard.top_variances.map((row) => row.name || row.product_id).join(', ') }}</p>
      </div>

      <div class="app-modal__actions">
        <button type="button" class="btn-secondary" @click="emit('close')">{{ t('common.cancel') }}</button>
        <button type="button" class="btn-secondary" :disabled="saving || !form.warehouse_id" @click="generate">{{ t('inventory.generateCycle') }}</button>
        <button type="submit" class="btn-primary" :disabled="saving || !form.warehouse_id">
          {{ t('inventory.planCycle') }}<template v-if="selectedIds.length"> ({{ selectedIds.length }})</template>
        </button>
      </div>
    </form>
  </AppModal>
</template>
