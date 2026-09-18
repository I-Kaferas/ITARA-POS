<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue'
import { RouterLink } from 'vue-router'
import { useI18n } from 'vue-i18n'
import PageFrame from '../../components/layout/PageFrame.vue'
import AppIcon from '../../components/ui/AppIcon.vue'
import AppModal from '../../components/ui/AppModal.vue'
import EmptyState from '../../components/ui/EmptyState.vue'
import FieldLabel from '../../components/ui/FieldLabel.vue'
import { useConfirm } from '../../composables/useConfirm'
import { useAuthStore } from '../../stores/auth'
import { useBackofficeStore } from '../../stores/backoffice'
import { useContextStore } from '../../stores/context'
import type { Product, StoreProductItem } from '../../types'
import { formatMoney } from '../../utils/format'

const { t } = useI18n()
const { confirm: confirmDialog } = useConfirm()
const auth = useAuthStore()
const store = useBackofficeStore()
const context = useContextStore()

const catalogId = ref('')
const availableProducts = ref<Product[]>([])
const selectedIds = ref<string[]>([])
const importing = ref(false)
const loading = ref(true)
const editingItem = ref<StoreProductItem | null>(null)
const priceOverride = ref<number | null>(null)
const catalogQuery = ref('')
const storeQuery = ref('')

const firstName = computed(() => auth.user?.name?.split(' ')[0] ?? '')
const currentStore = computed(() => context.currentStore)
const storeName = computed(() => currentStore.value?.name ?? '')
const storePlace = computed(() => {
  const branch = currentStore.value?.branch?.name
  const company = currentStore.value?.branch?.company?.name
  return [branch, company].filter(Boolean).join(' · ')
})
const storeKind = computed(() => {
  if (!currentStore.value) return ''
  return currentStore.value.kind === 'boutique' ? t('org.boutiqueKind') : t('org.storeKind')
})
const showKindPill = computed(() => {
  if (!storeKind.value || !storeName.value) return false
  return storeName.value.trim().toLowerCase() !== storeKind.value.trim().toLowerCase()
})

const importedIds = computed(() => new Set(store.storeProducts.map(item => item.product_id)))
const notImported = computed(() => availableProducts.value.filter(product => !importedIds.value.has(product.id)))

const filteredCatalog = computed(() => notImported.value.filter(product => matchesProduct(product, catalogQuery.value)))
const filteredImported = computed(() =>
  store.storeProducts.filter(item => matchesProduct(item.product, storeQuery.value)),
)

const selectedCount = computed(() => selectedIds.value.length)
const waitingCount = computed(() => notImported.value.length)
const inStoreCount = computed(() => store.storeProducts.length)

onMounted(loadPage)

watch(() => context.currentStoreId, async (id) => {
  selectedIds.value = []
  storeQuery.value = ''
  if (id) await store.loadStoreProducts(id)
})

async function loadPage() {
  loading.value = true
  try {
    await context.loadStores()
    await store.loadCompanies()
    if (!store.companies.length) return

    const catalogs = await store.loadCatalogs(store.companies[0].id)
    catalogId.value = catalogs.find(c => c.is_default)?.id ?? catalogs[0]?.id ?? ''
    if (catalogId.value) {
      availableProducts.value = await store.loadProducts(catalogId.value)
    }

    if (context.currentStoreId) {
      await store.loadStoreProducts(context.currentStoreId)
    }
  } finally {
    loading.value = false
  }
}

function matchesProduct(product: Product, query: string) {
  const needle = query.trim().toLowerCase()
  if (!needle) return true
  const haystack = [
    product.name,
    product.sku,
    product.barcode,
    ...(product.barcodes?.map(code => code.barcode) ?? []),
  ]
    .filter(Boolean)
    .join(' ')
    .toLowerCase()
  return haystack.includes(needle)
}

function productImage(product?: Product | null) {
  return product?.images?.find(image => image.is_primary)?.cdn_url ?? product?.images?.[0]?.cdn_url ?? ''
}

function toggle(id: string) {
  selectedIds.value = selectedIds.value.includes(id)
    ? selectedIds.value.filter(item => item !== id)
    : [...selectedIds.value, id]
}

function selectVisible() {
  const visible = filteredCatalog.value.map(product => product.id)
  selectedIds.value = [...new Set([...selectedIds.value, ...visible])]
}

