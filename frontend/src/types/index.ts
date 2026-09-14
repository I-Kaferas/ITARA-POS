export interface User {
  id: string
  name: string
  email: string
  phone?: string | null
  country?: string | null
  pin?: string | null
  tenant_id: string | null
  is_super_admin?: boolean
  modules?: string[]
  is_active?: boolean
  email_verified?: boolean
  two_factor_enabled?: boolean
  created_at?: string | null
  last_seen_at?: string | null
  active_sessions_count?: number
  roles?: UserRoleAssignment[]
  store_ids?: string[]
  stores?: { id: string; name: string; code?: string | null }[]
}

export interface UserSession {
  id: string
  device_name?: string | null
  ip_address?: string | null
  last_used_at?: string | null
  created_at?: string | null
}

export interface UserRoleAssignment {
  id: string
  slug: string
  name: string
  branch_id?: string | null
  store_id?: string | null
}

export interface Role {
  id: string
  name: string
  slug: string
  is_system: boolean
  permissions?: Permission[]
}

export interface Permission {
  id: string
  slug: string
  name: string
  group: string
}

export interface CompanyAddress {
  street?: string
  number?: string
  avenue?: string
  quarter?: string
  commune?: string
  city?: string
  province?: string
  state?: string
  postal_code?: string
  country?: string
}

export interface CompanySettings {
  timezone?: string
  locale?: string
  receipt_footer?: string
  legal_mentions?: string
  /** When true, invoices must display VAT (HT / TVA / TTC). */
  vat_registered?: boolean
  company_type?: string
  moral_person?: string
  subject_to_tc?: boolean
  subject_to_pf?: boolean
  fiscal_center?: string
  dpmc?: string
  activity_sector?: string
  vat_status?: string
}

export interface Company {
  id: string
  tenant_id: string
  name: string
  trade_name?: string | null
  legal_name?: string | null
  legal_form?: string | null
  tax_id?: string | null
  registration_number?: string | null
  phone?: string | null
  email?: string | null
  website?: string | null
  logo_url?: string | null
  currency_code: string
  locale?: string
  timezone?: string
  taxes?: Tax[]
  address?: CompanyAddress | null
  settings?: CompanySettings | null
  is_active: boolean
  branches?: Branch[]
}

export interface Currency {
  id: string
  tenant_id: string
  code: string
  name: string
  symbol?: string | null
  decimal_places: number
  exchange_rate: number
  is_default: boolean
  is_active: boolean
}

export interface CompanyPaymentMethod {
  id: string
  value: string
  code: string
  label: string
  label_fr?: string | null
  provider?: string
  requires_customer: boolean
  supports_change: boolean
  is_enabled: boolean
  available_on_pos: boolean
  sort_order: number
  is_system?: boolean
  settle_as?: string
  config?: Record<string, unknown>
}

export interface Branch {
  id: string
  tenant_id: string
  company_id: string
  name: string
  code: string
  is_active: boolean
  settings?: { timezone?: string; receipt_footer?: string } | null
  stores?: Store[]
  warehouses?: Warehouse[]
  stock?: { lines: number; warehouses: Warehouse[] }
  users?: Array<{ id: string; name: string; email: string }>
  registers?: Array<{ id: string; store_id: string; store_name: string; name: string; code: string; is_active: boolean }>
  sales_count?: number
  expenses?: BranchExpense[]
}

export interface BranchExpense {
  id: string
  branch_id: string
  store_id?: string | null
  category: string
  description: string
  amount: number
  currency_code: string
  occurred_on: string
}

export interface Store {
  id: string
  tenant_id: string
  branch_id: string
  name: string
  code: string
  kind?: 'store' | 'boutique'
  is_active: boolean
  branch?: Branch & { company?: Company }
}

export interface Warehouse {
  id: string
  tenant_id: string
  branch_id: string
  name: string
  code: string
  is_active: boolean
}

