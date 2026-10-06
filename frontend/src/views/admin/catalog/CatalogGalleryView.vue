<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import { useRouter } from 'vue-router'
import { extractApiErrorMessage } from '../../../api/client'
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
const fileInput = ref<HTMLInputElement | null>(null)
const draggingOver = ref(false)
const dropTargetId = ref<string | null>(null)
const uploading = ref(false)
const uploadError = ref('')

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
    await Promise.all([
      store.loadProducts(selectedCatalog.value.id),
      store.loadGalleryImages(selectedCatalog.value.id),
    ])
  }
}

async function selectCatalog(catalogId: string) {
  selectedCatalog.value = store.catalogs.find(c => c.id === catalogId) ?? null
  if (selectedCatalog.value) {
    await Promise.all([
      store.loadProducts(selectedCatalog.value.id),
      store.loadGalleryImages(selectedCatalog.value.id),
    ])
  }
}

function primaryImage(product: Product) {
  return product.images?.find(i => i.is_primary)?.cdn_url ?? product.images?.[0]?.cdn_url
}

const galleryItems = computed(() =>
  store.products.filter(product => Boolean(primaryImage(product))),
)

function imageFiles(list: FileList | null | undefined) {
  return [...(list ?? [])].filter((file) => file.type.startsWith('image/'))
}

function hasFiles(event: DragEvent) {
  return [...(event.dataTransfer?.types ?? [])].includes('Files')
}

function onZoneDragOver(event: DragEvent) {
  if (!hasFiles(event)) return
  event.preventDefault()
  draggingOver.value = true
}

function onZoneDragLeave(event: DragEvent) {
  const next = event.relatedTarget
  if (next instanceof Node && (event.currentTarget as HTMLElement).contains(next)) return
  draggingOver.value = false
}

function queueFiles(files: File[]) {
  if (!files.length) return
  void uploadLoose(files)
}

async function uploadLoose(files: File[]) {
  uploading.value = true
  uploadError.value = ''
  try {
    for (const file of files) {
      await store.uploadGalleryImage(file, selectedCatalog.value?.id ?? '')
    }
  } catch (error) {
    uploadError.value = extractApiErrorMessage(error, t('catalog.galleryUploadFailed'))
  } finally {
    uploading.value = false
  }
}

function onZoneDrop(event: DragEvent) {
  event.preventDefault()
  draggingOver.value = false
  queueFiles(imageFiles(event.dataTransfer?.files))
}

function onBrowse(event: Event) {
  const input = event.target as HTMLInputElement
  queueFiles(imageFiles(input.files))
  input.value = ''
}

function onCardDragOver(productId: string, event: DragEvent) {
  if (!hasFiles(event)) return
  event.preventDefault()
  event.stopPropagation()
  dropTargetId.value = productId
}

function onCardDragLeave(productId: string, event: DragEvent) {
  const next = event.relatedTarget
  if (next instanceof Node && (event.currentTarget as HTMLElement).contains(next)) return
  if (dropTargetId.value === productId) dropTargetId.value = null
}

function onCardDrop(product: Product, event: DragEvent) {
  event.preventDefault()
  event.stopPropagation()
  dropTargetId.value = null
  draggingOver.value = false
  const files = imageFiles(event.dataTransfer?.files)
  if (!files.length) return
  void uploadTo(product.id, files)
}

