<script setup lang="ts">
import CountUp from '../../../components/motion/CountUp.vue'
import { computed, defineAsyncComponent, onMounted, onUnmounted, ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import { useRoute, useRouter, RouterLink } from 'vue-router'
import PageFrame from '../../../components/layout/PageFrame.vue'
import PosCartPanel from '../../../components/pos/PosCartPanel.vue'
import PosCategorySidebar from '../../../components/pos/PosCategorySidebar.vue'
import PosFooterPanel from '../../../components/pos/PosFooterPanel.vue'
import PosProductGrid from '../../../components/pos/PosProductGrid.vue'
import PosSearchBar from '../../../components/pos/PosSearchBar.vue'
import AppIcon from '../../../components/ui/AppIcon.vue'
import { api, extractApiErrorMessage } from '../../../api/client'
import { printSaleDocument } from '../../../utils/printSaleDocument'
import { realtimeTopics, useRealtimeSync } from '../../../composables/useRealtimeSync'
import { useContextStore } from '../../../stores/context'
import { usePosStore } from '../../../stores/pos'
import AppModal from '../../../components/ui/AppModal.vue'
import Badge from '../../../components/ui/Badge.vue'
import FieldLabel from '../../../components/ui/FieldLabel.vue'
import { formatMoney } from '../../../utils/money'
import { formatDateTime } from '../../../utils/format'
import type { PosProduct } from '../../../types/pos'
import { availableStock, needsSaleQuantity } from '../../../utils/product'

type FloorTableStatus = 'available' | 'occupied' | 'reserved' | 'cleaning' | 'inactive'
interface FloorTableOption {
  id: string
  name: string
  code?: string
  capacity?: number
  status: FloorTableStatus
  is_active?: boolean
  zone?: { id: string; name: string } | null
  current_sale_id?: string | null
  current_sale?: {
    id: string
    reference: string
    total: number
    item_count: number
    opened_at?: string | null
    server?: { id: string; name: string } | null
  } | null
  reservation?: {
    guest_name: string
    party_size: number
    reserved_at?: string | null
  } | null
  pending_qr_count?: number
}

const DeliveryMapPicker = defineAsyncComponent(() => import('../../../components/pos/DeliveryMapPicker.vue'))

const { t } = useI18n()
const route = useRoute()
const router = useRouter()
const context = useContextStore()
const pos = usePosStore()

const searchQuery = ref('')
const selectedCategoryId = ref<string | null>(null)
const footerRef = ref<{
  openPaymentModal: () => void
  openCustomerModal: () => void
  openCreateCustomer: () => void
} | null>(null)
const searchRef = ref<{ focus: () => void } | null>(null)
const unitProduct = ref<PosProduct | null>(null)
const unitId = ref('')
const unitQty = ref(1)
const optionProduct = ref<PosProduct | null>(null)
const variantId = ref('')
const optionQty = ref(1)
const accompanimentHost = ref<{ product: PosProduct; lineId: string } | null>(null)
const selectedAccompanimentIds = ref<string[]>([])
const cartOpen = ref(false)
const showTablePicker = ref(false)
const tablePickerLoading = ref(false)
const tablePickerSaving = ref(false)
const tablePickerError = ref('')
const floorTables = ref<FloorTableOption[]>([])

function chooseDelivery() {
  if (pos.activeTable) return
  pos.orderMode = 'delivery'
}

function ensureServiceReady(): boolean {
  if (pos.activeTable || pos.orderMode !== 'delivery') return true
  if (!pos.customer) {
    pos.setStatus(t('pos.deliveryNeedsCustomer'), true)
    return false
  }
  if (!pos.deliveryAddress.trim()) {
    pos.setStatus(t('pos.deliveryNeedsAddress'), true)
    return false
  }
  return true
}

const footerLabels = computed(() => ({
  customer: t('pos.customer'),
  discount: t('pos.discount'),
  note: t('pos.note'),
  subtotal: t('pos.subtotal'),
  lineDiscounts: t('pos.lineDiscounts'),
  promoDiscounts: t('pos.promoDiscounts'),
  globalDiscount: t('pos.globalDiscount'),
  fees: t('pos.fees'),
  tax: t('pos.tax'),
  total: t('pos.total'),
  hold: t('pos.hold'),
  retrieve: t('pos.retrieve'),
  cancel: t('pos.cancel'),
  pay: t('pos.confirmPay'),
  searchCustomer: t('pos.searchCustomer'),
  discountType: t('pos.discountType'),
  fixed: t('pos.fixed'),
  percent: t('pos.percent'),
  amount: t('pos.amount'),
  payment: t('pos.payment'),
  cash: t('pos.cash'),
  card: t('pos.card'),
  tendered: t('pos.tendered'),
  change: t('pos.change'),
  heldSales: t('pos.heldSales'),
  noHeldSales: t('pos.noHeldSales'),
  modify: t('pos.modify'),
  addArticles: t('pos.addArticles'),
  payHeld: t('pos.payHeld'),
  heldItems: t('pos.heldItems'),
  notePlaceholder: t('pos.notePlaceholder'),
  confirm: t('common.save'),
  createCustomer: t('pos.createCustomer'),
  customerName: t('pos.customerName'),
  customerPhone: t('pos.customerPhone'),
  customerEmail: t('pos.customerEmail'),
  noCustomerFound: t('pos.noCustomerFound'),
  customerCreated: t('pos.customerCreated'),
  noPaymentMethods: t('pos.noPaymentMethods'),
  customerRequired: t('pos.customerRequired'),
  paymentSingle: t('pos.paymentSingle'),
  paymentMixed: t('pos.paymentMixed'),
  remaining: t('pos.remaining'),
  paid: t('pos.paid'),
  addPaymentLine: t('pos.addPaymentLine'),
  removeLine: t('pos.removeLine'),
  fillRemaining: t('pos.fillRemaining'),
  mixedMinLines: t('pos.mixedMinLines'),
  amountMismatch: t('pos.amountMismatch'),
}))

const lineTotalsById = computed(() => {
  const map: Record<string, number> = {}
  for (const line of pos.totals.lines) {
    map[line.line_id] = line.line_total
  }
  return map
})

const quantitiesByProductId = computed(() => {
  const map: Record<string, number> = {}
  for (const line of pos.lines) {
    if (line.isAccompaniment) continue
    map[line.product.product_id] = (map[line.product.product_id] ?? 0) + line.quantity
  }
  return map
})

const uiOrderMode = computed<'dine_in' | 'takeaway' | 'delivery'>(() => {
  if (pos.activeTable) return 'dine_in'
  return pos.orderMode
})

function setOrderMode(mode: 'dine_in' | 'takeaway' | 'delivery') {
  if (mode === 'dine_in') {
    void openTablePicker()
    return
  }
  if (pos.activeTable) {
    pos.setActiveTable(null)
  }
  if (mode === 'delivery') {
    chooseDelivery()
    return
  }
  pos.orderMode = 'takeaway'
}

async function openTablePicker() {
  showTablePicker.value = true
  tablePickerError.value = ''
  await loadFloorTables()
}

async function loadFloorTables() {
  const storeId = context.currentStoreId
  if (!storeId) {
    floorTables.value = []
    tablePickerError.value = t('pos.selectStore')
    return
  }
  tablePickerLoading.value = true
  tablePickerError.value = ''
  try {
    const res = await api.get<{
      data?: { tables?: FloorTableOption[] } | FloorTableOption[]
      tables?: FloorTableOption[]
    }>(`/stores/${storeId}/pos/tables`)
    const raw = res.data
    const list = Array.isArray(raw)
      ? raw
      : (raw?.tables ?? res.tables ?? [])
    floorTables.value = list.filter(table => table.is_active !== false && table.status !== 'inactive')
  } catch (e) {
    floorTables.value = []
    tablePickerError.value = extractApiErrorMessage(e, t('pointOfSale.tables.loadError'))
  } finally {
    tablePickerLoading.value = false
  }
}

function tableStatusLabel(status: FloorTableStatus) {
  const key = `pointOfSale.tables.status.${status}`
  const label = t(key)
  return label === key ? status : label
}

function tableStatusVariant(status: FloorTableStatus): 'success' | 'warning' | 'brand' | 'neutral' {
  if (status === 'available') return 'success'
  if (status === 'occupied') return 'warning'
  if (status === 'reserved') return 'brand'
  return 'neutral'
}

function isTableSelectable(table: FloorTableOption) {
  return table.status === 'available' || table.status === 'reserved'
}

function formatTableTime(value?: string | null) {
  if (!value) return '—'
  return new Intl.DateTimeFormat(undefined, { hour: '2-digit', minute: '2-digit' }).format(new Date(value))
}

async function clearSelectedTable() {
  pos.setActiveTable(null)
  pos.orderMode = 'takeaway'
  showTablePicker.value = false
}

async function pickFloorTable(table: FloorTableOption) {
  const storeId = context.currentStoreId
  if (!storeId || tablePickerSaving.value) return
  if (table.status === 'occupied') {
    tablePickerError.value = t('pos.tableOccupied')
    return
  }
  if (table.status === 'cleaning' || table.status === 'inactive') {
    tablePickerError.value = t('pos.tableCleaning')
    return
  }

  tablePickerSaving.value = true
  tablePickerError.value = ''
  try {
    if (table.status === 'reserved') {
      const res = await api.post<{ data: { sale: { id: string } } }>(
        `/stores/${storeId}/pos/tables/${table.id}/open`,
        { confirm_reserved: true },
      )
      await pos.retrieveSale(res.data.sale.id)
      pos.setActiveTable({ id: table.id, name: table.name, code: table.code })
      showTablePicker.value = false
      return
    }

    // Available table: open server-side order then attach, or just bind if cart already open
    if (pos.lines.length > 0 || pos.pendingSaleId) {
      pos.setActiveTable({ id: table.id, name: table.name, code: table.code })
      if (pos.pendingSaleId) {
        await pos.persistTableOrder().catch(() => undefined)
      }
      showTablePicker.value = false
      return
    }

    const res = await api.post<{ data: { sale: { id: string } } }>(
      `/stores/${storeId}/pos/tables/${table.id}/open`,
      { confirm_reserved: false },
    )
    await pos.retrieveSale(res.data.sale.id)
    pos.setActiveTable({ id: table.id, name: table.name, code: table.code })
    showTablePicker.value = false
  } catch (e) {
    tablePickerError.value = extractApiErrorMessage(e, t('pointOfSale.tables.openError'))
  } finally {
    tablePickerSaving.value = false
  }
}

function onProductIncrement(product: PosProduct) {
  if (hasComplexOptions(product)) {
    onAddProduct(product)
    return
  }
  const existing = pos.lines.find(line => line.product.product_id === product.product_id && !line.isAccompaniment)
  if (existing) {
    pos.incrementQuantity(existing.lineId)
    return
  }
  onAddProduct(product)
}

function onProductDecrement(product: PosProduct) {
  const existing = [...pos.lines]
    .reverse()
    .find(line => line.product.product_id === product.product_id && !line.isAccompaniment)
  if (!existing) return
  if (existing.quantity <= 1) {
    pos.removeLine(existing.lineId)
    return
  }
  pos.decrementQuantity(existing.lineId)
}

function hasComplexOptions(product: PosProduct) {
  return (product.variants?.length ?? 0) > 0
    || product.product_type === 'variant'
    || (product.option_groups?.length ?? 0) > 0
    || (product.sale_units?.length ?? 0) > 1
}

function heldItemCount(sale: { lines: { quantity: number }[] }) {
  return sale.lines.reduce((sum, line) => sum + line.quantity, 0)
}

const categoryCounts = computed(() => {
  const direct: Record<string, number> = {}
  for (const product of pos.products) {
    if (!product.category_id) continue
    direct[product.category_id] = (direct[product.category_id] ?? 0) + 1
  }

  const counts: Record<string, number> = { ...direct }
  const addChildren = (id: string): number => {
    let total = direct[id] ?? 0
    for (const category of pos.categories) {
      if (category.parent_id === id) total += addChildren(category.id)
    }
    counts[id] = total
    return total
  }
  for (const category of pos.categories) {
    if (!category.parent_id) addChildren(category.id)
  }
  return counts
})

const selectedCategoryIds = computed(() => {
  const selected = selectedCategoryId.value
  if (!selected) return null

  const ids = new Set<string>([selected])
  const collect = (parentId: string) => {
    for (const category of pos.categories) {
      if (category.parent_id === parentId && !ids.has(category.id)) {
        ids.add(category.id)
        collect(category.id)
      }
    }
  }
  collect(selected)
  return ids
})

const visibleCategories = computed(() => {
  if (!selectedCategoryIds.value) return pos.categories
  return pos.categories.filter(category => selectedCategoryIds.value?.has(category.id))
})

const productSections = computed(() => {
  const query = searchQuery.value.trim().toLowerCase()
  const matches = (product: PosProduct) => {
    if (!query) return true
    return product.name.toLowerCase().includes(query)
      || product.sku.toLowerCase().includes(query)
      || (product.barcode?.toLowerCase().includes(query) ?? false)
  }

  const used = new Set<string>()
  const sections = visibleCategories.value.map(category => {
    const products = pos.products.filter(product => product.category_id === category.id && matches(product))
    products.forEach(product => used.add(product.product_id))
    return { id: category.id, name: category.name, depth: category.depth ?? 0, products }
  })

  if (!selectedCategoryId.value) {
    const leftover = pos.products.filter(product => matches(product) && !used.has(product.product_id))
    const grouped = new Map<string, typeof leftover>()
    for (const product of leftover) {
      const key = product.category_id || 'uncategorized'
      grouped.set(key, [...(grouped.get(key) ?? []), product])
    }
    for (const [id, products] of grouped) {
      const name = id === 'uncategorized'
        ? t('pos.uncategorized')
        : (products[0]?.category_name || t('pos.uncategorized'))
      sections.push({ id, name, depth: 0, products })
    }
  }

  return query ? sections.filter(section => section.products.length > 0) : sections
})

async function loadForStore(storeId: string) {
  try {
    await pos.loadCatalog(storeId)
    await pos.refreshHeldSales(storeId)
    const saleId = typeof route.query.sale === 'string' ? route.query.sale : ''
    if (saleId) {
      await pos.retrieveSale(saleId)
      if (route.query.pay === '1') {
        footerRef.value?.openPaymentModal()
      }
    } else {
      await pos.recalculate(storeId)
    }
  } catch {
    // error shown in UI
  }
}

function onViewportChange() {
  if (window.innerWidth > 900) cartOpen.value = false
}

useRealtimeSync(realtimeTopics.posTerminal, async (payload) => {
  const storeId = context.currentStoreId
  if (!storeId) return
  const type = payload?.type ?? ''
  if (type.startsWith('sale.')) {
    await pos.refreshHeldSales(storeId)
    return
  }
  await pos.refreshCatalogQuiet(storeId)
})

onMounted(async () => {
  window.addEventListener('keydown', onScanKey)
  window.addEventListener('resize', onViewportChange)
  pos.loading = true
  await context.loadStores()
  if (context.currentStoreId) {
    await loadForStore(context.currentStoreId)
  } else {
    pos.loading = false
  }
})

watch(
  () => route.query.sale,
  async (saleId) => {
    if (typeof saleId !== 'string' || !saleId || !context.currentStoreId) return
    if (pos.lines.length > 0) return
    try {
      await pos.retrieveSale(saleId)
      if (route.query.pay === '1') {
        footerRef.value?.openPaymentModal()
      }
    } catch (e) {
      pos.setStatus(e instanceof Error ? e.message : 'Erreur', true)
    }
  },
)

watch(
  () => context.currentStoreId,
  async (storeId) => {
    pos.reset()
    if (storeId) await loadForStore(storeId)
  },
)

watch(
  () => pos.lines.map(line => `${line.lineId}:${line.quantity}`).join('|'),
  () => {
    if (!pos.activeTable || !pos.pendingSaleId) return
    window.setTimeout(() => {
      void pos.persistTableOrder().catch(() => undefined)
    }, 600)
  },
)

function addHostProduct(product: PosProduct, quantity = 1, saleUnitId?: string, variantId?: string) {
  const before = pos.lines.length
  const line = pos.addProduct(product, quantity, saleUnitId, variantId)
  if (!line) return
  if (pos.lines.length > before) promptAccompaniments(product, line)
}

function promptAccompaniments(product: PosProduct, line: { lineId: string }) {
  if ((product.accompaniments?.length ?? 0) > 0) {
    accompanimentHost.value = { product, lineId: line.lineId }
    selectedAccompanimentIds.value = []
  }
}

function toggleAccompaniment(id: string) {
  if (selectedAccompanimentIds.value.includes(id)) {
    selectedAccompanimentIds.value = selectedAccompanimentIds.value.filter(item => item !== id)
    return
  }
  selectedAccompanimentIds.value = [...selectedAccompanimentIds.value, id]
}

function confirmAccompaniments() {
  const host = accompanimentHost.value
  if (!host) return
  const line = pos.lines.find(item => item.lineId === host.lineId)
  if (line && selectedAccompanimentIds.value.length) {
    pos.addAccompaniments(line, selectedAccompanimentIds.value)
  }
  accompanimentHost.value = null
}

function onAddProduct(product: PosProduct) {
  if (needsSaleQuantity(product)) {
    const available = availableStock(product, pos.cartReservedByProductId)
    if (available !== null && available <= 0) {
      pos.setStatus(t('pos.outOfStock'), true)
      return
    }
  }
  if (product.variants?.length || product.product_type === 'variant' || product.option_groups?.length) {
    optionProduct.value = product
    variantId.value = product.variants?.[0]?.variant_id ?? ''
    optionQty.value = 1
    return
  }
  if (product.sale_units?.length) {
    unitProduct.value = product
    unitId.value = product.sale_units.find(unit => !unit.is_base)?.id ?? product.sale_units[0].id
    unitQty.value = 1
    return
  }
  addHostProduct(product, 1)
}

function confirmOptionSale() {
  if (!optionProduct.value || !variantId.value) return
  const quantity = needsSaleQuantity(optionProduct.value) ? Math.max(1, Math.trunc(optionQty.value) || 1) : 1
  const product = optionProduct.value
  const variant = variantId.value
  optionProduct.value = null
  addHostProduct(product, quantity, undefined, variant)
}

function confirmUnitSale() {
  if (!unitProduct.value || !unitId.value) return
  const quantity = needsSaleQuantity(unitProduct.value) ? Math.max(1, Math.trunc(unitQty.value) || 1) : 1
  const product = unitProduct.value
  const unit = unitId.value
  unitProduct.value = null
  addHostProduct(product, quantity, unit)
}

async function onSearchSubmit(value: string) {
  const code = value.trim()
  if (!code) return

  const local = pos.products.find(p => pos.productMatchesBarcode(p, code))
  if (local) {
    onAddProduct(local)
    searchQuery.value = ''
    return
  }

  const q = code.toLowerCase()
  const named = pos.products.filter(product =>
    product.name.toLowerCase() === q || product.sku.toLowerCase() === q || product.name.toLowerCase().includes(q),
  )
  if (named.length === 1) {
    onAddProduct(named[0])
    searchQuery.value = ''
    return
  }

  if (context.currentStoreId) {
    const product = await pos.lookupBarcode(context.currentStoreId, code)
    if (product) {
      onAddProduct(product)
      searchQuery.value = ''
      return
    }
  }

  if (/^\d{4,}$/.test(code)) pos.setStatus(t('pos.barcodeNotFound', { code }))
}

async function onHold() {
  if (!ensureServiceReady()) return
  try {
    const fromTable = Boolean(pos.activeTable)
    await pos.holdSale()
    if (fromTable) {
      await router.push({ name: 'pos-tables' })
    }
  } catch (e) {
    pos.setStatus(e instanceof Error ? e.message : 'Erreur', true)
  }
}

async function onRetrieve(id: string, options?: { openPayment?: boolean }) {
  try {
    await pos.retrieveSale(id)
    if (options?.openPayment) {
      footerRef.value?.openPaymentModal()
    }
  } catch (e) {
    pos.setStatus(e instanceof Error ? e.message : 'Erreur', true)
  }
}

function onPay(
  payments: { method: string; amount: number; tendered?: number; currency?: string }[],
  done: (result: { success: boolean; message?: string }) => void,
) {
  if (!ensureServiceReady()) {
    done({
      success: false,
      message: pos.customer ? t('pos.deliveryNeedsAddress') : t('pos.deliveryNeedsCustomer'),
    })
    return
  }
  void pos.pay(payments).then(async (result) => {
    const changeMsg = result.change > 0 ? ` — ${t('pos.change')}: ${formatChange(result.change)}` : ''
    const earned = result.loyalty?.earned ?? 0
    const pointsMsg = earned > 0 ? ` — ${t('pos.loyaltyEarned', { points: earned })}` : ''
    pos.setStatus(`${result.message}${changeMsg}${pointsMsg}`, !result.success)
    done({ success: result.success, message: result.message })
    if (!result.success) return
    if (!payments.every(line => line.method === 'room')) kickDrawer()
    if (result.receipt) {
      printSaleDocument(result.receipt, t('pointOfSale.orders.receipt'))
    }
    if (context.currentStoreId) {
      void pos.loadSession(context.currentStoreId)
    }
  }).catch((e) => {
    const message = e instanceof Error ? e.message : 'Paiement refusé'
    pos.setStatus(message, true)
    done({ success: false, message })
  })
}

function kickDrawer() {
  const frame = document.createElement('iframe')
  frame.style.display = 'none'
  document.body.appendChild(frame)
  const doc = frame.contentDocument
  if (!doc) return
  doc.open()
  doc.write('<pre style="font-size:1px">\u001Bp\u0000\u0025\u00250</pre>')
  doc.close()
  frame.contentWindow?.print()
  setTimeout(() => frame.remove(), 800)
}

let scanBuffer = ''
let scanTimer: ReturnType<typeof setTimeout> | null = null

function onScanKey(event: KeyboardEvent) {
  if (event.ctrlKey || event.metaKey || event.altKey) return
  if (event.key === 'F2') {
    event.preventDefault()
    searchRef.value?.focus()
    return
  }
  if (event.key === 'F8' && !pos.isEmpty) {
    event.preventDefault()
    footerRef.value?.openPaymentModal()
    return
  }
  const target = event.target as HTMLElement | null
  if (target && ['INPUT', 'TEXTAREA', 'SELECT'].includes(target.tagName)) return
  if (event.key === 'Enter') {
    const code = scanBuffer
    scanBuffer = ''
    if (code.length >= 4 && context.currentStoreId) void onSearchSubmit(code)
    return
  }
  if (event.key.length !== 1) return
  scanBuffer += event.key
  if (scanTimer) clearTimeout(scanTimer)
  scanTimer = setTimeout(() => { scanBuffer = '' }, 80)
}

function formatChange(amount: number) {
  return (amount / 100).toFixed(0)
}

onUnmounted(() => {
  window.removeEventListener('keydown', onScanKey)
  window.removeEventListener('resize', onViewportChange)
  pos.reset()
})
</script>

<template>
  <PageFrame>
    <template #title>{{ t('nav.posTerminal') }}</template>

    <div class="pos-root">
      <div v-if="!context.currentStoreId" class="pos-empty-store">
        <p>{{ t('pos.selectStore') }}</p>
      </div>

      <template v-else>
        <div class="pos-workspace" :class="{ 'pos-workspace--cart-open': cartOpen }">
          <button
            v-if="cartOpen"
            type="button"
            class="pos-cart-backdrop"
            :aria-label="t('pos.cart')"
            @click="cartOpen = false"
          />

          <section class="pos-main">
            <div class="pos-held" v-if="pos.heldSales.length || pos.lines.length">
              <div class="pos-held__head">
                <h2>{{ t('pos.currentOrder') }}</h2>
                <RouterLink class="pos-held__link" :to="{ name: 'pos-orders' }">
                  {{ t('pos.viewOrders') }}
                </RouterLink>
              </div>
              <div class="pos-held__row">
                <button
                  v-if="pos.lines.length"
                  type="button"
                  class="pos-held__card pos-held__card--live"
                >
                  <div class="pos-held__copy">
                    <strong>{{ pos.customer?.name || t('pos.walkIn') }}</strong>
                    <span>
                      {{ pos.activeTable ? pos.activeTable.name : t(`pos.${uiOrderMode === 'dine_in' ? 'dineIn' : uiOrderMode}`) }}
                      · {{ pos.lines.length }} {{ t('pos.articles') }}
                    </span>
                    <em><CountUp :value="Number(pos.totals.grand_total ?? 0)" format="money" :currency="pos.totals.currency" /></em>
                  </div>
                  <span class="pos-held__ring" aria-hidden="true">●</span>
                </button>
                <button
                  v-for="sale in pos.heldSales"
                  :key="sale.id"
                  type="button"
                  class="pos-held__card"
                  @click="onRetrieve(sale.id)"
                >
                  <div class="pos-held__copy">
                    <strong>{{ sale.customerName || sale.label || t('pos.walkIn') }}</strong>
                    <span>{{ heldItemCount(sale) }} {{ t('pos.articles') }} · #{{ sale.id.slice(0, 6) }}</span>
                    <em>{{ formatMoney(sale.total ?? 0, pos.totals.currency) }}</em>
                  </div>
                  <span class="pos-held__ring pos-held__ring--muted" aria-hidden="true">○</span>
                </button>
              </div>
            </div>

            <div class="pos-catalog-head">
              <div class="pos-catalog-head__title">
                <h2>{{ t('pos.categories') }}</h2>
                <button
                  type="button"
                  class="pos-refresh"
                  :title="t('pos.retry')"
                  @click="loadForStore(context.currentStoreId!)"
                >
                  <AppIcon name="recycle" :size="16" />
                </button>
              </div>
              <div class="pos-catalog-head__tools">
                <PosSearchBar
                  ref="searchRef"
                  v-model="searchQuery"
                  :placeholder="t('pos.searchProducts')"
                  @submit="onSearchSubmit"
                />
                <button
                  type="button"
                  class="pos-cart-toggle"
                  :class="{ 'pos-cart-toggle--open': cartOpen }"
                  @click="cartOpen = !cartOpen"
                >
                  <AppIcon name="receipt" :size="18" />
                  <span>{{ t('pos.cart') }}</span>
                  <em>{{ pos.lines.length }}</em>
                </button>
              </div>
            </div>

            <PosCategorySidebar
              v-if="pos.loading || !pos.error"
              :categories="pos.categories"
              :selected-category-id="selectedCategoryId"
              :all-label="t('pos.allCategories')"
              :counts="categoryCounts"
              :total-count="pos.products.length"
              :loading="pos.loading"
              @select="selectedCategoryId = $event"
            />

            <div v-if="!pos.activeTable && pos.orderMode === 'delivery'" class="pos-location-card">
              <DeliveryMapPicker
                :model-value="pos.deliveryAddress"
                @update:model-value="(value) => { pos.deliveryAddress = value }"
              />
            </div>

            <div v-if="pos.error && !pos.loading" class="pos-error">
              <p>{{ pos.error }}</p>
              <button type="button" class="pos-retry" @click="loadForStore(context.currentStoreId!)">
                {{ t('pos.retry') }}
              </button>
            </div>
            <PosProductGrid
              v-else
              :sections="productSections"
              :currency="pos.totals.currency"
              :empty-label="t('pos.noProducts')"
              :reserved-by-product-id="pos.cartReservedByProductId"
              :quantities-by-product-id="quantitiesByProductId"
              :loading="pos.loading"
              @select="onAddProduct"
              @increment="onProductIncrement"
              @decrement="onProductDecrement"
            />
          </section>

          <aside class="pos-side" :class="{ 'pos-side--cart-open': cartOpen }">
            <PosCartPanel
              :lines="pos.lines"
              :currency="pos.totals.currency"
              :empty-label="t('pos.emptyCart')"
              :empty-hint="t('pos.emptyCartHint')"
              :customer="pos.customer"
              :line-totals="lineTotalsById"
              :table-name="pos.activeTable?.name"
              :order-mode="uiOrderMode"
              @increment="pos.incrementQuantity"
              @decrement="pos.decrementQuantity"
              @quantity="pos.updateQuantity"
              @remove="pos.removeLine"
              @close="cartOpen = false"
              @select-customer="pos.setCustomer"
              @add-customer="footerRef?.openCreateCustomer()"
              @set-order-mode="setOrderMode"
              @open-tables="openTablePicker"
            />
            <PosFooterPanel
              ref="footerRef"
              compact
              hide-customer-chip
              :totals="pos.totals"
              :customer="pos.customer"
              :note="pos.note"
              :global-discount="pos.globalDiscount"
              :held-sales="pos.heldSales"
              :is-empty="pos.isEmpty"
              :calculating="pos.calculating"
              :payment-methods="pos.availablePaymentMethods"
              :labels="footerLabels"
              @select-customer="pos.setCustomer"
              @set-discount="pos.setGlobalDiscount"
              @set-note="pos.setNote"
              @hold="onHold"
              @retrieve="onRetrieve"
              @delete-held="pos.deleteHeldSale"
              @cancel="pos.cancel"
              @pay="onPay"
            />
          </aside>
        </div>

        <AppModal
          :open="Boolean(optionProduct)"
          :title="optionProduct ? `${t('pos.chooseOption')} · ${optionProduct.name}` : t('pos.chooseOption')"
          icon="products"
          tone="info"
          size="lg"
          @close="optionProduct = null"
        >
          <form class="pos-option-form" @submit.prevent="confirmOptionSale">
            <p class="pos-option-hint">{{ t('pos.chooseOptionHint') }}</p>
            <p v-if="!(optionProduct?.variants?.length)" class="pos-option-empty">{{ t('pos.noOptions') }}</p>
            <div class="pos-option-grid">
              <button
                v-for="variant in optionProduct?.variants ?? []"
                :key="variant.variant_id"
                type="button"
                class="pos-option-card"
                :class="{ 'pos-option-card--active': variantId === variant.variant_id }"
                @click="variantId = variant.variant_id"
              >
                <span class="pos-option-card__label">{{ variant.label || variant.name }}</span>
                <span class="pos-option-card__meta">{{ variant.sku }}</span>
                <span class="pos-option-card__price">{{ formatMoney(variant.price, pos.totals.currency) }}</span>
              </button>
            </div>
            <div v-if="optionProduct && needsSaleQuantity(optionProduct)" class="pos-option-qty">
              <span>{{ t('beverages.quantity') }}</span>
              <div class="pos-option-qty__controls">
                <button type="button" @click="optionQty = Math.max(1, optionQty - 1)">−</button>
                <input v-model.number="optionQty" type="number" min="1" />
                <button type="button" @click="optionQty += 1">+</button>
              </div>
            </div>
            <div class="pos-option-actions">
              <button type="button" class="pos-option-cancel" @click="optionProduct = null">{{ t('common.cancel') }}</button>
              <button type="submit" class="pos-option-add" :disabled="!variantId">{{ t('beverages.add') }}</button>
            </div>
          </form>
        </AppModal>

        <AppModal
          :open="Boolean(unitProduct)"
          :title="unitProduct?.name ?? t('beverages.sell')"
          icon="products"
          tone="info"
          size="md"
          @close="unitProduct = null"
        >
          <form class="space-y-3" @submit.prevent="confirmUnitSale">
            <p class="text-sm text-slate-500">{{ t('beverages.sellHint') }}</p>
            <div class="grid gap-2">
              <label
                v-for="unit in unitProduct?.sale_units ?? []"
                :key="unit.id"
                class="flex items-center justify-between gap-3 rounded-lg border px-3 py-2"
                :class="unitId === unit.id ? 'border-[var(--color-brand-600)] bg-slate-50' : 'border-slate-200'"
              >
                <span class="flex items-center gap-2">
                  <input v-model="unitId" type="radio" :value="unit.id" />
                  <span>
                    <span class="block font-medium">{{ unit.name }}</span>
                    <span class="text-xs text-slate-500">{{ unit.volume_ml }} ml<span v-if="unit.yield_per_bottle"> · {{ unit.yield_per_bottle }} / {{ t('beverages.bottle') }}</span></span>
                  </span>
                </span>
                <span class="font-medium">{{ formatMoney(unit.price, pos.totals.currency) }}</span>
              </label>
            </div>
            <div v-if="unitProduct && needsSaleQuantity(unitProduct)">
              <FieldLabel icon="package">{{ t('beverages.quantity') }}</FieldLabel>
              <input v-model.number="unitQty" type="number" min="1" class="w-full rounded-lg border border-slate-300 px-3 py-2" />
            </div>
            <div class="flex justify-end gap-2">
              <button type="button" class="rounded-lg border border-slate-300 px-4 py-2" @click="unitProduct = null">{{ t('common.cancel') }}</button>
              <button type="submit" class="rounded-lg bg-[var(--color-brand-600)] px-4 py-2 text-white">{{ t('beverages.add') }}</button>
            </div>
          </form>
        </AppModal>

        <AppModal
          :open="Boolean(accompanimentHost)"
          :title="accompanimentHost ? `${t('pos.chooseAccompaniment')} · ${accompanimentHost.product.name}` : t('pos.chooseAccompaniment')"
          icon="sparkles"
          tone="info"
          size="md"
          @close="accompanimentHost = null"
        >
          <form class="space-y-3" @submit.prevent="confirmAccompaniments">
            <p class="text-sm text-slate-500">{{ t('pos.chooseAccompanimentHint') }}</p>
            <div class="max-h-72 space-y-1 overflow-auto">
              <label
                v-for="item in accompanimentHost?.product.accompaniments ?? []"
                :key="item.product_id"
                class="flex cursor-pointer items-center justify-between gap-3 rounded-lg border px-3 py-2"
                :class="selectedAccompanimentIds.includes(item.product_id) ? 'border-[var(--color-brand-600)] bg-slate-50' : 'border-slate-200'"
              >
                <span class="flex items-center gap-2">
                  <input
                    type="checkbox"
                    class="rounded"
                    :checked="selectedAccompanimentIds.includes(item.product_id)"
                    @change="toggleAccompaniment(item.product_id)"
                  />
                  <span>
                    <span class="block font-medium">{{ item.name }}</span>
                    <span class="text-xs text-slate-500">{{ item.sku }}</span>
                  </span>
                </span>
                <span class="text-xs font-medium text-emerald-700">{{ t('accompaniments.priceFree') }}</span>
              </label>
            </div>
            <div class="flex justify-end gap-2">
              <button type="button" class="rounded-lg border border-slate-300 px-4 py-2" @click="accompanimentHost = null">{{ t('pos.skipAccompaniment') }}</button>
              <button type="submit" class="rounded-lg bg-[var(--color-brand-600)] px-4 py-2 text-white">{{ t('beverages.add') }}</button>
            </div>
          </form>
        </AppModal>

        <AppModal
          :open="showTablePicker"
          :title="t('pos.pickTable')"
          icon="tables"
          tone="brand"
          size="lg"
          @close="showTablePicker = false"
        >
          <div class="pos-table-picker">
            <p class="pos-table-picker__hint">{{ t('pos.pickTableHint') }}</p>
            <p v-if="tablePickerError" class="pos-table-picker__error">{{ tablePickerError }}</p>
            <div v-if="tablePickerLoading" class="pos-table-picker__loading">{{ t('common.loading') }}</div>
            <div v-else class="pos-table-picker__grid">
              <button
                type="button"
                class="pos-table-picker__card pos-table-picker__card--clear"
                :disabled="tablePickerSaving"
                @click="clearSelectedTable"
              >
                <header>
                  <strong>{{ t('pos.noTable') }}</strong>
                  <Badge variant="neutral">{{ t('pos.takeaway') }}</Badge>
                </header>
                <p class="pos-table-picker__meta">{{ t('pos.takeawayHint') }}</p>
              </button>
              <button
                v-for="table in floorTables"
                :key="table.id"
                type="button"
                class="pos-table-picker__card"
                :class="[
                  `pos-table-picker__card--${table.status}`,
                  {
                    'pos-table-picker__card--active': pos.activeTable?.id === table.id,
                    'pos-table-picker__card--locked': !isTableSelectable(table),
                    'pos-table-picker__card--qr': (table.pending_qr_count || 0) > 0,
                  },
                ]"
                :disabled="tablePickerSaving || !isTableSelectable(table)"
                :aria-disabled="!isTableSelectable(table)"
                @click="pickFloorTable(table)"
              >
                <header>
                  <strong>{{ table.name }}</strong>
                  <Badge :variant="tableStatusVariant(table.status)">{{ tableStatusLabel(table.status) }}</Badge>
                  <Badge v-if="(table.pending_qr_count || 0) > 0" variant="warning">QR {{ table.pending_qr_count }}</Badge>
                </header>
                <p class="pos-table-picker__meta">
                  {{ t('pointOfSale.tables.seats', { count: table.capacity ?? 0 }) }}
                  · {{ table.zone?.name || '—' }}
                </p>
                <template v-if="table.status === 'occupied' && table.current_sale">
                  <p class="pos-table-picker__sale">{{ table.current_sale.reference }}</p>
                  <p>{{ table.current_sale.item_count }} {{ t('pointOfSale.tables.items') }}</p>
                  <p class="pos-table-picker__total">{{ formatMoney(table.current_sale.total) }}</p>
                  <p>{{ t('pointOfSale.tables.since') }} {{ formatTableTime(table.current_sale.opened_at) }}</p>
                </template>
                <template v-else-if="table.status === 'reserved' && table.reservation">
                  <p class="pos-table-picker__sale">{{ table.reservation.guest_name }}</p>
                  <p>{{ formatDateTime(table.reservation.reserved_at) }}</p>
                  <p>{{ t('pointOfSale.tables.party', { count: table.reservation.party_size }) }}</p>
                </template>
              </button>
            </div>
            <div v-if="!tablePickerLoading && !floorTables.length && !tablePickerError" class="pos-table-picker__empty">
              <p>{{ t('pos.noTables') }}</p>
              <RouterLink class="pos-table-picker__link" :to="{ name: 'pos-tables' }" @click="showTablePicker = false">
                {{ t('pos.manageTables') }}
              </RouterLink>
            </div>
          </div>
        </AppModal>

        <div v-if="pos.statusMessage" class="pos-toast" :class="{ 'pos-toast--error': pos.statusIsError }">
          {{ pos.statusMessage }}
        </div>
      </template>
    </div>
  </PageFrame>