export type DeviceCategory = 'pos' | 'printer' | 'tablet' | 'computer' | 'other' | 'scanner'
export type DeviceConnection = 'network' | 'usb' | 'bluetooth'
export type DeviceRole = 'master' | 'slave' | 'standalone'
export type DeviceRegistration = 'pending' | 'registered' | 'revoked'
export type DeviceStatus = 'pending' | 'active' | 'revoked'

export interface Device {
  id: string
  tenant_id: string
  store_id: string
  name: string
  device_type: DeviceCategory
  category?: DeviceCategory
  pos_role?: DeviceRole
  code?: string | null
  identifier: string
  user?: { id: string; name: string } | null
  branch?: { id: string; name: string } | null
  app_version?: string | null
  last_sync?: string | null
  status?: DeviceStatus
  local_server?: string | null
  connection_type?: DeviceConnection | null
  ip_address?: string | null
  port?: number | null
  description?: string | null
  registration_status?: DeviceRegistration
  sync_token?: string | null
  platform?: string | null
  is_active: boolean
  last_sync_at?: string | null
  warehouse_ids?: string[]
  warehouses?: Array<Pick<Warehouse, 'id' | 'name' | 'code'>>
}

export interface CashRegister {
  id: string
  tenant_id: string
  store_id: string
  device_id?: string | null
  name: string
  code: string
  is_active: boolean
  open_session?: CashRegisterSession | null
}

export interface CashRegisterSession {
  id: string
  cash_register_id: string
  status: 'open' | 'closed'
  opening_balance: number
  sales_total: number
  cash_in_total: number
  cash_out_total: number
  expenses_total: number
  expected_cash: number
  actual_cash?: number | null
  variance?: number | null
  variance_reason?: string | null
  opening_notes?: string | null
  closing_notes?: string | null
  opened_at: string
  closed_at?: string | null
  opened_by_user?: { id: string; name: string }
}

export interface RegisterSummary {
  session_id: string
  status: string
  opening_balance: number
  sales_total: number
  cash_in_total: number
  cash_out_total: number
  expenses_total: number
  expected_cash: number
  actual_cash?: number | null
  variance?: number | null
  variance_reason?: string | null
  opened_at: string
  closed_at?: string | null
  invoices_count?: number
  invoices_total?: number
  invoices?: Array<{
    reference: string
    total: number
    completed_at?: string | null
    currency?: string | null
  }>
  payment_methods?: Array<{
    method: string
    label: string
    count: number
    amount: number
  }>
}

export interface CashMovement {
  id: string
  cash_register_id: string
  cash_register_session_id?: string | null
  cashier_shift_id?: string | null
  movement_type: string
  amount: number
  reference?: string | null
  description?: string | null
  occurred_at?: string
  performed_by?: string | null
  performedBy?: { id: string; name: string } | null
}

export interface CashierShift {
  id: string
  cashier_id: string
  cash_register_id: string
  cash_register_session_id: string
  status: 'open' | 'closed'
  opening_balance: number
  sales_total: number
  refunds_total: number
  discounts_total: number
  cash_in_total: number
  cash_out_total: number
  expenses_total: number
  expected_cash: number
  actual_cash?: number | null
  variance?: number | null
  variance_reason?: string | null
  opening_notes?: string | null
  closing_notes?: string | null
  opened_at: string
  closed_at?: string | null
  cashier?: { id: string; name: string }
  cash_register?: CashRegister
  movements?: CashMovement[]
}

export interface ShiftSummary {
  shift_id: string
  cashier_id: string
  cash_register_id: string
  status: string
  opening_balance: number
  sales_count?: number
  sales_total: number
  refunds_total: number
  discounts_total: number
  cash_in_total: number
  cash_out_total: number
  expenses_total: number
  expected_cash: number
  actual_cash?: number | null
  variance?: number | null
  variance_reason?: string | null
  opened_at: string
  closed_at?: string | null
  invoices_count?: number
  invoices_total?: number
  invoices?: Array<{
    reference: string
    total: number
    completed_at?: string | null
    currency?: string | null
  }>
  payment_methods?: Array<{
    method: string
    label: string
    count: number
    amount: number
  }>
}

