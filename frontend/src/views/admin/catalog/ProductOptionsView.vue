<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import CatalogLayout from '../../../components/catalog/CatalogLayout.vue'
import AppModal from '../../../components/ui/AppModal.vue'
import FieldLabel from '../../../components/ui/FieldLabel.vue'
import { useBackofficeStore } from '../../../stores/backoffice'
import { useContextStore } from '../../../stores/context'
import type { Product } from '../../../types'
import { formatMoney } from '../../../utils/format'

type OptionGroup = { name: string; values: string[]; draft: string }

const { t } = useI18n()
const store = useBackofficeStore()
const context = useContextStore()

const products = ref<Product[]>([])
const showModal = ref(false)
const saving = ref(false)
const productId = ref('')
const groups = ref<OptionGroup[]>([{ name: '', values: [], draft: '' }])

const eligible = computed(() => products.value.filter(product => !['service', 'digital', 'bundle'].includes(product.product_type ?? '')))
const transformed = computed(() => products.value.filter(product => (product.metadata?.option_groups?.length ?? 0) > 0 || product.product_type === 'variant'))
const selectedProduct = computed(() => products.value.find(product => product.id === productId.value) ?? null)

const preview = computed(() => {
  const ready = groups.value
    .map(group => ({ name: group.name.trim(), values: group.values.filter(Boolean) }))
    .filter(group => group.name && group.values.length)
  if (!ready.length) return []
  let rows: Record<string, string>[] = [{}]
  for (const group of ready) {
    rows = rows.flatMap(current => group.values.map(value => ({ ...current, [group.name]: value })))
  }
  return rows.slice(0, 100).map(options => ({
    key: JSON.stringify(Object.fromEntries(Object.entries(options).sort(([a], [b]) => a.localeCompare(b)))),
    options,
    label: Object.values(options).join(' / '),
  }))
})

onMounted(async () => {
  await store.loadCatalogAttributes(true, context.currentStoreId)
  await load()
})

async function load() {
  await store.loadCompanies()
  const companyId = store.companies[0]?.id
  if (!companyId) return
  const catalogs = await store.loadCatalogs(companyId, context.currentStoreId)
  const catalogId = catalogs.find(item => item.is_default)?.id ?? catalogs[0]?.id
  if (!catalogId) return
  products.value = await store.loadProducts(catalogId)
}

function openCreate() {
  productId.value = ''
  groups.value = [{ name: '', values: [], draft: '' }]
  showModal.value = true
}

function openEdit(product: Product) {
  productId.value = product.id
  const saved = product.metadata?.option_groups ?? []
  const fromVariants = groupsFromVariants(product)
  const source = saved.length ? saved : fromVariants
  groups.value = source.length
    ? source.map(group => ({
      name: group.name,
      values: [...group.values],
      draft: '',
    }))
    : [{ name: '', values: [], draft: '' }]
  showModal.value = true
}

function groupsFromVariants(product: Product): { name: string; values: string[] }[] {
  const map = new Map<string, string[]>()
  for (const variant of product.variants ?? []) {
    const options = variant.attributes?.options ?? {}
    const entries = Object.keys(options).length
      ? Object.entries(options)
      : [
          ...(variant.size ? [['Taille', variant.size]] : []),
          ...(variant.color ? [['Couleur', variant.color]] : []),
        ]
    for (const [name, value] of entries) {
      if (!value) continue
      const values = map.get(name) ?? []
      if (!values.includes(value)) values.push(value)
      map.set(name, values)
    }
  }
  return [...map.entries()].map(([name, values]) => ({ name, values }))
}

function useAttribute(code: string, index: number) {
  const attribute = store.catalogAttributes.find(item => item.code === code)
  if (!attribute) return
  groups.value[index] = {
    name: attribute.name,
    values: [...attribute.values],
    draft: '',
  }
}

function addGroup() {
  if (groups.value.length >= 4) return
  groups.value.push({ name: '', values: [], draft: '' })
}

