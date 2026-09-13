<script setup lang="ts">
import { computed, ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import AppModal from '../ui/AppModal.vue'
import WarehouseOptions from './WarehouseOptions.vue'
import { extractApiErrorMessage } from '../../api/client'
import { useAuthStore } from '../../stores/auth'
import { useBackofficeStore } from '../../stores/backoffice'
import type { OpeningLine, Product, Warehouse } from '../../types'
import { isStockableProduct } from '../../utils/product'
import { formatMoney, parseMoneyInput } from '../../utils/money'

type SaleUnit = { id: string; name: string; volume_ml: number; is_base?: boolean }

const props = defineProps<{
  open: boolean
  warehouses: Warehouse[]
  products: Product[]
}>()

const emit = defineEmits<{
  close: []
  created: []
}>()

const { t } = useI18n()
const store = useBackofficeStore()
const auth = useAuthStore()

type LineDraft = {
  quantity: number
  sale_unit_id: string
  price: string
  units: SaleUnit[]
}

const saving = ref(false)
const loadingProducts = ref(false)
const error = ref('')
const successLines = ref<OpeningLine[]>([])
const productQuery = ref('')
const catalogProducts = ref<Product[]>([])
const openedIds = ref<string[]>([])
const lines = ref<Record<string, LineDraft>>({})

const form = ref({
  warehouse_id: '',
  counted_at: today(),
})

function today() {
  const now = new Date()
  const month = String(now.getMonth() + 1).padStart(2, '0')
  const day = String(now.getDate()).padStart(2, '0')
  return `${now.getFullYear()}-${month}-${day}`
}

const stockableProducts = computed(() => {
  const query = productQuery.value.trim().toLowerCase()
  return allStockable.value.filter(product => {
    if (!query) return true
    return product.name.toLowerCase().includes(query) || (product.sku ?? '').toLowerCase().includes(query)
  })
})
const allStockable = computed(() => {
  const source = catalogProducts.value.length ? catalogProducts.value : props.products
  const opened = new Set(openedIds.value)
  return source.filter(product => isStockableProduct(product) && !opened.has(product.id))
})
const selectedIds = computed(() => Object.keys(lines.value))
const totalValue = computed(() => selectedIds.value.reduce((sum, id) => {
  const line = lines.value[id]
  const qty = Math.max(0, Math.trunc(Number(line.quantity) || 0))
  return sum + qty * parseMoneyInput(line.price)
}, 0))

watch(() => props.open, (open) => {
  if (!open) return
  error.value = ''
  successLines.value = []
  productQuery.value = ''
  lines.value = {}
  form.value = {
    warehouse_id: props.warehouses[0]?.id ?? '',
    counted_at: today(),
  }
  void loadCatalogProducts()
  void loadOpened()
})

watch(() => form.value.warehouse_id, () => {
  void loadOpened()
})

async function loadOpened() {
  if (!form.value.warehouse_id) {
    openedIds.value = []
    return
  }
  try {
    openedIds.value = await store.loadOpenedProductIds(form.value.warehouse_id)
    const allowed = new Set(allStockable.value.map(product => product.id))
    const next = { ...lines.value }
    for (const id of Object.keys(next)) {
      if (!allowed.has(id)) delete next[id]
    }
    lines.value = next
  } catch (err) {
    error.value = extractApiErrorMessage(err)
  }
}

async function loadCatalogProducts() {
  loadingProducts.value = true
  try {
    await store.loadCompanies()
    const collected: Product[] = []
    const seen = new Set<string>()
    for (const company of store.companies) {
      const catalogs = await store.loadCatalogs(company.id)
      for (const catalog of catalogs) {
        const items = await store.loadProducts(catalog.id)
        for (const product of items) {
          if (seen.has(product.id) || !isStockableProduct(product)) continue
          seen.add(product.id)
          collected.push(product)
        }
      }
    }
    catalogProducts.value = collected
  } catch (err) {
    error.value = extractApiErrorMessage(err)
  } finally {
    loadingProducts.value = false
  }
}

function lineBaseQuantity(product: Product, line: LineDraft) {
  const qty = Math.max(0, Math.trunc(Number(line.quantity) || 0))
  const unit = line.units.find(item => item.id === line.sale_unit_id)
  if (product.bottle_volume_ml && unit?.volume_ml) return qty * unit.volume_ml
  return qty
}

async function toggleProduct(product: Product) {
  if (lines.value[product.id]) {
    const next = { ...lines.value }
    delete next[product.id]
    lines.value = next
    return
  }
  const detail = await store.loadProduct(product.id)
  const units = ((detail as Product & { sale_units?: SaleUnit[] }).sale_units ?? [])
    .filter(unit => unit.volume_ml > 0)
  const base = units.find(unit => unit.is_base) ?? units[0]
  lines.value = {
    ...lines.value,
    [product.id]: {
      quantity: 1,
      sale_unit_id: base?.id ?? '',
      price: detail.cost_price ? String(detail.cost_price / 100) : '',
      units,
    },
  }
}

async function submit() {
  error.value = ''
  const items = selectedIds.value
    .map(id => {
      const line = lines.value[id]
      return {
        product_id: id,
        quantity: Math.trunc(Number(line.quantity) || 0),
        sale_unit_id: line.sale_unit_id || null,
        unit_cost: parseMoneyInput(line.price),
      }
    })
    .filter(item => item.quantity >= 1)
  if (!items.length) {
    error.value = t('inventory.needItems')
    return
  }
  saving.value = true
  try {
    const result = await store.createOpeningBalance({
      warehouse_id: form.value.warehouse_id,
      counted_at: form.value.counted_at,
      items,
    })
    successLines.value = result.lines ?? []
    emit('created')
  } catch (err) {
    error.value = extractApiErrorMessage(err)
  } finally {
    saving.value = false
  }
}
</script>

<template>
  <AppModal :open="open" :title="t('inventory.createOpening')" icon="inventory" tone="info" size="lg" @close="emit('close')">
    <div v-if="successLines.length" class="space-y-3">
      <p class="rounded-lg bg-emerald-50 px-3 py-2 text-sm font-medium text-emerald-700">{{ t('inventory.openingSuccess') }}</p>
      <div v-for="line in successLines" :key="line.product_id" class="rounded-lg bg-slate-50 px-3 py-3 text-sm">
        <p class="font-medium">{{ line.name }}</p>
        <p class="mt-1 text-slate-600">{{ t('inventory.availableStock') }} : {{ line.display }}</p>
        <p v-if="line.base_unit === 'ml'" class="text-slate-600">{{ line.base_quantity }} ml</p>
        <p class="text-slate-500">{{ t('inventory.stockValue') }} : {{ formatMoney(line.line_value) }}</p>
      </div>
      <div class="app-modal__actions">
        <button type="button" class="btn-primary" @click="emit('close')">{{ t('common.ok') }}</button>
      </div>
    </div>

    <form v-else class="space-y-3" @submit.prevent="submit">
      <div class="grid gap-3 sm:grid-cols-2">
        <div>
          <label class="mb-1 block text-sm font-medium">{{ t('inventory.warehouse') }}</label>
          <WarehouseOptions v-model="form.warehouse_id" :warehouses="warehouses" />
        </div>
        <div>
          <label class="mb-1 block text-sm font-medium">{{ t('inventory.openingDate') }}</label>
          <input v-model="form.counted_at" type="date" required class="field" />
        </div>
      </div>

      <div>
        <label class="mb-1 block text-sm font-medium">{{ t('inventory.product') }}</label>
        <input v-model="productQuery" class="field" :placeholder="t('inventory.searchProduct')" />
        <div class="product-list">
          <p v-if="loadingProducts" class="px-3 py-4 text-sm text-slate-500">{{ t('common.loading') }}</p>
          <p v-else-if="!stockableProducts.length" class="px-3 py-4 text-sm text-slate-500">{{ t('inventory.noOpeningArticles') }}</p>
          <button
            v-for="product in stockableProducts"
            :key="product.id"
            type="button"
            class="product-row"
            :class="{ 'product-row--active': lines[product.id] }"
            @click="toggleProduct(product)"
          >
            <span class="product-check">{{ lines[product.id] ? '✓' : '' }}</span>
            <span class="min-w-0 flex-1">
              <span class="block truncate font-medium">{{ product.name }}</span>
              <span class="text-xs text-slate-500">{{ product.sku }}</span>
            </span>
          </button>
        </div>
      </div>

      <p class="text-sm text-slate-500">{{ t('inventory.operator') }} : {{ auth.user?.name || '—' }}</p>

      <div v-if="selectedIds.length" class="space-y-2">
        <p class="text-sm font-medium">{{ selectedIds.length }} {{ t('inventory.articles') }}</p>
        <div v-for="product in allStockable.filter(item => lines[item.id])" :key="product.id" class="line-card">
          <p class="font-medium">{{ product.name }}</p>
          <div class="mt-2 grid gap-2 sm:grid-cols-3">
            <input v-model.number="lines[product.id].quantity" type="number" min="1" required class="field" :placeholder="t('inventory.openingQty')" />
            <select v-if="lines[product.id].units.length" v-model="lines[product.id].sale_unit_id" class="field">
              <option v-for="unit in lines[product.id].units" :key="unit.id" :value="unit.id">{{ unit.name }} · {{ unit.volume_ml }} ml</option>
            </select>
            <input v-else :value="product.unit || '—'" class="field" disabled />
            <input v-model="lines[product.id].price" inputmode="decimal" class="field" :placeholder="t('inventory.purchasePrice')" />
          </div>
          <p v-if="lines[product.id].units.find(unit => unit.id === lines[product.id].sale_unit_id)?.volume_ml" class="mt-1 text-xs text-slate-500">
            {{ t('inventory.conversion') }} : {{ lines[product.id].quantity || 0 }} × {{ lines[product.id].units.find(unit => unit.id === lines[product.id].sale_unit_id)?.volume_ml }} ml = {{ lineBaseQuantity(product, lines[product.id]) }} ml
          </p>
        </div>
      </div>

      <div class="rounded-lg bg-slate-50 px-3 py-2 text-sm text-slate-600">
        <p>{{ t('inventory.stockValue') }} : <strong>{{ formatMoney(totalValue) }}</strong></p>
      </div>

      <p class="text-xs text-slate-500">{{ t('inventory.openingOnce') }}</p>
      <p v-if="error" class="text-sm text-red-600">{{ error }}</p>
      <div class="app-modal__actions">
        <button type="button" class="btn-secondary" @click="emit('close')">{{ t('common.cancel') }}</button>
        <button type="submit" class="btn-primary" :disabled="saving || !selectedIds.length">{{ t('inventory.validateOpening') }}</button>
      </div>
    </form>
  </AppModal>
</template>

<style scoped>
.field { width: 100%; border-radius: 0.5rem; border: 1px solid #cbd5e1; padding: 0.5rem 0.75rem; }
.product-list { margin-top: 0.5rem; max-height: 14rem; overflow: auto; border: 1px solid #e2e8f0; border-radius: 0.6rem; }
.product-row { display: flex; align-items: center; gap: 0.6rem; width: 100%; padding: 0.55rem 0.75rem; text-align: left; border-bottom: 1px solid #f1f5f9; }
.product-row--active { background: #f4efe4; }
.product-check { width: 1rem; font-weight: 700; color: #4a6d86; }
.line-card { border: 1px solid #e2e8f0; border-radius: 0.7rem; padding: 0.7rem; }
.btn-primary { border-radius: 0.5rem; padding: 0.5rem 1rem; font-weight: 500; color: white; background-color: var(--color-brand-600); }
.btn-secondary { border-radius: 0.5rem; border: 1px solid #cbd5e1; padding: 0.5rem 1rem; }
</style>