export type TenantUser = User

export interface Catalog {
  id: string
  tenant_id: string
  company_id: string
  name: string
  description?: string | null
  is_default: boolean
  is_active: boolean
}

export interface Category {
  id: string
  tenant_id: string
  catalog_id: string
  parent_id?: string | null
  name: string
  slug: string
  sort_order: number
  is_active: boolean
  children?: Category[]
  parent?: Category | null
}

export interface CatalogAttribute {
  id: string
  name: string
  code: string
  values: string[]
  sort_order?: number
  is_active: boolean
}

export interface Brand {
  id: string
  name: string
  slug: string
  description?: string | null
  is_active: boolean
}

export interface Unit {
  id: string
  code: string
  name: string
  symbol?: string | null
  is_fractional: boolean
  is_active: boolean
}

export interface Tax {
  id: string
  name: string
  code: string
  rate: number
  type?: string
  priority?: number
  country?: string | null
  region?: string | null
  is_inclusive: boolean
  is_compound?: boolean
  is_active: boolean
  description?: string | null
}

export interface TaxGroup {
  id: string
  name: string
  code: string
  description?: string | null
  is_active: boolean
  taxes?: Tax[]
}

export interface TaxClass {
  id: string
  name: string
  code: string
  description?: string | null
  is_active: boolean
}

export interface TaxRule {
  id: string
  name: string
  tax_class_id?: string | null
  tax_id?: string | null
  tax_group_id?: string | null
  country?: string | null
  region?: string | null
  priority: number
  is_active: boolean
  description?: string | null
  tax_class?: { id: string; name: string; code: string } | null
  tax?: { id: string; name: string; code: string } | null
  tax_group?: { id: string; name: string; code: string } | null
}

export interface TaxReportRow {
  tax_id?: string | null
  code?: string | null
  name?: string | null
  rate: number
  lines: number
  taxable_amount: number
  tax_amount: number
}

export interface TaxRegisterRow {
  id: string
  sale_id: string
  reference?: string | null
  occurred_at?: string | null
  tax_id?: string | null
  code?: string | null
  name?: string | null
  rate: number
  taxable_amount: number
  tax_amount: number
}

export type PromotionType =
  | 'percentage_discount'
  | 'fixed_discount'
  | 'buy_x_get_y'
  | 'bundle'
  | 'quantity_discount'
  | 'category_discount'
  | 'customer_discount'
  | 'time_based'

export interface PromotionItem {
  id?: string
  product_id?: string | null
  product_variant_id?: string | null
  role: 'target' | 'trigger' | 'reward' | 'bundle'
  quantity: number
  product?: Product
}

export interface PromotionSchedule {
  days_of_week?: number[]
  time_start?: string
  time_end?: string
}

export interface Promotion {
  id: string
  tenant_id?: string
  store_id?: string | null
  category_id?: string | null
  name: string
  code?: string | null
  type: PromotionType
  description?: string | null
  starts_at?: string | null
  ends_at?: string | null
  min_quantity: number
  max_uses?: number | null
  uses_count?: number
  priority: number
  discount_percent?: number | null
  discount_amount?: number | null
  buy_quantity?: number | null
  get_quantity?: number | null
  bundle_price?: number | null
  schedule?: PromotionSchedule | null
  is_active: boolean
  items?: PromotionItem[]
  customers?: { id: string; customer_id: string; customer?: Customer }[]
  category?: Category
  store?: Store
}

export interface PromotionTypeMeta {
  value: PromotionType
  label: string
  label_fr: string
  requires: string[]
}

export type BarcodeType = 'ean13' | 'ean8' | 'upc' | 'code128' | 'qr' | 'internal'

export interface Barcode {
  id?: string
  barcode: string
  type: BarcodeType | string
  is_primary?: boolean
}

export interface Price {
  id?: string
  price_type: string
  amount: number
  currency_code?: string
  store_id?: string | null
  min_quantity?: number
  is_active?: boolean
}

export type ProductType = 'simple' | 'variant' | 'batch' | 'service' | 'digital' | 'bundle'