async function uploadTo(productId: string, files: File[]) {
  uploading.value = true
  uploadError.value = ''
  try {
    const product = store.products.find((item) => item.id === productId)
    let primary = !product?.images?.length
    for (const file of files) {
      await store.uploadProductImage(productId, file, primary)
      primary = false
    }
    if (selectedCatalog.value) await store.loadProducts(selectedCatalog.value.id)
  } catch (error) {
    uploadError.value = extractApiErrorMessage(error, t('catalog.galleryUploadFailed'))
  } finally {
    uploading.value = false
  }
}

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

    <template v-else>
      <div
        class="gallery-drop"
        :class="{ 'gallery-drop--over': draggingOver, 'gallery-drop--busy': uploading }"
        @dragenter="onZoneDragOver"
        @dragover="onZoneDragOver"
        @dragleave="onZoneDragLeave"
        @drop="onZoneDrop"
      >
        <AppIcon name="upload" :size="22" />
        <p class="gallery-drop__title">{{ uploading ? t('common.loading') : t('catalog.galleryDrop') }}</p>
        <p class="gallery-drop__hint">{{ t('catalog.galleryDropHint') }}</p>
        <button type="button" class="btn-secondary" :disabled="uploading" @click="fileInput?.click()">
          {{ t('catalog.galleryBrowse') }}
        </button>
        <input
          ref="fileInput"
          type="file"
          accept="image/*"
          multiple
          class="sr-only"
          @change="onBrowse"
        />
      </div>

      <p v-if="uploadError" class="gallery-error" role="alert">{{ uploadError }}</p>

      <div v-if="store.galleryImages.length || galleryItems.length" class="gallery-grid">
        <figure v-for="image in store.galleryImages" :key="image.id" class="gallery-card gallery-card--file">
          <img :src="image.cdn_url" :alt="image.original_filename || ''" class="gallery-card__image" />
          <figcaption class="gallery-card__meta">
            <p class="gallery-card__name">{{ image.original_filename || t('products.image') }}</p>
          </figcaption>
        </figure>
        <button
          v-for="product in galleryItems"
          :key="product.id"
          type="button"
          class="gallery-card"
          :class="{ 'gallery-card--drop': dropTargetId === product.id }"
          :title="t('catalog.galleryDropOnCard')"
          @click="router.push({ name: 'product-edit', params: { id: product.id } })"
          @dragenter="onCardDragOver(product.id, $event)"
          @dragover="onCardDragOver(product.id, $event)"
          @dragleave="onCardDragLeave(product.id, $event)"
          @drop="onCardDrop(product, $event)"
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
    </template>

  </PageFrame>
</template>

<style scoped>
.gallery-drop {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: var(--space-2);
  margin-bottom: var(--space-4);
  padding: var(--space-8) var(--space-4);
  border: 2px dashed var(--color-border);
  border-radius: var(--radius-lg);
  background: var(--color-surface);
  color: var(--color-text-secondary);
  text-align: center;
  transition: border-color var(--motion-normal) var(--ease-out), background var(--motion-normal) var(--ease-out);
}

.gallery-drop--over {
  border-color: var(--color-brand-500);
  background: color-mix(in srgb, var(--color-brand-500) 8%, var(--color-surface));
}

.gallery-drop--busy {
  opacity: 0.7;
}

.gallery-drop__title {
  margin: 0;
  font-size: var(--text-sm);
  font-weight: 600;
  color: var(--color-text-primary);
}

.gallery-drop__hint {
  margin: 0 0 var(--space-2);
  font-size: var(--text-xs);
  color: var(--color-text-muted);
}

.gallery-error {
  margin: 0 0 var(--space-4);
  padding: var(--space-3) var(--space-4);
  border-radius: var(--radius-md);
  background: color-mix(in srgb, var(--color-danger, #dc2626) 10%, white);
  color: var(--color-danger, light-dark(#b91c1c, #e2a0a0));
  font-size: var(--text-sm);}

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
  background: var(--color-surface);
  text-align: left;
  cursor: pointer;
  transition: border-color 0.15s ease, box-shadow 0.15s ease;}

.gallery-card--file {
  margin: 0;
  cursor: default;
}

.gallery-card:hover,
.gallery-card--drop {
  border-color: var(--color-brand-500);
  box-shadow: 0 8px 24px rgba(15, 23, 42, 0.06);
}

.gallery-card__image {
  aspect-ratio: 1;
  width: 100%;
  object-fit: cover;
  background: var(--color-table-header);}

.gallery-card__meta {
  padding: 0.75rem;
}

.gallery-card__name {
  margin: 0;
  font-size: 0.8125rem;
  font-weight: 600;
  color: var(--color-text-primary);
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;}

.gallery-card__sku {
  display: inline-block;
  margin-top: 0.25rem;
  border-radius: 0.25rem;
  background: var(--color-table-header);
  padding: 0.125rem 0.375rem;
  font-family: var(--font-mono);
  font-size: 0.6875rem;
  color: var(--color-text-muted);}
</style>
