<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref } from 'vue'
import { useI18n } from 'vue-i18n'
import { useRoute, useRouter } from 'vue-router'
import AdminLayout from '../../components/layout/AdminLayout.vue'
import { extractApiErrorMessage } from '../../api/client'
import { useBackofficeStore } from '../../stores/backoffice'
import type { Barcode, BarcodeType, Brand, Category, Price, Product, ProductBundleItem, ProductImage, ProductType, ProductVariant, Tax, Unit } from '../../types'
import { getAppCurrency } from '../../utils/currency'
import { taxQuote } from '../../utils/taxQuote'
import { isStockableProduct } from '../../utils/product'

const STOCKABLE_TYPES: ProductType[] = ['simple', 'variant', 'batch', 'bundle']
const BARCODE_TYPES: BarcodeType[] = ['ean13', 'ean8', 'upc', 'code128', 'qr', 'internal']

const { t } = useI18n()
const route = useRoute()
const router = useRouter()
const store = useBackofficeStore()

const isEdit = computed(() => Boolean(route.params.id))
const saveError = ref('')
const saveNotice = ref('')
const catalogId = ref((route.query.catalogId as string) ?? '')
const saving = ref(false)
const uploading = ref(false)
const activeTab = ref('general')

const form = ref({
  sku: '',
  name: '',
  description: '',
  product_type: 'simple' as ProductType,
  brand_id: '' as string | null,
  unit_id: '' as string | null,
  tax_id: '' as string | null,
  category_id: '' as string | null,
  barcode: '',
  base_price: 0,
  cost_price: 0,
  is_active: true,
  is_serialized: false,
  track_batch: false,
  track_expiration: false,
  expiration_days: null as number | null,
})

const variants = ref<ProductVariant[]>([])
const bundleItems = ref<ProductBundleItem[]>([])
const barcodes = ref<Partial<Barcode>[]>([])
const prices = ref<Partial<Price>[]>([])
const product = ref<Product | null>(null)
const images = ref<ProductImage[]>([])
const allProducts = ref<Product[]>([])
const brandOptions = ref<Brand[]>([])
const unitOptions = ref<Unit[]>([])
const taxOptions = ref<Tax[]>([])

const selectedTax = computed(() => taxOptions.value.find(tax => tax.id === form.value.tax_id) ?? null)
const sellingQuote = computed(() => taxQuote(toCents(form.value.base_price), Number(selectedTax.value?.rate ?? 0), Boolean(selectedTax.value?.is_inclusive)))

const isQuantifiable = computed(() => isStockableProduct(form.value))
const stockableComponents = computed(() => allProducts.value.filter(isStockableProduct))

function setNature(kind: 'quantifiable' | 'service') {
  if (kind === 'service') {
    form.value.product_type = 'service'
    form.value.is_serialized = false
    form.value.track_batch = false
    form.value.track_expiration = false
    form.value.expiration_days = null
    return
  }
  if (!STOCKABLE_TYPES.includes(form.value.product_type)) {
    form.value.product_type = 'simple'
  }
}

const categoryOptions = computed(() => {
  const result: Category[] = []
  const seen = new Set<string>()

  function walk(items: Category[] | undefined, prefix = '') {
    for (const item of items ?? []) {
      if (!item?.id || seen.has(item.id)) continue
      seen.add(item.id)
      result.push({ ...item, name: prefix ? `${prefix} / ${item.name}` : item.name })
      if (item.children?.length) {
        walk(item.children, prefix ? `${prefix} / ${item.name}` : item.name)
      }
    }
  }

  walk(store.categories)

  const current = product.value?.category
  if (current?.id && !seen.has(current.id)) {
    result.unshift(current)
  }

  return result
})

const tabs = computed(() => {
  const base = [
    { id: 'general', label: t('products.tabs.general') },
    { id: 'pricing', label: t('products.tabs.pricing') },
    { id: 'barcodes', label: t('products.tabs.barcodes') },
  ]
  if (form.value.product_type === 'variant') base.push({ id: 'variants', label: t('products.tabs.variants') })
  if (form.value.product_type === 'bundle') base.push({ id: 'bundle', label: t('products.tabs.bundle') })
  if (isEdit.value) base.push({ id: 'gallery', label: t('products.gallery') })
  return base
})

function asList<T>(value: unknown): T[] {
  return Array.isArray(value) ? value : []
}