export interface ProductVariant {
  id?: string
  sku: string
  name?: string | null
  size?: string | null
  color?: string | null
  color_hex?: string | null
  base_price: number
  cost_price?: number
  sort_order?: number
  is_active?: boolean
  attributes?: { options?: Record<string, string> } | null
  barcodes?: Partial<Barcode>[]
  prices?: Partial<Price>[]
}

export interface ProductBundleItem {
  id?: string
  component_product_id: string
  component_variant_id?: string | null
  quantity: number
  sort_order?: number
}

export interface ProductImage {
  id: string
  product_id: string
  cdn_url: string
  original_filename?: string | null
  mime_type: string
  file_size: number
  sort_order: number
  is_primary: boolean
}

export interface Product {
  id: string
  tenant_id: string
  catalog_id: string
  category_id?: string | null
  product_type?: ProductType
  brand_id?: string | null
  unit_id?: string | null
  tax_id?: string | null
  sku: string
  name: string
  description?: string | null
  barcode?: string | null
  unit: string
  bottle_volume_ml?: number | null
  base_price: number
  cost_price: number
  stock?: number
  created_at?: string | null
  is_active: boolean
  is_serialized?: boolean
  track_batch?: boolean
  track_expiration?: boolean
  expiration_days?: number | null
  category?: Category | null
  brand?: Brand | null
  sale_units?: { id: string; name: string; volume_ml: number; is_base?: boolean }[]
  unit_model?: { id: string; name: string; symbol?: string | null; code?: string } | null
  tax?: { id: string; name: string; code?: string; rate?: number } | null
  images?: ProductImage[]
  barcodes?: Barcode[]
  prices?: Price[]
  variants?: ProductVariant[]
  bundle_items?: ProductBundleItem[]
  metadata?: { option_groups?: { name: string; values: string[] }[] } | null
}

export interface StoreProductItem {
  id: string
  product_id: string
  is_available: boolean
  price_override?: number | null
  effective_price: number
  imported_at: string
  product: Product
}

export interface DashboardStats {
  companies: number
  catalogs: number
  products: number
  stores: number
  store_imports: number
}

export interface Paginated<T> {
  data: T[]
  current_page: number
  last_page: number
  per_page: number
  total: number
}

export interface Supplier {
  id: string
  name: string
  code: string
  legal_name?: string | null
  contact_person?: string | null
  tax_id?: string | null
  email?: string | null
  phone?: string | null
  address?: { line1?: string | null; city?: string | null; country?: string | null } | null
  payment_terms_days?: number | null
  credit_limit?: number | null
  currency_code?: string
  contacts?: SupplierContact[]
  is_active: boolean
}

export interface SupplierContact {
  id: string
  supplier_id: string
  name: string
  title?: string | null
  email?: string | null
  phone?: string | null
  is_primary: boolean
  notes?: string | null
}

export interface SupplierSummary {
  supplier_id: string
  balance: number
  debt: number
  credit: number
  total_purchases: number
  total_payments: number
  open_invoices: number
  overdue_invoices: number
}

export interface PayablesSummary {
  total_debt: number
  total_overdue: number
  open_invoices: number
  overdue_invoices: number
  suppliers_with_debt: number
  suppliers: PayableSupplierRow[]
}

export interface PayableSupplierRow {
  supplier_id: string
  supplier_name: string
  supplier_code: string
  debt: number
  credit: number
  overdue_amount: number
  open_invoices: number
  overdue_invoices: number
}

export interface PayableScheduleItem {
  id: string
  supplier_id: string
  supplier_name: string
  supplier_code: string
  reference: string | null
  due_date: string | null
  amount: number
  outstanding: number
  is_overdue: boolean
}

export interface SupplierStatementLine {
  id: string
  occurred_at: string
  transaction_type: string
  reference: string | null
  description: string | null
  debit: number
  credit: number
  balance: number
  due_date: string | null
  outstanding: number
}

