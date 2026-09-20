<script setup lang="ts">
import { computed, onMounted, onUnmounted, ref, watch } from 'vue'
import { useI18n } from 'vue-i18n'
import { useRoute, useRouter } from 'vue-router'
import PageFrame from '../../../components/layout/PageFrame.vue'
import PosCartPanel from '../../../components/pos/PosCartPanel.vue'
import PosCategorySidebar from '../../../components/pos/PosCategorySidebar.vue'
import PosFooterPanel from '../../../components/pos/PosFooterPanel.vue'
import PosProductGrid from '../../../components/pos/PosProductGrid.vue'
import PosReturnSheet from '../../../components/pos/PosReturnSheet.vue'
import PosSearchBar from '../../../components/pos/PosSearchBar.vue'
import PosSessionGate from '../../../components/pos/PosSessionGate.vue'
import AppIcon from '../../../components/ui/AppIcon.vue'
import { openPrintWindow, printSaleDocument } from '../../../utils/printSaleDocument'
import { printZReport, type ZReportPayload } from '../../../utils/printZReport'
import { useContextStore } from '../../../stores/context'
import { usePosStore } from '../../../stores/pos'
import AppModal from '../../../components/ui/AppModal.vue'
import FieldLabel from '../../../components/ui/FieldLabel.vue'
import { formatMoney } from '../../../utils/money'
import { api } from '../../../api/client'
import type { PosProduct } from '../../../types/pos'
import { availableStock, needsSaleQuantity } from '../../../utils/product'

const { t } = useI18n()
const route = useRoute()
const router = useRouter()
const context = useContextStore()
const pos = usePosStore()

const showClose = ref(false)
const showOpen = ref(false)
const showReturn = ref(false)
const drawerAmount = ref('')
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
const qtyProduct = ref<PosProduct | null>(null)
const saleQty = ref(1)
const accompanimentHost = ref<{ product: PosProduct; lineId: string } | null>(null)
const selectedAccompanimentIds = ref<string[]>([])
const cartOpen = ref(false)
const orderMode = ref<'takeaway' | 'delivery'>('takeaway')

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
  pay: t('pos.pay'),
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