function clearSelection() {
  selectedIds.value = []
}

async function importSelected() {
  if (!context.currentStoreId || !selectedIds.value.length) return
  importing.value = true
  try {
    await store.importToStore(context.currentStoreId, selectedIds.value)
    selectedIds.value = []
    catalogQuery.value = ''
    await store.loadStoreProducts(context.currentStoreId)
  } finally {
    importing.value = false
  }
}

async function remove(item: StoreProductItem) {
  if (!context.currentStoreId) return
  const ok = await confirmDialog(t('stores.confirmRemove', { name: item.product.name }), {
    title: t('stores.imported'),
    confirmLabel: t('stores.remove'),
    danger: true,
  })
  if (!ok) return
  await store.removeFromStore(context.currentStoreId, item.product_id)
  await store.loadStoreProducts(context.currentStoreId)
}

function openPriceEdit(item: StoreProductItem) {
  editingItem.value = item
  priceOverride.value = item.price_override != null ? item.price_override / 100 : null
}

async function savePriceOverride() {
  if (!context.currentStoreId || !editingItem.value) return
  await store.updateStoreProduct(context.currentStoreId, editingItem.value.product_id, {
    price_override: priceOverride.value != null ? Math.round(priceOverride.value * 100) : null,
  })
  editingItem.value = null
  await store.loadStoreProducts(context.currentStoreId)
}
</script>