export interface SupplierPayment {
  id: string
  payment_number: string
  amount: number
  payment_method: string
  reference?: string | null
  notes?: string | null
  status: string
  paid_at: string
  supplier?: { id: string; name: string; code: string } | null
  recorded_by?: { id: string; name: string } | null
}

export interface DueDateItem {
  id: string
  reference: string | null
  due_date: string | null
  amount: number
  outstanding: number
  is_overdue: boolean
}

export interface SupplierDueDates {
  open: DueDateItem[]
  overdue: DueDateItem[]
}

export interface Customer {
  id: string
  name: string
  code?: string | null
  company_name?: string | null
  tax_id?: string | null
  email?: string | null
  phone?: string | null
  date_of_birth?: string | null
  credit_limit?: number | null
  loyalty_points?: number
  loyalty_tier?: string | null
  payment_terms_days?: number | null
  notes?: string | null
  metadata?: Record<string, unknown> | null
  addresses?: CustomerAddress[]
  is_active: boolean
  created_at?: string
}

export interface CustomerAddress {
  id: string
  customer_id: string
  label?: string | null
  line1: string
  line2?: string | null
  city?: string | null
  state?: string | null
  postal_code?: string | null
  country_code?: string | null
  is_primary: boolean
  is_billing: boolean
  is_shipping: boolean
}

export interface PurchaseOrder {
  id: string
  order_number: string
  status: string
  supplier_id?: string | null
  warehouse_id: string
  total: number
  subtotal?: number
  tax_total?: number
  expected_at?: string | null
  created_at?: string
  supplier?: { id: string; name: string; code: string } | null
  warehouse?: { id: string; name: string; code: string } | null
}

export interface PurchaseInvoice {
  id: string
  invoice_number: string
  status: string
  total: number
  paid_amount: number
  invoiced_at?: string | null
  supplier?: { id: string; name: string; code: string } | null
  purchase_order?: { id: string; order_number: string } | null
}

export interface StockBalance {
  id: string
  product_id: string
  quantity_on_hand: number
  quantity_available: number
  quantity_reserved?: number
  product?: {
    id: string
    sku: string
    name: string
    unit?: string | null
    base_price?: number | null
    is_active?: boolean
    product_type?: string | null
    category?: { id: string; name: string } | null
    unit_model?: { id: string; name: string; symbol?: string | null } | null
  } | null
  product_variant?: { id: string; sku: string; name: string } | null
  batch?: { id: string; batch_number: string } | null
}

export interface InventoryMovement {
  id: string
  movement_type: string
  spec_code?: string
  quantity: number
  balance_after?: number
  notes?: string | null
  occurred_at?: string | null
  product?: { id: string; sku: string; name: string } | null
  product_variant?: { id: string; sku: string; name: string } | null
  performed_by?: { id: string; name: string } | null
}

export interface StockTransfer {
  id: string
  transfer_number: string
  status: string
  source_warehouse_id: string
  destination_warehouse_id: string
  created_at?: string
  shipped_at?: string | null
  received_at?: string | null
  source_warehouse?: { id: string; name: string; code: string } | null
  destination_warehouse?: { id: string; name: string; code: string } | null
}

export interface StockAdjustment {
  id: string
  adjustment_number: string
  status: string
  warehouse_id: string
  movement_type?: string
  reason?: string | null
  created_at?: string
  warehouse?: { id: string; name: string; code: string } | null
}

export interface OpeningLine {
  product_id: string
  name: string
  category?: string | null
  unit_name: string
  entered_quantity: number
  unit_volume_ml?: number | null
  base_quantity: number
  unit_cost: number
  line_value: number
  display: string
  base_unit: string
  performed_by?: string | null
}

export interface StockLedgerRow {
  product_id: string
  name: string
  sku: string
  category?: string | null
  opening: number
  purchases: number
  entries: number
  sales: number
  losses: number
  adjustments_in: number
  adjustments_out: number
  calculated: number
  quantity_on_hand: number
  display: string
  base_unit: string
  average_cost: number
  stock_value: number
  low_stock_threshold: number | null
  low_stock: boolean
  formula: string
}

