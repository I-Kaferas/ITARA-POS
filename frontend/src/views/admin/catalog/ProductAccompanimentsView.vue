<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import { extractApiErrorMessage } from '../../../api/client'
import CatalogLayout from '../../../components/catalog/CatalogLayout.vue'
import AppModal from '../../../components/ui/AppModal.vue'
import EmptyState from '../../../components/ui/EmptyState.vue'
import FieldLabel from '../../../components/ui/FieldLabel.vue'
import { useBackofficeStore } from '../../../stores/backoffice'
import type { Product, ProductAccompanimentHost } from '../../../types'

const { t } = useI18n()
const store = useBackofficeStore()

const rows = ref<ProductAccompanimentHost[]>([])
const products = ref<Product[]>([])
const candidates = ref<Product[]>([])
const showModal = ref(false)
const saving = ref(false)
const error = ref('')
const productId = ref('')
const selectedIds = ref<string[]>([])

const hostProducts = computed(() => products.value.filter(product => product.id !== ''))
const availableCandidates = computed(() =>
  candidates.value.filter(product => product.id !== productId.value),
)

onMounted(async () => {
  await load()
})

async function load() {
  const [hosts, allProducts, enabled] = await Promise.all([
    store.loadProductAccompaniments(),
    store.loadAllProducts(),
    store.loadAccompanimentCandidates(),
  ])
  rows.value = hosts
  products.value = allProducts
  candidates.value = enabled
}

function openCreate() {
  productId.value = ''
  selectedIds.value = []
  error.value = ''
  showModal.value = true
}

function openEdit(row: ProductAccompanimentHost) {
  productId.value = row.product.id
  selectedIds.value = row.accompaniments.map(item => item.id)
  error.value = ''
  showModal.value = true
}

function toggle(id: string) {
  if (selectedIds.value.includes(id)) {
    selectedIds.value = selectedIds.value.filter(item => item !== id)
    return
  }
  selectedIds.value = [...selectedIds.value, id]
}

async function onProductChange() {
  selectedIds.value = []
  const existing = rows.value.find(row => row.product.id === productId.value)
  if (existing) {
    selectedIds.value = existing.accompaniments.map(item => item.id)
  }
  candidates.value = await store.loadAccompanimentCandidates(productId.value || undefined)
}

async function submit() {
  if (!productId.value) return
  saving.value = true
  error.value = ''
  try {
    await store.saveProductAccompaniments(productId.value, selectedIds.value)
    showModal.value = false
    await load()
  } catch (err) {
    error.value = extractApiErrorMessage(err, t('accompaniments.saveFailed'))
  } finally {
    saving.value = false
  }
}
</script>

<template>
  <CatalogLayout>
    <div class="mb-4 flex flex-wrap items-center justify-between gap-3">
      <p class="m-0 max-w-2xl text-sm text-slate-500">{{ t('accompaniments.subtitle') }}</p>
      <button class="btn-primary" @click="openCreate">+ {{ t('accompaniments.new') }}</button>
    </div>

    <div class="overflow-hidden rounded-xl bg-white shadow-sm ring-1 ring-slate-200">
      <table class="min-w-full divide-y divide-slate-200 text-sm">
        <thead class="bg-slate-50">
          <tr>
            <th class="px-4 py-3 text-left font-medium">{{ t('accompaniments.product') }}</th>
            <th class="px-4 py-3 text-left font-medium">{{ t('accompaniments.freeAccompaniments') }}</th>
            <th class="px-4 py-3"></th>
          </tr>
        </thead>
        <tbody class="divide-y divide-slate-100">
          <tr v-for="row in rows" :key="row.id" class="hover:bg-slate-50">
            <td class="px-4 py-3">
              <span class="block font-medium">{{ row.product.name }}</span>
              <span class="font-mono text-xs text-slate-500">{{ row.product.sku }}</span>
            </td>
            <td class="px-4 py-3">
              <div class="flex flex-wrap gap-1.5">
                <span
                  v-for="item in row.accompaniments"
                  :key="item.id"
                  class="rounded-full bg-emerald-50 px-2 py-0.5 text-xs font-medium text-emerald-700"
                >
                  {{ item.name }}
                </span>
              </div>
            </td>
            <td class="px-4 py-3 text-right">
              <button class="text-sm text-brand-600" @click="openEdit(row)">{{ t('common.edit') }}</button>
            </td>
          </tr>
        </tbody>
      </table>
      <EmptyState
        v-if="!rows.length"
        icon="sparkles"
        :title="t('accompaniments.empty')"
        :description="t('accompaniments.emptyHint')"
      />
    </div>

    <AppModal
      :open="showModal"
      :title="t('accompaniments.new')"
      icon="sparkles"
      size="lg"
      @close="showModal = false"
    >
      <form class="space-y-4" @submit.prevent="submit">
        <div>
          <FieldLabel icon="products">{{ t('accompaniments.product') }}</FieldLabel>
          <select v-model="productId" class="field" required :disabled="saving" @change="onProductChange">
            <option value="">{{ t('accompaniments.selectProduct') }}</option>
            <option v-for="product in hostProducts" :key="product.id" :value="product.id">
              {{ product.sku }} — {{ product.name }}
            </option>
          </select>
        </div>

        <div>
          <FieldLabel icon="sparkles">{{ t('accompaniments.freeAccompaniments') }}</FieldLabel>
          <p class="mb-2 text-xs text-slate-500">{{ t('accompaniments.selectAccompaniments') }}</p>
          <p v-if="!availableCandidates.length" class="m-0 text-sm text-slate-500">{{ t('accompaniments.noCandidates') }}</p>
          <div v-else class="max-h-72 space-y-1 overflow-auto rounded-lg border border-slate-200 p-2">
            <label
              v-for="item in availableCandidates"
              :key="item.id"
              class="flex cursor-pointer items-center justify-between gap-3 rounded-lg px-3 py-2 hover:bg-slate-50"
            >
              <span class="flex items-center gap-2">
                <input
                  type="checkbox"
                  class="rounded"
                  :checked="selectedIds.includes(item.id)"
                  @change="toggle(item.id)"
                />
                <span>
                  <span class="block font-medium">{{ item.name }}</span>
                  <span class="font-mono text-xs text-slate-500">{{ item.sku }}</span>
                </span>
              </span>
              <span class="text-xs font-medium text-emerald-700">{{ t('accompaniments.priceFree') }}</span>
            </label>
          </div>
        </div>

        <p v-if="error" class="m-0 text-sm text-red-600">{{ error }}</p>
        <div class="flex justify-end gap-2">
          <button type="button" class="btn-secondary" @click="showModal = false">{{ t('common.cancel') }}</button>
          <button type="submit" class="btn-primary" :disabled="saving || !productId || !selectedIds.length">
            {{ saving ? t('common.loading') : t('common.save') }}
          </button>
        </div>
      </form>
    </AppModal>
  </CatalogLayout>
</template>

<style scoped>
.field { width: 100%; border-radius: 0.5rem; border: 1px solid #cbd5e1; padding: 0.5rem 0.75rem; background: white; }
.btn-primary { border-radius: 0.5rem; padding: 0.5rem 1rem; font-weight: 500; color: white; background-color: var(--color-brand-600); }
.btn-primary:disabled { opacity: 0.5; }
.btn-secondary { border-radius: 0.5rem; border: 1px solid #cbd5e1; padding: 0.5rem 1rem; font-weight: 500; background: white; }
.text-brand-600 { color: var(--color-brand-600); }
</style>