async function loadLookups() {
  const [brands, units, taxes] = await Promise.all([
    store.loadBrands().catch(() => store.brands),
    store.loadUnits(false).catch(() => store.units),
    store.loadTaxes(true).catch(() => store.taxes),
    store.loadCurrencies(true).catch(() => store.currencies),
  ])
  brandOptions.value = asList<Brand>(brands)
  unitOptions.value = asList<Unit>(units)
  taxOptions.value = asList<Tax>(taxes).filter(tax => tax.is_active !== false)
}

function onWindowFocus() {
  void loadLookups()
}

onBeforeUnmount(() => {
  window.removeEventListener('focus', onWindowFocus)
})

onMounted(async () => {
  window.addEventListener('focus', onWindowFocus)
  await loadLookups()

  if (catalogId.value) {
    await store.loadCategories(catalogId.value)
    allProducts.value = await store.loadProducts(catalogId.value)
  }

  if (isEdit.value) {
    product.value = await store.loadProduct(route.params.id as string)
    catalogId.value = product.value.catalog_id
    await store.loadCategories(catalogId.value)
    allProducts.value = await store.loadProducts(catalogId.value)

    form.value = {
      sku: product.value.sku,
      name: product.value.name,
      description: product.value.description ?? '',
      product_type: product.value.product_type ?? 'simple',
      brand_id: product.value.brand_id || '',
      unit_id: product.value.unit_id || '',
      tax_id: product.value.tax_id ?? '',
      category_id: product.value.category_id || '',
      barcode: product.value.barcode ?? '',
      base_price: product.value.base_price / 100,
      cost_price: product.value.cost_price / 100,
      is_active: product.value.is_active,
      is_serialized: product.value.is_serialized ?? false,
      track_batch: product.value.track_batch ?? false,
      track_expiration: product.value.track_expiration ?? false,
      expiration_days: product.value.expiration_days ?? null,
    }
    variants.value = (product.value.variants ?? []).map(v => ({
      ...v,
      base_price: v.base_price / 100,
      cost_price: (v.cost_price ?? 0) / 100,
    }))
    bundleItems.value = product.value.bundle_items ?? []
    barcodes.value = product.value.barcodes ?? []
    prices.value = (product.value.prices ?? []).map(p => ({ ...p, amount: p.amount / 100 }))
    images.value = product.value.images ?? []
  }
})

function addVariant() {
  variants.value.push({ sku: '', name: '', size: '', color: '', base_price: 0, cost_price: 0, is_active: true })
}

function addBundleItem() {
  bundleItems.value.push({ component_product_id: '', quantity: 1 })
}

function addBarcode() {
  barcodes.value.push({ barcode: '', type: 'internal', is_primary: barcodes.value.length === 0 })
}

async function generateBarcodeForRow(index: number) {
  const type = barcodes.value[index]?.type ?? 'internal'
  const generated = await store.generateBarcode(type as BarcodeType)
  barcodes.value[index] = { ...barcodes.value[index], barcode: generated.barcode, type: generated.type as BarcodeType }
}

async function printBarcodeRow(bc: Partial<Barcode>) {
  if (!bc.id) return
  const payload = await store.printBarcode(bc.id)
  window.print()
  console.info('Print label:', payload)
}

function addPrice() {
  prices.value.push({ price_type: 'retail', amount: 0, currency_code: getAppCurrency(), min_quantity: 1, is_active: true })
}

function formatQuote(cents: number) {
  return (cents / 100).toFixed(2)
}

function toCents(value: unknown): number {
  const amount = Number(value)
  if (!Number.isFinite(amount) || amount < 0) return 0
  return Math.round(amount * 100)
}

function buildPayload() {
  const payload: Record<string, unknown> = {
    ...form.value,
    brand_id: form.value.brand_id || null,
    unit_id: form.value.unit_id || null,
    tax_id: form.value.tax_id || null,
    category_id: form.value.category_id || null,
    base_price: toCents(form.value.base_price),
    cost_price: toCents(form.value.cost_price),
    is_serialized: isQuantifiable.value ? form.value.is_serialized : false,
    track_batch: isQuantifiable.value ? form.value.track_batch : false,
    track_expiration: isQuantifiable.value ? form.value.track_expiration : false,
    expiration_days: isQuantifiable.value ? form.value.expiration_days : null,
    barcodes: barcodes.value.filter(b => b.barcode),
    prices: prices.value
      .filter(p => p.price_type)
      .map(p => ({
        ...(p.id ? { id: p.id } : {}),
        price_type: p.price_type,
        amount: toCents(p.amount),
        currency_code: (p.currency_code || getAppCurrency()).slice(0, 3),
        min_quantity: Math.max(1, Math.round(Number(p.min_quantity) || 1)),
        is_active: p.is_active !== false,
      })),
  }

  if (form.value.product_type === 'variant') {
    payload.variants = variants.value.map(v => ({
      ...v,
      base_price: Math.round(v.base_price * 100),
      cost_price: Math.round((v.cost_price ?? 0) * 100),
    }))
  }

  if (form.value.product_type === 'bundle') {
    payload.bundle_items = bundleItems.value.filter(b => b.component_product_id)
  }

  return payload
}