export interface InventoryCountItem {
  id: string
  product_id: string
  counted_quantity: number
  entered_quantity?: number | null
  remainder_ml?: number | null
  unit_name?: string | null
  unit_volume_ml?: number | null
  variance_reason?: string | null
  notes?: string | null
  system_quantity?: number | null
  sale_unit_id?: string | null
  product?: {
    id: string
    sku: string
    barcode?: string | null
    barcodes?: { barcode: string }[]
    name: string
    unit?: string
    bottle_volume_ml?: number | null
    cost_price?: number
    category?: { id: string; name: string } | null
    sale_units?: { id: string; name: string; volume_ml: number; is_base?: boolean }[]
  } | null
}

export interface CycleSuggestion {
  product_id: string
  name: string
  sku: string
  category?: string | null
  inventory_class?: string | null
  count_frequency?: string | null
  last_counted_at?: string | null
  next_count_at?: string | null
  error_count: number
  score: number
  priority: 'high' | 'normal'
}

export interface CycleDashboard {
  planned: number
  completed: number
  overdue: number
  accuracy: number
  counted_lines: number
  matched_lines: number
  top_variances: { product_id: string; name?: string | null; variances: number }[]
}

export interface FullCountSummary {
  total_products: number
  counted_products: number
  matched: number
  shortage: number
  surplus: number
  shortage_value: number
  surplus_value: number
  net_value: number
}

export interface FullCountLineInput {
  id: string
  entered_quantity?: number | null
  remainder_ml?: number | null
  sale_unit_id?: string | null
  variance_reason?: string | null
  notes?: string | null
}

export interface InventoryCount {
  id: string
  count_number: string
  count_type?: string
  counted_at?: string | null
  status: string
  warehouse_id: string
  notes?: string | null
  created_at?: string
  items_count?: number
  warehouse?: { id: string; name: string; code: string } | null
  items?: InventoryCountItem[]
}

export interface InventoryCountDetail extends InventoryCount {
  items: InventoryCountItem[]
  confirmed_at?: string | null
  performed_by?: { id: string; name: string } | null
  confirmed_by?: { id: string; name: string } | null
  approved_by?: { id: string; name: string } | null
}

export interface InventoryAlert {
  id: string
  alert_type: string
  status: string
  quantity_on_hand?: number | null
  threshold_value?: number | null
  message?: string | null
  created_at?: string
  product?: { id: string; sku: string; name: string } | null
  warehouse?: { id: string; name: string; code: string } | null
}

export interface PosOverview {
  date: string
  store_id: string
  kpis: {
    sales_count: number
    revenue: number
    paid_amount: number
    average_ticket: number
  }
  best_selling_products: Array<{
    product_id?: string | null
    product_name: string
    product_sku?: string | null
    quantity: number
    revenue: number
  }>
  recent_orders: Sale[]
  payment_methods: Array<{
    payment_method: string
    label: string
    amount: number
    count: number
    share: number
  }>
  sales_by_hour: Array<{
    hour: number
    label: string
    sales_count: number
    revenue: number
  }>
}

export interface Sale {
  id: string
  reference: string
  status: string
  store_id: string
  customer_id?: string | null
  warehouse_id?: string | null
  subtotal: number
  tax_total: number
  discount_total: number
  fees_total: number
  total: number
  paid_amount: number
  outstanding_amount?: number
  due_date?: string | null
  payment_status: string
  currency?: string
  payment_transaction_number?: string | null
  completed_at?: string | null
  created_at?: string
  notes?: string | null
  customer?: { id: string; name: string; email?: string } | null
  processed_by?: { id: string; name: string } | null
  items?: SaleItem[]
  payments?: SalePayment[]
  taxes?: SaleTax[]
  discounts?: SaleDiscount[]
  installments?: SaleInstallment[]
}

