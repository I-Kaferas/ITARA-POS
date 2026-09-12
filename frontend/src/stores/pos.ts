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
import type { CashRegister } from '../types'
import { getAppCurrency } from '../utils/currency'
import { needsSaleQuantity } from '../utils/product'

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
  const fees = ref<{ label: string; amount: number; code?: string }[]>([])

  const loading = ref(false)
  const calculating = ref(false)
  const error = ref<string | null>(null)
  const statusMessage = ref<string | null>(null)
  const statusIsError = ref(false)
  const heldCounter = ref(0)
  const pendingSaleId = ref<string | null>(null)
  const currentStoreId = ref<string | null>(null)
  const activeRegisterId = ref<string | null>(null)
  const paymentMethods = ref<PosPaymentMethod[]>([])

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
      ]
    }
  }

  async function loadCatalog(storeId: string) {
    currentStoreId.value = storeId
    loading.value = true
    error.value = null
    try {
      const res = await api.get<ApiItemResponse<{ products: PosProduct[]; categories: PosCategory[] }>>(
        `/stores/${storeId}/pos/catalog`,
      )
      products.value = res.data.products ?? []
      categories.value = res.data.categories ?? []
      await Promise.all([loadActiveRegister(storeId), loadPaymentMethods(storeId)])
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

  function addProduct(product: PosProduct, quantity = 1, saleUnitId?: string, variantId?: string) {
    const qty = needsSaleQuantity(product) ? Math.max(1, Math.trunc(quantity) || 1) : 1
    const unit = product.sale_units?.find(item => item.id === saleUnitId)
    const variant = product.variants?.find(item => item.variant_id === variantId)
    const priced: PosProduct = unit
      ? { ...product, name: `${product.name} · ${unit.name}`, price: unit.price }
      : variant
        ? { ...product, name: `${product.name} · ${variant.label || variant.name}`, price: variant.price, sku: variant.sku }
        : product
    const existing = lines.value.find(line =>
      line.product.product_id === product.product_id
      && line.saleUnitId === saleUnitId
      && line.variantId === variantId,
    )
    if (existing) {
      if (needsSaleQuantity(product)) existing.quantity += qty
    } else {
      lines.value.push({
        lineId: `${product.product_id}-${saleUnitId ?? variantId ?? 'base'}-${Date.now()}`,
        product: priced,
        quantity: qty,
        saleUnitId,
        variantId,
      })
    }
    scheduleCalculate()
  }

  function removeLine(lineId: string) {
    lines.value = lines.value.filter(line => line.lineId !== lineId)
    scheduleCalculate()
  }

  function updateQuantity(lineId: string, quantity: number) {
    const line = lines.value.find(l => l.lineId === lineId)
    if (!line) return
    if (!needsSaleQuantity(line.product)) return
    if (quantity < 1) {
      line.quantity = 1
      scheduleCalculate()
      return
    }
    line.quantity = quantity
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
    customer.value = value
    scheduleCalculate()
  }

  function setNote(value: string | null) {
    note.value = value?.trim() || null
  }

  function setGlobalDiscount(value: CartDiscountPayload | null) {
    globalDiscount.value = value
    scheduleCalculate()
  }

  function clearDiscount() {
    globalDiscount.value = null
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
    if (lines.value.length === 0) {
      totals.value = emptyTotals(getAppCurrency())
      return
    }

    const requestId = ++calculateRequestId
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
      items: lines.value.map(line => ({
        line_id: line.lineId,
        product_id: line.product.product_id,
        product_variant_id: line.variantId,
        sale_unit_id: line.saleUnitId,
        quantity: line.quantity,
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
    if (lines.value.length === 0) throw new Error('Panier vide')

    const storeId = currentStoreId.value
    if (!storeId) throw new Error('Aucun magasin sélectionné')

    const payload = cartPayload()
    const saved = pendingSaleId.value
      ? (await api.put<ApiItemResponse<{ id: string; reference: string }>>(`/sales/${pendingSaleId.value}`, payload)).data
      : (await api.post<ApiItemResponse<{ id: string; reference: string }>>(`/stores/${storeId}/sales/holds`, payload)).data

    const label = saved.reference
    pendingSaleId.value = null
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

  async function deleteHeldSale(heldSaleId: string) {
    await api.delete(`/sales/${heldSaleId}`)
    if (pendingSaleId.value === heldSaleId) pendingSaleId.value = null
    heldSales.value = heldSales.value.filter(sale => sale.id !== heldSaleId)
  }

  function cancel() {
    pendingSaleId.value = null
    clearCurrentSale()
    setStatus('Vente annulée')
  }

  async function pay(
    methodOrPayments: string | { method: string; amount: number; tendered?: number }[],
    amountTendered = 0,
  ): Promise<{ success: boolean; message: string; change: number }> {
    if (lines.value.length === 0) {
      return { success: false, message: 'Le panier est vide', change: 0 }
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

    try {
      await api.post(`/stores/${storeId}/sales`, {
        customer_id: customer.value?.id ?? undefined,
        cash_register_id: activeRegisterId.value ?? undefined,
        notes: note.value ?? undefined,
        apply_promotions: true,
        items: lines.value.map(line => ({
          line_id: line.lineId,
          product_id: line.product.product_id,
          product_variant_id: line.variantId,
          sale_unit_id: line.saleUnitId,
          quantity: line.quantity,
          line_discount: line.lineDiscountFixed
            ? { type: 'fixed' as const, value: line.lineDiscountFixed }
            : undefined,
        })),
        global_discount: globalDiscount.value ?? undefined,
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
    } catch (e) {
      return { success: false, message: extractApiErrorMessage(e, 'Paiement refusé'), change: 0 }
    }

    pendingSaleId.value = null
    clearCurrentSale()
    if (currentStoreId.value) void refreshHeldSales(currentStoreId.value)
    return { success: true, message: 'Paiement accepté', change }
  }

  function clearCurrentSale(notify = true) {
    lines.value = []
    customer.value = null
    note.value = null
    globalDiscount.value = null
    fees.value = []
    totals.value = emptyTotals(totals.value.currency)
    if (notify) scheduleCalculate()
  }

  function reset() {
    products.value = []
    categories.value = []
    heldSales.value = []
    pendingSaleId.value = null
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
    loadCatalog,
    loadPaymentMethods,
    searchCustomers,
    createCustomer,
    lookupBarcode,
    productMatchesBarcode,
    addProduct,
    removeLine,
    updateQuantity,
    incrementQuantity,
    decrementQuantity,
    setCustomer,
    setNote,
    setGlobalDiscount,
    clearDiscount,
    recalculate,
    pendingSaleId,
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
