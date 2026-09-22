<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import { useRouter } from 'vue-router'
import PageFrame from '../../../components/layout/PageFrame.vue'
import AppIcon from '../../../components/ui/AppIcon.vue'
import EmptyState from '../../../components/ui/EmptyState.vue'
import LoadingBlock from '../../../components/ui/LoadingBlock.vue'
import { useBackofficeStore } from '../../../stores/backoffice'
import { useContextStore } from '../../../stores/context'
import type { Catalog, Company, Product } from '../../../types'

const { t } = useI18n()
const router = useRouter()
const store = useBackofficeStore()
const context = useContextStore()

const selectedCompany = ref<Company | null>(null)
const selectedCatalog = ref<Catalog | null>(null)

onMounted(async () => {
  await context.loadStores()
  await store.loadCompanies()
  if (store.companies.length) {
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
    await store.loadProducts(selectedCatalog.value.id)
  }
}

async function selectCatalog(catalogId: string) {
  selectedCatalog.value = store.catalogs.find(c => c.id === catalogId) ?? null
  if (selectedCatalog.value) {
    await store.loadProducts(selectedCatalog.value.id)
  }
}

function primaryImage(product: Product) {
  return product.images?.find(i => i.is_primary)?.cdn_url ?? product.images?.[0]?.cdn_url
}

const galleryItems = computed(() =>
  store.products.filter(product => Boolean(primaryImage(product))),
)
</script>

<template>
  <PageFrame>
    <template #title>{{ t('nav.catalogGallery') }}</template>
    <template #subtitle>{{ t('catalog.gallerySubtitle') }}</template>

    <div class="ui-toolbar">
      <div class="ui-field min-w-[10rem]">
        <label class="ui-label">{{ t('org.company') }}</label>
        <select
          class="ui-select"
          :value="selectedCompany?.id"
          @change="selectCompany(($event.target as HTMLSelectElement).value)"
        >
          <option v-for="c in store.companies" :key="c.id" :value="c.id">{{ c.name }}</option>
        </select>
      </div>
      <div class="ui-field min-w-[10rem]">
        <label class="ui-label">{{ t('nav.catalogs') }}</label>
        <select
          class="ui-select"
          :value="selectedCatalog?.id"
          @change="selectCatalog(($event.target as HTMLSelectElement).value)"
        >
          <option v-for="c in store.catalogs" :key="c.id" :value="c.id">{{ c.name }}</option>
        </select>
      </div>
    </div>

    <LoadingBlock v-if="store.loading" variant="cards" :rows="8" :label="t('common.loading')" />

    <div v-else-if="galleryItems.length" class="gallery-grid">
      <button
        v-for="product in galleryItems"
        :key="product.id"
        type="button"
        class="gallery-card"
        @click="router.push({ name: 'product-edit', params: { id: product.id } })"
      >
        <img :src="primaryImage(product)" :alt="product.name" class="gallery-card__image" />
        <div class="gallery-card__meta">
          <p class="gallery-card__name">{{ product.name }}</p>
          <code class="gallery-card__sku">{{ product.sku }}</code>
        </div>
      </button>
    </div>

    <EmptyState
      v-else
      icon="layers"
      :title="t('catalog.galleryEmpty')"
      :description="t('catalog.galleryEmptyHint')"
    />
  </PageFrame>
</template>

<style scoped>
.border-brand-500 { border-color: var(--color-brand-500); }

.gallery-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(11rem, 1fr));
  gap: 1rem;
}

.gallery-card {
  display: flex;
  flex-direction: column;
  overflow: hidden;
  border: 1px solid #e2e8f0;
  border-radius: 0.75rem;
  background: #fff;
  text-align: left;
  cursor: pointer;
  transition: border-color 0.15s ease, box-shadow 0.15s ease;
}

.gallery-card:hover {
  border-color: #c5d4df;
  box-shadow: 0 8px 24px rgba(15, 23, 42, 0.06);
}

.gallery-card__image {
  aspect-ratio: 1;
  width: 100%;
  object-fit: cover;
  background: #f8fafc;
}

.gallery-card__meta {
  padding: 0.75rem;
}

.gallery-card__name {
  margin: 0;
  font-size: 0.8125rem;
  font-weight: 600;
  color: #1e293b;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.gallery-card__sku {
  display: inline-block;
  margin-top: 0.25rem;
  border-radius: 0.25rem;
  background: #f1f5f9;
  padding: 0.125rem 0.375rem;
  font-family: var(--font-mono);
  font-size: 0.6875rem;
  color: #64748b;
}
</style>