async function save() {
  saveError.value = ''
  saveNotice.value = ''

  if (!form.value.sku.trim() || !form.value.name.trim()) {
    activeTab.value = 'general'
    saveError.value = t('products.missingIdentity')
    return
  }

  if (!isEdit.value && !catalogId.value) {
    saveError.value = t('products.missingCatalog')
    return
  }

  saving.value = true
  try {
    const saved = await store.saveProduct(catalogId.value, buildPayload(), isEdit.value ? (route.params.id as string) : undefined)
    form.value.base_price = saved.base_price / 100
    form.value.cost_price = saved.cost_price / 100
    prices.value = (saved.prices ?? []).map(p => ({ ...p, amount: p.amount / 100 }))
    barcodes.value = saved.barcodes ?? []
    product.value = saved
    form.value.category_id = saved.category_id || ''
    images.value = saved.images ?? []
    saveNotice.value = t('common.saved')

    if (!isEdit.value) {
      await router.replace({ name: 'product-edit', params: { id: saved.id } })
    }
  } catch (error) {
    saveError.value = extractApiErrorMessage(error, t('products.saveFailed'))
  } finally {
    saving.value = false
  }
}

async function onFileChange(event: Event) {
  const input = event.target as HTMLInputElement
  const file = input.files?.[0]
  if (!file || !product.value) return
  uploading.value = true
  try {
    await store.uploadProductImage(product.value.id, file, images.value.length === 0)
    product.value = await store.loadProduct(product.value.id)
    images.value = product.value.images ?? []
    input.value = ''
  } finally {
    uploading.value = false
  }
}

async function removeImage(id: string) {
  if (!product.value) return
  await store.deleteProductImage(id)
  product.value = await store.loadProduct(product.value.id)
  images.value = product.value.images ?? []
}

async function makePrimary(id: string) {
  if (!product.value) return
  await store.setPrimaryImage(id)
  product.value = await store.loadProduct(product.value.id)
  images.value = product.value.images ?? []
}
</script>