export interface SaleItem {
  id: string
  product_id?: string | null
  product_variant_id?: string | null
  product_name?: string | null
  product_sku?: string | null
  quantity: number
  quantity_returnable?: number
  quantity_returned?: number
  unit_price: number
  line_subtotal?: number
  line_tax?: number
  line_total: number
  tax_rate?: number | string | null
  product?: { id: string; sku: string; name: string } | null
  product_variant?: { id: string; sku: string; name: string } | null
}

export interface SalePayment {
  id: string
  payment_method: string
  amount: number
  currency?: string
  payment_transaction?: {
    id?: string
    transaction_number?: string
    status?: string
  } | null
}

export interface SaleTax {
  id: string
  tax_name?: string | null
  tax_rate?: number | string | null
  taxable_amount?: number
  tax_amount: number
}

export interface SaleDiscount {
  id: string
  label?: string | null
  amount: number
  discount_type?: string
  source?: string
}

export interface SaleInstallment {
  id: string
  installment_number: number
  amount: number
  paid_amount: number
  outstanding_amount?: number
  due_date: string
  status: string
}

export interface SaleReturn {
  id: string
  return_number: string
  status: string
  reason: string
  refund_method?: string | null
  total: number
  created_at?: string
  sale?: { id: string; reference: string; total: number } | null
  customer?: { id: string; name: string } | null
  items?: SaleReturnItem[]
  refunds?: unknown[]
}

export interface SaleReturnItem {
  id: string
  sale_item_id: string
  quantity: number
  unit_price: number
  line_total: number
  product?: { id: string; sku: string; name: string } | null
}

export interface CustomerSummary {
  customer_id: string
  balance: number
  receivable: number
  credit: number
  credit_limit?: number | null
  available_credit?: number | null
  total_sales: number
  total_payments: number
  loyalty_points: number
  loyalty_tier?: string | null
  open_invoices: number
  overdue_invoices: number
}

export interface CustomerStatementLine {
  id: string
  occurred_at: string
  transaction_type: string
  reference: string | null
  description: string | null
  debit: number
  credit: number
  balance: number
  outstanding: number
}

export interface CustomerPayment {
  id: string
  payment_number: string
  amount: number
  payment_method: string
  reference?: string | null
  notes?: string | null
  status: string
  paid_at: string
  recorded_by?: { id: string; name: string } | null
}

export interface PurchaseOrderItem {
  id: string
  product_id: string
  product_variant_id?: string | null
  quantity: number
  quantity_ordered?: number
  quantity_received?: number
  remaining?: number
  unit_cost: number
  line_total: number
  received_quantity?: number
  product?: { id: string; sku: string; name: string } | null
}

export interface PurchaseReceipt {
  id: string
  receipt_number: string
  received_at?: string | null
  notes?: string | null
  items?: Array<{ id: string; quantity_received: number; product?: { id: string; sku: string; name: string } | null }>
  invoice?: { id: string; invoice_number: string; status: string; total: number; paid_amount: number } | null
}

export interface PurchaseOrderInvoice {
  id: string
  invoice_number: string
  status: string
  total: number
  paid_amount: number
  due_date?: string | null
  payments?: Array<{ id: string; payment_number: string; amount: number; payment_method: string; paid_at?: string | null }>
}

export interface PurchaseOrderDetail extends PurchaseOrder {
  notes?: string | null
  submitted_at?: string | null
  approved_at?: string | null
  items?: PurchaseOrderItem[]
  goods_receipts?: PurchaseReceipt[]
  invoices?: PurchaseOrderInvoice[]
  created_by_user?: { id: string; name: string } | null
  confirmed_by_user?: { id: string; name: string } | null
  approved_by_user?: { id: string; name: string } | null
}

export interface StockTransferItem {
  id: string
  product_id: string
  quantity: number
  product?: { id: string; sku: string; name: string } | null
}

export interface StockTransferDetail extends StockTransfer {
  notes?: string | null
  confirmed_at?: string | null
  items?: (StockTransferItem & { quantity_requested?: number; quantity_shipped?: number; quantity_received?: number })[]
  requested_by?: { id: string; name: string } | null
  confirmed_by?: { id: string; name: string } | null
  approved_by?: { id: string; name: string } | null
}

