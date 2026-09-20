<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import { api, extractApiErrorMessage } from '../../../api/client'
import InventoryLayout from '../../../components/inventory/InventoryLayout.vue'
import OpeningBalanceModal from '../../../components/inventory/OpeningBalanceModal.vue'
import WarehouseOptions from '../../../components/inventory/WarehouseOptions.vue'
import FullCountSheet from '../../../components/inventory/FullCountSheet.vue'
import CycleCountModal from '../../../components/inventory/CycleCountModal.vue'
import { useConfirm } from '../../../composables/useConfirm'
import StatusBadge from '../../../components/organization/StatusBadge.vue'
import AppModal from '../../../components/ui/AppModal.vue'
import FieldLabel from '../../../components/ui/FieldLabel.vue'
import ModuleFilters from '../../../components/ui/ModuleFilters.vue'
import { useBackofficeStore } from '../../../stores/backoffice'
import { useContextStore } from '../../../stores/context'
import type { Category, InventoryCountDetail, Product, StockBalance, StockLedgerRow, Warehouse } from '../../../types'
import { formatMoney } from '../../../utils/money'
import { isStockableProduct } from '../../../utils/product'
import { formatDate, formatDateTime } from '../../../utils/format'
import { emptyListFilters, inPeriod, matchesSearch, type ListFilters } from '../../../utils/listFilters'

type CountType = 'opening' | 'full' | 'cycle' | 'spot'

const { t } = useI18n()
const store = useBackofficeStore()
const context = useContextStore()
const { notify, confirm: confirmDialog } = useConfirm()

const COUNT_TYPES: CountType[] = ['opening', 'full', 'cycle', 'spot']

const warehouses = ref<Warehouse[]>([])
const products = ref<Product[]>([])
const categories = ref<Category[]>([])
const stockedIds = ref<Set<string>>(new Set())
const onHandByProduct = ref<Record<string, number>>({})
const showModal = ref(false)
const showOpening = ref(false)
const showFullCount = ref(false)
const fullCountId = ref<string | null>(null)
const showCycle = ref(false)
const ledgerWarehouseId = ref('')
const ledger = ref<StockLedgerRow[]>([])
const showPreview = ref(false)
const preview = ref<InventoryCountDetail | null>(null)
const previewItems = ref<{ product_id: string; name: string; sku: string; quantity: number; system_quantity: number | null }[]>([])
const saving = ref(false)
const categoryId = ref('')
const search = ref('')
const selected = ref<Record<string, boolean>>({})
const listFilters = ref<ListFilters>(emptyListFilters('all'))
const countStatusOptions = computed(() =>
  ['draft', 'confirmed', 'completed', 'cancelled'].map(value => ({
    value,
    label: statusLabel(value),
  })),
)
const filteredCounts = computed(() => store.inventoryCounts.filter(row =>
  matchesSearch(
    `${row.count_number} ${row.count_type ?? ''} ${row.warehouse?.name ?? ''}`,
    listFilters.value.search,
  )
  && (!listFilters.value.status || row.status === listFilters.value.status)
  && inPeriod(row.counted_at ?? row.created_at, listFilters.value),
))

const form = ref({
  warehouse_id: '',
  count_type: 'full' as CountType,
  counted_at: today(),
  notes: '',
})

function today() {
  const now = new Date()
  const month = String(now.getMonth() + 1).padStart(2, '0')
  const day = String(now.getDate()).padStart(2, '0')
  return `${now.getFullYear()}-${month}-${day}`
}

const flatCategories = computed(() => {
  const result: Category[] = []
  function walk(items: Category[] | undefined, prefix = '') {
    for (const item of items ?? []) {
      result.push({ ...item, name: prefix ? `${prefix} / ${item.name}` : item.name })
      if (item.children?.length) walk(item.children, prefix ? `${prefix} / ${item.name}` : item.name)
    }
  }
  walk(categories.value)
  return result
})

const usesProductPicker = computed(() => form.value.count_type === 'spot')

const candidates = computed(() => {
  const stockable = products.value.filter(isStockableProduct)
  if (form.value.count_type === 'spot') {
    return [...stockable].sort((a, b) => {
      const stockA = onHandByProduct.value[a.id] ?? 0
      const stockB = onHandByProduct.value[b.id] ?? 0
      if (stockB > 0 && stockA <= 0) return 1
      if (stockA > 0 && stockB <= 0) return -1
      return 0
    })
  }
  return stockable
})