<template>
  <AdminLayout>
    <template #title>{{ isEdit ? t('products.edit') : t('products.new') }}</template>

    <nav class="mb-6 flex flex-wrap gap-2 border-b border-slate-200 pb-4">
      <button
        v-for="tab in tabs"
        :key="tab.id"
        type="button"
        class="rounded-lg px-4 py-2 text-sm font-medium transition"
        :class="activeTab === tab.id ? 'bg-brand-600 text-white' : 'bg-slate-100 text-slate-600 hover:bg-slate-200'"
        @click="activeTab = tab.id"
      >
        {{ tab.label }}
      </button>
    </nav>

    <form class="space-y-6" novalidate @submit.prevent="save">
      <!-- General -->
      <div v-show="activeTab === 'general'" class="rounded-xl bg-white p-6 shadow-sm ring-1 ring-slate-200 space-y-4">
        <div class="grid gap-4 sm:grid-cols-2">
          <div><label class="label">SKU</label><input v-model="form.sku" required class="field" /></div>
          <div><label class="label">{{ t('products.name') }}</label><input v-model="form.name" required class="field" /></div>
        </div>
        <div><label class="label">{{ t('products.description') }}</label><textarea v-model="form.description" rows="3" class="field" /></div>
        <div>
          <label class="label">{{ t('products.nature') }}</label>
          <div class="product-type-grid">
            <label class="product-type-card product-type-card--stock" :class="{ 'product-type-card--active': isQuantifiable }">
              <input type="radio" class="sr-only" :checked="isQuantifiable" @change="setNature('quantifiable')" />
              <span class="product-type-card__title">{{ t('products.natures.quantifiable.label') }}</span>
            </label>
            <label class="product-type-card product-type-card--service" :class="{ 'product-type-card--active': !isQuantifiable }">
              <input type="radio" class="sr-only" :checked="!isQuantifiable" @change="setNature('service')" />
              <span class="product-type-card__title">{{ t('products.natures.service.label') }}</span>
            </label>
          </div>
          <p class="mt-2 text-xs text-slate-500">{{ isQuantifiable ? t('products.quantifiableHint') : t('products.serviceHint') }}</p>
        </div>
        <div v-if="isQuantifiable">
          <label class="label">{{ t('products.structure') }}</label>
          <div class="product-type-grid">
            <label
              v-for="pt in STOCKABLE_TYPES"
              :key="pt"
              class="product-type-card"
              :class="[`product-type-card--${pt}`, { 'product-type-card--active': form.product_type === pt }]"
            >
              <input v-model="form.product_type" type="radio" class="sr-only" :value="pt" />
              <span class="product-type-card__title">{{ t(`products.types.${pt}.label`) }}</span>
            </label>
          </div>
        </div>
        <div class="grid gap-4 sm:grid-cols-2">
          <div>
            <div class="mb-1 flex items-center justify-between gap-2">
              <label class="label !mb-0">{{ t('catalog.tabs.categories') }}</label>
              <button type="button" class="text-xs font-medium text-brand-600" @click="router.push({ name: 'catalog-categories' })">
                {{ t('catalog.manageCategories') }}
              </button>
            </div>
            <select
              v-model="form.category_id"
              class="field"
              :key="`categories-${categoryOptions.map(cat => cat.id).join('|')}`"
            >
              <option value="">—</option>
              <option v-for="cat in categoryOptions" :key="cat.id" :value="cat.id">{{ cat.name }}</option>
            </select>
            <p v-if="!categoryOptions.length" class="mt-1 text-xs text-slate-500">{{ t('catalog.emptyCategories') }}</p>
          </div>
          <div>
            <div class="mb-1 flex items-center justify-between gap-2">
              <label class="label !mb-0">{{ t('catalog.tabs.brands') }}</label>
              <button type="button" class="text-xs font-medium text-brand-600" @click="router.push({ name: 'catalog-brands' })">
                {{ t('catalog.manageBrands') }}
              </button>
            </div>
            <select v-model="form.brand_id" class="field" :key="`brands-${brandOptions.map(b => b.id).join('|')}`">
              <option value="">—</option>
              <option v-for="b in brandOptions" :key="b.id" :value="b.id">{{ b.name }}</option>
            </select>
            <p v-if="!brandOptions.length" class="mt-1 text-xs text-slate-500">{{ t('catalog.emptyBrands') }}</p>
          </div>
        </div>
        <div class="grid gap-4 sm:grid-cols-2">
          <div>
            <div class="mb-1 flex items-center justify-between gap-2">
              <label class="label !mb-0">{{ t('nav.units') }}</label>
              <button type="button" class="text-xs font-medium text-brand-600" @click="router.push({ name: 'catalog-units' })">
                {{ t('catalog.manageUnits') }}
              </button>
            </div>
            <select v-model="form.unit_id" class="field" :key="`units-${unitOptions.map(u => u.id).join('|')}`">
              <option value="">—</option>
              <option v-for="u in unitOptions" :key="u.id" :value="u.id">{{ u.name }} ({{ u.code }})</option>
            </select>
            <p v-if="!unitOptions.length" class="mt-1 text-xs text-slate-500">{{ t('catalog.emptyUnits') }}</p>
          </div>
          <div>
            <div class="mb-1 flex items-center justify-between gap-2">
              <label class="label !mb-0">{{ t('catalog.tabs.taxes') }}</label>
              <button type="button" class="text-xs font-medium text-brand-600" @click="router.push({ name: 'catalog-taxes' })">
                {{ t('catalog.manageTaxes') }}
              </button>
            </div>
            <select v-model="form.tax_id" class="field" :key="`taxes-${taxOptions.map(tx => tx.id).join('|')}`">
              <option value="">—</option>
              <option v-for="tx in taxOptions" :key="tx.id" :value="tx.id">{{ tx.name }} ({{ tx.rate }}%)</option>
            </select>
            <p v-if="!taxOptions.length" class="mt-1 text-xs text-slate-500">{{ t('catalog.emptyTaxes') }}</p>
          </div>
        </div>
        <div v-if="isQuantifiable" class="grid gap-4 sm:grid-cols-3">
          <label class="flex items-center gap-2 text-sm"><input v-model="form.is_serialized" type="checkbox" class="rounded" />{{ t('products.serialized') }}</label>
          <label class="flex items-center gap-2 text-sm"><input v-model="form.track_batch" type="checkbox" class="rounded" />{{ t('products.batch') }}</label>
          <label class="flex items-center gap-2 text-sm"><input v-model="form.track_expiration" type="checkbox" class="rounded" />{{ t('products.expiration') }}</label>
        </div>
        <div v-if="form.track_expiration">
          <label class="label">{{ t('products.expirationDays') }}</label>
          <input v-model.number="form.expiration_days" type="number" min="1" class="field max-w-xs" />
        </div>
        <label class="flex items-center gap-2 text-sm"><input v-model="form.is_active" type="checkbox" class="rounded" />{{ t('products.active') }}</label>
        <p v-if="product && isQuantifiable" class="text-sm text-slate-600">
          {{ t('products.stock') }} : <span class="font-medium">{{ product.stock ?? 0 }}</span>
        </p>
      </div>

      <!-- Pricing -->
      <div v-show="activeTab === 'pricing'" class="rounded-xl bg-white p-6 shadow-sm ring-1 ring-slate-200 space-y-4">
        <p class="text-sm text-slate-500">{{ t('products.priceHint') }}</p>
        <div class="grid gap-4 sm:grid-cols-2">
          <div><label class="label">{{ t('products.price') }}</label><input v-model.number="form.base_price" type="number" step="0.01" min="0" class="field" /></div>
          <div><label class="label">{{ t('products.cost') }}</label><input v-model.number="form.cost_price" type="number" step="0.01" min="0" class="field" /></div>
        </div>
        <p class="m-0 text-sm text-slate-600">
          HT {{ formatQuote(sellingQuote.ht) }}
          · TVA {{ formatQuote(sellingQuote.tva) }}
          · TTC {{ formatQuote(sellingQuote.ttc) }}
          <span v-if="selectedTax" class="text-slate-400">({{ selectedTax.code }} {{ selectedTax.rate }}%)</span>
        </p>
        <div class="flex items-center justify-between">
          <h3 class="font-medium">{{ t('products.priceTiers') }}</h3>
          <button type="button" class="text-sm text-brand-600" @click="addPrice">+ {{ t('products.addPrice') }}</button>
        </div>
        <div v-for="(price, i) in prices" :key="i" class="grid gap-3 rounded-lg border border-slate-200 p-3 sm:grid-cols-5">
          <select v-model="price.price_type" class="field">
            <option value="base">{{ t('products.priceTypes.base') }}</option>
            <option value="retail">{{ t('products.priceTypes.retail') }}</option>
            <option value="wholesale">{{ t('products.priceTypes.wholesale') }}</option>
            <option value="vip">{{ t('products.priceTypes.vip') }}</option>
            <option value="distributor">{{ t('products.priceTypes.distributor') }}</option>
            <option value="special">{{ t('products.priceTypes.special') }}</option>
          </select>
          <input v-model.number="price.amount" type="number" step="0.01" min="0" class="field" :placeholder="t('common.amount')" />
          <select v-model="price.currency_code" class="field">
            <option v-for="currency in store.currencies" :key="currency.id" :value="currency.code">{{ currency.code }}</option>
            <option v-if="!store.currencies.length" :value="getAppCurrency()">{{ getAppCurrency() }}</option>
          </select>
          <input v-model.number="price.min_quantity" type="number" min="1" class="field" :placeholder="t('common.minQty')" />
          <button type="button" class="text-red-600 text-sm" @click="prices.splice(i, 1)">{{ t('common.delete') }}</button>
        </div>
      </div>

      <!-- Barcodes -->
      <div v-show="activeTab === 'barcodes'" class="rounded-xl bg-white p-6 shadow-sm ring-1 ring-slate-200 space-y-4">
        <div class="flex justify-between items-center">
          <h3 class="font-medium">{{ t('products.tabs.barcodes') }}</h3>
          <button type="button" class="text-sm text-brand-600" @click="addBarcode">+ {{ t('products.addBarcode') }}</button>
        </div>
        <div v-for="(bc, i) in barcodes" :key="i" class="grid gap-3 rounded-lg border border-slate-200 p-3 sm:grid-cols-6">
          <input v-model="bc.barcode" class="field sm:col-span-2" :placeholder="t('products.barcode')" />
          <select v-model="bc.type" class="field">
            <option v-for="bt in BARCODE_TYPES" :key="bt" :value="bt">{{ bt.toUpperCase() }}</option>
          </select>
          <button type="button" class="btn-secondary text-sm" @click="generateBarcodeForRow(i)">{{ t('products.generateBarcode') }}</button>
          <div class="flex items-center gap-2">
            <label class="flex items-center gap-1 text-sm"><input v-model="bc.is_primary" type="checkbox" class="rounded" />★</label>
            <button v-if="bc.id" type="button" class="text-sm text-brand-600" @click="printBarcodeRow(bc)">{{ t('products.printBarcode') }}</button>
            <button type="button" class="row-remove" @click="barcodes.splice(i, 1)">✕</button>
          </div>
        </div>
      </div>

      <!-- Variants -->
      <div v-show="activeTab === 'variants'" class="rounded-xl bg-white p-6 shadow-sm ring-1 ring-slate-200 space-y-4">
        <div class="flex justify-between">
          <h3 class="font-medium">{{ t('products.tabs.variants') }}</h3>
          <button type="button" class="text-sm text-brand-600" @click="addVariant">+ {{ t('products.addVariant') }}</button>
        </div>
        <div v-for="(v, i) in variants" :key="i" class="rounded-lg border border-slate-200 p-4 space-y-3">
          <div class="grid gap-3 sm:grid-cols-3">
            <input v-model="v.sku" class="field" placeholder="SKU" required />
            <input v-model="v.size" class="field" :placeholder="t('products.size')" />
            <input v-model="v.color" class="field" :placeholder="t('products.color')" />
          </div>
          <div class="grid gap-3 sm:grid-cols-2">
            <input v-model.number="v.base_price" type="number" step="0.01" class="field" :placeholder="t('products.price')" />
            <input v-model.number="v.cost_price" type="number" step="0.01" class="field" :placeholder="t('products.cost')" />
          </div>
          <div v-if="v.barcodes?.length" class="space-y-2">
            <p class="text-sm font-medium text-slate-600">{{ t('products.variantBarcodes') }}</p>
            <div v-for="(vbc, bi) in v.barcodes" :key="bi" class="flex gap-2">
              <input v-model="vbc.barcode" class="field flex-1" />
              <select v-model="vbc.type" class="field w-32">
                <option v-for="bt in BARCODE_TYPES" :key="bt" :value="bt">{{ bt }}</option>
              </select>
            </div>
          </div>
          <button type="button" class="text-sm text-brand-600" @click="(v.barcodes ??= []).push({ barcode: '', type: 'internal', is_primary: true })">+ {{ t('products.addBarcode') }}</button>
          <button type="button" class="text-sm text-red-600" @click="variants.splice(i, 1)">{{ t('common.delete') }}</button>
        </div>
      </div>

      <!-- Bundle -->
      <div v-show="activeTab === 'bundle'" class="rounded-xl bg-white p-6 shadow-sm ring-1 ring-slate-200 space-y-4">
        <div class="flex justify-between">
          <h3 class="font-medium">{{ t('products.tabs.bundle') }}</h3>
          <button type="button" class="text-sm text-brand-600" @click="addBundleItem">+ {{ t('products.addComponent') }}</button>
        </div>
        <div v-for="(item, i) in bundleItems" :key="i" class="grid gap-3 sm:grid-cols-3 rounded-lg border border-slate-200 p-3">
          <select v-model="item.component_product_id" class="field sm:col-span-2" required>
            <option value="">—</option>
            <option v-for="p in stockableComponents.filter(p => p.id !== product?.id)" :key="p.id" :value="p.id">{{ p.sku }} — {{ p.name }}</option>
          </select>
          <div class="flex gap-2">
            <input v-model.number="item.quantity" type="number" step="0.01" min="0.01" class="field" />
            <button type="button" class="row-remove" @click="bundleItems.splice(i, 1)">✕</button>
          </div>
        </div>
      </div>

      <!-- Gallery -->
      <div v-show="activeTab === 'gallery'" class="rounded-xl bg-white p-6 shadow-sm ring-1 ring-slate-200">
        <p v-if="!product" class="text-sm text-slate-500">{{ t('products.galleryAfterSave') }}</p>
        <template v-else>
          <label class="mb-4 flex cursor-pointer flex-col items-center justify-center rounded-lg border-2 border-dashed border-slate-300 px-4 py-6 hover:border-brand-500">
            <span class="text-sm text-slate-600">{{ uploading ? t('common.loading') : t('products.uploadImage') }}</span>
            <input type="file" accept="image/*" class="hidden" @change="onFileChange" />
          </label>
          <div class="grid grid-cols-2 gap-3 sm:grid-cols-4">
            <div v-for="image in images" :key="image.id" class="group relative overflow-hidden rounded-lg ring-1 ring-slate-200">
              <img :src="image.cdn_url" class="aspect-square w-full object-cover" alt="" />
              <div class="absolute inset-x-0 bottom-0 flex gap-1 bg-black/60 p-1 opacity-0 transition group-hover:opacity-100">
                <button type="button" class="flex-1 rounded bg-white/90 px-1 py-0.5 text-xs" @click="makePrimary(image.id)">{{ image.is_primary ? '★' : '☆' }}</button>
                <button type="button" class="flex-1 rounded bg-red-500 px-1 py-0.5 text-xs text-white" @click="removeImage(image.id)">✕</button>
              </div>
            </div>
          </div>
        </template>
      </div>

      <p v-if="saveError" class="rounded-lg bg-red-50 px-4 py-3 text-sm text-red-700">{{ saveError }}</p>
      <p v-if="saveNotice" class="rounded-lg bg-emerald-50 px-4 py-3 text-sm text-emerald-700">{{ saveNotice }}</p>
      <div class="flex gap-3">
        <button type="submit" class="btn-primary" :disabled="saving">{{ saving ? t('common.loading') : t('common.save') }}</button>
        <button type="button" class="btn-secondary" @click="router.push({ name: 'products' })">{{ t('common.cancel') }}</button>
      </div>
    </form>
  </AdminLayout>
