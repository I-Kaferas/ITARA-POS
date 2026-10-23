<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue'
import { watchLiveSearch } from '../../composables/useLiveSearch'
import { useI18n } from 'vue-i18n'
import { useConfirm } from '../../composables/useConfirm'
import { useRouter } from 'vue-router'
import CatalogLayout from '../../components/catalog/CatalogLayout.vue'
import AppIcon from '../../components/ui/AppIcon.vue'
import FilterFold from '../../components/ui/FilterFold.vue'
import Badge from '../../components/ui/Badge.vue'
import DataTableShell from '../../components/ui/DataTableShell.vue'
import { extractApiErrorMessage } from '../../api/client'
import { realtimeTopics, useRealtimeSync } from '../../composables/useRealtimeSync'
import { useBackofficeStore } from '../../stores/backoffice'
import { useContextStore } from '../../stores/context'
import type { Catalog, Company, Product } from '../../types'
import { isStockableProduct } from '../../utils/product'
import { formatMoney } from '../../utils/format'

const { t } = useI18n()
const { confirm: confirmDialog } = useConfirm()
const router = useRouter()
const store = useBackofficeStore()
const context = useContextStore()

const search = ref('')
const selectedCompany = ref<Company | null>(null)
const selectedCatalog = ref<Catalog | null>(null)
const rows = ref<Product[]>([])
const page = ref(1)
const lastPage = ref(1)
const total = ref(0)
const loadingProducts = ref(false)
const perPage = 40
const fileInput = ref<HTMLInputElement | null>(null)
const exportOpen = ref(false)
const importing = ref(false)
const importNotice = ref('')
const importError = ref('')
const importRowErrors = ref<string[]>([])

onMounted(async () => {
  await context.loadStores()
  await store.loadCompanies()
  if (store.companies.length) {
    selectedCompany.value = store.companies[0]
    await selectCompany(store.companies[0].id)
  }
})

watch(() => context.currentStoreId, async () => {
  if (selectedCompany.value) await selectCompany(selectedCompany.value.id)
})

async function selectCompany(companyId: string) {
  selectedCompany.value = store.companies.find(c => c.id === companyId) ?? null
  const catalogs = await store.loadCatalogs(companyId, context.currentStoreId)
  selectedCatalog.value = catalogs.find(c => c.is_default) ?? catalogs[0] ?? null
  page.value = 1
  if (selectedCatalog.value) await loadPage(1)
}

async function loadPage(next = page.value) {
  if (!selectedCatalog.value) return
  loadingProducts.value = true
  page.value = next
  try {
    const response = await store.loadProductPage(selectedCatalog.value.id, search.value, next, perPage)
    rows.value = response.data
    lastPage.value = response.meta.last_page
    total.value = response.meta.total
  } finally {
    loadingProducts.value = false
  }
}

async function onSearch() {
  page.value = 1
  await loadPage(1)
}

watchLiveSearch(search, onSearch)

useRealtimeSync(realtimeTopics.catalog, () => {
  if (selectedCatalog.value) void loadPage(page.value)
})

async function removeProduct(id: string) {
  if (!(await confirmDialog(t('products.confirmDelete')))) return
  await store.deleteProduct(id)
  await loadPage(page.value)
}


function primaryImage(product: { images?: { cdn_url: string; is_primary: boolean }[] }) {
  return product.images?.find(i => i.is_primary)?.cdn_url ?? product.images?.[0]?.cdn_url
}

const catalogOptions = computed(() => store.catalogs)
const productCount = computed(() => total.value)
const pageFrom = computed(() => (total.value === 0 ? 0 : (page.value - 1) * perPage + 1))
const pageTo = computed(() => Math.min(page.value * perPage, total.value))