</template>

<style scoped>
.pos-root {
  position: relative;
  margin: 0;
  flex: 1;
  width: 100%;
  height: 100%;
  min-height: 0;
  display: flex;
  flex-direction: column;
  overflow: hidden;
  background: var(--color-canvas, #eef1f5);
}

.pos-workspace {
  position: relative;
  flex: 1 1 auto;
  width: 100%;
  max-width: 100%;
  min-width: 0;
  min-height: 0;
  display: grid;
  grid-template-columns: minmax(0, 1fr) clamp(20rem, 28vw, 24.5rem);
  gap: 0.85rem;
  overflow: hidden;
  margin-top: 0.25rem;
  padding: 0.15rem 0.15rem 0.35rem;
  background: transparent;
}

.pos-main {
  display: flex;
  flex-direction: column;
  min-width: 0;
  max-width: 100%;
  min-height: 0;
  overflow: hidden;
  padding: 0.95rem 1.05rem 0.55rem;
  background: var(--color-canvas, #eef1f5);
  border: 1px solid var(--color-border, #dbe3ea);
  border-radius: 18px;
}

.pos-held {
  flex-shrink: 0;
  margin-bottom: 0.85rem;
}

.pos-held__head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 0.75rem;
  margin-bottom: 0.55rem;
}

.pos-held__head h2 {
  margin: 0;
  font-family: var(--font-display, var(--font-brand, inherit));
  font-size: 1.05rem;
  font-weight: 750;
  letter-spacing: -0.02em;
  color: var(--color-text-primary);
}

.pos-held__link {
  font-size: 0.78rem;
  font-weight: 650;
  color: var(--color-brand-600, #12243c);
  text-decoration: none;
}

.pos-held__row {
  display: flex;
  gap: 0.65rem;
  overflow-x: auto;
  padding-bottom: 0.15rem;
  scrollbar-width: thin;
}

.pos-held__card {
  flex: 0 0 auto;
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 1rem;
  min-width: 15.5rem;
  padding: 0.85rem 0.95rem;
  border: 1px solid var(--color-border, #dbe3ea);
  border-radius: 14px;
  background: var(--color-surface, #fff);
  text-align: left;
  cursor: pointer;
  box-shadow: 0 2px 8px rgba(18, 36, 60, 0.04);
}

.pos-held__card--live {
  border-color: color-mix(in srgb, var(--color-accent, #e39b2b) 45%, var(--color-border));
  box-shadow: 0 6px 16px rgba(227, 155, 43, 0.12);
}

.pos-held__copy {
  display: flex;
  flex-direction: column;
  gap: 0.15rem;
  min-width: 0;
}

.pos-held__copy strong {
  font-size: 0.88rem;
  font-weight: 750;
  color: var(--color-text-primary);
}

.pos-held__copy span {
  font-size: 0.72rem;
  color: var(--color-text-faint);
}

.pos-held__copy em {
  margin-top: 0.15rem;
  font-style: normal;
  font-size: 0.92rem;
  font-weight: 750;
  color: var(--color-brand-600, #12243c);
}

.pos-held__ring {
  width: 2.2rem;
  height: 2.2rem;
  display: grid;
  place-items: center;
  border-radius: 999px;
  background: color-mix(in srgb, var(--color-accent, #e39b2b) 18%, transparent);
  color: var(--color-accent, #e39b2b);
  font-size: 0.7rem;
  flex-shrink: 0;
}

.pos-held__ring--muted {
  background: var(--color-canvas, #eef1f5);
  color: #94a3b8;
}

.pos-catalog-head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 0.85rem;
  flex-wrap: wrap;
  margin-bottom: 0.65rem;
}

.pos-catalog-head__title {
  display: flex;
  align-items: center;
  gap: 0.45rem;
}

.pos-catalog-head__title h2 {
  margin: 0;
  font-family: var(--font-display, var(--font-brand, inherit));
  font-size: 1.05rem;
  font-weight: 750;
  letter-spacing: -0.02em;
  color: var(--color-text-primary);
}

.pos-catalog-head__tools {
  display: flex;
  align-items: center;
  gap: 0.55rem;
  flex: 1 1 18rem;
  min-width: 0;
  justify-content: flex-end;
}

.pos-location-card {
  display: grid;
  gap: 0.55rem;
  width: min(100%, 42rem);
  margin: 0.55rem 0 0.7rem;
  padding: 0.85rem 0.95rem;
  border: 1px solid var(--color-border, #dbe3ea);
  border-radius: 14px;
  background: var(--color-surface, #fff);
  box-shadow: 0 2px 8px rgba(18, 36, 60, 0.04);
}

.pos-location-card__head {
  display: flex;
  align-items: center;
  gap: 0.45rem;
  font-size: 0.92rem;
}

.pos-location-picks {
  display: flex;
  flex-wrap: wrap;
  gap: 0.5rem;
}

.pos-location-pick {
  display: inline-flex;
  align-items: center;
  gap: 0.4rem;
  min-height: 2.6rem;
  padding: 0.45rem 0.8rem;
  border: 1px solid var(--color-border, #dbe3ea);
  border-radius: 0.85rem;
  background: var(--color-surface, #fff);
  box-shadow: var(--shadow-md);
  color: inherit;
  font-weight: 700;
  cursor: pointer;
}

.pos-location-pick:hover {
  box-shadow: var(--shadow-lg);
  transform: translateY(-1px);
}

.pos-location-pick--selected {
  border-color: var(--color-brand-600, #0b6e4f);
  background: color-mix(in srgb, var(--color-brand-600, #0b6e4f) 12%, var(--color-surface, #fff));
}

.pos-delivery__hint {
  grid-column: 1 / -1;
  margin: 0;
  color: var(--color-text-secondary);
  font-size: 0.78rem;
}

.pos-delivery__hint--alone {
  margin: -0.35rem 0 0.7rem;
}

.pos-refresh {
  flex-shrink: 0;
  width: 2.1rem;
  height: 2.1rem;
  display: grid;
  place-items: center;
  border: 1px solid var(--color-border, #dbe3ea);
  border-radius: 999px;
  background: var(--color-surface);
  color: var(--color-text-secondary);
  cursor: pointer;
}

.pos-refresh:hover {
  border-color: var(--color-brand-300, #a3b7c8);
  color: var(--color-ink-brand, var(--color-brand-700));}

.pos-cart-toggle {
  display: none;
  align-items: center;
  gap: 0.4rem;
  flex-shrink: 0;
  border: 1px solid #cbd5e1;
  border-radius: 0.65rem;
  padding: 0 0.85rem;
  height: 2.65rem;
  background: var(--color-surface);
  color: var(--color-text-primary);
  font-size: 0.82rem;
  font-weight: 700;
  cursor: pointer;}
.pos-cart-toggle em {
  min-width: 1.35rem;
  padding: 0.1rem 0.4rem;
  border-radius: 999px;
  background: var(--color-brand-600);
  color: #fff;
  font-style: normal;
  font-size: 0.72rem;
  text-align: center;
}
.pos-cart-toggle--open {
  border-color: var(--color-brand-600);
  background: var(--color-brand-600);
  color: #fff;
}
.pos-cart-toggle--open em {
  background: rgba(255, 255, 255, 0.2);
}

.pos-side {
  display: flex;
  flex-direction: column;
  position: relative;
  z-index: 2;
  width: 100%;
  min-width: 0;
  min-height: 0;
  overflow: hidden;
  border: 1px solid var(--color-border, #dbe3ea);
  border-radius: 18px;
  background: var(--color-surface, #fff);
  box-shadow: 0 4px 18px rgba(18, 36, 60, 0.05);
}

.pos-cart-backdrop {
  display: none;
}

@media (max-width: 1100px) {
  .pos-workspace {
    grid-template-columns: minmax(0, 1fr) minmax(18rem, 21rem);
  }
}

@media (max-width: 900px) {
  .pos-cart-toggle {
    display: inline-flex;
  }
  .pos-location-card {
    width: 100%;
  }
  .pos-cart-toggle span {
    display: none;
  }
  .pos-workspace {
    grid-template-columns: minmax(0, 1fr);
  }
  .pos-side {
    position: absolute;
    inset: 0 0 0 auto;
    z-index: 50;
    width: min(22rem, 92%);
    transform: translateX(110%);
    transition: transform 320ms var(--ease-emphasized);
    pointer-events: none;
    box-shadow: -12px 0 28px rgba(15, 23, 42, 0.16);
  }
  .pos-workspace--cart-open .pos-side,
  .pos-side--cart-open {
    transform: none;
    pointer-events: auto;
  }
  .pos-cart-backdrop {
    display: block;
    position: absolute;
    inset: 0;
    z-index: 40;
    border: 0;
    background: rgba(15, 23, 42, 0.38);
    cursor: pointer;
    animation: pos-backdrop-in var(--motion-page) var(--ease-out);
  }

  @keyframes pos-backdrop-in {
    from { opacity: 0; }
    to { opacity: 1; }
  }
  .pos-side :deep(.pos-cart) {
    position: static;
    transform: none;
    width: 100%;
    pointer-events: auto;
    box-shadow: none;
  }
}
.pos-shift-gate {
  position: absolute;
  inset: 0;
  z-index: 40;
}
.pos-loading,
.pos-error,
.pos-empty-store {
  flex: 1;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  color: var(--color-text-muted);
  gap: 0.75rem;
  margin: 0.75rem;
  border-radius: var(--radius-lg);
  background: var(--color-surface);
  border: 1px dashed #dbe3ea;}
.pos-retry {
  padding: 0.5rem 1rem;
  border-radius: 0.5rem;
  background: var(--color-brand-600, var(--color-brand-600));
  color: white;
  border: none;
  cursor: pointer;
}
.pos-toast {
  position: fixed;
  bottom: 6.5rem;
  left: 50%;
  transform: translateX(-50%);
  background: var(--color-inverse);
  color: white;
  padding: 0.625rem 1.25rem;
  border-radius: 0.5rem;
  font-size: 0.875rem;
  z-index: 200;
  box-shadow: 0 8px 24px rgba(0, 0, 0, 0.2);
  max-width: min(90vw, 36rem);
  text-align: center;}
.pos-toast--error {
  background: #b91c1c;
}
.pos-option-form { display: flex; flex-direction: column; gap: 0.85rem; }
.pos-option-hint { margin: 0; font-size: 0.85rem; color: var(--color-text-muted);}
.pos-option-empty { margin: 0; font-size: 0.85rem; color: light-dark(#b45309, #d49b70);}
.pos-option-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(min(100%, 11rem), 1fr)); gap: 0.55rem; max-height: 22rem; overflow: auto; }
.pos-option-card {
  display: flex; flex-direction: column; align-items: flex-start; gap: 0.15rem;
  padding: 0.75rem 0.8rem; border-radius: 0.75rem; border: 1px solid #dbe3ea;
  background: var(--color-surface); text-align: left; cursor: pointer;}
.pos-option-card--active { border-color: var(--color-brand-600); background: var(--color-brand-600); color: #fff; }
.pos-option-card__label { font-weight: 650; }
.pos-option-card__meta { font-size: 0.72rem; opacity: 0.75; }
.pos-option-card__price { margin-top: 0.25rem; font-weight: 650; color: #e39b2b; }
.pos-option-card--active .pos-option-card__price { color: #fff; }
.pos-option-qty { display: flex; align-items: center; justify-content: space-between; gap: 1rem; }
.pos-option-qty__controls { display: flex; align-items: center; gap: 0.4rem; }
.pos-option-qty__controls button,
.pos-option-qty__controls input {
  height: 2.4rem; border: 1px solid #cbd5e1; border-radius: 0.5rem; background: var(--color-surface);}
.pos-option-qty__controls button { width: 2.4rem; font-size: 1.1rem; }
.pos-option-qty__controls input { width: 4rem; text-align: center; }
.pos-option-actions { display: flex; justify-content: flex-end; gap: 0.5rem; }
.pos-option-cancel { border: 1px solid #cbd5e1; border-radius: 0.5rem; padding: 0.55rem 1rem; background: var(--color-surface);}
.pos-option-add { border: 0; border-radius: 0.5rem; padding: 0.55rem 1rem; background: var(--color-brand-600); color: #fff; font-weight: 600; }
.pos-option-add:disabled { opacity: 0.5; }

.pos-table-picker__hint {
  margin: 0 0 0.85rem;
  font-size: 0.88rem;
  color: var(--color-text-muted);
}

.pos-table-picker__error {
  margin: 0 0 0.75rem;
  padding: 0.55rem 0.75rem;
  border-radius: 10px;
  background: color-mix(in srgb, #dc2626 10%, transparent);
  color: #b91c1c;
  font-size: 0.84rem;
}

.pos-table-picker__loading,
.pos-table-picker__empty {
  margin: 0;
  padding: 1.5rem 0.5rem;
  text-align: center;
  color: var(--color-text-muted);
}

.pos-table-picker__empty p {
  margin: 0 0 0.75rem;
}

.pos-table-picker__link {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  min-height: 2.35rem;
  padding: 0 1rem;
  border-radius: 10px;
  background: var(--color-brand-600, #12243c);
  color: #fff;
  font-size: 0.84rem;
  font-weight: 700;
  text-decoration: none;
}

.pos-table-picker__grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(120px, 1fr));
  gap: 6px;
  max-height: min(58vh, 28rem);
  overflow: auto;
  padding: 2px;
}

.pos-table-picker__card {
  display: grid;
  gap: 1px;
  min-height: 0;
  padding: 0.4rem 0.55rem;
  border: 1px solid #e2e8f0;
  border-radius: 7px;
  background: var(--color-surface, #fff);
  text-align: left;
  font-size: 10.5px;
  line-height: 1.2;
  color: var(--color-text-secondary);
  cursor: pointer;
  transition: transform 160ms ease, box-shadow 160ms ease;
}

.pos-table-picker__card header {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  gap: 6px;
}

.pos-table-picker__card header strong {
  font-size: 11.5px;
  font-weight: 700;
  color: var(--color-text-primary);
}

.pos-table-picker__card :deep(.ui-badge) {
  font-size: 0.62rem;
  padding: 0.05rem 0.35rem;
}

.pos-table-picker__card p {
  margin: 0;
}

.pos-table-picker__meta {
  color: var(--color-text-secondary);
}

.pos-table-picker__sale {
  margin-top: 2px !important;
  font-weight: 600;
  color: var(--color-text-primary);
}

.pos-table-picker__total {
  font-size: 11px;
  font-weight: 700;
  color: var(--color-text-primary);
}

.pos-table-picker__card:hover:not(:disabled) {
  transform: translateY(-1px);
  box-shadow: 0 6px 14px rgba(18, 36, 60, 0.08);
}

.pos-table-picker__card--available {
  box-shadow: inset 4px 0 0 #059669;
}

.pos-table-picker__card--occupied {
  background: #fff7ed;
  border-color: #fdba74;
  box-shadow: inset 4px 0 0 #d97706;
  cursor: not-allowed;
}

.pos-table-picker__card--qr {
  animation: qr-wait 1.2s ease-in-out infinite;
}

@keyframes qr-wait {
  50% { box-shadow: inset 4px 0 0 #d97706; }
}

.pos-table-picker__card--reserved {
  box-shadow: inset 4px 0 0 #2563eb;
}

.pos-table-picker__card--cleaning,
.pos-table-picker__card--inactive {
  background: #f8fafc;
  box-shadow: inset 4px 0 0 #64748b;
  opacity: 0.72;
  cursor: not-allowed;
}

.pos-table-picker__card--locked:disabled {
  opacity: 1;
}

.pos-table-picker__card--occupied:disabled {
  opacity: 1;
}

.pos-table-picker__card--clear {
  border-style: dashed;
  background: var(--color-canvas, #eef1f5);
  box-shadow: none;
}

.pos-table-picker__card--active {
  border-color: var(--color-accent, #e39b2b);
  box-shadow:
    inset 4px 0 0 #059669,
    0 0 0 2px color-mix(in srgb, var(--color-accent, #e39b2b) 35%, transparent);
}
</style>