<template>
  <PageFrame>
    <template #title>{{ t('stores.title') }}</template>
    <template #subtitle>{{ t('stores.subtitle') }}</template>

    <div v-if="loading" class="flex items-center gap-2 py-16 text-sm text-slate-500">
      <span class="inline-block h-4 w-4 animate-spin rounded-full border-2 border-brand-500 border-t-transparent" />
      {{ t('common.loading') }}
    </div>

    <template v-else>
      <div class="stores-home">
      <section class="home-banner">
        <div class="home-banner__content">
          <p class="home-banner__eyebrow">
            <AppIcon name="stores" :size="14" />
            {{ t('stores.welcomeEyebrow') }}
          </p>
          <p class="home-banner__hello">
            {{ firstName ? t('stores.hello', { name: firstName }) : t('stores.helloGeneric') }}
          </p>
          <h2 class="home-banner__store">
            {{ storeName || t('stores.select') }}
            <span v-if="showKindPill" class="kind-pill">{{ storeKind }}</span>
          </h2>
          <p v-if="storePlace" class="home-banner__place">{{ storePlace }}</p>
          <p class="home-banner__hint">
            {{ currentStore ? t('stores.welcomeHint') : t('stores.noStoreHint') }}
          </p>
        </div>
        <div class="home-banner__actions">
          <RouterLink v-if="currentStore" class="ui-btn ui-btn--primary" to="/admin/pos/shifts">
            <AppIcon name="shift" :size="16" />
            {{ t('stores.openPos') }}
          </RouterLink>
          <RouterLink class="ui-btn ui-btn--secondary" to="/admin/products">
            <AppIcon name="products" :size="16" />
            {{ t('stores.openCatalog') }}
          </RouterLink>
        </div>
        <AppIcon name="stores" :size="96" class="home-banner__mark" />
      </section>

      <div v-if="currentStore" class="home-strip">
        <div class="home-chip home-chip--warm">
          <AppIcon name="stores" :size="16" />
          <strong>{{ inStoreCount }}</strong>
          <span>{{ t('stores.inStore') }}</span>
        </div>
        <div class="home-chip">
          <AppIcon name="catalog" :size="16" />
          <strong>{{ waitingCount }}</strong>
          <span>{{ t('stores.waiting') }}</span>
        </div>
        <div class="home-chip" :class="{ 'home-chip--active': selectedCount }">
          <AppIcon name="import" :size="16" />
          <strong>{{ selectedCount }}</strong>
          <span>{{ t('stores.selected') }}</span>
        </div>
      </div>

      <EmptyState
        v-if="!currentStore"
        icon="stores"
        :title="t('stores.noStoreTitle')"
        :description="t('stores.noStoreHint')"
      />

      <div v-else class="assortment-grid">
        <section class="ui-card assortment-card">
          <div class="ui-card__header">
            <div>
              <h3 class="ui-card__title">{{ t('stores.importFromCatalog') }}</h3>
              <p class="ui-card__desc">{{ t('stores.sourceHint') }}</p>
            </div>
            <span class="count-pill">{{ waitingCount }}</span>
          </div>
          <div class="ui-card__body flex flex-1 flex-col gap-4">
            <div class="relative">
              <AppIcon name="search" :size="15" class="pointer-events-none absolute left-2.5 top-1/2 -translate-y-1/2 text-slate-400" />
              <input
                v-model="catalogQuery"
                type="search"
                class="ui-input !pl-8"
                :placeholder="t('stores.searchCatalog')"
              />
            </div>
            <div class="flex flex-wrap items-center gap-2">
              <button type="button" class="ui-btn ui-btn--ghost ui-btn--sm" :disabled="!filteredCatalog.length" @click="selectVisible">
                {{ t('stores.selectVisible') }}
              </button>
              <button type="button" class="ui-btn ui-btn--ghost ui-btn--sm" :disabled="!selectedCount" @click="clearSelection">
                {{ t('stores.clearSelection') }}
              </button>
            </div>

            <div class="product-list">
              <label
                v-for="product in filteredCatalog"
                :key="product.id"
                class="product-row"
                :class="{ 'product-row--selected': selectedIds.includes(product.id) }"
              >
                <input
                  class="product-row__check"
                  type="checkbox"
                  :checked="selectedIds.includes(product.id)"
                  @change="toggle(product.id)"
                />
                <img
                  v-if="productImage(product)"
                  :src="productImage(product)"
                  :alt="product.name"
                  class="product-row__photo"
                />
                <div v-else class="product-row__photo product-row__photo--empty">
                  <AppIcon name="products" :size="16" />
                </div>
                <div class="min-w-0 flex-1">
                  <p class="product-row__name">{{ product.name }}</p>
                  <p class="product-row__meta">
                    {{ product.sku }}
                    <span v-if="product.barcode"> · {{ product.barcode }}</span>
                  </p>
                </div>
                <strong class="product-row__price">{{ formatMoney(product.base_price) }}</strong>
              </label>

              <EmptyState
                v-if="!availableProducts.length"
                icon="catalog"
                :title="t('stores.emptyCatalogTitle')"
                :description="t('stores.emptyCatalogDesc')"
              >
                <RouterLink class="ui-btn ui-btn--primary mt-4" to="/admin/products">
                  <AppIcon name="plus" :size="16" />
                  {{ t('products.new') }}
                </RouterLink>
              </EmptyState>
              <EmptyState
                v-else-if="!notImported.length"
                icon="sparkles"
                :title="t('stores.allHereTitle')"
                :description="t('stores.allHereDesc')"
              />
              <p v-else-if="!filteredCatalog.length" class="empty-line">{{ t('stores.noMatch') }}</p>
            </div>

            <button
              type="button"
              class="ui-btn ui-btn--primary mt-auto w-full"
              :disabled="!selectedCount || importing"
              @click="importSelected"
            >
              <AppIcon name="import" :size="16" />
              {{ importing ? t('common.loading') : `${t('stores.importSelected')}${selectedCount ? ` (${selectedCount})` : ''}` }}
            </button>
          </div>
        </section>

        <section class="ui-card assortment-card">
          <div class="ui-card__header">
            <div>
              <h3 class="ui-card__title">{{ t('stores.imported') }}</h3>
              <p class="ui-card__desc">{{ t('stores.storeHint') }}</p>
            </div>
            <span class="count-pill count-pill--warm">{{ inStoreCount }}</span>
          </div>
          <div class="ui-card__body flex flex-1 flex-col gap-4">
            <div class="relative">
              <AppIcon name="search" :size="15" class="pointer-events-none absolute left-2.5 top-1/2 -translate-y-1/2 text-slate-400" />
              <input
                v-model="storeQuery"
                type="search"
                class="ui-input !pl-8"
                :placeholder="t('stores.searchImported')"
              />
            </div>

            <div class="product-list">
              <div v-for="item in filteredImported" :key="item.id" class="product-row product-row--home">
                <img
                  v-if="productImage(item.product)"
                  :src="productImage(item.product)"
                  :alt="item.product.name"
                  class="product-row__photo"
                />
                <div v-else class="product-row__photo product-row__photo--empty product-row__photo--warm">
                  <AppIcon name="stores" :size="16" />
                </div>
                <div class="min-w-0 flex-1">
                  <p class="product-row__name">{{ item.product.name }}</p>
                  <p class="product-row__meta">
                    {{ formatMoney(item.effective_price) }}
                    <span v-if="item.price_override" class="price-tag">{{ t('stores.override') }}</span>
                    <span v-else class="text-slate-400"> · {{ t('stores.catalogPrice') }}</span>
                  </p>
                </div>
                <div class="flex shrink-0 items-center gap-1">
                  <button type="button" class="ui-btn ui-btn--ghost ui-btn--sm" @click="openPriceEdit(item)">
                    {{ t('products.price') }}
                  </button>
                  <button type="button" class="ui-btn ui-btn--ghost ui-btn--sm text-red-600" @click="remove(item)">
                    {{ t('stores.remove') }}
                  </button>
                </div>
              </div>

              <EmptyState
                v-if="!store.storeProducts.length"
                icon="stores"
                :title="t('stores.emptyTitle')"
                :description="t('stores.emptyDesc')"
              />
              <p v-else-if="!filteredImported.length" class="empty-line">{{ t('stores.noMatch') }}</p>
            </div>
          </div>
        </section>
      </div>
      </div>
    </template>

    <AppModal
      :open="!!editingItem"
      :title="t('stores.priceOverride')"
      icon="coins"
      tone="accent"
      size="sm"
      @close="editingItem = null"
    >
      <form class="space-y-3" @submit.prevent="savePriceOverride">
        <p class="m-0 text-sm font-medium text-slate-800">{{ editingItem?.product.name }}</p>
        <p class="m-0 text-xs text-slate-500">
          {{ t('stores.catalogPrice') }} :
          {{ editingItem ? formatMoney(editingItem.product.base_price) : '—' }}
        </p>
        <FieldLabel icon="coins">{{ t('stores.storePrice') }}</FieldLabel>
        <input
          v-model.number="priceOverride"
          type="number"
          step="0.01"
          min="0"
          class="ui-input"
          :placeholder="t('stores.leaveEmptyForDefault')"
        />
        <div class="app-modal__actions">
          <button type="button" class="ui-btn ui-btn--secondary" @click="editingItem = null">{{ t('common.cancel') }}</button>
          <button type="submit" class="ui-btn ui-btn--primary">{{ t('common.save') }}</button>
        </div>
      </form>
    </AppModal>
  </PageFrame>