function escapeHtml(value: string) {
  return value.replace(/[&<>"']/g, (char) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[char] ?? char))
}

async function onImport(event: Event) {
  const input = event.target as HTMLInputElement
  const file = input.files?.[0]
  input.value = ''
  if (!file || !selectedCatalog.value) return
  importing.value = true
  importNotice.value = ''
  importError.value = ''
  importRowErrors.value = []
  try {
    const result = await store.importProducts(selectedCatalog.value.id, file, true)
    importNotice.value = t('products.importDone', { created: result.created, updated: result.updated, skipped: result.skipped })
    importRowErrors.value = result.errors ?? []
    await loadPage(1)
  } catch (error) {
    importError.value = extractApiErrorMessage(error, t('products.importFailed'))
  } finally {
    importing.value = false
  }
}

async function exportExcel() {
  exportOpen.value = false
  if (!selectedCatalog.value) return
  importError.value = ''
  try {
    await store.exportProducts(selectedCatalog.value.id, 'xlsx')
  } catch (error) {
    importError.value = extractApiErrorMessage(error, t('products.importFailed'))
  }
}

async function downloadTemplate() {
  exportOpen.value = false
  importError.value = ''
  try {
    await store.downloadProductTemplate()
  } catch (error) {
    importError.value = extractApiErrorMessage(error, t('products.importFailed'))
  }
}

async function exportPdf() {
  exportOpen.value = false
  if (!selectedCatalog.value) return
  const products = await store.loadProducts(selectedCatalog.value.id)
  const popup = window.open('', '_blank', 'noopener,noreferrer')
  if (!popup) return
  const body = products.map((product) => `<tr>
    <td>${escapeHtml(product.sku)}</td>
    <td>${escapeHtml(product.name)}</td>
    <td>${escapeHtml(formatMoney(product.base_price))}</td>
    <td>${escapeHtml(formatMoney(product.cost_price ?? 0))}</td>
    <td>${escapeHtml(product.is_active ? t('products.active') : t('products.inactive'))}</td>
  </tr>`).join('')
  popup.document.write(`<!DOCTYPE html><html><head><meta charset="utf-8"><title>${escapeHtml(selectedCatalog.value.name)}</title>
    <style>body{font-family:sans-serif;padding:24px;color:#12243c}h1{font-size:18px}table{width:100%;border-collapse:collapse}th,td{border-bottom:1px solid #e2e8f0;padding:8px;text-align:left;font-size:12px}</style>
    </head><body><h1>${escapeHtml(selectedCatalog.value.name)}</h1>
    <table><thead><tr><th>SKU</th><th>${escapeHtml(t('products.name'))}</th><th>${escapeHtml(t('products.price'))}</th><th>${escapeHtml(t('products.cost'))}</th><th>${escapeHtml(t('products.status'))}</th></tr></thead>
    <tbody>${body}</tbody></table></body></html>`)
  popup.document.close()
  popup.focus()
  popup.print()
}
</script>

<template>
  <CatalogLayout>
    <div class="ui-toolbar">
      <div class="ui-field min-w-[10rem]">
        <label class="ui-label">{{ t('org.company') }}</label>
        <select class="ui-select" :value="selectedCompany?.id" @change="selectCompany(($event.target as HTMLSelectElement).value)">
          <option v-for="c in store.companies" :key="c.id" :value="c.id">{{ c.name }}</option>
        </select>
      </div>
      <div class="ui-field min-w-[10rem]">
        <label class="ui-label">{{ t('nav.catalogs') }}</label>
        <select
          class="ui-select"
          :value="selectedCatalog?.id"
          @change="selectedCatalog = catalogOptions.find(c => c.id === ($event.target as HTMLSelectElement).value) ?? null; page = 1; selectedCatalog && loadPage(1)"
        >
          <option v-for="c in catalogOptions" :key="c.id" :value="c.id">{{ c.name }}</option>
        </select>
      </div>
      <FilterFold>
      <div class="ui-field flex-1 min-w-[12rem]">
        <label class="ui-label">{{ t('common.search') }}</label>
        <div class="relative">
          <AppIcon name="search" :size="15" class="pointer-events-none absolute left-2.5 top-1/2 -translate-y-1/2 text-slate-400" />
          <input
            v-model="search"
            type="search"
            class="ui-input !pl-8"
            :placeholder="t('products.searchPlaceholder')"
          />
        </div>
      </div>
      </FilterFold>
      <div class="products-actions">
        <button type="button" class="btn-secondary" :disabled="!selectedCatalog || importing" @click="fileInput?.click()">
          <AppIcon name="upload" :size="16" />
          {{ t('products.importExcel') }}
        </button>
        <input ref="fileInput" class="sr-only" type="file" accept=".xlsx,.csv,text/csv,application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" @change="onImport" />
        <div class="products-export">
          <button type="button" class="btn-secondary" :disabled="!selectedCatalog" @click="exportOpen = !exportOpen">
            <AppIcon name="download" :size="16" />
            {{ t('products.exportPdfExcel') }}
          </button>
          <div class="fold-panel fold-panel--pop products-export__pop" :class="{ 'is-open': exportOpen }">
          <div class="fold-panel__body" :inert="!exportOpen">
          <div class="products-export__menu">
            <button type="button" @click="exportPdf">{{ t('products.exportPdf') }}</button>
            <button type="button" @click="exportExcel">{{ t('products.exportExcel') }}</button>
            <button type="button" @click="downloadTemplate">{{ t('products.downloadTemplate') }}</button>
          </div>
          </div>
          </div>
        </div>
        <button
          type="button"
          class="btn-primary"
          :disabled="!selectedCatalog"
          @click="router.push({ name: 'product-create', query: { catalogId: selectedCatalog?.id } })"
        >
          <AppIcon name="plus" :size="16" />
          {{ t('products.newAction') }}
        </button>
      </div>
    </div>

    <p v-if="importNotice" class="products-note" role="status">{{ importNotice }}</p>
    <p v-if="importError" class="products-note products-note--error" role="alert">{{ importError }}</p>
    <div v-if="importRowErrors.length" class="products-note products-note--error products-import-errors" role="alert">
      <p>{{ t('products.importRowErrors', { count: importRowErrors.length }) }}</p>
      <ul>
        <li v-for="(message, i) in importRowErrors" :key="i">{{ message }}</li>
      </ul>
    </div>

    <DataTableShell
      :title="t('nav.products')"
      :meta="productCount ? `${pageFrom}–${pageTo} / ${total}` : undefined"
      :loading="loadingProducts"
      :loading-label="t('common.loading')"
      :empty="!loadingProducts && !productCount"
      empty-icon="products"
      :empty-title="t('products.empty')"
      :empty-description="t('products.emptyHint')"
    >
      <template v-if="lastPage > 1" #toolbar>
        <button class="ui-btn ui-btn--ghost ui-btn--sm" type="button" :disabled="page <= 1" @click="loadPage(page - 1)">‹</button>
        <span class="text-xs text-slate-500">{{ page }} / {{ lastPage }}</span>
        <button class="ui-btn ui-btn--ghost ui-btn--sm" type="button" :disabled="page >= lastPage" @click="loadPage(page + 1)">›</button>
      </template>
      <template #emptyActions>
        <button
          class="ui-btn ui-btn--primary mt-4"
          :disabled="!selectedCatalog"
          @click="router.push({ name: 'product-create', query: { catalogId: selectedCatalog?.id } })"
        >
          <AppIcon name="plus" :size="16" />
          {{ t('products.newAction') }}
        </button>
      </template>
      <table class="ui-table">
        <thead>
          <tr>
            <th>{{ t('products.image') }}</th>
            <th>SKU</th>
            <th>{{ t('products.name') }}</th>
            <th>{{ t('products.type') }}</th>
            <th>{{ t('products.price') }}</th>
            <th>{{ t('products.cost') }}</th>
            <th>{{ t('catalog.tabs.taxes') }}</th>
            <th>{{ t('products.stock') }}</th>
            <th>{{ t('products.status') }}</th>
            <th />
          </tr>
        </thead>
        <tbody>
          <tr v-for="product in rows" :key="product.id">
            <td>
              <img
                v-if="primaryImage(product)"
                :src="primaryImage(product)"
                loading="lazy"
                decoding="async"
                class="h-10 w-10 rounded-lg object-cover ring-1 ring-slate-200"
                alt=""
              />
              <div v-else class="flex h-10 w-10 items-center justify-center rounded-lg bg-slate-100 text-slate-300">
                <AppIcon name="products" :size="16" />
              </div>
            </td>
            <td>
              <code class="font-mono rounded bg-slate-100 px-1.5 py-0.5 text-xs text-slate-600">{{ product.sku }}</code>
              <span v-if="product.barcode" class="mt-1 block text-xs text-slate-400">{{ product.barcode }}</span>
            </td>
            <td class="!font-semibold !text-slate-800">
              {{ product.name }}
              <span class="mt-1 block text-xs font-normal text-slate-400">
                {{ [product.category?.name, product.brand?.name, product.unit_model?.symbol || product.unit].filter(Boolean).join(' · ') || '—' }}
              </span>
            </td>
            <td>
              <Badge :variant="isStockableProduct(product) ? 'brand' : 'warning'">
                {{ isStockableProduct(product) ? t('products.natures.quantifiable.label') : t('products.natures.service.label') }}
              </Badge>
              <span v-if="isStockableProduct(product)" class="mt-1 block text-xs text-slate-500">
                {{ t(`products.types.${product.product_type ?? 'simple'}.label`) }}
              </span>
            </td>
            <td class="num">{{ formatMoney(product.base_price) }}</td>
            <td class="num">{{ formatMoney(product.cost_price ?? 0) }}</td>
            <td class="text-slate-600">{{ product.tax ? `${product.tax.code ?? product.tax.name}` : '—' }}</td>
            <td class="num">{{ isStockableProduct(product) ? (product.stock ?? 0) : '' }}</td>
            <td>
              <Badge :variant="product.is_active ? 'success' : 'neutral'">
                {{ product.is_active ? t('products.active') : t('products.inactive') }}
              </Badge>
            </td>
            <td class="text-right">
              <div class="ui-table__actions">
                <button class="ui-btn ui-btn--ghost ui-btn--sm" @click="router.push({ name: 'product-edit', params: { id: product.id } })">
                  <AppIcon name="edit" :size="16" />
                  {{ t('common.edit') }}
                </button>
                <button class="ui-btn ui-btn--danger ui-btn--sm" @click="removeProduct(product.id)">
                  <AppIcon name="trash" :size="16" />
                  {{ t('common.delete') }}
                </button>
              </div>
            </td>
          </tr>
        </tbody>
      </table>
    </DataTableShell>
  </CatalogLayout>
</template>

<style scoped>
.products-actions {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 0.5rem;
  width: 100%;
}

.products-export {
  position: relative;
}

.products-export__pop {
  position: absolute;
  z-index: 20;
  top: calc(100% + 0.35rem);
  right: 0;
}

.products-export__menu {
  min-width: 8rem;
  display: flex;
  flex-direction: column;
  padding: 0.35rem;
  border: 1px solid var(--color-border);
  border-radius: var(--radius-md);
  background: var(--color-surface);
  box-shadow: var(--shadow-lg);
}

.products-export__menu button {
  border: 0;
  background: transparent;
  text-align: left;
  padding: 0.45rem 0.6rem;
  border-radius: var(--radius-sm, 0.4rem);
  cursor: pointer;
  color: var(--color-text-primary);
}

.products-export__menu button:hover {
  background: var(--color-canvas);
}

.products-note {
  margin: 0 0 0.75rem;
  font-size: 0.85rem;
  color: var(--color-text-secondary);
}

.products-note--error {
  color: var(--color-danger, #b91c1c);
}

.products-import-errors {
  max-height: 12rem;
  overflow-y: auto;
  padding: 0.75rem 1rem;
  border: 1px solid color-mix(in srgb, var(--color-danger, #b91c1c) 25%, transparent);
  border-radius: 12px;
  background: var(--color-danger-bg, #fef2f2);
}

.products-import-errors p {
  margin: 0 0 0.35rem;
  font-weight: 600;
}

.products-import-errors ul {
  margin: 0;
  padding-left: 1.1rem;
  list-style: disc;
}

.sr-only {
  position: absolute;
  width: 1px;
  height: 1px;
  padding: 0;
  margin: -1px;
  overflow: hidden;
  clip: rect(0, 0, 0, 0);
  white-space: nowrap;
  border: 0;
}
</style>