function commitDraft(group: OptionGroup) {
  const parts = group.draft.split(',').map(value => value.trim()).filter(Boolean)
  for (const value of parts) {
    if (!group.values.includes(value) && group.values.length < 20) {
      group.values.push(value)
    }
  }
  group.draft = ''
}

function onValueKey(event: KeyboardEvent, group: OptionGroup) {
  if (event.key !== 'Enter' && event.key !== ',') return
  event.preventDefault()
  commitDraft(group)
}

async function apply() {
  const payload = groups.value
    .map(group => ({
      name: group.name.trim(),
      values: group.values.filter(Boolean),
    }))
    .filter(group => group.name && group.values.length)
  if (!productId.value || !payload.length) return
  saving.value = true
  try {
    await store.transformProductOptions(productId.value, payload, [])
    showModal.value = false
    await load()
  } finally {
    saving.value = false
  }
}

function optionLabel(product: Product) {
  const groups = product.metadata?.option_groups ?? []
  if (groups.length) return groups.map(group => `${group.name}: ${group.values.join(', ')}`).join(' · ')
  return (product.variants ?? []).map(variant => variant.name).filter(Boolean).join(', ') || '—'
}

function priceLabel(product: Product) {
  const amounts = (product.variants ?? [])
    .filter(item => item.is_active !== false)
    .map(item => item.base_price ?? product.base_price)
  if (!amounts.length) return formatMoney(product.base_price)
  const min = Math.min(...amounts)
  const max = Math.max(...amounts)
  return min === max ? formatMoney(min) : `${formatMoney(min)} – ${formatMoney(max)}`
}
</script>