</template>

<style scoped>
.stores-home {
  display: flex;
  flex: 1;
  min-height: 0;
  height: 100%;
  flex-direction: column;
  overflow-x: hidden;
  overflow-y: auto;
  overscroll-behavior: contain;
  padding-right: 0.15rem;
}

.home-banner {
  position: relative;
  overflow: hidden;
  display: flex;
  flex-shrink: 0;
  flex-wrap: wrap;
  align-items: center;
  justify-content: space-between;
  gap: 0.75rem 1.25rem;
  margin-bottom: 0.85rem;
  padding: 0.85rem 1.15rem;
  border: 1px solid var(--color-border);
  border-radius: var(--radius-lg);
  background: #fff;
}

.home-strip {
  display: flex;
  flex-shrink: 0;
  flex-wrap: wrap;
  gap: 0.6rem;
  margin-bottom: 1rem;
}

.home-chip {
  display: inline-flex;
  align-items: center;
  gap: 0.45rem;
  min-height: 2.5rem;
  padding: 0 0.85rem;
  border: 1px solid #e2e8f0;
  border-radius: 999px;
  background: #fff;
  color: #64748b;
  font-size: 0.8rem;
}

.home-chip strong {
  color: #1a2833;
  font-size: 0.95rem;
  font-weight: 700;
}

.home-chip--warm {
  border-color: rgba(227, 155, 43, 0.28);
  background: #fffdf8;
  color: #b45309;
}

.home-chip--warm strong {
  color: #b45309;
}

.home-chip--active {
  border-color: rgba(15, 118, 110, 0.28);
  background: #f0fdfa;
  color: #0f766e;
}

.home-chip--active strong {
  color: #0f766e;
}

.assortment-grid {
  display: grid;
  flex-shrink: 0;
  gap: 1.25rem;
  padding-bottom: 0.5rem;
}