const visibleProducts = computed(() => {
  const query = search.value.trim().toLowerCase()
  return candidates.value.filter(product => {
    if (categoryId.value && product.category_id !== categoryId.value) return false
    if (!query) return true
    return product.name.toLowerCase().includes(query) || product.sku.toLowerCase().includes(query)
  })
})

const selectedProducts = computed(() => candidates.value.filter(product => selected.value[product.id]))

onMounted(async () => {
  await store.loadInventoryCounts()
  warehouses.value = await store.loadAllWarehouses()
  if (!store.users.length) await store.loadUsers()
  ledgerWarehouseId.value = warehouses.value[0]?.id ?? ''
  await refreshLedger()
  await store.loadCompanies()
  const companyId = store.companies[0]?.id
  if (companyId) {
    const catalogs = await store.loadCatalogs(companyId)
    const catalogId = catalogs.find(c => c.is_default)?.id ?? catalogs[0]?.id
    if (catalogId) {
      categories.value = await store.loadCategories(catalogId, context.currentStoreId)
      products.value = await store.loadProducts(catalogId)
    }
  }
})

watch(() => form.value.warehouse_id, () => {
  void refreshStock()
})

watch(() => form.value.count_type, () => {
  applyTypeSelection()
})

async function refreshLedger() {
  if (!ledgerWarehouseId.value) {
    ledger.value = []
    return
  }
  ledger.value = await store.loadStockLedger(ledgerWarehouseId.value)
}

async function onOpeningCreated() {
  await store.loadInventoryCounts()
  await refreshLedger()
}

async function openCreate() {
  form.value = {
    warehouse_id: warehouses.value[0]?.id ?? '',
    count_type: 'full',
    counted_at: today(),
    notes: '',
  }
  categoryId.value = ''
  search.value = ''
  selected.value = {}
  showModal.value = true
  await refreshStock()
}

async function refreshStock() {
  stockedIds.value = new Set()
  onHandByProduct.value = {}
  if (!form.value.warehouse_id) return
  const res = await api.get<{ data: { data?: StockBalance[] } | StockBalance[] }>(`/warehouses/${form.value.warehouse_id}/stock?per_page=500`)
  const body = res.data
  const rows = Array.isArray(body) ? body : (body?.data ?? [])
  const totals: Record<string, number> = {}
  for (const row of rows) {
    totals[row.product_id] = (totals[row.product_id] ?? 0) + Number(row.quantity_on_hand ?? 0)
  }
  onHandByProduct.value = totals
  stockedIds.value = new Set(Object.entries(totals).filter(([, qty]) => qty > 0).map(([id]) => id))
  applyTypeSelection()
}

function applyTypeSelection() {
  const next: Record<string, boolean> = {}
  if (form.value.count_type === 'full') {
    for (const product of candidates.value) next[product.id] = true
  }
  selected.value = next
}

function toggleVisible(checked: boolean) {
  const next = { ...selected.value }
  for (const product of visibleProducts.value) next[product.id] = checked
  selected.value = next
}

function actorLabel(user?: { name: string } | null, at?: string | null) {
  if (!user?.name) return ''
  return at ? `${user.name} · ${formatDateTime(at)}` : user.name
}

function statusLabel(status: string) {
  const key = `inventory.countStatus.${status}`
  const translated = t(key)
  return translated === key ? status : translated
}

function openCountSheet(id: string) {
  fullCountId.value = id
  showFullCount.value = true
}

function openRow(row: { id: string; count_type?: string }) {
  if (row.count_type === 'full' || row.count_type === 'cycle' || row.count_type === 'spot') {
    openCountSheet(row.id)
    return
  }
  openPreview(row.id)
}