</template>

<style scoped>
.label { display: block; margin-bottom: 0.25rem; font-size: 0.875rem; font-weight: 500; }
.field { width: 100%; border-radius: 0.5rem; border: 1px solid #cbd5e1; padding: 0.5rem 0.75rem; }
.btn-primary { border-radius: 0.5rem; padding: 0.5rem 1rem; font-weight: 500; color: white; background-color: var(--color-brand-600); }
.btn-primary:disabled { opacity: 0.5; }
.btn-secondary { border-radius: 0.5rem; border: 1px solid #cbd5e1; padding: 0.5rem 1rem; font-weight: 500; }
.bg-brand-600 { background-color: var(--color-brand-600); }
.text-brand-600 { color: var(--color-brand-600); }
.hover\:border-brand-500:hover { border-color: var(--color-brand-500); }

.product-type-grid {
  display: flex;
  flex-wrap: wrap;
  gap: 0.4rem;
}

.product-type-card {
  display: inline-flex;
  align-items: center;
  padding: 0.3rem 0.7rem;
  border: 1px solid transparent;
  border-radius: 999px;
  background: #fff;
  cursor: pointer;
  transition: background 0.15s ease, color 0.15s ease, border-color 0.15s ease;
}

.product-type-card__title {
  font-size: 0.75rem;
  font-weight: 600;
  line-height: 1.2;
}

.product-type-card--stock { border-color: #4a6d86; color: #4a6d86; background: #eef3f6; }
.product-type-card--service { border-color: #e39b2b; color: #9a6412; background: #fdf6ea; }
.product-type-card--simple { border-color: #3d7a6a; color: #2f6256; background: #eef6f3; }
.product-type-card--variant { border-color: #6b5b95; color: #534678; background: #f3f0f8; }
.product-type-card--batch { border-color: #c46b4a; color: #9a4e32; background: #fbf1ec; }
.product-type-card--bundle { border-color: #12181e; color: #12181e; background: #f3f4f6; }

.product-type-card--stock.product-type-card--active { background: #4a6d86; color: #fff; }
.product-type-card--service.product-type-card--active { background: #e39b2b; color: #12181e; }
.product-type-card--simple.product-type-card--active { background: #3d7a6a; color: #fff; }
.product-type-card--variant.product-type-card--active { background: #6b5b95; color: #fff; }
.product-type-card--batch.product-type-card--active { background: #c46b4a; color: #fff; }
.product-type-card--bundle.product-type-card--active { background: #12181e; color: #fff; }

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
