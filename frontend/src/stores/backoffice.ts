import { defineStore } from 'pinia'
import { ref } from 'vue'

function queryFrom(params: Record<string, string> = {}) {
  const query = new URLSearchParams()
  for (const [key, value] of Object.entries(params)) {
    if (value) query.set(key, value)
  }
  const text = query.toString()
  return text ? `?${text}` : ''
}
import { api, type ApiItemResponse, type ApiListResponse } from '../api/client'
import type {
  BarcodeType,
  Branch,
  BranchExpense,
  Brand,
  CatalogAttribute,
  Catalog,
  Category,
  Company,
  Currency,
  CompanyPaymentMethod,
  CashRegister,
  CashRegisterSession,
  CashierShift,
  Customer,
  CustomerAddress,
  CustomerPayment,
  CustomerStatementLine,
  CustomerSummary,
  DashboardStats,
  Device,
  InventoryAlert,
  InventoryCount,
  InventoryCountDetail,
  FullCountLineInput,
  FullCountSummary,
  CycleSuggestion,
  CycleDashboard,
  OpeningLine,
  StockLedgerRow,
  InventoryMovement,
  Permission,
  Product,
  ProductVariant,
  PurchaseInvoice,
  PurchaseOrder,
  PayablesSummary,
  PayableScheduleItem,
  PurchaseOrderDetail,
  Role,
  Sale,
  SaleReturn,
  StockAdjustment,
  StockAdjustmentDetail,
  StockBalance,
  StockTransfer,
  StockTransferDetail,
  Store,
  StoreProductItem,
  Supplier,
  SupplierContact,
  SupplierSummary,
  SupplierStatementLine,
  SupplierPayment,
  SupplierDueDates,
  Tax,
  TaxClass,
  TaxGroup,
  TaxRule,
  TaxRegisterRow,
  TaxReportRow,
  Promotion,
  PromotionTypeMeta,
  RegisterSummary,
  ShiftSummary,
  TenantUser,
  Unit,
  Warehouse,
  AuditLog,
  AccountingEntry,
  AccountingSummary,
  SalesReport,
  PosOverview,
  InventoryReport,
  FinancialReport,
  SerialNumber,
  ProductBatch,
  ImportResult,
} from '../types'

