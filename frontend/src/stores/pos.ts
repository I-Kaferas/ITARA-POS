import { defineStore } from 'pinia'
import { computed, ref, watch } from 'vue'
import { api, extractApiErrorMessage, type ApiItemResponse, type ApiListResponse } from '../api/client'
import type {
  CartCalculation,
  CartDiscountPayload,
  PosCartLine,
  PosCategory,
  PosCustomerOption,
  PosHeldSale,
  PosPaymentMethod,
  PosProduct,
} from '../types/pos'
import type { CashierShift, CashRegister, ShiftSummary } from '../types'
import { getAppCurrency } from '../utils/currency'
import { needsSaleQuantity, cartLineStockUnits, catalogOnHand } from '../utils/product'
import type { SaleDocPayload } from '../utils/printSaleDocument'

function emptyTotals(currency = getAppCurrency()): CartCalculation {
  return {
    currency,
    subtotal: 0,
    line_discounts_total: 0,
    promotion_discounts_total: 0,
    global_discount_total: 0,
    discount_total: 0,
    tax_total: 0,
    fees_total: 0,
    grand_total: 0,
    lines: [],
    fees: [],
    promotions: [],
  }
}

export const usePosStore = defineStore('pos', () => {
  const products = ref<PosProduct[]>([])
  const categories = ref<PosCategory[]>([])
  const lines = ref<PosCartLine[]>([])
  const heldSales = ref<PosHeldSale[]>([])
  const totals = ref<CartCalculation>(emptyTotals())
  const customer = ref<PosCustomerOption | null>(null)
  const note = ref<string | null>(null)
  const globalDiscount = ref<CartDiscountPayload | null>(null)
  const loyaltyPoints = ref(0)
  const fees = ref<{ label: string; amount: number; code?: string }[]>([])

  const loading = ref(false)
  const calculating = ref(false)
  const error = ref<string | null>(null)
  const statusMessage = ref<string | null>(null)
  const statusIsError = ref(false)
  const heldCounter = ref(0)
  const pendingSaleId = ref<string | null>(null)
  const activeTable = ref<{ id: string; name: string; code?: string } | null>(null)
  const currentStoreId = ref<string | null>(null)
  const activeRegisterId = ref<string | null>(null)
  const paymentMethods = ref<PosPaymentMethod[]>([])
  const shift = ref<CashierShift | null>(null)
  const shiftSummary = ref<ShiftSummary | null>(null)
  const registers = ref<Array<{ id: string; name: string; code?: string }>>([])
  const priceMode = ref('retail')
  const currencyCode = ref(getAppCurrency())
  const currencies = computed(() => [{ code: currencyCode.value }])

  watch(
    () => getAppCurrency(),
    (code) => {
      if (currencyCode.value === code) return
      currencyCode.value = code
      if (!lines.value.length) {
        totals.value = emptyTotals(code)
      }
    },
  )

  let calculateTimer: ReturnType<typeof setTimeout> | null = null
  let calculateRequestId = 0

  const isEmpty = computed(() => lines.value.length === 0)
  const itemCount = computed(() => lines.value.reduce((sum, line) => sum + line.quantity, 0))
  const availablePaymentMethods = computed(() => paymentMethods.value)

  function setStatus(message: string, isError = false) {
    statusMessage.value = message
    statusIsError.value = isError
    setTimeout(() => {
      if (statusMessage.value === message) {
        statusMessage.value = null
        statusIsError.value = false
      }
    }, isError ? 6000 : 2500)
  }

  function productMatchesBarcode(product: PosProduct, code: string): boolean {
    const normalized = code.trim()
    if (!normalized) return false
    if (product.barcode === normalized) return true
    return product.barcodes?.some(b => b.barcode === normalized) ?? false
  }

  async function loadActiveRegister(storeId: string) {
    try {
      const res = await api.get<ApiListResponse<CashRegister>>(`/stores/${storeId}/cash-registers`)
      const open = res.data.find(r => r.open_session)
      activeRegisterId.value = open?.id ?? null
    } catch {
      activeRegisterId.value = null
    }
  }

  async function loadPaymentMethods(storeId: string) {
    try {
      const res = await api.get<ApiListResponse<PosPaymentMethod>>(
        `/payments/methods?store_id=${storeId}&pos_only=1`,
      )
      paymentMethods.value = res.data ?? []
    } catch {
      paymentMethods.value = [
        { value: 'cash', label: 'Cash', label_fr: 'Espèces', requires_customer: false, supports_change: true },
        { value: 'mobile_money', label: 'Mobile Money', label_fr: 'Mobile Money', requires_customer: false, supports_change: false },
        { value: 'card', label: 'Card', label_fr: 'Carte', requires_customer: false, supports_change: false },
        { value: 'bank_transfer', label: 'Bank transfer', label_fr: 'Virement', requires_customer: false, supports_change: false },
        { value: 'credit', label: 'Credit', label_fr: 'Crédit', requires_customer: true, supports_change: false },
      ]
    }
  }

  async function fetchCatalog(storeId: string) {
    const res = await api.get<ApiItemResponse<{
      products: PosProduct[]
      categories: PosCategory[]
      registers?: Array<{ id: string; name: string; code?: string }>
    }>>(
      `/stores/${storeId}/pos/catalog`,
    )
    products.value = res.data.products ?? []
    categories.value = res.data.categories ?? []
    const catalogRegisters = res.data.registers
    if (Array.isArray(catalogRegisters) && catalogRegisters.length) {
      registers.value = catalogRegisters.map(item => ({
        id: item.id,
        name: item.name,
        code: item.code,
      }))
    }
  }

  function applyLocalStockDelta(soldLines: PosCartLine[]) {
    const deltas = new Map<string, number>()
    for (const line of soldLines) {
      if (line.isAccompaniment) continue
      if (line.product.requires_stock === false) continue
      if (!needsSaleQuantity(line.product)) continue
      const saleUnit = line.product.sale_units?.find(unit => unit.id === line.saleUnitId)
      const unit = saleUnit?.volume_ml && saleUnit.volume_ml > 0 ? saleUnit.volume_ml : 1
      deltas.set(line.product.product_id, (deltas.get(line.product.product_id) ?? 0) + line.quantity * unit)
    }
    if (!deltas.size) return

    products.value = products.value.map((product) => {
      const delta = deltas.get(product.product_id)
      if (!delta) return product
      const current = Number(product.quantity_on_hand)
      if (!Number.isFinite(current)) return product
      const next = Math.max(0, current - delta)
      const unitLabel = typeof product.stock_display === 'string'
        ? product.stock_display.replace(/^\d+(\.\d+)?\s*/, '').trim()
        : ''
      return {
        ...product,
        quantity_on_hand: next,
        stock_display: unitLabel ? `${next} ${unitLabel}` : String(next),
      }
    })
  }

  async function loadCatalog(storeId: string) {
    currentStoreId.value = storeId
    loading.value = true
    error.value = null
    try {
      await fetchCatalog(storeId)
      loading.value = false
      void Promise.all([
        loadActiveRegister(storeId),
        loadPaymentMethods(storeId),
        loadSession(storeId),
      ]).catch(() => undefined)
    } catch (e) {
      error.value = e instanceof Error ? e.message : 'Erreur catalogue'
      throw e
    } finally {
      loading.value = false
    }
  }

  async function searchCustomers(query: string): Promise<PosCustomerOption[]> {
    const q = encodeURIComponent(query.trim())
    if (!q) return []
    const res = await api.get<ApiListResponse<PosCustomerOption>>(
      `/customers?search=${q}&active_only=1&per_page=20`,
    )
    return res.data
  }

  async function createCustomer(payload: {
    name: string
    phone?: string
    email?: string
  }): Promise<PosCustomerOption> {
    const res = await api.post<ApiItemResponse<PosCustomerOption>>('/customers', {
      ...payload,
      is_active: true,
    })

    return {
      id: res.data.id,
      name: res.data.name,
      email: res.data.email ?? null,
      phone: res.data.phone ?? null,
    }
  }

  async function lookupBarcode(storeId: string, code: string): Promise<PosProduct | null> {
    const local = products.value.find(p => productMatchesBarcode(p, code))
    if (local) return local

    try {
      const res = await api.get<{ found: boolean; data?: { product?: { sku?: string } } }>(
        `/barcodes/lookup?code=${encodeURIComponent(code)}&store_id=${storeId}`,
      )
      if (!res.found || !res.data?.product?.sku) return null
      return products.value.find(p => p.sku === res.data!.product!.sku) ?? null
    } catch {
      return null
    }
  }

  function addProduct(
    product: PosProduct,
    quantity = 1,
    saleUnitId?: string,
    variantId?: string,
    options?: { isAccompaniment?: boolean; parentLineId?: string },
  ) {
    const qty = needsSaleQuantity(product) ? Math.max(1, Math.trunc(quantity) || 1) : 1
    const catalogProduct = products.value.find(item => item.product_id === product.product_id) ?? product

    if (needsSaleQuantity(catalogProduct) && !options?.isAccompaniment) {
      const onHand = catalogOnHand(catalogProduct)
      if (onHand !== null) {
        const existingLine = lines.value.find(line =>
          line.product.product_id === product.product_id
          && line.saleUnitId === saleUnitId
          && line.variantId === variantId
          && !line.isAccompaniment
          && (line.parentLineId ?? '') === (options?.parentLineId ?? ''),
        )
        const lineUnits = existingLine
          ? cartLineStockUnits(existingLine.product, existingLine.quantity, existingLine.saleUnitId)
          : 0
        const reserved = cartReservedByProductId.value[product.product_id] ?? 0
        const free = onHand - (reserved - lineUnits)
        const nextUnits = lineUnits + cartLineStockUnits(catalogProduct, qty, saleUnitId)
        if (free <= 0 || nextUnits > free) {
          setStatus(free <= 0 ? 'Stock insuffisant — article en rupture' : `Stock insuffisant (disponible: ${Math.max(0, free)})`, true)
          return null
        }
      }
    }

    const unit = product.sale_units?.find(item => item.id === saleUnitId)
    const variant = product.variants?.find(item => item.variant_id === variantId)
    const isAccompaniment = Boolean(options?.isAccompaniment)
    const priced: PosProduct = unit
      ? { ...product, name: `${product.name} · ${unit.name}`, price: unit.price }
      : variant
        ? { ...product, name: `${product.name} · ${variant.label || variant.name}`, price: variant.price, sku: variant.sku }
        : isAccompaniment
          ? { ...product, price: 0 }
          : product
    const existing = lines.value.find(line =>
      line.product.product_id === product.product_id
      && line.saleUnitId === saleUnitId
      && line.variantId === variantId
      && Boolean(line.isAccompaniment) === isAccompaniment
      && (line.parentLineId ?? '') === (options?.parentLineId ?? ''),
    )
    if (existing) {
      if (needsSaleQuantity(product)) {
        const nextQty = existing.quantity + qty
        lines.value = lines.value.map(line =>
          line.lineId === existing.lineId ? { ...line, quantity: nextQty } : line,
        )
        scheduleCalculate()
        return lines.value.find(line => line.lineId === existing.lineId) ?? existing
      }
      scheduleCalculate()
      return existing
    }
    const line: PosCartLine = {
      lineId: `${product.product_id}-${saleUnitId ?? variantId ?? 'base'}-${Date.now()}`,
      product: priced,
      quantity: qty,
      saleUnitId,
      variantId,
      isAccompaniment,
      parentLineId: options?.parentLineId,
    }
    lines.value = [...lines.value, line]
    scheduleCalculate()
    return line
  }

  function addAccompaniments(parent: PosCartLine, accompanimentIds: string[]) {
    for (const id of accompanimentIds) {
      const side = products.value.find(item => item.product_id === id)
      if (!side) continue
      addProduct(side, parent.quantity, undefined, undefined, {
        isAccompaniment: true,
        parentLineId: parent.lineId,
      })
    }
  }

  function removeLine(lineId: string) {
    lines.value = lines.value.filter(line => line.lineId !== lineId && line.parentLineId !== lineId)
    scheduleCalculate()
  }

  function updateQuantity(lineId: string, quantity: number) {
    const line = lines.value.find(l => l.lineId === lineId)
    if (!line) return
    if (!needsSaleQuantity(line.product)) return
    const nextQty = quantity < 1 ? 1 : Math.trunc(quantity)
    if (!line.isAccompaniment) {
      const catalogProduct = products.value.find(item => item.product_id === line.product.product_id) ?? line.product
      const onHand = catalogOnHand(catalogProduct)
      if (onHand !== null) {
        const lineUnits = cartLineStockUnits(line.product, line.quantity, line.saleUnitId)
        const reserved = cartReservedByProductId.value[line.product.product_id] ?? 0
        const free = onHand - (reserved - lineUnits)
        const nextUnits = cartLineStockUnits(line.product, nextQty, line.saleUnitId)
        if (nextUnits > free) {
          setStatus(`Stock insuffisant (disponible: ${Math.max(0, free)})`, true)
          return
        }
      }
    }
    lines.value = lines.value.map(item => {
      if (item.lineId === lineId || item.parentLineId === lineId) {
        return { ...item, quantity: nextQty }
      }
      return item
    })
    scheduleCalculate()
  }

  function incrementQuantity(lineId: string) {
    const line = lines.value.find(l => l.lineId === lineId)
    if (line) updateQuantity(lineId, line.quantity + 1)
  }

  function decrementQuantity(lineId: string) {
    const line = lines.value.find(l => l.lineId === lineId)
    if (line) updateQuantity(lineId, line.quantity - 1)
  }

  function setCustomer(value: PosCustomerOption | null) {
    if (loyaltyPoints.value > 0) globalDiscount.value = null
    customer.value = value
    loyaltyPoints.value = 0
    scheduleCalculate()
  }

  function setNote(value: string | null) {
    note.value = value?.trim() || null
  }

  function setGlobalDiscount(value: CartDiscountPayload | null) {
    globalDiscount.value = value
    loyaltyPoints.value = 0
    scheduleCalculate()
  }

  function applyLoyaltyReward(points: number, amount: number) {
    loyaltyPoints.value = points
    globalDiscount.value = points > 0 ? { type: 'fixed', value: amount } : null
    scheduleCalculate()
  }

  function clearDiscount() {
    globalDiscount.value = null
    loyaltyPoints.value = 0
    scheduleCalculate()
  }

  function scheduleCalculate() {
    if (!currentStoreId.value) return

    if (calculateTimer) clearTimeout(calculateTimer)
    calculateTimer = setTimeout(() => {
      void recalculate(currentStoreId.value!)
    }, 200)
  }

  async function recalculate(storeId?: string) {
    const activeStoreId = storeId ?? currentStoreId.value
    if (!activeStoreId) return

    const requestId = ++calculateRequestId

    if (lines.value.length === 0) {
      if (requestId === calculateRequestId) {
        totals.value = emptyTotals(currencyCode.value || getAppCurrency())
        calculating.value = false
      }
      return
    }

    calculating.value = true

    try {
      const payload = {
        customer_id: customer.value?.id ?? undefined,
        apply_promotions: true,
        items: lines.value.map(line => ({
          line_id: line.lineId,
          product_id: line.product.product_id,
          product_variant_id: line.variantId,
          sale_unit_id: line.saleUnitId,
          quantity: line.quantity,
          ...(line.isAccompaniment ? { unit_price: 0, is_accompaniment: true } : {}),
          line_discount: line.lineDiscountFixed
            ? { type: 'fixed' as const, value: line.lineDiscountFixed }
            : undefined,
        })),
        global_discount: globalDiscount.value ?? undefined,
        fees: fees.value,
      }

      const res = await api.post<ApiItemResponse<CartCalculation>>(
        `/stores/${activeStoreId}/cart/calculate`,
        payload,
      )

      if (requestId === calculateRequestId) {
        totals.value = res.data
      }
    } catch (e) {
      if (requestId === calculateRequestId) {
        setStatus(e instanceof Error ? e.message : 'Erreur calcul panier')
      }
    } finally {
      if (requestId === calculateRequestId) {
        calculating.value = false
      }
    }
  }

  function cartPayload() {
    return {
      customer_id: customer.value?.id ?? undefined,
      cash_register_id: activeRegisterId.value ?? undefined,
      notes: note.value ?? undefined,
      apply_promotions: true,
      table_id: activeTable.value?.id ?? undefined,
      items: lines.value.map(line => ({
        line_id: line.lineId,
        product_id: line.product.product_id,
        product_variant_id: line.variantId,
        sale_unit_id: line.saleUnitId,
        quantity: line.quantity,
        ...(line.isAccompaniment ? { unit_price: 0, is_accompaniment: true } : {}),
        line_discount: line.lineDiscountFixed
          ? { type: 'fixed' as const, value: line.lineDiscountFixed }
          : undefined,
      })),
      global_discount: globalDiscount.value ?? undefined,
      fees: fees.value,
    }
  }

  async function refreshHeldSales(storeId?: string) {
    const activeStoreId = storeId ?? currentStoreId.value
    if (!activeStoreId) {
      heldSales.value = []
      return
    }

    const res = await api.get<ApiListResponse<{
      id: string
      reference: string
      created_at?: string
      customer?: { id: string; name: string } | null
    }>>(`/stores/${activeStoreId}/sales?status=pending&limit=50`)

    heldSales.value = (res.data ?? []).map(sale => ({
      id: sale.id,
      label: sale.reference,
      heldAt: sale.created_at ?? new Date().toISOString(),
      lines: [],
      customerId: sale.customer?.id ?? null,
      customerName: sale.customer?.name ?? null,
      note: null,
      globalDiscount: null,
      fees: [],
    }))
  }

  async function holdSale(): Promise<string> {
    if (lines.value.length === 0 && !activeTable.value) throw new Error('Panier vide')

    const storeId = currentStoreId.value
    if (!storeId) throw new Error('Aucun magasin sélectionné')

    const payload = cartPayload()
    const saved = pendingSaleId.value
      ? (await api.put<ApiItemResponse<{ id: string; reference: string }>>(`/sales/${pendingSaleId.value}`, payload)).data
      : (await api.post<ApiItemResponse<{ id: string; reference: string }>>(`/stores/${storeId}/sales/holds`, payload)).data

    const label = saved.reference
    pendingSaleId.value = null
    activeTable.value = null
    clearCurrentSale(false)
    await refreshHeldSales(storeId)
    setStatus(`Commande mise en attente: ${label}`)
    return label
  }

  async function retrieveSale(heldSaleId: string) {
    if (lines.value.length > 0) {
      throw new Error('Videz ou mettez en attente la vente en cours')
    }

    const sale = (await api.get<ApiItemResponse<{
      id: string
      reference: string
      status: string
      notes?: string | null
      table_id?: string | null
      table?: { id: string; name: string; code?: string } | null
      customer?: { id: string; name: string } | null
      items?: {
        id: string
        product_id?: string | null
        product_name?: string | null
        product_sku?: string | null
        quantity: number
        unit_price: number
      }[]
      discounts?: { sale_item_id?: string | null; discount_type?: string; amount: number }[]
    }>>(`/sales/${heldSaleId}`)).data

    if (sale.status !== 'pending') {
      throw new Error('Cette commande n’est plus modifiable')
    }

    pendingSaleId.value = sale.id
    activeTable.value = sale.table
      ? { id: sale.table.id, name: sale.table.name, code: sale.table.code }
      : (sale.table_id ? { id: sale.table_id, name: sale.reference } : null)
    customer.value = sale.customer
      ? { id: sale.customer.id, name: sale.customer.name }
      : null
    note.value = sale.notes ?? null

    const discounts = sale.discounts ?? []
    const globalAmount = discounts
      .filter(discount => discount.discount_type === 'global')
      .reduce((sum, discount) => sum + discount.amount, 0)
    globalDiscount.value = globalAmount > 0 ? { type: 'fixed', value: globalAmount } : null
    fees.value = []

    lines.value = (sale.items ?? []).map(item => {
      const catalog = products.value.find(product => product.product_id === item.product_id)
      const lineDiscount = discounts.find(discount =>
        discount.sale_item_id === item.id && discount.discount_type === 'line',
      )
      return {
        lineId: item.id,
        quantity: item.quantity,
        lineDiscountFixed: lineDiscount?.amount,
        product: catalog ?? {
          product_id: item.product_id ?? item.id,
          sku: item.product_sku ?? '',
          name: item.product_name ?? 'Article',
          price: item.unit_price,
        },
      }
    })

    scheduleCalculate()
    setStatus(`Commande ${sale.reference} reprise`)
  }

  function setActiveTable(table: { id: string; name: string; code?: string } | null) {
    activeTable.value = table
  }

  async function persistTableOrder() {
    if (!pendingSaleId.value || !activeTable.value) return
    await api.put(`/sales/${pendingSaleId.value}`, cartPayload())
  }

  async function deleteHeldSale(heldSaleId: string) {
    await api.delete(`/sales/${heldSaleId}`)
    if (pendingSaleId.value === heldSaleId) {
      pendingSaleId.value = null
      activeTable.value = null
    }
    heldSales.value = heldSales.value.filter(sale => sale.id !== heldSaleId)
  }

  function cancel() {
    pendingSaleId.value = null
    activeTable.value = null
    clearCurrentSale()
    setStatus('Vente annulée')
  }

  async function loadSession(storeId: string) {
    try {
      const registerRes = await api.get<ApiListResponse<CashRegister>>(`/stores/${storeId}/cash-registers`)
      const list = Array.isArray(registerRes.data) ? registerRes.data : []
      if (list.length) {
        registers.value = list
          .filter(item => item.is_active !== false)
          .map(item => ({ id: item.id, name: item.name, code: item.code }))
      }
    } catch {
      // Keep registers already loaded with the POS catalog.
    }

    try {
      const shiftRes = await api.get<{ data: CashierShift | null; summary?: ShiftSummary }>(`/me/cashier-shifts/current`)
      shift.value = shiftRes.data
      shiftSummary.value = shiftRes.summary ?? null
      activeRegisterId.value = shiftRes.data?.cash_register_id ?? activeRegisterId.value
    } catch {
      shift.value = null
      shiftSummary.value = null
    }
  }

  async function openShiftWithPin(storeId: string, pin: string, registerId: string, opening: number) {
    const res = await api.post<{ data: CashierShift; summary: ShiftSummary }>(
      `/cash-registers/${registerId}/cashier-shifts/open-with-pin`,
      { pin, opening_balance: opening },
    )
    shift.value = res.data
    shiftSummary.value = res.summary
    activeRegisterId.value = registerId
    await loadSession(storeId)
  }

  async function closeShiftWithPin(storeId: string, pin: string, counted: number, notes: string, varianceReason = '') {
    const registerId = shift.value?.cash_register_id
    if (!registerId) throw new Error('Aucune caisse ouverte')
    const res = await api.post<{ data: CashierShift; summary: ShiftSummary }>(
      `/cash-registers/${registerId}/cashier-shifts/close-with-pin`,
      {
        pin,
        actual_cash: counted,
        closing_notes: notes || undefined,
        variance_reason: varianceReason || undefined,
      },
    )
    const summary = res.summary
    shift.value = null
    shiftSummary.value = null
    activeRegisterId.value = null
    await loadSession(storeId)
    return summary
  }

  async function recordDrawerMovement(type: 'cash_in' | 'cash_out', amount: number, description?: string) {
    const registerId = shift.value?.cash_register_id
    const shiftId = shift.value?.id
    const storeId = currentStoreId.value
    if (!registerId || !shiftId || !storeId) return
    const res = await api.post<{ summary: ShiftSummary }>(
      `/cash-registers/${registerId}/cashier-shifts/${shiftId}/movements`,
      { movement_type: type, amount, description },
    )
    shiftSummary.value = res.summary
    await loadSession(storeId)
  }

  async function pay(
    methodOrPayments: string | { method: string; amount: number; tendered?: number }[],
    amountTendered = 0,
  ): Promise<{ success: boolean; message: string; change: number; saleId?: string; receipt?: SaleDocPayload | null; loyalty?: { earned: number; points: number } | null }> {
    if (lines.value.length === 0) {
      return { success: false, message: 'Le panier est vide', change: 0 }
    }

    if (!customer.value?.id) {
      return { success: false, message: 'Sélectionnez un client pour encaisser', change: 0 }
    }

    const storeId = currentStoreId.value
    if (!storeId) {
      return { success: false, message: 'Aucun magasin sélectionné', change: 0 }
    }

    const total = totals.value.grand_total
    if (total < 1) {
      return { success: false, message: 'Le total de la vente est invalide', change: 0 }
    }

    const paymentLines = Array.isArray(methodOrPayments)
      ? methodOrPayments
      : [{
          method: methodOrPayments,
          amount: total,
          tendered: amountTendered > 0 ? amountTendered : undefined,
        }]

    if (paymentLines.length === 0) {
      return { success: false, message: 'Ajoutez au moins un mode de paiement', change: 0 }
    }

    const paidTotal = paymentLines.reduce((sum, line) => sum + line.amount, 0)
    if (paidTotal !== total) {
      return {
        success: false,
        message: `Le total payé (${paidTotal}) ne correspond pas au montant dû (${total})`,
        change: 0,
      }
    }

    let change = 0
    for (const line of paymentLines) {
      const methodMeta = paymentMethods.value.find(m => m.value === line.method)
      if ((methodMeta?.requires_customer || line.method === 'credit' || line.method === 'wallet') && !customer.value) {
        return { success: false, message: 'Un client est requis pour ce mode de paiement', change: 0 }
      }
      if (methodMeta?.supports_change) {
        const tendered = line.tendered ?? line.amount
        if (tendered < line.amount) {
          return { success: false, message: 'Montant reçu insuffisant pour les espèces', change: 0 }
        }
        change += Math.max(0, tendered - line.amount)
      }
    }

    let saleId: string | undefined
    let receipt: SaleDocPayload | null = null
    let loyalty: { earned: number; redeemed: number; points: number } | null = null
    try {
      const created = await api.post<ApiItemResponse<{
        sale: { id: string }
        receipt?: SaleDocPayload | null
        loyalty?: { earned: number; redeemed: number; points: number } | null
      }>>(`/stores/${storeId}/sales`, {
        customer_id: customer.value?.id ?? undefined,
        cash_register_id: shift.value?.cash_register_id ?? activeRegisterId.value ?? undefined,
        cashier_shift_id: shift.value?.id ?? undefined,
        notes: note.value ?? undefined,
        apply_promotions: true,
        items: lines.value.map(line => ({
          line_id: line.lineId,
          product_id: line.product.product_id,
          product_variant_id: line.variantId,
          sale_unit_id: line.saleUnitId,
          quantity: line.quantity,
          ...(line.isAccompaniment ? { unit_price: 0, is_accompaniment: true } : {}),
          line_discount: line.lineDiscountFixed
            ? { type: 'fixed' as const, value: line.lineDiscountFixed }
            : undefined,
        })),
        global_discount: globalDiscount.value ?? undefined,
        loyalty_points: loyaltyPoints.value > 0 ? loyaltyPoints.value : undefined,
        fees: fees.value,
        sale_id: pendingSaleId.value ?? undefined,
        payments: paymentLines.map((line) => {
          const methodMeta = paymentMethods.value.find(m => m.value === line.method)
          const tendered = line.tendered ?? line.amount
          return {
            method: line.method,
            amount: line.amount,
            metadata: methodMeta?.supports_change && tendered > 0
              ? { tendered }
              : undefined,
          }
        }),
        idempotency_key: crypto.randomUUID(),
      })
      saleId = created.data.sale.id
      receipt = created.data.receipt ?? null
      loyalty = created.data.loyalty ?? null
    } catch (e) {
      return { success: false, message: extractApiErrorMessage(e, 'Paiement refusé'), change: 0 }
    }

    const soldLines = [...lines.value]
    applyLocalStockDelta(soldLines)
    pendingSaleId.value = null
    activeTable.value = null
    if (calculateTimer) {
      clearTimeout(calculateTimer)
      calculateTimer = null
    }
    calculateRequestId += 1
    clearCurrentSale(false)
    lines.value = []
    totals.value = emptyTotals(currencyCode.value || getAppCurrency())
    if (currentStoreId.value) {
      void refreshHeldSales(currentStoreId.value)
      void fetchCatalog(currentStoreId.value).catch(() => {
        /* keep optimistic stock if silent refresh fails */
      })
    }
    return { success: true, message: 'Paiement accepté', change, saleId, receipt, loyalty }
  }

  function clearCurrentSale(notify = true) {
    lines.value = []
    customer.value = null
    note.value = null
    globalDiscount.value = null
    loyaltyPoints.value = 0
    fees.value = []
    totals.value = emptyTotals(totals.value.currency)
    if (notify) scheduleCalculate()
  }

  function reset() {
    products.value = []
    categories.value = []
    heldSales.value = []
    pendingSaleId.value = null
    activeTable.value = null
    currentStoreId.value = null
    activeRegisterId.value = null
    clearCurrentSale(false)
    error.value = null
    statusMessage.value = null
  }

  watch(
    () => lines.value.length,
    () => {
      if (lines.value.length === 0) totals.value = emptyTotals(totals.value.currency)
    },
  )

  /** Quantities currently held in the cart, in the same units as quantity_on_hand. */
  const cartReservedByProductId = computed(() => {
    const reserved: Record<string, number> = {}
    for (const line of lines.value) {
      if (line.isAccompaniment) continue
      if (line.product.requires_stock === false) continue
      if (!needsSaleQuantity(line.product)) continue
      const saleUnit = line.product.sale_units?.find(unit => unit.id === line.saleUnitId)
      const unit = saleUnit?.volume_ml && saleUnit.volume_ml > 0 ? saleUnit.volume_ml : 1
      const productId = line.product.product_id
      reserved[productId] = (reserved[productId] ?? 0) + line.quantity * unit
    }
    return reserved
  })

  return {
    products,
    categories,
    lines,
    heldSales,
    totals,
    customer,
    note,
    globalDiscount,
    fees,
    loading,
    calculating,
    error,
    statusMessage,
    statusIsError,
    isEmpty,
    itemCount,
    paymentMethods,
    availablePaymentMethods,
    shift,
    shiftSummary,
    registers,
    priceMode,
    currencyCode,
    currencies,
    cartReservedByProductId,
    loadSession,
    openShiftWithPin,
    closeShiftWithPin,
    recordDrawerMovement,
    loadCatalog,
    loadPaymentMethods,
    searchCustomers,
    createCustomer,
    lookupBarcode,
    productMatchesBarcode,
    addProduct,
    addAccompaniments,
    removeLine,
    updateQuantity,
    incrementQuantity,
    decrementQuantity,
    setCustomer,
    setNote,
    setGlobalDiscount,
    applyLoyaltyReward,
    clearDiscount,
    recalculate,
    pendingSaleId,
    activeTable,
    setActiveTable,
    persistTableOrder,
    holdSale,
    retrieveSale,
    deleteHeldSale,
    refreshHeldSales,
    cancel,
    pay,
    reset,
    setStatus,
  }
})