async function save() {
  saving.value = true
  try {
    if (form.value.count_type === 'opening') {
      showModal.value = false
      showOpening.value = true
      return
    }
    if (form.value.count_type === 'full') {
      const result = await store.startFullCount({
        warehouse_id: form.value.warehouse_id,
        counted_at: form.value.counted_at,
        category_id: categoryId.value || undefined,
        notes: form.value.notes || undefined,
        lock_movements: true,
      })
      const id = result.data?.id
      if (!id) throw new Error(t('inventory.noStockToCount'))
      showModal.value = false
      openCountSheet(id)
      await store.loadInventoryCounts()
      return
    }
    if (form.value.count_type === 'cycle') {
      showModal.value = false
      showCycle.value = true
      return
    }
    if (!selectedProducts.value.length) return
    const result = await store.startSpotCount({
      warehouse_id: form.value.warehouse_id,
      counted_at: form.value.counted_at,
      notes: form.value.notes || undefined,
      product_ids: selectedProducts.value.map(product => product.id),
    })
    const id = result.data?.id
    if (!id) throw new Error(t('inventory.noArticles'))
    showModal.value = false
    openCountSheet(id)
    await store.loadInventoryCounts()
  } catch (error) {
    await notify(extractApiErrorMessage(error))
  } finally {
    saving.value = false
  }
}

const previewEditable = computed(() => preview.value?.status === 'draft')
const previewHint = computed(() => {
  if (preview.value?.status === 'completed') return t('inventory.previewApplied')
  if (previewEditable.value) return t('inventory.previewHint')
  return t('inventory.previewLocked')
})

function mapPreviewItems(detail: InventoryCountDetail) {
  return (detail.items ?? []).map(item => ({
    product_id: item.product_id,
    name: item.product?.name ?? '—',
    sku: item.product?.sku ?? '',
    quantity: item.counted_quantity,
    system_quantity: item.system_quantity ?? null,
  }))
}

async function openPreview(id: string) {
  preview.value = await store.loadInventoryCount(id)
  previewItems.value = mapPreviewItems(preview.value)
  showPreview.value = true
}

async function savePreview() {
  if (!preview.value || !previewEditable.value) return
  saving.value = true
  try {
    preview.value = await store.updateInventoryCount(
      preview.value.id,
      previewItems.value.map(item => ({ product_id: item.product_id, quantity: Math.max(0, Number(item.quantity) || 0) })),
    )
    previewItems.value = mapPreviewItems(preview.value)
    await store.loadInventoryCounts()
  } finally {
    saving.value = false
  }
}

async function askStep(kind: 'confirm' | 'approve') {
  return confirmDialog(
    kind === 'approve' ? t('inventory.approveModalMessage') : t('inventory.confirmModalMessage'),
    {
      title: kind === 'approve' ? t('inventory.approveModalTitle') : t('inventory.confirmModalTitle'),
      confirmLabel: kind === 'approve' ? t('inventory.confirmFinal') : t('inventory.confirm'),
      danger: false,
      items: previewItems.value.map(item => ({
        name: item.name,
        detail: item.sku,
        quantity: item.quantity,
      })),
    },
  )
}

async function confirmFromPreview() {
  if (!preview.value || preview.value.status !== 'draft') return
  if (!(await askStep('confirm'))) return
  saving.value = true
  try {
    await savePreview()
    await store.confirmInventoryCount(preview.value.id)
    preview.value = await store.loadInventoryCount(preview.value.id)
    previewItems.value = mapPreviewItems(preview.value)
    await store.loadInventoryCounts()
  } catch (error) {
    await notify(extractApiErrorMessage(error))
  } finally {
    saving.value = false
  }
}

async function complete(id: string) {
  await store.completeInventoryCount(id)
  await store.loadInventoryCounts()
}

async function completeFromPreview() {
  if (!preview.value || preview.value.status !== 'confirmed') return
  if (!(await askStep('approve'))) return
  saving.value = true
  try {
    await complete(preview.value.id)
    preview.value = await store.loadInventoryCount(preview.value.id)
    previewItems.value = mapPreviewItems(preview.value)
  } catch (error) {
    await notify(extractApiErrorMessage(error))
  } finally {
    saving.value = false
  }
}
</script>