.assortment-card {
  display: flex;
  min-height: 22rem;
  flex-direction: column;
}

@media (min-width: 1100px) {
  .assortment-grid {
    grid-template-columns: 1fr 1fr;
    align-items: start;
  }
}

.home-banner__content {
  position: relative;
  z-index: 1;
  max-width: 38rem;
}

.home-banner__eyebrow {
  display: inline-flex;
  align-items: center;
  gap: 0.4rem;
  margin: 0 0 0.4rem;
  color: #b45309;
  font-size: 0.72rem;
  font-weight: 600;
  letter-spacing: 0.08em;
  text-transform: uppercase;
}

.home-banner__store {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 0.55rem;
  margin: 0.1rem 0 0;
  color: #1a2833;
  font-family: var(--font-sans);
  font-size: 1.4rem;
  font-weight: 600;
  letter-spacing: -0.03em;
  line-height: 1.2;
}

.kind-pill {
  display: inline-flex;
  align-items: center;
  height: 1.4rem;
  padding: 0 0.55rem;
  border-radius: 999px;
  background: rgba(180, 83, 9, 0.1);
  color: #b45309;
  font-size: 0.7rem;
  font-weight: 600;
  letter-spacing: 0.04em;
  text-transform: uppercase;
}

.home-banner__hello {
  margin: 0;
  color: #64748b;
  font-size: 0.95rem;
  font-weight: 500;
  text-transform: none;
  letter-spacing: 0;
}

.home-banner__place {
  margin: 0.3rem 0 0;
  color: #64748b;
  font-size: 0.82rem;
}

.home-banner__hint {
  margin: 0.55rem 0 0;
  max-width: 34rem;
  color: #57534e;
  font-size: 0.88rem;
  line-height: 1.45;
}

.home-banner__actions {
  position: relative;
  z-index: 1;
  display: flex;
  flex-wrap: wrap;
  gap: 0.5rem;
}

.home-banner__mark {
  position: absolute;
  right: -0.25rem;
  bottom: -1.1rem;
  color: #c4841d;
  opacity: 0.12;
  pointer-events: none;
}

.count-pill {
  display: inline-flex;
  min-width: 1.75rem;
  height: 1.75rem;
  align-items: center;
  justify-content: center;
  padding: 0 0.5rem;
  border-radius: 999px;
  background: #e4edf2;
  color: #4a6d86;
  font-size: 0.75rem;
  font-weight: 700;
}

.count-pill--warm {
  background: #f8efdc;
  color: #b45309;
}

.product-list {
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
}

.product-row {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  padding: 0.7rem 0.8rem;
  border: 1px solid #e2e8f0;
  border-radius: 0.85rem;
  background: #fff;
  cursor: pointer;
}

.product-row:hover {
  border-color: #cbd5e1;
  background: #f8fafc;
}

.product-row--selected {
  border-color: rgba(227, 155, 43, 0.55);
  background: #fffdf8;
  box-shadow: inset 0 0 0 1px rgba(227, 155, 43, 0.18);
}

.product-row--home {
  cursor: default;
}

.product-row__check {
  width: 1rem;
  height: 1rem;
  accent-color: var(--color-brand-600);
}

.product-row__photo {
  width: 2.5rem;
  height: 2.5rem;
  flex-shrink: 0;
  border-radius: 0.7rem;
  object-fit: cover;
  background: #f1f5f9;
}

.product-row__photo--empty {
  display: flex;
  align-items: center;
  justify-content: center;
  color: #94a3b8;
}

.product-row__photo--warm {
  background: #f8efdc;
  color: #c4841d;
}

.product-row__name {
  margin: 0;
  overflow: hidden;
  color: #0f172a;
  font-size: 0.9rem;
  font-weight: 600;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.product-row__meta {
  margin: 0.15rem 0 0;
  overflow: hidden;
  color: #94a3b8;
  font-size: 0.75rem;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.product-row__price {
  color: #1a2833;
  font-size: 0.85rem;
  font-weight: 600;
}

.price-tag {
  margin-left: 0.35rem;
  color: #b45309;
  font-weight: 600;
}

.empty-line {
  margin: auto;
  color: #94a3b8;
  font-size: 0.875rem;
  text-align: center;
}

.text-red-600 { color: #dc2626; }
</style>