onMounted(async () => {
  window.addEventListener('keydown', onScanKey)
  window.addEventListener('resize', onViewportChange)
  await context.loadStores()
  if (context.currentStoreId) {
    await loadForStore(context.currentStoreId)
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
  if (needsSaleQuantity(product)) {
    qtyProduct.value = product
    saleQty.value = 1
    return
  }
  addHostProduct(product, 1)
}

function confirmQtySale() {
  if (!qtyProduct.value) return
  const quantity = Math.max(1, Math.trunc(Number(saleQty.value) || 0))
  const product = qtyProduct.value
  qtyProduct.value = null
  addHostProduct(product, quantity)
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
  payments: { method: string; amount: number; tendered?: number }[],
  done: (result: { success: boolean; message?: string }) => void,
) {
  void pos.pay(payments).then(async (result) => {
    const changeMsg = result.change > 0 ? ` — ${t('pos.change')}: ${formatChange(result.change)}` : ''
    const earned = result.loyalty?.earned ?? 0
    const pointsMsg = earned > 0 ? ` — ${t('pos.loyaltyEarned', { points: earned })}` : ''
    pos.setStatus(`${result.message}${changeMsg}${pointsMsg}`, !result.success)
    done({ success: result.success, message: result.message })
    if (!result.success) return
    kickDrawer()
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

async function openShift(payload: { pin: string; registerId: string; opening: number }) {
  if (!context.currentStoreId) return
  try {
    await pos.openShiftWithPin(context.currentStoreId, payload.pin, payload.registerId, payload.opening)
    showOpen.value = false
    pos.setStatus(t('pos.shiftOpened'))
  } catch (e) {
    pos.setStatus(e instanceof Error ? e.message : 'PIN refusé', true)
  }
}

async function moveCash(type: 'cash_in' | 'cash_out') {
  const amount = Math.round((Number(drawerAmount.value) || 0) * 100)
  if (amount < 1) return
  try {
    await pos.recordDrawerMovement(type, amount)
    drawerAmount.value = ''
    pos.setStatus(type === 'cash_in' ? t('pos.cashIn') : t('pos.cashOut'))
  } catch (e) {
    pos.setStatus(e instanceof Error ? e.message : 'Mouvement refusé', true)
  }
}

async function closeShift(payload: { pin: string; counted: number; notes: string; reason: string }) {
  if (!context.currentStoreId) return
  try {
    const report = await pos.closeShiftWithPin(context.currentStoreId, payload.pin, payload.counted, payload.notes, payload.reason)
    const popup = openPrintWindow()
    printZReport({
      ...(report as ZReportPayload),
      currency: pos.totals.currency,
    }, t('pos.zReport'), popup)
    showClose.value = false
    pos.setStatus(t('pos.shiftClosed'))
  } catch (e) {
    pos.setStatus(e instanceof Error ? e.message : 'Clôture refusée', true)
  }
}

async function redeemLoyalty() {
  if (!pos.customer) return
  const res = await api.get<{ data: { points: number; reward_per_point: number } }>(`/customers/${pos.customer.id}/loyalty`)
  const available = res.data.points ?? 0
  const perPoint = res.data.reward_per_point || 100
  const usable = Math.min(available, Math.floor(pos.totals.grand_total / perPoint))
  if (usable < 1) {
    pos.setStatus(available < 1 ? t('pos.loyaltyNone') : t('pos.loyaltyTooSmall'), true)
    return
  }
  pos.applyLoyaltyReward(usable, usable * perPoint)
  pos.setStatus(t('pos.loyaltyApplied', { points: usable, value: formatMoney(usable * perPoint) }))
}

function onReturnDone(message: string) {
  showReturn.value = false
  pos.setStatus(message)
  if (context.currentStoreId) void pos.loadSession(context.currentStoreId)
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
        <div class="pos-desk">
          <span v-if="pos.shift" class="pos-desk__meta">
            {{ pos.shift.cashier?.name }}
            · {{ t('pos.shiftSales') }}: {{ Number(pos.shiftSummary?.sales_count ?? 0) }}
            · {{ formatMoney(Number(pos.shiftSummary?.sales_total ?? 0)) }}
            · {{ t('pos.theoreticalCash') }}: {{ formatMoney(Number(pos.shiftSummary?.expected_cash ?? 0)) }}
          </span>
          <input v-model="drawerAmount" class="pos-desk__amount" type="number" min="0" step="0.01" :placeholder="t('pos.amount')" />
          <button type="button" :disabled="!pos.shift" @click="moveCash('cash_in')">{{ t('pos.cashIn') }}</button>
          <button type="button" :disabled="!pos.shift" @click="moveCash('cash_out')">{{ t('pos.cashOut') }}</button>
          <select v-model="pos.priceMode">
            <option value="retail">{{ t('pos.retail') }}</option>
            <option value="wholesale">{{ t('pos.wholesale') }}</option>
          </select>
          <select v-model="pos.currencyCode">
            <option v-for="item in pos.currencies" :key="item.code" :value="item.code">{{ item.code }}</option>
          </select>
          <button type="button" @click="kickDrawer">{{ t('pos.drawer') }}</button>
          <button type="button" :disabled="!pos.customer" @click="redeemLoyalty">{{ t('pos.loyalty') }}</button>
          <button type="button" :disabled="!pos.shift" @click="showReturn = !showReturn">{{ t('pos.refund') }}</button>
          <button v-if="!pos.shift" type="button" @click="showOpen = true">{{ t('pos.openShift') }}</button>
          <button type="button" :disabled="!pos.shift" @click="showClose = !showClose">{{ t('pos.closeShift') }}</button>
        </div>
        <PosSessionGate
          v-if="showClose && pos.shift"
          :open="true"
          :registers="pos.registers"
          :cashier-name="pos.shift.cashier?.name"
          :expected-cash="Number(pos.shiftSummary?.expected_cash ?? 0)"
          @close-shift="closeShift"
        />
        <PosReturnSheet
          v-if="showReturn && context.currentStoreId"
          :store-id="context.currentStoreId"
          :cash-register-id="pos.shift?.cash_register_id"
          @close="showReturn = false"
          @done="onReturnDone"
        />

        <div v-if="pos.activeTable" class="pos-table-banner">
          <strong>{{ pos.activeTable.name }}</strong>
          <span>{{ t('pointOfSale.tables.status.occupied') }}</span>
          <button type="button" class="btn-secondary" @click="router.push({ name: 'pos-tables' })">
            {{ t('nav.posTables') }}
          </button>
        </div>

        <div class="pos-workspace" :class="{ 'pos-workspace--cart-open': cartOpen }">
          <button
            v-if="cartOpen"
            type="button"
            class="pos-cart-backdrop"
            :aria-label="t('pos.cart')"
            @click="cartOpen = false"
          />

          <section class="pos-main">
            <div class="pos-toolbar">
              <PosSearchBar
                ref="searchRef"
                v-model="searchQuery"
                :placeholder="t('pos.searchProducts')"
                @submit="onSearchSubmit"
              />
              <div class="pos-order-mode" role="group" :aria-label="t('pos.orderMode')">
                <button
                  type="button"
                  class="pos-order-mode__btn"
                  :class="{ 'pos-order-mode__btn--active': orderMode === 'takeaway' }"
                  @click="orderMode = 'takeaway'"
                >
                  {{ t('pos.takeaway') }}
                </button>
                <button
                  type="button"
                  class="pos-order-mode__btn"
                  :class="{ 'pos-order-mode__btn--active': orderMode === 'delivery' }"
                  @click="orderMode = 'delivery'"
                >
                  {{ t('pos.delivery') }}
                </button>
              </div>
              <button
                type="button"
                class="pos-refresh"
                :title="t('pos.retry')"
                @click="loadForStore(context.currentStoreId!)"
              >
                <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.85" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
                  <polyline points="23 4 23 10 17 10" />
                  <polyline points="1 20 1 14 7 14" />
                  <path d="M3.51 9a9 9 0 0 1 14.85-3.36L23 10M1 14l4.64 4.36A9 9 0 0 0 20.49 15" />
                </svg>
              </button>
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

            <PosCategorySidebar
              v-if="!pos.loading && !pos.error"
              :categories="pos.categories"
              :selected-category-id="selectedCategoryId"
              :all-label="t('pos.allCategories')"
              :counts="categoryCounts"
              :total-count="pos.products.length"
              @select="selectedCategoryId = $event"
            />

            <div v-if="pos.loading" class="pos-loading">{{ t('common.loading') }}</div>
            <div v-else-if="pos.error" class="pos-error">
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
              @select="onAddProduct"
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
              @increment="pos.incrementQuantity"
              @decrement="pos.decrementQuantity"
              @quantity="pos.updateQuantity"
              @remove="pos.removeLine"
              @close="cartOpen = false"
              @select-customer="pos.setCustomer"
              @add-customer="footerRef?.openCreateCustomer()"
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
          :open="Boolean(qtyProduct)"
          :title="qtyProduct?.name ?? t('pos.quantityTitle')"
          icon="products"
          tone="info"
          size="sm"
          @close="qtyProduct = null"
        >
          <form class="space-y-3" @submit.prevent="confirmQtySale">
            <p class="text-sm text-slate-500">{{ t('pos.quantityHint') }}</p>
            <div>
              <FieldLabel icon="package">{{ t('beverages.quantity') }}</FieldLabel>
              <input v-model.number="saleQty" type="number" min="1" required class="w-full rounded-lg border border-slate-300 px-3 py-2" />
            </div>
            <div class="flex justify-end gap-2">
              <button type="button" class="rounded-lg border border-slate-300 px-4 py-2" @click="qtyProduct = null">{{ t('common.cancel') }}</button>
              <button type="submit" class="rounded-lg bg-[var(--color-brand-600)] px-4 py-2 text-white">{{ t('beverages.add') }}</button>
            </div>
          </form>
        </AppModal>

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
            <p v-else class="text-sm text-slate-500">{{ t('pos.noQuantity') }}</p>
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

        <PosSessionGate
          v-if="showOpen && !pos.shift"
          class="pos-shift-gate"
          :open="false"
          :registers="pos.registers"
          @open-shift="openShift"
          @dismiss="showOpen = false"
        />

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
  background: var(--color-canvas, #f4f6f9);
}
.pos-desk {
  display: flex;
  flex-wrap: nowrap;
  justify-content: flex-end;
  align-items: center;
  gap: 0.4rem;
  padding: 0.4rem 0.75rem 0;
  flex-shrink: 0;
  overflow-x: auto;
}
.pos-desk__meta {
  margin-right: auto;
  min-width: 0;
  max-width: 100%;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  font-size: 0.75rem;
  color: #64748b;
}
.pos-table-banner {
  display: flex;
  align-items: center;
  gap: 12px;
  margin: 8px 12px 0;
  padding: 8px 12px;
  min-height: 40px;
  border-radius: 8px;
  background: #fff;
  border: 1px solid #e2e8f0;
  font-size: 13px;
}
.pos-table-banner strong {
  font-size: 14px;
}
.pos-desk__amount { width: 6.5rem; border: 1px solid #cbd5e1; border-radius: 0.45rem; padding: 0.3rem 0.45rem; }
.pos-desk select, .pos-desk button { border: 1px solid #cbd5e1; border-radius: 0.5rem; padding: 0.35rem 0.65rem; background: white; font-size: 0.8rem; }

.pos-workspace {
  position: relative;
  flex: 1 1 auto;
  min-height: 0;
  display: grid;
  grid-template-columns: minmax(0, 1fr) minmax(20rem, 23rem);
  overflow: hidden;
  margin-top: 0.45rem;
  background: #fff;
  border-top: 1px solid var(--color-border, #e7edf3);
}

.pos-main {
  display: flex;
  flex-direction: column;
  min-width: 0;
  min-height: 0;
  padding: 0.85rem 1rem 0.5rem;
  background: var(--color-canvas, #f7f8fb);
}

.pos-toolbar {
  display: flex;
  align-items: center;
  gap: 0.55rem;
  flex-shrink: 0;
  margin-bottom: 0.7rem;
}

.pos-order-mode {
  display: inline-flex;
  flex-shrink: 0;
  gap: 0.35rem;
}

.pos-order-mode__btn {
  border: 1px solid var(--color-border, #dbe3ea);
  border-radius: 0.75rem;
  padding: 0.7rem 1rem;
  background: #fff;
  color: var(--color-text-secondary, #475569);
  font-size: 0.84rem;
  font-weight: 700;
  cursor: pointer;
  white-space: nowrap;
}

.pos-order-mode__btn--active {
  background: #0f172a;
  border-color: #0f172a;
  color: #fff;
}

.pos-refresh {
  flex-shrink: 0;
  width: 2.65rem;
  height: 2.65rem;
  display: grid;
  place-items: center;
  border: 1px solid var(--color-border, #dbe3ea);
  border-radius: 0.75rem;
  background: #fff;
  color: var(--color-text-secondary, #475569);
  cursor: pointer;
}

.pos-refresh:hover {
  border-color: var(--color-brand-300, #c4b5fd);
  color: var(--color-brand-700);
}

.pos-cart-toggle {
  display: none;
  align-items: center;
  gap: 0.4rem;
  flex-shrink: 0;
  border: 1px solid #cbd5e1;
  border-radius: 0.65rem;
  padding: 0 0.85rem;
  height: 2.65rem;
  background: #fff;
  color: #1c2830;
  font-size: 0.82rem;
  font-weight: 700;
  cursor: pointer;
}
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
  min-width: 0;
  min-height: 0;
  border-left: 1px solid var(--color-border, #e7edf3);
  background: #fff;
}

.pos-cart-backdrop {
  display: none;
}

@media (max-width: 1100px) {
  .pos-workspace {
    grid-template-columns: minmax(0, 1fr) minmax(18rem, 20.5rem);
  }
  .pos-order-mode__btn {
    padding: 0.65rem 0.75rem;
    font-size: 0.78rem;
  }
}

@media (max-width: 900px) {
  .pos-desk__meta {
    display: none;
  }
  .pos-desk__amount {
    width: 5.25rem;
  }
  .pos-cart-toggle {
    display: inline-flex;
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
    transition: transform 0.2s ease;
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
  color: #64748b;
  gap: 0.75rem;
  margin: 0.75rem;
  border-radius: 1rem;
  background: #fff;
  border: 1px dashed #dbe3ea;
}
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
  background: #0f172a;
  color: white;
  padding: 0.625rem 1.25rem;
  border-radius: 0.5rem;
  font-size: 0.875rem;
  z-index: 200;
  box-shadow: 0 8px 24px rgba(0, 0, 0, 0.2);
  max-width: min(90vw, 36rem);
  text-align: center;
}
.pos-toast--error {
  background: #b91c1c;
}
.pos-option-form { display: flex; flex-direction: column; gap: 0.85rem; }
.pos-option-hint { margin: 0; font-size: 0.85rem; color: #64748b; }
.pos-option-empty { margin: 0; font-size: 0.85rem; color: #b45309; }
.pos-option-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(min(100%, 11rem), 1fr)); gap: 0.55rem; max-height: 22rem; overflow: auto; }
.pos-option-card {
  display: flex; flex-direction: column; align-items: flex-start; gap: 0.15rem;
  padding: 0.75rem 0.8rem; border-radius: 0.75rem; border: 1px solid #dbe3ea;
  background: #fff; text-align: left; cursor: pointer;
}
.pos-option-card--active { border-color: var(--color-brand-600); background: var(--color-brand-600); color: #fff; }
.pos-option-card__label { font-weight: 650; }
.pos-option-card__meta { font-size: 0.72rem; opacity: 0.75; }
.pos-option-card__price { margin-top: 0.25rem; font-weight: 650; color: #e39b2b; }
.pos-option-card--active .pos-option-card__price { color: #fff; }
.pos-option-qty { display: flex; align-items: center; justify-content: space-between; gap: 1rem; }
.pos-option-qty__controls { display: flex; align-items: center; gap: 0.4rem; }
.pos-option-qty__controls button,
.pos-option-qty__controls input {
  height: 2.4rem; border: 1px solid #cbd5e1; border-radius: 0.5rem; background: #fff;
}
.pos-option-qty__controls button { width: 2.4rem; font-size: 1.1rem; }
.pos-option-qty__controls input { width: 4rem; text-align: center; }
.pos-option-actions { display: flex; justify-content: flex-end; gap: 0.5rem; }
.pos-option-cancel { border: 1px solid #cbd5e1; border-radius: 0.5rem; padding: 0.55rem 1rem; background: #fff; }
.pos-option-add { border: 0; border-radius: 0.5rem; padding: 0.55rem 1rem; background: var(--color-brand-600); color: #fff; font-weight: 600; }
.pos-option-add:disabled { opacity: 0.5; }
</style>