<template>
  <InventoryLayout>
    <div class="mb-4 flex flex-wrap items-center justify-end gap-2">
      <button class="btn-secondary" @click="showOpening = true">{{ t('inventory.createOpening') }}</button>
      <button class="btn-secondary" @click="fullCountId = null; showFullCount = true">{{ t('inventory.fullCountTitle') }}</button>
      <button class="btn-secondary" @click="showCycle = true">{{ t('inventory.cycleTitle') }}</button>
      <button class="btn-primary" @click="openCreate">+ {{ t('inventory.newInventory') }}</button>
    </div>

    <div class="mb-6 overflow-hidden rounded-xl bg-white shadow-sm ring-1 ring-slate-200">
      <div class="flex flex-wrap items-center justify-between gap-3 border-b border-slate-100 px-4 py-3">
        <div>
          <h2 class="m-0 text-sm font-semibold text-slate-800">{{ t('inventory.ledgerTitle') }}</h2>
          <p class="m-0 text-xs text-slate-500">{{ t('inventory.ledgerHint') }}</p>
        </div>
        <select v-model="ledgerWarehouseId" class="field max-w-xs" @change="refreshLedger">
          <option v-for="warehouse in warehouses" :key="warehouse.id" :value="warehouse.id">{{ warehouse.name }}</option>
        </select>
      </div>
      <div class="overflow-x-auto">
        <table class="min-w-full divide-y divide-slate-200 text-sm">
          <thead class="bg-slate-50">
            <tr>
              <th class="px-4 py-3 text-left font-medium">{{ t('inventory.product') }}</th>
              <th class="px-4 py-3 text-left font-medium">{{ t('inventory.openingShort') }}</th>
              <th class="px-4 py-3 text-left font-medium">{{ t('inventory.entries') }}</th>
              <th class="px-4 py-3 text-left font-medium">{{ t('inventory.sales') }}</th>
              <th class="px-4 py-3 text-left font-medium">{{ t('inventory.losses') }}</th>
              <th class="px-4 py-3 text-left font-medium">{{ t('inventory.availableStock') }}</th>
              <th class="px-4 py-3 text-left font-medium">{{ t('inventory.averageCost') }}</th>
              <th class="px-4 py-3 text-left font-medium">{{ t('inventory.stockValue') }}</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-slate-100">
            <tr v-for="row in ledger" :key="row.product_id" class="hover:bg-slate-50">
              <td class="px-4 py-3">
                <span class="block font-medium">{{ row.name }}</span>
                <span class="text-xs text-slate-500">{{ row.category || row.sku }}</span>
              </td>
              <td class="px-4 py-3">{{ row.opening }}</td>
              <td class="px-4 py-3">{{ row.entries }}</td>
              <td class="px-4 py-3">{{ row.sales }}</td>
              <td class="px-4 py-3">{{ row.losses }}</td>
              <td class="px-4 py-3">
                <span class="block">{{ row.display }}</span>
                <span v-if="row.low_stock" class="text-xs text-red-600">{{ t('inventory.lowStock') }}</span>
              </td>
              <td class="px-4 py-3">{{ formatMoney(row.average_cost) }}</td>
              <td class="px-4 py-3">{{ formatMoney(row.stock_value) }}</td>
            </tr>
          </tbody>
        </table>
        <p v-if="!ledger.length" class="px-4 py-6 text-center text-sm text-slate-500">{{ t('inventory.ledgerEmpty') }}</p>
      </div>
    </div>

    <div class="overflow-hidden rounded-xl bg-white shadow-sm ring-1 ring-slate-200">
      <div class="border-b border-slate-100 p-4">
        <ModuleFilters
          v-model="listFilters"
          :statuses="countStatusOptions"
          show-search
          show-period
          show-status
        />
      </div>
      <table class="min-w-full divide-y divide-slate-200 text-sm">
        <thead class="bg-slate-50">
          <tr>
            <th class="px-4 py-3 text-left font-medium">#</th>
            <th class="px-4 py-3 text-left font-medium">{{ t('inventory.countType') }}</th>
            <th class="px-4 py-3 text-left font-medium">{{ t('inventory.warehouse') }}</th>
            <th class="px-4 py-3 text-left font-medium">{{ t('inventory.articles') }}</th>
            <th class="px-4 py-3 text-left font-medium">{{ t('products.status') }}</th>
            <th class="px-4 py-3 text-left font-medium">{{ t('inventory.countDate') }}</th>
            <th />
          </tr>
        </thead>
        <tbody class="divide-y divide-slate-100">
          <tr v-for="row in filteredCounts" :key="row.id" class="cursor-pointer hover:bg-slate-50" @click="openRow(row)">
            <td class="px-4 py-3 font-mono">{{ row.count_number }}</td>
            <td class="px-4 py-3">{{ row.count_type ? t(`inventory.countTypes.${row.count_type}.label`) : '—' }}</td>
            <td class="px-4 py-3">{{ row.warehouse?.name ?? '—' }}</td>
            <td class="px-4 py-3">{{ row.items_count ?? '—' }}</td>
            <td class="px-4 py-3"><StatusBadge :active="row.status === 'completed'" :label="statusLabel(row.status)" /></td>
            <td class="px-4 py-3 text-slate-500">{{ formatDate(row.counted_at ?? row.created_at) }}</td>
            <td class="px-4 py-3 text-right" @click.stop>
              <button class="text-slate-600" @click="openRow(row)">{{ t('inventory.viewDetails') }}</button>
              <button v-if="row.status === 'draft'" class="ml-3 text-brand-600" @click="openPreview(row.id)">{{ t('inventory.confirm') }}</button>
              <button v-else-if="row.status === 'confirmed'" class="ml-3 text-brand-600" @click="openPreview(row.id)">{{ t('inventory.confirmFinal') }}</button>
            </td>
          </tr>
        </tbody>
      </table>
      <p v-if="!filteredCounts.length" class="px-4 py-8 text-center text-slate-500">{{ t('org.empty') }}</p>
    </div>

    <CycleCountModal
      :open="showCycle"
      :warehouses="warehouses"
      :categories="flatCategories"
      :products="products"
      :users="store.users"
      :warehouse-id="form.warehouse_id"
      @close="showCycle = false"
      @created="(id) => { showCycle = false; fullCountId = id; showFullCount = true; store.loadInventoryCounts() }"
    />

    <FullCountSheet
      :open="showFullCount"
      :warehouses="warehouses"
      :categories="flatCategories"
      :users="store.users"
      :count-id="fullCountId"
      @close="showFullCount = false"
      @changed="store.loadInventoryCounts()"
    />

    <OpeningBalanceModal
      :open="showOpening"
      :warehouses="warehouses"
      :products="products"
      :warehouse-id="form.warehouse_id"
      @close="showOpening = false"
      @created="onOpeningCreated"
    />

    <AppModal
      :open="showModal"
      :title="t('inventory.newInventory')"
      icon="inventory"
      tone="info"
      size="xl"
      @close="showModal = false"
    >
      <form class="space-y-4" @submit.prevent="save">
        <div class="grid gap-3 sm:grid-cols-2">
          <div>
            <FieldLabel icon="inventory">{{ t('inventory.warehouse') }}</FieldLabel>
            <WarehouseOptions v-model="form.warehouse_id" :warehouses="warehouses" />
          </div>
          <div>
            <FieldLabel icon="calendar">{{ t('inventory.countDate') }} *</FieldLabel>
            <input v-model="form.counted_at" type="date" required class="field" />
          </div>
        </div>

        <div>
          <FieldLabel icon="inventory">{{ t('inventory.countType') }}</FieldLabel>
          <div class="count-types">
            <label
              v-for="type in COUNT_TYPES"
              :key="type"
              class="count-type"
              :class="{ 'count-type--active': form.count_type === type }"
            >
              <input v-model="form.count_type" type="radio" class="sr-only" :value="type" />
              <span class="count-type__title">{{ t(`inventory.countTypes.${type}.label`) }}</span>
              <span class="count-type__desc">{{ t(`inventory.countTypes.${type}.description`) }}</span>
            </label>
          </div>
        </div>

        <p v-if="form.count_type === 'opening'" class="rounded-lg bg-slate-50 px-3 py-2 text-sm text-slate-600">{{ t('inventory.openingOnce') }}</p>
        <p v-else-if="form.count_type === 'full'" class="rounded-lg bg-slate-50 px-3 py-2 text-sm text-slate-600">{{ t('inventory.fullCountHint') }}</p>
        <p v-else-if="form.count_type === 'cycle'" class="rounded-lg bg-slate-50 px-3 py-2 text-sm text-slate-600">{{ t('inventory.cycleHint') }}</p>
        <p v-else-if="form.count_type === 'spot'" class="rounded-lg bg-slate-50 px-3 py-2 text-sm text-slate-600">{{ t('inventory.spotHint') }}</p>

        <div v-if="form.count_type === 'full'" class="grid gap-3 sm:grid-cols-2">
          <div>
            <FieldLabel icon="layers">{{ t('catalog.tabs.categories') }}</FieldLabel>
            <select v-model="categoryId" class="field">
              <option value="">—</option>
              <option v-for="cat in flatCategories" :key="cat.id" :value="cat.id">{{ cat.name }}</option>
            </select>
          </div>
        </div>

        <template v-if="usesProductPicker">
        <div class="grid gap-3 sm:grid-cols-2">
          <div>
            <FieldLabel icon="layers">{{ t('catalog.tabs.categories') }}</FieldLabel>
            <select v-model="categoryId" class="field">
              <option value="">—</option>
              <option v-for="cat in flatCategories" :key="cat.id" :value="cat.id">{{ cat.name }}</option>
            </select>
          </div>
          <div>
            <FieldLabel icon="search">{{ t('inventory.searchProduct') }}</FieldLabel>
            <input v-model="search" class="field" />
          </div>
        </div>

        <div class="flex flex-wrap gap-3 text-sm">
          <button type="button" class="text-brand-600" @click="toggleVisible(true)">{{ t('inventory.selectVisible') }}</button>
          <button type="button" class="text-slate-500" @click="toggleVisible(false)">{{ t('inventory.clearSelection') }}</button>
        </div>

        <div class="count-list">
          <p v-if="!visibleProducts.length" class="px-3 py-6 text-center text-sm text-slate-500">
            {{ form.count_type === 'opening' ? t('inventory.noOpeningArticles') : t('inventory.noArticles') }}
          </p>
          <label v-for="product in visibleProducts" :key="product.id" class="count-row">
            <input v-model="selected[product.id]" type="checkbox" />
            <span class="min-w-0 flex-1">
              <span class="block truncate font-medium">{{ product.name }}</span>
              <span class="text-xs text-slate-500">{{ product.sku }}</span>
            </span>
            <span class="count-sys text-xs text-slate-500">{{ onHandByProduct[product.id] ?? 0 }}</span>
          </label>
        </div>
        </template>

        <div class="app-modal__actions">
          <button type="button" class="btn-secondary" @click="showModal = false">{{ t('common.cancel') }}</button>
          <button type="submit" class="btn-primary" :disabled="saving || (form.count_type === 'spot' && !selectedProducts.length)">
            {{ form.count_type === 'opening' ? t('inventory.createOpening') : form.count_type === 'full' ? t('inventory.startFullCount') : form.count_type === 'cycle' ? t('inventory.planCycle') : t('inventory.startSpotCount') }}
          </button>
        </div>
      </form>
    </AppModal>

    <AppModal
      :open="showPreview"
      :title="preview ? `${t('inventory.previewTitle')} · ${preview.count_number}` : t('inventory.previewTitle')"
      icon="inventory"
      tone="info"
      size="lg"
      @close="showPreview = false"
    >
      <div v-if="preview" class="space-y-3">
        <p class="text-xs text-slate-500">{{ previewHint }}</p>
        <div class="flex flex-wrap items-center gap-4 text-sm text-slate-600">
          <span>{{ preview.warehouse?.name }}</span>
          <span>{{ preview.count_type ? t(`inventory.countTypes.${preview.count_type}.label`) : '' }}</span>
          <span>{{ formatDate(preview.counted_at) }}</span>
          <StatusBadge :active="preview.status === 'completed'" :label="statusLabel(preview.status)" />
        </div>
        <dl class="grid gap-3 sm:grid-cols-2">
          <div class="rounded-lg bg-slate-50 px-3 py-2">
            <dt class="text-xs uppercase tracking-wide text-slate-400">{{ t('inventory.confirmedBy') }}</dt>
            <dd class="mt-1 font-medium text-slate-800">{{ actorLabel(preview.confirmed_by, preview.confirmed_at) || '—' }}</dd>
          </div>
          <div class="rounded-lg bg-slate-50 px-3 py-2">
            <dt class="text-xs uppercase tracking-wide text-slate-400">{{ t('inventory.approvedBy') }}</dt>
            <dd class="mt-1 font-medium text-slate-800">{{ preview.status === 'completed' ? (actorLabel(preview.approved_by) || '—') : '—' }}</dd>
          </div>
        </dl>
        <div class="count-list">
          <div class="count-row count-row--head">
            <span class="min-w-0 flex-1">{{ t('inventory.articles') }}</span>
            <span class="count-sys">{{ t('inventory.systemQty') }}</span>
            <span class="count-qty-label">{{ t('inventory.countedQty') }}</span>
          </div>
          <div v-for="(item, index) in previewItems" :key="item.product_id" class="count-row">
            <span class="min-w-0 flex-1">
              <span class="block truncate font-medium">{{ item.name }}</span>
              <span class="text-xs text-slate-500">{{ item.sku }}</span>
            </span>
            <span class="count-sys">{{ item.system_quantity ?? '—' }}</span>
            <input
              v-model.number="item.quantity"
              type="number"
              min="0"
              class="field count-qty"
              :disabled="!previewEditable"
            />
            <button v-if="previewEditable && previewItems.length > 1" type="button" class="text-sm text-red-600" @click="previewItems.splice(index, 1)">{{ t('inventory.removeLine') }}</button>
          </div>
        </div>
        <div class="app-modal__actions">
          <button type="button" class="btn-secondary" @click="showPreview = false">{{ t('common.cancel') }}</button>
          <button v-if="previewEditable" type="button" class="btn-secondary" :disabled="saving" @click="savePreview">{{ t('common.save') }}</button>
          <button v-if="preview.status === 'draft'" type="button" class="btn-primary" :disabled="saving" @click="confirmFromPreview">{{ t('inventory.confirm') }}</button>
          <button v-else-if="preview.status === 'confirmed'" type="button" class="btn-primary" :disabled="saving" @click="completeFromPreview">{{ t('inventory.confirmFinal') }}</button>
        </div>
      </div>
    </AppModal>
  </InventoryLayout>
