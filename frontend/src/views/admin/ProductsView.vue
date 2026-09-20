<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue'
import { watchLiveSearch } from '../../composables/useLiveSearch'
import { useI18n } from 'vue-i18n'
import { useConfirm } from '../../composables/useConfirm'
import { useRouter } from 'vue-router'
import CatalogLayout from '../../components/catalog/CatalogLayout.vue'
import AppIcon from '../../components/ui/AppIcon.vue'
import Badge from '../../components/ui/Badge.vue'
import EmptyState from '../../components/ui/EmptyState.vue'
import { useBackofficeStore } from '../../stores/backoffice'
import { useContextStore } from '../../stores/context'
import type { Catalog, Company } from '../../types'
import { isStockableProduct } from '../../utils/product'

const { t } = useI18n()
const { confirm: confirmDialog } = useConfirm()
const router = useRouter()
const store = useBackofficeStore()
const context = useContextStore()

const search = ref('')
const selectedCompany = ref<Company | null>(null)
const selectedCatalog = ref<Catalog | null>(null)

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
  if (selectedCatalog.value) {
    await store.loadProducts(selectedCatalog.value.id, search.value)
  }
}

async function onSearch() {
  if (selectedCatalog.value) {
    await store.loadProducts(selectedCatalog.value.id, search.value)
  }
}

watchLiveSearch(search, onSearch)

async function removeProduct(id: string) {
  if (!(await confirmDialog(t('products.confirmDelete')))) return
  await store.deleteProduct(id)
  if (selectedCatalog.value) {
    await store.loadProducts(selectedCatalog.value.id, search.value)
  }
}

function formatPrice(cents: number) {
  return (cents / 100).toFixed(2)
}

function primaryImage(product: { images?: { cdn_url: string; is_primary: boolean }[] }) {
  return product.images?.find(i => i.is_primary)?.cdn_url ?? product.images?.[0]?.cdn_url
}

const catalogOptions = computed(() => store.catalogs)
const productCount = computed(() => store.products.length)
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
          @change="selectedCatalog = catalogOptions.find(c => c.id === ($event.target as HTMLSelectElement).value) ?? null; selectedCatalog && store.loadProducts(selectedCatalog.id, search)"
        >
          <option v-for="c in catalogOptions" :key="c.id" :value="c.id">{{ c.name }}</option>
        </select>
      </div>
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
      <button
        class="ui-btn ui-btn--primary self-end"
        :disabled="!selectedCatalog"
        @click="router.push({ name: 'product-create', query: { catalogId: selectedCatalog?.id } })"
      >
        <AppIcon name="plus" :size="16" />
        {{ t('products.new') }}
      </button>
    </div>

    <div v-if="store.loading" class="flex items-center gap-2 py-12 text-sm text-slate-500">
      <span class="inline-block h-4 w-4 animate-spin rounded-full border-2 border-brand-500 border-t-transparent" />
      {{ t('common.loading') }}
    </div>

    <div v-else class="ui-table-wrap">
      <div v-if="productCount" class="flex items-center justify-between border-b border-slate-100 px-4 py-3">
        <p class="m-0 text-xs font-medium text-slate-500">
          {{ productCount }} {{ productCount > 1 ? 'produits' : 'produit' }}
        </p>
      </div>

      <table v-if="productCount" class="ui-table">
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
          <tr v-for="product in store.products" :key="product.id">
            <td>
              <img
                v-if="primaryImage(product)"
                :src="primaryImage(product)"
                class="h-10 w-10 rounded-lg object-cover ring-1 ring-slate-200"
                alt=""
              />
              <div v-else class="flex h-10 w-10 items-center justify-center rounded-lg bg-slate-100 text-slate-300">
                <AppIcon name="products" :size="16" />
              </div>
            </td>
            <td>
              <code class="rounded bg-slate-100 px-1.5 py-0.5 text-xs text-slate-600">{{ product.sku }}</code>
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
            <td class="!font-medium">{{ formatPrice(product.base_price) }}</td>
            <td>{{ formatPrice(product.cost_price ?? 0) }}</td>
            <td class="text-slate-600">{{ product.tax ? `${product.tax.code ?? product.tax.name}` : '—' }}</td>
            <td>{{ isStockableProduct(product) ? (product.stock ?? 0) : '—' }}</td>
            <td>
              <Badge :variant="product.is_active ? 'success' : 'neutral'">
                {{ product.is_active ? t('products.active') : t('products.inactive') }}
              </Badge>
            </td>
            <td class="text-right">
              <div class="flex items-center justify-end gap-1">
                <button class="ui-btn ui-btn--ghost ui-btn--sm" @click="router.push({ name: 'product-edit', params: { id: product.id } })">
                  {{ t('common.edit') }}
                </button>
                <button class="ui-btn ui-btn--danger ui-btn--sm" @click="removeProduct(product.id)">
                  {{ t('common.delete') }}
                </button>
              </div>
            </td>
          </tr>
        </tbody>
      </table>

      <EmptyState
        v-else
        icon="products"
        :title="t('products.empty')"
        :description="t('products.emptyHint')"
      >
        <button
          class="ui-btn ui-btn--primary mt-4"
          :disabled="!selectedCatalog"
          @click="router.push({ name: 'product-create', query: { catalogId: selectedCatalog?.id } })"
        >
          <AppIcon name="plus" :size="16" />
          {{ t('products.new') }}
        </button>
      </EmptyState>
    </div>
  </CatalogLayout>
</template>

<style scoped>
.border-brand-500 { border-color: var(--color-brand-500); }
</style>