export const useBackofficeStore = defineStore('backoffice', () => {
  const companies = ref<Company[]>([])
  const branches = ref<Branch[]>([])
  const catalogs = ref<Catalog[]>([])
  const categories = ref<Category[]>([])
  const brands = ref<Brand[]>([])
  const catalogAttributes = ref<CatalogAttribute[]>([])
  const units = ref<Unit[]>([])
  const taxes = ref<Tax[]>([])
  const currencies = ref<Currency[]>([])
  const paymentMethods = ref<CompanyPaymentMethod[]>([])
  const promotions = ref<Promotion[]>([])
  const promotionTypes = ref<PromotionTypeMeta[]>([])
  const products = ref<Product[]>([])
  const stores = ref<Store[]>([])
  const warehouses = ref<Warehouse[]>([])
  const devices = ref<Device[]>([])
  const cashRegisters = ref<CashRegister[]>([])
  const cashierShifts = ref<CashierShift[]>([])
  const currentCashierShift = ref<CashierShift | null>(null)
  const users = ref<TenantUser[]>([])
  const roles = ref<Role[]>([])
  const permissions = ref<Permission[]>([])
  const storeProducts = ref<StoreProductItem[]>([])
  const stats = ref<DashboardStats | null>(null)
  const suppliers = ref<Supplier[]>([])
  const customers = ref<Customer[]>([])
  const purchaseOrders = ref<PurchaseOrder[]>([])
  const purchaseInvoices = ref<PurchaseInvoice[]>([])
  const payablesSummary = ref<PayablesSummary | null>(null)
  const payablesSchedule = ref<PayableScheduleItem[]>([])
  const supplierPayments = ref<SupplierPayment[]>([])
  const stockBalances = ref<StockBalance[]>([])
  const stockTransfers = ref<StockTransfer[]>([])
  const stockAdjustments = ref<StockAdjustment[]>([])
  const inventoryCounts = ref<InventoryCount[]>([])
  const inventoryAlerts = ref<InventoryAlert[]>([])
  const sales = ref<Sale[]>([])
  const auditLogs = ref<AuditLog[]>([])
  const accountingEntries = ref<AccountingEntry[]>([])
  const serialNumbers = ref<SerialNumber[]>([])
  const productBatches = ref<ProductBatch[]>([])
  const loading = ref(false)

  function unwrapWarehouses(payload: { data?: Warehouse[] | { data?: Warehouse[] } | null }): Warehouse[] {
    const body = payload?.data
    if (Array.isArray(body)) return body.filter((item) => item?.id && item?.name)
    if (body && Array.isArray(body.data)) return body.data.filter((item) => item?.id && item?.name)
    return []
  }

  async function loadPaginated<T>(path: string): Promise<T[]> {
    const res = await api.get<{ data: { data: T[] } }>(`${path}${path.includes('?') ? '&' : '?'}per_page=100`)
    return res.data.data
  }

  async function loadStats() {
    stats.value = (await api.get<ApiItemResponse<DashboardStats>>('/dashboard/stats')).data
  }

  // Companies
  async function loadCompanies() {
    loading.value = true
    try {
      companies.value = (await api.get<ApiListResponse<Company>>('/companies')).data
    } finally {
      loading.value = false
    }
  }

  async function loadCompanyDetail(id: string) {
    return (await api.get<ApiItemResponse<Company>>(`/companies/${id}`)).data
  }

  async function saveCompany(payload: Partial<Company>, id?: string) {
    if (id) return (await api.patch<ApiItemResponse<Company>>(`/companies/${id}`, payload)).data
    return (await api.post<ApiItemResponse<Company>>('/companies', payload)).data
  }

  async function uploadCompanyLogo(id: string, file: File) {
    const form = new FormData()
    form.append('logo', file)
    return (await api.upload<ApiItemResponse<Company>>(`/companies/${id}/logo`, form)).data
  }

  async function deleteCompanyLogo(id: string) {
    return (await api.delete<ApiItemResponse<Company>>(`/companies/${id}/logo`)).data
  }

  async function deleteCompany(id: string) {
    await api.delete(`/companies/${id}`)
  }

  // Currencies
  async function loadCurrencies(activeOnly = false) {
    const q = activeOnly ? '?active_only=1' : ''
    currencies.value = (await api.get<ApiListResponse<Currency>>(`/currencies${q}`)).data
    return currencies.value
  }

  async function saveCurrency(payload: Partial<Currency>, id?: string) {
    if (id) return (await api.patch<ApiItemResponse<Currency>>(`/currencies/${id}`, payload)).data
    return (await api.post<ApiItemResponse<Currency>>('/currencies', payload)).data
  }

  async function deleteCurrency(id: string) {
    await api.delete(`/currencies/${id}`)
  }

  async function loadPaymentMethods(companyId: string) {
    paymentMethods.value = (await api.get<ApiListResponse<CompanyPaymentMethod>>(
      `/companies/${companyId}/payment-methods`,
    )).data
    return paymentMethods.value
  }

  async function savePaymentMethod(
    companyId: string,
    payload: Partial<CompanyPaymentMethod>,
    id?: string,
  ) {
    if (id) {
      return updatePaymentMethod(companyId, id, payload)
    }
    const created = (await api.post<ApiItemResponse<CompanyPaymentMethod>>(
      `/companies/${companyId}/payment-methods`,
      payload,
    )).data
    paymentMethods.value = [...paymentMethods.value, created]
    return created
  }

  async function deletePaymentMethod(companyId: string, id: string) {
    await api.delete(`/companies/${companyId}/payment-methods/${id}`)
    paymentMethods.value = paymentMethods.value.filter(method => method.id !== id)
  }

  async function updatePaymentMethod(
    companyId: string,
    id: string,
    payload: Partial<CompanyPaymentMethod>,
  ) {
    return (await api.patch<ApiItemResponse<CompanyPaymentMethod>>(
      `/companies/${companyId}/payment-methods/${id}`,
      payload,
    )).data
  }

  async function reorderPaymentMethods(companyId: string, order: string[]) {
    paymentMethods.value = (await api.post<ApiListResponse<CompanyPaymentMethod>>(
      `/companies/${companyId}/payment-methods/reorder`,
      { order },
    )).data
    return paymentMethods.value
  }

  // Branches
  async function loadBranches(companyId: string) {
    branches.value = (await api.get<ApiListResponse<Branch>>(`/companies/${companyId}/branches`)).data
    return branches.value
  }

  async function saveBranch(companyId: string, payload: Partial<Branch>, id?: string) {
    if (id) return (await api.patch<ApiItemResponse<Branch>>(`/branches/${id}`, payload)).data
    return (await api.post<ApiItemResponse<Branch>>(`/companies/${companyId}/branches`, payload)).data
  }

  async function deleteBranch(id: string) {
    await api.delete(`/branches/${id}`)
  }

  async function loadBranchProfile(id: string) {
    return (await api.get<ApiItemResponse<Branch>>(`/branches/${id}`)).data
  }

  async function addBranchExpense(branchId: string, payload: { description: string; amount: number; category?: string; occurred_on?: string }) {
    return (await api.post<ApiItemResponse<BranchExpense>>(`/branches/${branchId}/expenses`, payload)).data
  }

  // Stores (per branch)
  async function loadStores(branchId: string) {
    stores.value = (await api.get<ApiListResponse<Store>>(`/branches/${branchId}/stores`)).data
    return stores.value
  }

  async function saveStore(branchId: string, payload: Partial<Store>, id?: string) {
    if (id) return (await api.patch<ApiItemResponse<Store>>(`/stores/${id}`, payload)).data
    return (await api.post<ApiItemResponse<Store>>(`/branches/${branchId}/stores`, payload)).data
  }

  async function deleteStore(id: string) {
    await api.delete(`/stores/${id}`)
  }

  // Warehouses
  async function loadWarehouses(branchId: string) {
    warehouses.value = (await api.get<ApiListResponse<Warehouse>>(`/branches/${branchId}/warehouses`)).data
    return warehouses.value
  }

  async function saveWarehouse(branchId: string, payload: Partial<Warehouse>, id?: string) {
    if (id) return (await api.patch<ApiItemResponse<Warehouse>>(`/warehouses/${id}`, payload)).data
    return (await api.post<ApiItemResponse<Warehouse>>(`/branches/${branchId}/warehouses`, payload)).data
  }

  async function deleteWarehouse(id: string) {
    await api.delete(`/warehouses/${id}`)
  }

  // Devices
  async function loadDevices(storeId: string, deviceType?: string) {
    const q = deviceType ? `?device_type=${deviceType}` : ''
    devices.value = (await api.get<ApiListResponse<Device>>(`/stores/${storeId}/devices${q}`)).data
    return devices.value
  }

  async function saveDevice(storeId: string, payload: Partial<Device>, id?: string) {
    if (id) return (await api.patch<ApiItemResponse<Device>>(`/devices/${id}`, payload)).data
    return (await api.post<ApiItemResponse<Device>>(`/stores/${storeId}/devices`, payload)).data
  }

  async function deleteDevice(id: string) {
    await api.delete(`/devices/${id}`)
  }

  async function revokeDevice(id: string) {
    return (await api.post<ApiItemResponse<Device>>(`/devices/${id}/revoke`, {})).data
  }

  async function regenerateDeviceToken(id: string) {
    return (await api.post<ApiItemResponse<Device>>(`/devices/${id}/sync-token`, {})).data
  }

  // Cash registers
  async function loadCashRegisters(storeId: string) {
    cashRegisters.value = (await api.get<ApiListResponse<CashRegister>>(`/stores/${storeId}/cash-registers`)).data
    return cashRegisters.value
  }

  async function saveCashRegister(storeId: string, payload: Partial<CashRegister>, id?: string) {
    if (id) return (await api.patch<ApiItemResponse<CashRegister>>(`/cash-registers/${id}`, payload)).data
    return (await api.post<ApiItemResponse<CashRegister>>(`/stores/${storeId}/cash-registers`, payload)).data
  }

  async function deleteCashRegister(id: string) {
    await api.delete(`/cash-registers/${id}`)
  }

  async function loadStoreCashierShifts(storeId: string) {
    cashierShifts.value = (await api.get<ApiListResponse<CashierShift>>(`/stores/${storeId}/cashier-shifts`)).data
    return cashierShifts.value
  }

  async function loadCashierShiftDetail(storeId: string, shiftId: string) {
    return api.get<{ data: CashierShift; summary: ShiftSummary }>(
      `/stores/${storeId}/cashier-shifts/${shiftId}`,
    )
  }

  async function loadCurrentCashierShift() {
    const res = await api.get<{ data: CashierShift | null; summary?: ShiftSummary }>('/me/cashier-shifts/current')
    currentCashierShift.value = res.data
    return { shift: res.data, summary: res.summary ?? null }
  }

  async function openCashierShift(
    registerId: string,
    payload: { opening_balance?: number; opening_notes?: string; opened_at?: string } = {},
  ) {
    const res = await api.post<{ data: CashierShift; summary: ShiftSummary }>(
      `/cash-registers/${registerId}/cashier-shifts/open`,
      {
        opening_balance: Math.round((payload.opening_balance ?? 0) * 100),
        opening_notes: payload.opening_notes,
        opened_at: payload.opened_at,
      },
    )
    currentCashierShift.value = res.data
    return res
  }

  async function closeCashierShift(
    registerId: string,
    payload: { actual_cash: number; closing_notes?: string; variance_reason?: string; closed_at?: string },
  ) {
    const res = await api.post<{ data: CashierShift; summary: ShiftSummary }>(
      `/cash-registers/${registerId}/cashier-shifts/close`,
      {
        actual_cash: Math.round(payload.actual_cash * 100),
        closing_notes: payload.closing_notes,
        variance_reason: payload.variance_reason,
        closed_at: payload.closed_at,
      },
    )
    currentCashierShift.value = null
    return res
  }

  async function getCurrentRegisterSession(registerId: string) {
    const res = await api.get<{ data: CashRegisterSession | null; summary?: RegisterSummary }>(
      `/cash-registers/${registerId}/sessions/current`,
    )
    return { session: res.data, summary: res.summary ?? null }
  }

  async function openRegisterSession(registerId: string, payload: { opening_balance?: number; opening_notes?: string }) {
    const res = await api.post<{ data: CashRegisterSession; summary: RegisterSummary }>(
      `/cash-registers/${registerId}/sessions/open`,
      payload,
    )
    return res
  }

  async function closeRegisterSession(
    registerId: string,
    payload: { actual_cash: number; closing_notes?: string; variance_reason?: string },
  ) {
    const res = await api.post<{ data: CashRegisterSession; summary: RegisterSummary; z_report?: RegisterSummary }>(
      `/cash-registers/${registerId}/sessions/close`,
      payload,
    )
    return res
  }

  async function recordRegisterMovement(
    registerId: string,
    payload: {
      movement_type: 'cash_in' | 'cash_out' | 'expense'
      amount: number
      description?: string
      reference?: string
    },
  ) {
    const res = await api.post<{ data: unknown; summary: RegisterSummary }>(
      `/cash-registers/${registerId}/movements`,
      payload,
    )
    return res
  }

  // Users & RBAC
  async function loadUsers(params?: { search?: string; status?: string; role_id?: string }) {
    const query = new URLSearchParams()
    if (params?.search) query.set('search', params.search)
    if (params?.status && params.status !== 'all') query.set('status', params.status)
    if (params?.role_id) query.set('role_id', params.role_id)
    const suffix = query.toString() ? `?${query.toString()}` : ''
    users.value = (await api.get<ApiListResponse<TenantUser>>(`/users${suffix}`)).data
    return users.value
  }

  async function loadUserSessions(userId: string) {
    return (await api.get<ApiListResponse<{ id: string; device_name?: string | null; ip_address?: string | null; last_used_at?: string | null; created_at?: string | null }>>(`/users/${userId}/sessions`)).data
  }

  async function resetUserPassword(userId: string, password: string) {
    await api.post(`/users/${userId}/reset-password`, { password })
  }

  async function setUserActive(userId: string, active: boolean) {
    const action = active ? 'activate' : 'deactivate'
    return (await api.post<ApiItemResponse<TenantUser>>(`/users/${userId}/${action}`)).data
  }

  async function revokeUserSessions(userId: string) {
    await api.delete(`/users/${userId}/sessions`)
  }

  async function saveUser(
    payload: { name: string; email: string; phone?: string | null; pin?: string | null; password?: string; is_active?: boolean },
    id?: string,
  ) {
    if (id) {
      return (await api.patch<ApiItemResponse<TenantUser>>(`/users/${id}`, payload)).data
    }
    return (await api.post<ApiItemResponse<TenantUser>>('/users', payload)).data
  }

  async function deleteUser(id: string) {
    await api.delete(`/users/${id}`)
  }

  async function loadRoles() {
    roles.value = (await api.get<ApiListResponse<Role>>('/roles')).data
    return roles.value
  }

  async function loadPermissions() {
    const groups = (await api.get<ApiListResponse<{ group: string; permissions: Omit<Permission, 'group'>[] }>>('/permissions')).data
    permissions.value = groups.flatMap(group =>
      group.permissions.map(permission => ({ ...permission, group: group.group })),
    )
    return permissions.value
  }

  async function saveRole(payload: { name: string; slug: string; permissions?: string[] }, id?: string) {
    if (id) return (await api.patch<ApiItemResponse<Role>>(`/roles/${id}`, payload)).data
    return (await api.post<ApiItemResponse<Role>>('/roles', payload)).data
  }

  async function deleteRole(id: string) {
    await api.delete(`/roles/${id}`)
  }

  async function assignUserRole(userId: string, roleId: string, branchId?: string | null, storeId?: string | null) {
    await api.post<void>(`/users/${userId}/roles`, { role_id: roleId, branch_id: branchId ?? null, store_id: storeId ?? null })
  }

  async function assignUserStore(userId: string, storeIds: string[], roleId?: string | null) {
    return (await api.patch<ApiItemResponse<TenantUser>>(`/users/${userId}/store`, {
      store_ids: storeIds,
      role_id: roleId || null,
    })).data
  }

  async function removeUserRole(userId: string, roleId: string) {
    await api.delete(`/users/${userId}/roles/${roleId}`)
  }

  // Catalogs
  async function loadCatalogs(companyId: string) {
    catalogs.value = (await api.get<ApiListResponse<Catalog>>(`/companies/${companyId}/catalogs`)).data
    return catalogs.value
  }

  async function saveCatalog(companyId: string, payload: Partial<Catalog>, id?: string) {
    if (id) return (await api.patch<ApiItemResponse<Catalog>>(`/catalogs/${id}`, payload)).data
    return (await api.post<ApiItemResponse<Catalog>>(`/companies/${companyId}/catalogs`, payload)).data
  }

  async function deleteCatalog(id: string) {
    await api.delete(`/catalogs/${id}`)
  }

  // Categories
  async function loadCategories(catalogId: string) {
    categories.value = (await api.get<ApiListResponse<Category>>(`/catalogs/${catalogId}/categories`)).data
    return categories.value
  }

  async function saveCategory(catalogId: string, payload: Partial<Category>, id?: string) {
    if (id) return (await api.patch<ApiItemResponse<Category>>(`/categories/${id}`, payload)).data
    return (await api.post<ApiItemResponse<Category>>(`/catalogs/${catalogId}/categories`, payload)).data
  }

  async function deleteCategory(id: string) {
    await api.delete(`/categories/${id}`)
  }

  // Brands, units, taxes
  async function loadBrands() {
    brands.value = (await api.get<ApiListResponse<Brand>>('/brands')).data
    return brands.value
  }

  async function saveBrand(payload: Partial<Brand>, id?: string) {
    if (id) return (await api.patch<ApiItemResponse<Brand>>(`/brands/${id}`, payload)).data
    return (await api.post<ApiItemResponse<Brand>>('/brands', payload)).data
  }

  async function deleteBrand(id: string) {
    await api.delete(`/brands/${id}`)
  }

  async function loadUnits(activeOnly = false) {
    const q = activeOnly ? '?active_only=1' : ''
    units.value = (await api.get<ApiListResponse<Unit>>(`/units${q}`)).data
    return units.value
  }

  async function saveUnit(payload: Partial<Unit>, id?: string) {
    if (id) return (await api.patch<ApiItemResponse<Unit>>(`/units/${id}`, payload)).data
    return (await api.post<ApiItemResponse<Unit>>('/units', payload)).data
  }

  async function deleteUnit(id: string) {
    await api.delete(`/units/${id}`)
  }

  async function loadCatalogAttributes(ensureDefaults = false) {
    const q = ensureDefaults ? '?ensure_defaults=1' : ''
    catalogAttributes.value = (await api.get<ApiListResponse<CatalogAttribute>>(`/catalog-attributes${q}`)).data
    return catalogAttributes.value
  }

  async function saveCatalogAttribute(payload: Partial<CatalogAttribute>, id?: string) {
    if (id) return (await api.patch<ApiItemResponse<CatalogAttribute>>(`/catalog-attributes/${id}`, payload)).data
    return (await api.post<ApiItemResponse<CatalogAttribute>>('/catalog-attributes', payload)).data
  }

  async function deleteCatalogAttribute(id: string) {
    await api.delete(`/catalog-attributes/${id}`)
  }

  async function loadTaxes(activeOnly = true) {
    const query = activeOnly ? '?active_only=1' : ''
    taxes.value = (await api.get<ApiListResponse<Tax>>(`/taxes${query}`)).data
    return taxes.value
  }

  async function saveTax(payload: Partial<Tax>, id?: string) {
    if (id) return (await api.patch<ApiItemResponse<Tax>>(`/taxes/${id}`, payload)).data
    return (await api.post<ApiItemResponse<Tax>>('/taxes', payload)).data
  }

  async function deleteTax(id: string) {
    await api.delete(`/taxes/${id}`)
  }

  async function loadTaxReport(from?: string, to?: string) {
    const params = new URLSearchParams()
    if (from) params.set('from', from)
    if (to) params.set('to', to)
    const query = params.toString()
    return (await api.get<{ data: { summary: TaxReportRow[]; taxable_amount: number; tax_amount: number; lines: number } }>(`/taxes/report${query ? `?${query}` : ''}`)).data
  }

  async function loadTaxRegister(from?: string, to?: string) {
    const params = new URLSearchParams()
    if (from) params.set('from', from)
    if (to) params.set('to', to)
    const query = params.toString()
    return (await api.get<ApiListResponse<TaxRegisterRow>>(`/taxes/register${query ? `?${query}` : ''}`)).data
  }

  async function calculateTaxes(payload: { amount: number; amount_is_inclusive: boolean; tax_ids?: string[]; tax_group_id?: string }) {
    return (await api.post<{ data: { net: number; tax_total: number; total: number; lines: { tax_id: string; name: string; code: string; rate: number; priority: number; is_inclusive: boolean; is_compound: boolean; taxable_amount: number; tax_amount: number }[] } }>('/taxes/calculate', payload)).data
  }

  async function loadTaxGroups() {
    return (await api.get<ApiListResponse<TaxGroup>>('/tax-groups')).data
  }

  async function saveTaxGroup(payload: Partial<TaxGroup> & { tax_ids?: string[] }, id?: string) {
    if (id) return (await api.patch<ApiItemResponse<TaxGroup>>(`/tax-groups/${id}`, payload)).data
    return (await api.post<ApiItemResponse<TaxGroup>>('/tax-groups', payload)).data
  }

  async function deleteTaxGroup(id: string) {
    await api.delete(`/tax-groups/${id}`)
  }

  async function loadTaxClasses() {
    return (await api.get<ApiListResponse<TaxClass>>('/tax-classes')).data
  }

  async function saveTaxClass(payload: Partial<TaxClass>, id?: string) {
    if (id) return (await api.patch<ApiItemResponse<TaxClass>>(`/tax-classes/${id}`, payload)).data
    return (await api.post<ApiItemResponse<TaxClass>>('/tax-classes', payload)).data
  }

  async function deleteTaxClass(id: string) {
    await api.delete(`/tax-classes/${id}`)
  }

  async function loadTaxRules() {
    return (await api.get<ApiListResponse<TaxRule>>('/tax-rules')).data
  }

  async function saveTaxRule(payload: Partial<TaxRule>, id?: string) {
    if (id) return (await api.patch<ApiItemResponse<TaxRule>>(`/tax-rules/${id}`, payload)).data
    return (await api.post<ApiItemResponse<TaxRule>>('/tax-rules', payload)).data
  }

  async function deleteTaxRule(id: string) {
    await api.delete(`/tax-rules/${id}`)
  }

  async function loadPromotionTypes() {
    promotionTypes.value = (await api.get<ApiListResponse<PromotionTypeMeta>>('/promotions/types')).data
    return promotionTypes.value
  }

  async function loadPromotions() {
    promotions.value = (await api.get<ApiListResponse<Promotion>>('/promotions')).data
    return promotions.value
  }

  async function savePromotion(payload: Partial<Promotion>, id?: string) {
    if (id) return (await api.patch<ApiItemResponse<Promotion>>(`/promotions/${id}`, payload)).data
    return (await api.post<ApiItemResponse<Promotion>>('/promotions', payload)).data
  }

  async function deletePromotion(id: string) {
    await api.delete(`/promotions/${id}`)
  }

  // Products
  async function loadPriceList(catalogId: string) {
    return api.get<{
      default_currency: string
      currencies: Currency[]
      data: Array<{
        id: string
        sku: string
        name: string
        tax: { code?: string; name: string; rate: number; is_inclusive: boolean } | null
        prices: Record<string, {
          amount: number
          currency_code: string
          price_id?: string | null
          quote: { ht: number; tva: number; ttc: number }
          in_default: number
        }>
      }>
    }>(`/catalogs/${catalogId}/price-list`)
  }

  async function loadProducts(catalogId: string, search = '') {
    const q = search ? `?search=${encodeURIComponent(search)}` : ''
    products.value = (await api.get<ApiListResponse<Product>>(`/catalogs/${catalogId}/products${q}`)).data
    return products.value
  }

  async function loadProduct(id: string) {
    return (await api.get<ApiItemResponse<Product>>(`/products/${id}`)).data
  }

  async function saveProduct(catalogId: string, payload: Record<string, unknown>, id?: string) {
    if (id) return (await api.patch<ApiItemResponse<Product>>(`/products/${id}`, payload)).data
    return (await api.post<ApiItemResponse<Product>>(`/catalogs/${catalogId}/products`, payload)).data
  }

  async function deleteProduct(id: string) {
    await api.delete(`/products/${id}`)
  }

  async function transformProductOptions(
    productId: string,
    groups: { name: string; values: string[] }[],
    prices: { options: Record<string, string>; price: number }[] = [],
  ) {
    return (await api.post<ApiItemResponse<{ product: Product; groups: { name: string; values: string[] }[]; variants: ProductVariant[] }>>(
      `/products/${productId}/transform-options`,
      { groups, prices },
    )).data
  }

  // Barcodes
  async function generateBarcode(type: BarcodeType = 'internal') {
    return (await api.post<ApiItemResponse<{ barcode: string; type: string }>>('/barcodes/generate', { type })).data
  }

  async function printBarcode(barcodeId: string) {
    return (await api.get<ApiItemResponse<unknown>>(`/barcodes/${barcodeId}/print`)).data
  }

  // Images
  async function uploadProductImage(productId: string, file: File, isPrimary = false) {
    const form = new FormData()
    form.append('image', file)
    if (isPrimary) form.append('is_primary', '1')
    return api.upload(`/products/${productId}/images`, form)
  }

  async function deleteProductImage(imageId: string) {
    await api.delete(`/product-images/${imageId}`)
  }

  async function setPrimaryImage(imageId: string) {
    await api.patch(`/product-images/${imageId}/primary`)
  }

  // Store products
  async function loadStoreProducts(storeId: string) {
    storeProducts.value = (await api.get<ApiListResponse<StoreProductItem>>(`/stores/${storeId}/products`)).data
    return storeProducts.value
  }

  async function importToStore(storeId: string, productIds: string[]) {
    await api.post(`/stores/${storeId}/products/import`, { product_ids: productIds })
  }

  async function updateStoreProduct(storeId: string, productId: string, payload: { is_available?: boolean; price_override?: number | null }) {
    return (await api.patch<ApiItemResponse<StoreProductItem>>(`/stores/${storeId}/products/${productId}`, payload)).data
  }

  async function removeFromStore(storeId: string, productId: string) {
    await api.delete(`/stores/${storeId}/products/${productId}`)
  }

  async function loadAllWarehouses(): Promise<Warehouse[]> {
    try {
      const fromList = unwrapWarehouses(await api.get<{ data: Warehouse[] | { data?: Warehouse[] } }>('/warehouses'))
      if (fromList.length) return fromList
    } catch {
      // Fall back to the branch listing used by organization screens.
    }

    await loadCompanies()
    const all: Warehouse[] = []
    const companiesList = Array.isArray(companies.value) ? companies.value : []
    for (const company of companiesList) {
      const companyBranches = await loadBranches(company.id).catch(() => [])
      const branches = Array.isArray(companyBranches) ? companyBranches : []
      for (const branch of branches) {
        try {
          const payload = await api.get<{ data: Warehouse[] | { data?: Warehouse[] } }>(`/branches/${branch.id}/warehouses`)
          all.push(...unwrapWarehouses(payload))
        } catch {
          // Skip a branch the current role cannot list.
        }
      }
    }
    return all
  }

  // Suppliers
  async function loadSuppliers(search = '') {
    loading.value = true
    try {
      const q = search ? `?search=${encodeURIComponent(search)}` : ''
      suppliers.value = await loadPaginated<Supplier>(`/suppliers${q}`)
      return suppliers.value
    } finally {
      loading.value = false
    }
  }

  async function saveSupplier(payload: Partial<Supplier>, id?: string) {
    if (id) return (await api.patch<ApiItemResponse<Supplier>>(`/suppliers/${id}`, payload)).data
    return (await api.post<ApiItemResponse<Supplier>>('/suppliers', payload)).data
  }

  async function deleteSupplier(id: string) {
    await api.delete(`/suppliers/${id}`)
  }

  async function loadSupplierContacts(supplierId: string) {
    return (await api.get<ApiListResponse<SupplierContact>>(`/suppliers/${supplierId}/contacts`)).data
  }

  async function saveSupplierContact(
    supplierId: string,
    payload: Partial<SupplierContact>,
    id?: string,
  ) {
    if (id) return (await api.patch<ApiItemResponse<SupplierContact>>(`/supplier-contacts/${id}`, payload)).data
    return (await api.post<ApiItemResponse<SupplierContact>>(`/suppliers/${supplierId}/contacts`, payload)).data
  }

  async function deleteSupplierContact(id: string) {
    await api.delete(`/supplier-contacts/${id}`)
  }

  async function loadPayablesSummary() {
    loading.value = true
    try {
      payablesSummary.value = (await api.get<ApiItemResponse<PayablesSummary>>('/payables/summary')).data
    } finally {
      loading.value = false
    }
  }

  async function loadPayablesSchedule(overdueOnly = false) {
    loading.value = true
    try {
      const q = overdueOnly ? '?overdue_only=1' : ''
      payablesSchedule.value = (await api.get<ApiListResponse<PayableScheduleItem>>(`/payables/schedule${q}`)).data
    } finally {
      loading.value = false
    }
  }

  async function loadRecentSupplierPayments(params: Record<string, string> = {}) {
    loading.value = true
    try {
      const query = new URLSearchParams(params)
      const suffix = query.toString()
      supplierPayments.value = (await api.get<ApiListResponse<SupplierPayment>>(`/payables/payments${suffix ? `?${suffix}` : ''}`)).data
    } finally {
      loading.value = false
    }
  }

  async function loadSupplierSummary(supplierId: string) {
    return (await api.get<ApiItemResponse<SupplierSummary>>(`/suppliers/${supplierId}/summary`)).data
  }

  async function loadSupplierDetail(supplierId: string) {
    const response = await api.get<{ data: Supplier; summary: SupplierSummary }>(`/suppliers/${supplierId}`)
    return { supplier: response.data, summary: response.summary }
  }

  async function loadSupplierStatement(supplierId: string) {
    return api.get<{ data: SupplierStatementLine[]; meta: { balance: number; debt: number; credit: number } }>(
      `/suppliers/${supplierId}/statement`,
    )
  }

  async function loadSupplierDueDates(supplierId: string) {
    return (await api.get<ApiItemResponse<SupplierDueDates>>(`/suppliers/${supplierId}/due-dates`)).data
  }

  async function loadSupplierProducts(supplierId: string) {
    return (await api.get<ApiListResponse<{ id: string; sku: string; name: string; supplier_sku?: string | null; cost_price?: number | null }>>(`/suppliers/${supplierId}/products`)).data
  }

  async function attachSupplierProduct(supplierId: string, payload: { product_id: string; supplier_sku?: string | null; cost_price?: number | null }) {
    return (await api.post<ApiListResponse<{ id: string; sku: string; name: string; supplier_sku?: string | null; cost_price?: number | null }>>(`/suppliers/${supplierId}/products`, payload)).data
  }

  async function detachSupplierProduct(supplierId: string, productId: string) {
    await api.delete(`/suppliers/${supplierId}/products/${productId}`)
  }

  async function loadSupplierOrders(supplierId: string) {
    return (await api.get<ApiListResponse<{ id: string; order_number: string; status: string; total: number; ordered_at?: string | null; expected_at?: string | null }>>(`/suppliers/${supplierId}/orders`)).data
  }

  async function loadSupplierInvoices(supplierId: string) {
    return (await api.get<ApiListResponse<{ id: string; invoice_number: string; status: string; total: number; paid_amount: number; due_date?: string | null; invoiced_at?: string | null }>>(`/suppliers/${supplierId}/invoices`)).data
  }

  async function loadSupplierPayments(supplierId: string) {
    return (await api.get<ApiListResponse<SupplierPayment>>(`/suppliers/${supplierId}/payments`)).data
  }

  async function recordSupplierPayment(
    supplierId: string,
    payload: {
      amount: number
      payment_method?: string
      reference?: string
      notes?: string
      allocations?: { transaction_id: string; amount: number }[]
    },
  ) {
    return (await api.post<ApiItemResponse<SupplierPayment>>(`/suppliers/${supplierId}/payments`, payload)).data
  }

  async function recordPurchaseInvoicePayment(
    invoiceId: string,
    payload: { amount: number; payment_method?: string; reference?: string; notes?: string },
  ) {
    return (await api.post<ApiItemResponse<SupplierPayment>>(`/purchase-invoices/${invoiceId}/payments`, payload)).data
  }

  // Customers
  async function loadCustomers(search = '') {
    loading.value = true
    try {
      const q = search ? `?search=${encodeURIComponent(search)}` : ''
      customers.value = await loadPaginated<Customer>(`/customers${q}`)
    } finally {
      loading.value = false
    }
  }

  async function saveCustomer(payload: Partial<Customer>, id?: string) {
    if (id) return (await api.patch<ApiItemResponse<Customer>>(`/customers/${id}`, payload)).data
    return (await api.post<ApiItemResponse<Customer>>('/customers', payload)).data
  }

  async function deleteCustomer(id: string) {
    await api.delete(`/customers/${id}`)
  }

  async function loadCustomerAddresses(customerId: string) {
    return (await api.get<ApiListResponse<CustomerAddress>>(`/customers/${customerId}/addresses`)).data
  }

  async function saveCustomerAddress(
    customerId: string,
    payload: Partial<CustomerAddress>,
    id?: string,
  ) {
    if (id) {
      return (await api.patch<ApiItemResponse<CustomerAddress>>(`/customer-addresses/${id}`, payload)).data
    }
    return (await api.post<ApiItemResponse<CustomerAddress>>(`/customers/${customerId}/addresses`, payload)).data
  }

  async function deleteCustomerAddress(id: string) {
    await api.delete(`/customer-addresses/${id}`)
  }

  // Purchases
  async function loadPurchaseOrders(params: string | Record<string, string> = '') {
    loading.value = true
    try {
      const suffix = typeof params === 'string'
        ? (params ? `?status=${encodeURIComponent(params)}` : '')
        : queryFrom(params)
      purchaseOrders.value = await loadPaginated<PurchaseOrder>(`/purchase-orders${suffix}`)
    } finally {
      loading.value = false
    }
  }

  async function loadExpenseDashboard(params: Record<string, string> = {}) {
    return (await api.get<{ data: Record<string, unknown> }>(`/expenses/dashboard${queryFrom(params)}`)).data
  }

  async function loadExpenses(params: Record<string, string> = {}) {
    return (await api.get<ApiListResponse<Record<string, unknown>>>(`/expenses${queryFrom(params)}`)).data
  }

  async function createExpense(payload: Record<string, unknown>) {
    return (await api.post<ApiItemResponse<Record<string, unknown>>>('/expenses', payload)).data
  }

  async function submitExpense(id: string) {
    return (await api.post<ApiItemResponse<Record<string, unknown>>>(`/expenses/${id}/submit`)).data
  }

  async function decideExpense(id: string, decision: 'approved' | 'rejected', comment?: string) {
    return (await api.post<ApiItemResponse<Record<string, unknown>>>(`/expenses/${id}/decide`, { decision, comment })).data
  }

  async function payExpense(id: string, payload: { amount: number; payment_method: string; reference?: string; idempotency_key?: string }) {
    return (await api.post<ApiItemResponse<Record<string, unknown>>>(`/expenses/${id}/pay`, payload)).data
  }

  async function cancelExpense(id: string) {
    return (await api.post<ApiItemResponse<Record<string, unknown>>>(`/expenses/${id}/cancel`, {})).data
  }

  async function loadExpenseCategories(params: Record<string, string> = {}) {
    return (await api.get<ApiListResponse<Record<string, unknown>>>(`/expenses/categories${queryFrom(params)}`)).data
  }

  async function saveExpenseCategory(payload: Record<string, unknown>, id?: string) {
    if (id) return (await api.patch<ApiItemResponse<Record<string, unknown>>>(`/expense-categories/${id}`, payload)).data
    return (await api.post<ApiItemResponse<Record<string, unknown>>>('/expenses/categories', payload)).data
  }

  async function loadRecurringExpenses(params: Record<string, string> = {}) {
    return (await api.get<ApiListResponse<Record<string, unknown>>>(`/expenses/recurring${queryFrom(params)}`)).data
  }

  async function saveRecurringExpense(payload: Record<string, unknown>) {
    return (await api.post<ApiItemResponse<Record<string, unknown>>>('/expenses/recurring', payload)).data
  }

  async function generateRecurringExpenses() {
    return (await api.post<{ data: { created: number } }>('/expenses/recurring/generate')).data
  }

  async function loadExpenseReport(group = 'category', params: Record<string, string> = {}) {
    const query = new URLSearchParams({ ...params, group })
    return (await api.get<{ data: Record<string, unknown> }>(`/expenses/report?${query.toString()}`)).data
  }

  async function loadPurchaseOverview(params: { from?: string; to?: string; supplier_id?: string; warehouse_id?: string } = {}) {
    const query = new URLSearchParams()
    if (params.from) query.set('from', params.from)
    if (params.to) query.set('to', params.to)
    if (params.supplier_id) query.set('supplier_id', params.supplier_id)
    if (params.warehouse_id) query.set('warehouse_id', params.warehouse_id)
    const suffix = query.toString()
    return (await api.get<{ data: Record<string, unknown> }>(`/purchases/overview${suffix ? `?${suffix}` : ''}`)).data
  }

  async function loadPurchaseRequisitions(params: Record<string, string> = {}) {
    return (await api.get<ApiListResponse<Record<string, unknown>>>(`/purchase-requisitions${queryFrom(params)}`)).data
  }

  async function createPurchaseRequisition(payload: Record<string, unknown>) {
    return (await api.post<ApiItemResponse<Record<string, unknown>>>('/purchase-requisitions', payload)).data
  }

  async function actPurchaseRequisition(id: string, action: string, comment?: string) {
    return (await api.post<ApiItemResponse<Record<string, unknown>>>(`/purchase-requisitions/${id}/act`, { action, comment })).data
  }

  async function convertPurchaseRequisition(id: string, target: 'proforma' | 'purchase_order', supplierId?: string) {
    return (await api.post<{ data: { type: string; id: string; number: string } }>(`/purchase-requisitions/${id}/convert`, { target, supplier_id: supplierId })).data
  }

  async function loadPurchaseProformas(params: Record<string, string> = {}) {
    return (await api.get<ApiListResponse<Record<string, unknown>>>(`/purchase-proformas${queryFrom(params)}`)).data
  }

  async function createPurchaseProforma(payload: Record<string, unknown>) {
    return (await api.post<ApiItemResponse<Record<string, unknown>>>('/purchase-proformas', payload)).data
  }

  async function actPurchaseProforma(id: string, action: string) {
    return (await api.post<ApiItemResponse<Record<string, unknown>>>(`/purchase-proformas/${id}/act`, { action })).data
  }

  async function convertPurchaseProforma(id: string, warehouseId: string) {
    return (await api.post<{ data: { id: string; number: string } }>(`/purchase-proformas/${id}/convert`, { warehouse_id: warehouseId })).data
  }

  async function loadPurchaseReturns(params: Record<string, string> = {}) {
    return (await api.get<ApiListResponse<Record<string, unknown>>>(`/purchase-returns${queryFrom(params)}`)).data
  }

  async function createPurchaseReturn(payload: Record<string, unknown>) {
    return (await api.post<ApiItemResponse<Record<string, unknown>>>('/purchase-returns', payload)).data
  }

  async function actPurchaseReturn(id: string, action: string) {
    return (await api.post<ApiItemResponse<Record<string, unknown>>>(`/purchase-returns/${id}/act`, { action })).data
  }

  async function loadPurchasePayments() {
    return loadPaginated<{
      id: string
      payment_number: string
      amount: number
      payment_method: string
      reference?: string | null
      paid_at?: string | null
      invoice?: { id: string; invoice_number: string; supplier?: { id: string; name: string } | null } | null
    }>('/purchase-payments')
  }

  async function loadPurchaseInvoices(params: string | Record<string, string> = '') {
    loading.value = true
    try {
      const suffix = typeof params === 'string'
        ? (params ? `?status=${encodeURIComponent(params)}` : '')
        : queryFrom(params)
      purchaseInvoices.value = await loadPaginated<PurchaseInvoice>(`/purchase-invoices${suffix}`)
    } finally {
      loading.value = false
    }
  }

  // Inventory
  async function loadInventoryMovements(warehouseId: string) {
    return loadPaginated<InventoryMovement>(`/warehouses/${warehouseId}/movements`)
  }

  async function createInventoryMovement(
    warehouseId: string,
    payload: {
      product_id: string
      movement_type: string
      quantity: number
      notes?: string
    },
  ) {
    return (await api.post<ApiItemResponse<InventoryMovement>>(`/warehouses/${warehouseId}/movements`, payload)).data
  }

  async function loadStockBalances(warehouseId: string, inStockOnly = true) {
    loading.value = true
    try {
      const query = inStockOnly ? '?in_stock_only=1' : ''
      stockBalances.value = await loadPaginated<StockBalance>(`/warehouses/${warehouseId}/stock${query}`)
    } finally {
      loading.value = false
    }
  }

  async function loadStockTransfers() {
    loading.value = true
    try {
      stockTransfers.value = await loadPaginated<StockTransfer>('/stock-transfers')
    } finally {
      loading.value = false
    }
  }

  async function loadStockAdjustments(issuesOnly = false) {
    loading.value = true
    try {
      const query = issuesOnly ? '?issues_only=1' : ''
      stockAdjustments.value = await loadPaginated<StockAdjustment>(`/stock-adjustments${query}`)
    } finally {
      loading.value = false
    }
  }

  async function loadInventoryAlerts() {
    loading.value = true
    try {
      inventoryAlerts.value = await loadPaginated<InventoryAlert>('/inventory/alerts')
    } finally {
      loading.value = false
    }
  }

  async function acknowledgeInventoryAlert(alertId: string) {
    return (await api.post<ApiItemResponse<InventoryAlert>>(`/inventory/alerts/${alertId}/acknowledge`)).data
  }

  async function resolveInventoryAlert(alertId: string) {
    return (await api.post<ApiItemResponse<InventoryAlert>>(`/inventory/alerts/${alertId}/resolve`)).data
  }

  async function refreshInventoryAlerts() {
    await api.post('/inventory/alerts/refresh')
    return loadInventoryAlerts()
  }

  async function createStockTransfer(payload: {
    source_warehouse_id: string
    destination_warehouse_id: string
    notes?: string
    items: { product_id: string; quantity: number; product_variant_id?: string | null }[]
  }) {
    return (await api.post<ApiItemResponse<StockTransfer>>('/stock-transfers', payload)).data
  }

  async function loadStockTransfer(id: string) {
    return (await api.get<ApiItemResponse<StockTransferDetail>>(`/stock-transfers/${id}`)).data
  }

  async function confirmStockTransfer(id: string) {
    return (await api.post<ApiItemResponse<StockTransfer>>(`/stock-transfers/${id}/confirm`)).data
  }

  async function approveStockTransfer(id: string) {
    return (await api.post<ApiItemResponse<StockTransfer>>(`/stock-transfers/${id}/approve`)).data
  }

  async function shipStockTransfer(id: string) {
    return (await api.post<ApiItemResponse<StockTransfer>>(`/stock-transfers/${id}/ship`)).data
  }

  async function receiveStockTransfer(id: string) {
    return (await api.post<ApiItemResponse<StockTransfer>>(`/stock-transfers/${id}/receive`)).data
  }

  async function createStockAdjustment(payload: {
    warehouse_id: string
    movement_type: string
    reason?: string
    items: { product_id: string; quantity: number; sale_unit_id?: string | null; product_variant_id?: string | null }[]
  }) {
    return (await api.post<ApiItemResponse<StockAdjustment>>('/stock-adjustments', payload)).data
  }

  async function loadStockAdjustment(id: string) {
    return (await api.get<ApiItemResponse<StockAdjustmentDetail>>(`/stock-adjustments/${id}`)).data
  }

  async function confirmStockAdjustment(id: string) {
    return (await api.post<ApiItemResponse<StockAdjustment>>(`/stock-adjustments/${id}/confirm`)).data
  }

  async function completeStockAdjustment(id: string) {
    return (await api.post<ApiItemResponse<StockAdjustment>>(`/stock-adjustments/${id}/complete`)).data
  }

  async function loadInventoryCounts() {
    loading.value = true
    try {
      inventoryCounts.value = await loadPaginated<InventoryCount>('/inventory-counts')
    } finally {
      loading.value = false
    }
  }

  async function planCycleCount(payload: {
    warehouse_id: string
    counted_at: string
    zone?: string
    category_id?: string
    inventory_class?: string
    product_ids?: string[]
    notes?: string
    responsible_id?: string
  }) {
    return api.post<{ data: InventoryCountDetail; summary: FullCountSummary }>('/inventory-counts/cycle', payload)
  }

  async function suggestCycleCounts(warehouseId: string, categoryId?: string, inventoryClass?: string) {
    const query = new URLSearchParams({ warehouse_id: warehouseId })
    if (categoryId) query.set('category_id', categoryId)
    if (inventoryClass) query.set('inventory_class', inventoryClass)
    return (await api.get<{ data: CycleSuggestion[] }>(`/inventory-counts/cycle/suggestions?${query}`)).data
  }

  async function loadCycleDashboard(warehouseId: string) {
    return (await api.get<{ data: CycleDashboard }>(`/inventory-counts/cycle/dashboard?warehouse_id=${warehouseId}`)).data
  }

  async function generateCycleCounts(warehouseId: string) {
    return api.post<{ data: { created: number; count: InventoryCountDetail | null } }>('/inventory-counts/cycle/generate', { warehouse_id: warehouseId })
  }

  async function startCycleCount(id: string) {
    return api.post<{ data: InventoryCountDetail; summary: FullCountSummary }>(`/inventory-counts/${id}/start`)
  }

  async function saveCycleRules(rules: { product_id: string; inventory_class?: string | null; count_frequency?: string | null }[]) {
    return api.patch<{ updated: number }>('/inventory-cycle/rules', { rules })
  }

  async function startFullCount(payload: {
    warehouse_id: string
    counted_at: string
    zone?: string
    category_id?: string
    notes?: string
    lock_movements?: boolean
    responsible_id?: string
  }) {
    return api.post<{ data: InventoryCountDetail; summary: FullCountSummary }>('/inventory-counts/full', payload)
  }

  async function startSpotCount(payload: {
    warehouse_id: string
    counted_at: string
    notes?: string
    product_ids: string[]
  }) {
    return api.post<{ data: InventoryCountDetail; summary: FullCountSummary }>('/inventory-counts/spot', payload)
  }

  async function saveFullCountLines(id: string, lines: FullCountLineInput[]) {
    return api.patch<{ data: InventoryCountDetail; summary: FullCountSummary }>(`/inventory-counts/${id}/lines`, { lines })
  }

  async function submitFullCount(id: string) {
    return api.post<{ data: InventoryCountDetail; summary: FullCountSummary }>(`/inventory-counts/${id}/submit`)
  }

  async function reviewFullCount(id: string) {
    return api.post<{ data: InventoryCountDetail; summary: FullCountSummary }>(`/inventory-counts/${id}/review`)
  }

  async function approveFullCount(id: string) {
    return api.post<{ data: InventoryCountDetail; summary: FullCountSummary }>(`/inventory-counts/${id}/approve`)
  }

  async function cancelFullCount(id: string, reason?: string) {
    return api.post<{ data: InventoryCountDetail; summary: FullCountSummary }>(`/inventory-counts/${id}/cancel`, { reason })
  }

  async function loadOpenedProductIds(warehouseId: string) {
    return (await api.get<{ data: string[] }>(`/warehouses/${warehouseId}/opening-opened`)).data
  }

  async function createOpeningBalance(payload: {
    warehouse_id: string
    counted_at: string
    notes?: string
    items: { product_id: string; quantity: number; sale_unit_id?: string | null; unit_cost?: number }[]
  }) {
    return api.post<{ message: string; data: InventoryCount; lines: OpeningLine[] }>('/inventory-counts/opening', payload)
  }

  async function loadStockLedger(warehouseId: string) {
    return (await api.get<{ data: StockLedgerRow[] }>(`/warehouses/${warehouseId}/stock-ledger`)).data
  }

  async function createInventoryCount(payload: {
    warehouse_id: string
    count_type: string
    counted_at: string
    notes?: string
    items: { product_id: string; quantity: number }[]
  }) {
    return (await api.post<ApiItemResponse<InventoryCount>>('/inventory-counts', payload)).data
  }

  async function loadInventoryCount(id: string) {
    return (await api.get<ApiItemResponse<InventoryCountDetail>>(`/inventory-counts/${id}`)).data
  }

  async function updateInventoryCount(id: string, items: { product_id: string; quantity: number }[]) {
    return (await api.patch<ApiItemResponse<InventoryCountDetail>>(`/inventory-counts/${id}`, { items })).data
  }

  async function confirmInventoryCount(id: string) {
    return (await api.post<ApiItemResponse<InventoryCount>>(`/inventory-counts/${id}/confirm`)).data
  }

  async function completeInventoryCount(id: string) {
    return (await api.post<ApiItemResponse<InventoryCount>>(`/inventory-counts/${id}/complete`)).data
  }

  async function confirmPurchaseOrderStep(id: string) {
    return (await api.post<ApiItemResponse<PurchaseOrder>>(`/purchase-orders/${id}/confirm`)).data
  }

  async function loadAllProducts(): Promise<Product[]> {
    await loadCompanies()
    for (const company of companies.value) {
      const cats = await loadCatalogs(company.id)
      if (cats.length) {
        await loadProducts(cats[0].id)
        return products.value
      }
    }
    return []
  }

  // Sales
  async function loadSales(
    storeId: string,
    filters: {
      q?: string
      status?: string
      payment_status?: string
      customer_id?: string
      from?: string
      to?: string
      limit?: number
    } = {},
  ) {
    loading.value = true
    try {
      const params = new URLSearchParams()
      params.set('limit', String(filters.limit ?? 200))
      if (filters.q) params.set('q', filters.q)
      if (filters.status) params.set('status', filters.status)
      if (filters.payment_status) params.set('payment_status', filters.payment_status)
      if (filters.customer_id) params.set('customer_id', filters.customer_id)
      if (filters.from) params.set('from', filters.from)
      if (filters.to) params.set('to', filters.to)
      sales.value = (await api.get<ApiListResponse<Sale>>(`/stores/${storeId}/sales?${params}`)).data
      return sales.value
    } finally {
      loading.value = false
    }
  }

  async function exportSales(
    storeId: string,
    filters: {
      q?: string
      status?: string
      payment_status?: string
      customer_id?: string
      from?: string
      to?: string
    } = {},
  ) {
    const params = new URLSearchParams()
    if (filters.q) params.set('q', filters.q)
    if (filters.status) params.set('status', filters.status)
    if (filters.payment_status) params.set('payment_status', filters.payment_status)
    if (filters.customer_id) params.set('customer_id', filters.customer_id)
    if (filters.from) params.set('from', filters.from)
    if (filters.to) params.set('to', filters.to)
    const suffix = params.toString() ? `?${params}` : ''
    await api.download(`/stores/${storeId}/sales/export${suffix}`, `commandes-${storeId}.csv`)
  }

  async function loadSaleReceipt(saleId: string, format = 'thermal_80') {
    const issued = await api.post<ApiItemResponse<{ payload: Record<string, unknown> }>>(`/sales/${saleId}/receipt`, { format })
    return issued.data.payload
  }

  async function loadSaleInvoice(saleId: string, format = 'a4') {
    const issued = await api.post<ApiItemResponse<{ payload: Record<string, unknown> }>>(`/sales/${saleId}/invoice`, { format })
    return issued.data.payload
  }

  async function loadSale(id: string) {
    return (await api.get<ApiItemResponse<Sale>>(`/sales/${id}`)).data
  }

  async function loadSaleReturns(saleId: string) {
    return (await api.get<ApiListResponse<SaleReturn>>(`/sales/${saleId}/returns`)).data
  }

  async function loadStoreSaleReturns(storeId: string) {
    return (await api.get<ApiListResponse<SaleReturn>>(`/stores/${storeId}/sale-returns?limit=100`)).data
  }

  async function loadSaleReturn(id: string) {
    return (await api.get<ApiItemResponse<SaleReturn>>(`/sale-returns/${id}`)).data
  }

  async function loadReturnReasons() {
    return (await api.get<ApiListResponse<{ value: string; label: string }>>('/returns/reasons')).data
  }

  async function createSaleReturn(
    saleId: string,
    payload: {
      reason: string
      refund_method?: string
      notes?: string
      items: { sale_item_id: string; quantity: number }[]
    },
  ) {
    return (await api.post<ApiItemResponse<SaleReturn>>(`/sales/${saleId}/returns`, payload)).data
  }

  // Customer detail
  async function loadCustomerDetail(id: string) {
    return (await api.get<ApiItemResponse<Customer>>(`/customers/${id}`)).data
  }

  async function loadCustomerSummary(id: string) {
    return (await api.get<ApiItemResponse<CustomerSummary>>(`/customers/${id}/summary`)).data
  }

  async function loadCustomerHistory(id: string) {
    return api.get<{ data: CustomerStatementLine[]; meta: CustomerSummary }>(`/customers/${id}/history`)
  }

  async function loadCustomerPayments(id: string) {
    return (await api.get<ApiListResponse<CustomerPayment>>(`/customers/${id}/payments`)).data
  }

  async function redeemCustomerLoyalty(id: string, points: number) {
    return (await api.post<{ data: { points: number; tier: string; tier_label: string; next_tier: string | null; points_to_next: number | null } }>(`/customers/${id}/loyalty/redeem`, { points })).data
  }

  async function loadCustomerSales(id: string) {
    return (await api.get<ApiListResponse<Sale>>(`/customers/${id}/sales`)).data
  }

  async function recordCustomerPayment(
    customerId: string,
    payload: { amount: number; payment_method?: string; reference?: string; notes?: string },
  ) {
    return (await api.post<ApiItemResponse<CustomerPayment>>(`/customers/${customerId}/payments`, payload)).data
  }

  // Purchase orders
  async function loadPurchaseOrder(id: string) {
    return (await api.get<ApiItemResponse<PurchaseOrderDetail>>(`/purchase-orders/${id}`)).data
  }

  async function createPurchaseOrder(payload: {
    warehouse_id: string
    supplier_id?: string | null
    notes?: string
    expected_at?: string
    items: { product_id: string; quantity: number; unit_cost: number; product_variant_id?: string | null }[]
  }) {
    return (await api.post<ApiItemResponse<PurchaseOrderDetail>>('/purchase-orders', payload)).data
  }

  async function submitPurchaseOrder(id: string) {
    return (await api.post<ApiItemResponse<PurchaseOrderDetail>>(`/purchase-orders/${id}/submit`)).data
  }

  async function approvePurchaseOrder(id: string) {
    return (await api.post<ApiItemResponse<PurchaseOrderDetail>>(`/purchase-orders/${id}/approve`)).data
  }

  async function cancelPurchaseOrder(id: string) {
    return (await api.post<ApiItemResponse<PurchaseOrderDetail>>(`/purchase-orders/${id}/cancel`)).data
  }

  async function receivePurchaseOrder(
    id: string,
    payload: { notes?: string; items: { purchase_order_item_id: string; quantity: number }[] },
  ) {
    return (await api.post<ApiItemResponse<unknown>>(`/purchase-orders/${id}/receive`, payload)).data
  }

  // Audit
  async function loadAuditLogs(params: Record<string, string> = {}) {
    loading.value = true
    try {
      const q = new URLSearchParams({ per_page: '100', ...params }).toString()
      auditLogs.value = await loadPaginated<AuditLog>(`/audit-logs?${q}`)
    } finally {
      loading.value = false
    }
  }

  // Accounting
  async function loadAccountingEntries(params: Record<string, string> = {}) {
    loading.value = true
    try {
      const q = new URLSearchParams({ per_page: '100', ...params }).toString()
      accountingEntries.value = await loadPaginated<AccountingEntry>(`/accounting/entries?${q}`)
    } finally {
      loading.value = false
    }
  }

  async function loadAccountingSummary(from?: string, to?: string) {
    const q = new URLSearchParams()
    if (from) q.set('from', from)
    if (to) q.set('to', to)
    const suffix = q.toString() ? `?${q}` : ''
    return (await api.get<ApiItemResponse<AccountingSummary>>(`/accounting/summary${suffix}`)).data
  }

  async function createAccountingEntry(payload: {
    entry_type: string
    reference_type: string
    reference_id: string
    debit: number
    credit: number
    account_code?: string
    description?: string
  }) {
    return (await api.post<ApiItemResponse<AccountingEntry>>('/accounting/entries', payload)).data
  }

  // Reports
  async function loadPosOverview(storeId: string, date?: string) {
    const q = date ? `?date=${encodeURIComponent(date)}` : ''
    return (await api.get<ApiItemResponse<PosOverview>>(`/stores/${storeId}/pos/overview${q}`)).data
  }

  async function loadSalesReport(params: { store_id?: string; from?: string; to?: string } = {}) {
    const q = new URLSearchParams()
    Object.entries(params).forEach(([k, v]) => { if (v) q.set(k, v) })
    const suffix = q.toString() ? `?${q}` : ''
    return api.get<{ data: SalesReport; meta: { by_store: { store_id: string; store_name: string; sales_count: number; revenue: number }[]; from?: string; to?: string } }>(`/reports/sales${suffix}`)
  }

  async function loadInventoryReport(params: { warehouse_id?: string; from?: string; to?: string } = {}) {
    const q = new URLSearchParams()
    Object.entries(params).forEach(([k, v]) => { if (v) q.set(k, v) })
    const suffix = q.toString() ? `?${q}` : ''
    return (await api.get<ApiItemResponse<InventoryReport>>(`/reports/inventory${suffix}`)).data
  }

  async function loadFinancialReport(from?: string, to?: string) {
    const q = new URLSearchParams()
    if (from) q.set('from', from)
    if (to) q.set('to', to)
    const suffix = q.toString() ? `?${q}` : ''
    return (await api.get<ApiItemResponse<FinancialReport>>(`/reports/financial${suffix}`)).data
  }

  async function exportSalesReport(params: { store_id?: string; from?: string; to?: string } = {}) {
    const q = new URLSearchParams()
    Object.entries(params).forEach(([k, v]) => { if (v) q.set(k, v) })
    const suffix = q.toString() ? `?${q}` : ''
    await api.download(`/reports/export/sales${suffix}`, 'sales-export.csv')
  }

  async function exportInventoryReport(warehouseId?: string) {
    const q = warehouseId ? `?warehouse_id=${warehouseId}` : ''
    await api.download(`/reports/export/inventory${q}`, 'inventory-export.csv')
  }

  // Serial numbers
  async function loadSerialNumbers(params: Record<string, string> = {}) {
    loading.value = true
    try {
      const q = new URLSearchParams({ per_page: '100', ...params }).toString()
      serialNumbers.value = await loadPaginated<SerialNumber>(`/serial-numbers?${q}`)
    } finally {
      loading.value = false
    }
  }

  async function saveSerialNumber(
    payload: {
      product_id: string
      serial_number: string
      warehouse_id?: string | null
      batch_id?: string | null
      status?: string
    },
    id?: string,
  ) {
    if (id) {
      return (await api.patch<ApiItemResponse<SerialNumber>>(`/serial-numbers/${id}`, payload)).data
    }
    return (await api.post<ApiItemResponse<SerialNumber>>('/serial-numbers', payload)).data
  }

  async function deleteSerialNumber(id: string) {
    await api.delete(`/serial-numbers/${id}`)
  }

  // Batches
  async function loadProductBatches(productId: string) {
    productBatches.value = (await api.get<ApiListResponse<ProductBatch>>(`/products/${productId}/batches`)).data
    return productBatches.value
  }

  async function createProductBatch(
    productId: string,
    payload: {
      batch_number: string
      quantity?: number
      warehouse_id?: string
      expires_at?: string
      unit_cost?: number
    },
  ) {
    return (await api.post<ApiItemResponse<ProductBatch>>(`/products/${productId}/batches`, payload)).data
  }

  // Import / Export products
  async function exportProducts(catalogId?: string) {
    const q = catalogId ? `?catalog_id=${catalogId}` : ''
    await api.download(`/import-export/products/export${q}`, 'products-export.csv')
  }

  async function downloadProductTemplate() {
    await api.download('/import-export/products/template', 'products-import-template.csv')
  }

  async function importProducts(catalogId: string, file: File, updateExisting = true) {
    const form = new FormData()
    form.append('catalog_id', catalogId)
    form.append('file', file)
    form.append('update_existing', updateExisting ? '1' : '0')
    return (await api.upload<ApiItemResponse<ImportResult>>('/import-export/products/import', form)).data
  }

  return {
    companies, branches, catalogs, categories, brands, units, taxes, currencies, paymentMethods, promotions, promotionTypes, products,
    stores, warehouses, devices, cashRegisters, cashierShifts, currentCashierShift, users, roles, permissions, storeProducts, stats,
    catalogAttributes,
    suppliers, customers, purchaseOrders, purchaseInvoices,
    payablesSummary, payablesSchedule, supplierPayments,
    stockBalances, stockTransfers, stockAdjustments, inventoryCounts, inventoryAlerts, sales,
    auditLogs, accountingEntries, serialNumbers, productBatches,
    loading,
    loadStats, loadCompanies, loadCompanyDetail, saveCompany, deleteCompany, uploadCompanyLogo, deleteCompanyLogo,
    loadCurrencies, saveCurrency, deleteCurrency,
    loadPaymentMethods, savePaymentMethod, updatePaymentMethod, deletePaymentMethod, reorderPaymentMethods,
    loadBranches, saveBranch, deleteBranch, loadBranchProfile, addBranchExpense, loadStores, saveStore, deleteStore,
    loadWarehouses, saveWarehouse, deleteWarehouse, loadDevices, saveDevice, deleteDevice, revokeDevice, regenerateDeviceToken,
    loadCashRegisters, saveCashRegister, deleteCashRegister,
    loadStoreCashierShifts, loadCashierShiftDetail, loadCurrentCashierShift, openCashierShift, closeCashierShift,
    getCurrentRegisterSession, openRegisterSession, closeRegisterSession, recordRegisterMovement,
    loadUsers, loadUserSessions, resetUserPassword, setUserActive, revokeUserSessions, loadRoles, loadPermissions, saveRole, deleteRole, assignUserRole, assignUserStore, removeUserRole,
    loadCatalogs, saveCatalog, deleteCatalog, loadCategories, saveCategory, deleteCategory,
    loadBrands, saveBrand, deleteBrand, loadUnits, saveUnit, deleteUnit,
    loadCatalogAttributes, saveCatalogAttribute, deleteCatalogAttribute,
    loadTaxes, saveTax, deleteTax,
    loadPromotionTypes, loadPromotions, savePromotion, deletePromotion,
    loadProducts, loadPriceList, loadProduct, saveProduct, deleteProduct, transformProductOptions,
    generateBarcode, printBarcode,
    uploadProductImage, deleteProductImage, setPrimaryImage,
    loadStoreProducts, importToStore, updateStoreProduct, removeFromStore,
    loadAllWarehouses,
    loadSuppliers, saveSupplier, deleteSupplier,
    loadPayablesSummary, loadPayablesSchedule, loadRecentSupplierPayments,
    loadSupplierSummary, loadSupplierDetail, loadSupplierStatement, loadSupplierDueDates,
    loadSupplierPayments, loadSupplierProducts, attachSupplierProduct, detachSupplierProduct, loadSupplierOrders, loadSupplierInvoices, recordSupplierPayment, recordPurchaseInvoicePayment,
    loadCustomers, saveCustomer, deleteCustomer,
    loadPurchaseOrders, loadPurchaseInvoices, loadPurchasePayments,
    loadExpenseDashboard, loadExpenses, createExpense, submitExpense, decideExpense, payExpense, cancelExpense,
    loadExpenseCategories, saveExpenseCategory, loadRecurringExpenses, saveRecurringExpense, generateRecurringExpenses, loadExpenseReport,
    loadPurchaseOverview, loadPurchaseRequisitions, createPurchaseRequisition, actPurchaseRequisition, convertPurchaseRequisition,
    loadPurchaseProformas, createPurchaseProforma, actPurchaseProforma, convertPurchaseProforma,
    loadPurchaseReturns, createPurchaseReturn, actPurchaseReturn,
    loadStockBalances, loadStockTransfers, loadStockAdjustments, loadInventoryAlerts,
    acknowledgeInventoryAlert, resolveInventoryAlert, refreshInventoryAlerts,
    createStockTransfer, loadStockTransfer, confirmStockTransfer, approveStockTransfer, shipStockTransfer, receiveStockTransfer,
    createStockAdjustment, loadStockAdjustment, confirmStockAdjustment, completeStockAdjustment,
    loadInventoryCounts, loadInventoryCount, createInventoryCount, createOpeningBalance, loadOpenedProductIds, loadStockLedger,
    loadTaxReport, loadTaxRegister, calculateTaxes, loadTaxGroups, saveTaxGroup, deleteTaxGroup,
    loadTaxClasses, saveTaxClass, deleteTaxClass, loadTaxRules, saveTaxRule, deleteTaxRule,
    startFullCount, startSpotCount, saveFullCountLines, submitFullCount, reviewFullCount, approveFullCount, cancelFullCount,
    planCycleCount, suggestCycleCounts, loadCycleDashboard, generateCycleCounts, startCycleCount, saveCycleRules,
    updateInventoryCount, confirmInventoryCount, completeInventoryCount,
    confirmPurchaseOrderStep,
    loadAllProducts,
    loadSales, exportSales, loadSaleReceipt, loadSaleInvoice, loadSale, loadSaleReturns, loadStoreSaleReturns, loadSaleReturn, loadReturnReasons, createSaleReturn,
    loadCustomerDetail, loadCustomerSummary, loadCustomerHistory, loadCustomerPayments, redeemCustomerLoyalty,
    loadCustomerSales, recordCustomerPayment,
    loadCustomerAddresses, saveCustomerAddress, deleteCustomerAddress,
    loadSupplierContacts, saveSupplierContact, deleteSupplierContact,
    loadInventoryMovements, createInventoryMovement,
    loadPurchaseOrder, createPurchaseOrder, submitPurchaseOrder, approvePurchaseOrder,
    cancelPurchaseOrder, receivePurchaseOrder,
    saveUser, deleteUser,
    loadAuditLogs,
    loadAccountingEntries, loadAccountingSummary, createAccountingEntry,
    loadSalesReport, loadInventoryReport, loadFinancialReport,
    loadPosOverview,
    exportSalesReport, exportInventoryReport,
    loadSerialNumbers, saveSerialNumber, deleteSerialNumber,
    loadProductBatches, createProductBatch,
    exportProducts, downloadProductTemplate, importProducts,
  }
})