export interface StockAdjustmentItem {
  id: string
  product_id: string
  quantity: number
  entered_quantity?: number | null
  unit_name?: string | null
  sale_unit_id?: string | null
  product?: { id: string; sku: string; name: string } | null
}

export interface StockAdjustmentDetail extends StockAdjustment {
  movement_type?: string
  items?: StockAdjustmentItem[]
  performed_by?: { id: string; name: string } | null
  confirmed_by?: { id: string; name: string } | null
  approved_by?: { id: string; name: string } | null
}

export interface AuditLog {
  id: string
  action: string
  entity_type: string
  entity_id: string
  payload?: Record<string, unknown> | null
  ip_address?: string | null
  created_at?: string
  user?: { id: string; name: string; email?: string } | null
}

export interface AccountingEntry {
  id: string
  entry_type: string
  reference_type: string
  reference_id: string
  debit: number
  credit: number
  account_code?: string | null
  description?: string | null
  occurred_at?: string
  recorded_by_user?: { id: string; name: string } | null
}

export interface AccountingSummary {
  totals: { total_debit: number; total_credit: number; entries_count: number }
  by_account: { account_code: string | null; total_debit: number; total_credit: number; balance: number }[]
  books?: { code: string; balance: number }[]
}

export interface SalesReport {
  sales_count: number
  revenue: number
  subtotal: number
  tax_total: number
  discount_total: number
  paid_amount: number
  outstanding_amount: number
  returns_count: number
  returns_total: number
  by_day: { day: string; sales_count: number; revenue: number; tax_total: number; discount_total: number }[]
  by_week?: { label: string; sales_count: number; revenue: number }[]
  by_month?: { label: string; sales_count: number; revenue: number }[]
  by_year?: { label: string; sales_count: number; revenue: number }[]
  by_product?: { label: string; sku?: string | null; quantity: number; revenue: number }[]
  by_category?: { label: string | null; quantity: number; revenue: number }[]
  by_cashier?: { label: string | null; sales_count: number; revenue: number }[]
}

export interface InventoryReport {
  skus_in_stock: number
  total_units: number
  total_available: number
  estimated_value: number
  open_alerts: number
  top_items: {
    product_id: string
    sku?: string | null
    name?: string | null
    warehouse?: string | null
    quantity_on_hand: number
    quantity_available: number
  }[]
  low_stock_count?: number
  low_stock?: { product_id: string; sku?: string | null; name?: string | null; warehouse?: string | null; quantity_on_hand: number; threshold: number }[]
  movements?: { occurred_at?: string | null; type: string; sku?: string | null; name?: string | null; warehouse?: string | null; quantity: number; amount: number }[]
  losses?: { occurred_at?: string | null; type: string; sku?: string | null; name?: string | null; warehouse?: string | null; quantity: number; amount: number }[]
  losses_value?: number
  expiration?: { sku?: string | null; name?: string | null; warehouse?: string | null; batch?: string | null; expires_at?: string | null; quantity_on_hand: number; expired: boolean }[]
}

export interface FinancialReport {
  total_debit: number
  total_credit: number
  revenue: number
  cogs: number
  gross_margin: number
  expenses?: number
  profit?: number
  credit?: number
  debts?: number
  tax_liability: number
  by_account: { account_code: string | null; total_debit: number; total_credit: number; net: number }[]
}

export interface SerialNumber {
  id: string
  serial_number: string
  status: string
  product_id: string
  warehouse_id?: string | null
  batch_id?: string | null
  product?: { id: string; sku: string; name: string } | null
  warehouse?: { id: string; name: string; code: string } | null
  batch?: { id: string; batch_number: string } | null
}

export interface ProductBatch {
  id: string
  batch_number: string
  product_id: string
  manufactured_at?: string | null
  expires_at?: string | null
  unit_cost?: number | null
  received_at?: string | null
  quantity_on_hand?: number
  product?: { id: string; sku: string; name: string } | null
}

export interface ImportResult {
  created: number
  updated: number
  skipped: number
  errors: string[]
}