<template>
  <CatalogLayout>
    <div class="space-y-4">
      <div class="flex flex-wrap items-center justify-between gap-3">
        <p class="m-0 max-w-2xl text-sm text-slate-500">{{ t('catalog.options.hint') }}</p>
        <button class="rounded-lg bg-brand-600 px-4 py-2 text-sm text-white" @click="openCreate">+ {{ t('catalog.options.transform') }}</button>
      </div>

      <div class="overflow-hidden rounded-xl bg-white shadow-sm ring-1 ring-slate-200">
        <table class="min-w-full divide-y divide-slate-200 text-sm">
          <thead class="bg-slate-50">
            <tr>
              <th class="px-4 py-3 text-left font-medium">{{ t('catalog.options.product') }}</th>
              <th class="px-4 py-3 text-left font-medium">{{ t('catalog.options.optionsCount') }}</th>
              <th class="px-4 py-3 text-left font-medium">{{ t('inventory.articles') }}</th>
              <th class="px-4 py-3 text-left font-medium">{{ t('catalog.options.price') }}</th>
              <th class="px-4 py-3 text-right">{{ t('common.edit') }}</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-slate-100">
            <tr v-for="product in transformed" :key="product.id" class="hover:bg-slate-50">
              <td class="px-4 py-3">
                <span class="block font-medium">{{ product.name }}</span>
                <span class="font-mono text-xs text-slate-500">{{ product.sku }}</span>
              </td>
              <td class="px-4 py-3 text-slate-600">{{ optionLabel(product) }}</td>
              <td class="px-4 py-3">{{ product.variants?.filter(item => item.is_active !== false).length ?? 0 }}</td>
              <td class="px-4 py-3">{{ priceLabel(product) }}</td>
              <td class="px-4 py-3 text-right">
                <button class="text-brand-600" @click="openEdit(product)">{{ t('catalog.options.edit') }}</button>
              </td>
            </tr>
          </tbody>
        </table>
        <p v-if="!transformed.length" class="px-4 py-8 text-center text-slate-500">{{ t('catalog.options.empty') }}</p>
      </div>
    </div>

    <AppModal
      :open="showModal"
      :title="t('catalog.options.transform')"
      icon="catalog"
      tone="info"
      size="lg"
      @close="showModal = false"
    >
      <form class="space-y-4" @submit.prevent="apply">
        <div>
          <FieldLabel icon="products">{{ t('catalog.options.product') }}</FieldLabel>
          <select v-model="productId" required class="field" :disabled="saving">
            <option value="">{{ t('catalog.options.selectProduct') }}</option>
            <option v-for="product in eligible" :key="product.id" :value="product.id">{{ product.sku }} — {{ product.name }}</option>
          </select>
          <p v-if="selectedProduct" class="mt-1 text-xs text-slate-500">
            {{ t('catalog.options.basePrice') }} : {{ formatMoney(selectedProduct.base_price) }}
          </p>
          <p class="mt-1 text-xs text-slate-500">{{ t('catalog.options.createHint') }}</p>
        </div>

        <div v-for="(group, index) in groups" :key="index" class="rounded-lg border border-slate-200 p-3 space-y-2">
          <div class="flex items-center justify-between gap-2">
            <span class="text-sm font-medium">{{ t('catalog.options.group') }} {{ index + 1 }}</span>
            <button v-if="groups.length > 1" type="button" class="text-sm text-red-600" @click="groups.splice(index, 1)">{{ t('common.delete') }}</button>
          </div>
          <select class="field" :value="''" @change="useAttribute(($event.target as HTMLSelectElement).value, index); ($event.target as HTMLSelectElement).value = ''">
            <option value="">{{ t('catalog.options.useAttribute') }}</option>
            <option v-for="attribute in store.catalogAttributes" :key="attribute.id" :value="attribute.code">
              {{ attribute.name }} — {{ attribute.values.join(', ') }}
            </option>
          </select>
          <input v-model="group.name" class="field" :placeholder="t('catalog.options.groupName')" />
          <div>
            <FieldLabel icon="layers">{{ t('catalog.options.values') }}</FieldLabel>
            <div class="flex flex-wrap gap-2">
              <span v-for="(value, valueIndex) in group.values" :key="value" class="option-chip">
                {{ value }}
                <button type="button" @click="group.values.splice(valueIndex, 1)">×</button>
              </span>
            </div>
            <input
              v-model="group.draft"
              class="field mt-2"
              :placeholder="t('catalog.options.valuesHint')"
              @keydown="onValueKey($event, group)"
              @blur="commitDraft(group)"
            />
          </div>
        </div>

        <button v-if="groups.length < 4" type="button" class="text-sm text-brand-600" @click="addGroup">+ {{ t('catalog.options.addGroup') }}</button>

        <div v-if="preview.length" class="rounded-lg bg-slate-50 p-3">
          <p class="mb-2 text-sm font-medium">{{ t('catalog.options.preview') }} ({{ preview.length }})</p>
          <ul class="m-0 max-h-48 space-y-1 overflow-auto p-0 text-sm text-slate-600">
            <li v-for="row in preview" :key="row.key" class="preview-row">
              {{ row.label }}
            </li>
          </ul>
        </div>

        <div class="app-modal__actions">
          <button type="button" class="btn-secondary" @click="showModal = false">{{ t('common.cancel') }}</button>
          <button type="submit" class="btn-primary" :disabled="saving || !productId || !preview.length">{{ t('catalog.options.apply') }}</button>
        </div>
      </form>
    </AppModal>
  </CatalogLayout>
</template>

<style scoped>
.field { width: 100%; border-radius: 0.5rem; border: 1px solid #cbd5e1; padding: 0.5rem 0.75rem; }
.btn-primary { border-radius: 0.5rem; padding: 0.5rem 1rem; font-weight: 500; color: white; background-color: var(--color-brand-600); }
.btn-secondary { border-radius: 0.5rem; border: 1px solid #cbd5e1; padding: 0.5rem 1rem; }
.text-brand-600 { color: var(--color-brand-600); }
.option-chip { display: inline-flex; align-items: center; gap: 0.35rem; border-radius: 999px; background: var(--color-brand-600); color: #fff; padding: 0.15rem 0.45rem 0.15rem 0.55rem; font-size: 0.75rem; }
.option-chip button { color: #fff; line-height: 1; }
.preview-row {
  list-style: none;
}
</style>