</template>

<style scoped>
.field { width: 100%; border-radius: 0.5rem; border: 1px solid #cbd5e1; padding: 0.5rem 0.75rem; }
.btn-primary { border-radius: 0.5rem; padding: 0.5rem 1rem; font-weight: 500; color: white; background-color: var(--color-brand-600); }
.btn-secondary { border-radius: 0.5rem; border: 1px solid #cbd5e1; padding: 0.5rem 1rem; }
.text-brand-600 { color: var(--color-brand-600); }
.count-types { display: grid; gap: 0.5rem; grid-template-columns: repeat(auto-fit, minmax(12rem, 1fr)); }
.count-type {
  display: flex;
  flex-direction: column;
  gap: 0.2rem;
  padding: 0.7rem 0.8rem;
  border: 1px solid #e2e8f0;
  border-radius: 0.75rem;
  cursor: pointer;
  background: #fff;
}
.count-type--active { border-color: var(--color-brand-600); background: #eef3f6; }
.count-type__title { font-size: 0.8125rem; font-weight: 700; color: #12181e; }
.count-type__desc { font-size: 0.72rem; line-height: 1.35; color: #64748b; }
.count-list { max-height: 18rem; overflow: auto; border: 1px solid #e2e8f0; border-radius: 0.75rem; }
.count-row { display: flex; align-items: center; gap: 0.6rem; padding: 0.45rem 0.65rem; border-bottom: 1px solid #f1f5f9; }
.count-qty { width: 4.4rem; flex: 0 0 4.4rem; padding: 0.3rem 0.35rem; text-align: center; }
.count-qty-label { width: 4.4rem; flex: 0 0 4.4rem; text-align: center; font-size: 0.75rem; color: #64748b; }
.count-sys { width: 5.5rem; flex: 0 0 5.5rem; text-align: center; font-size: 0.875rem; color: #475569; }
.count-row--head { font-size: 0.75rem; color: #64748b; background: #f8fafc; }
.sr-only { position: absolute; width: 1px; height: 1px; overflow: hidden; clip: rect(0,0,0,0); }
</style>
