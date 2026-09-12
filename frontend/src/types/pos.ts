export interface PosCategory {
  id: string
  name: string
  parent_id?: string | null
  sort_order?: number
  depth?: number
}

export interface PosBarcode {
  barcode: string
  type: string
  is_primary?: boolean
}

export interface PosProduct {
  store_product_id?: string | null
  product_id: string
  sku: string
  name: string
  price: number
  wholesale_price?: number
  category_id?: string | null
  category_name?: string | null
  barcode?: string | null
  barcodes?: PosBarcode[]
  tax_rate?: string | number
  tax_inclusive?: boolean
  is_available?: boolean
  primary_image_cdn_url?: string | null
  unit?: string | null
  product_type?: string
  requires_stock?: boolean
  quantity_on_hand?: number | null
  stock_display?: string | null
  bottle_volume_ml?: number | null
  sale_units?: PosSaleUnit[]
  variants?: PosVariant[]
  option_groups?: { name: string; values: string[] }[]
}

export interface PosVariant {
  variant_id: string
  sku: string
  name: string
  label?: string
  options?: Record<string, string>
  price: number
  size?: string | null
  color?: string | null
}

export interface PosSaleUnit {
  id: string
  name: string
  code?: string | null
  volume_ml: number
  price: number
  is_base?: boolean
  yield_per_bottle?: number
}

export interface PosCartLine {
  lineId: string
  product: PosProduct
  quantity: number
  saleUnitId?: string
  variantId?: string
  lineDiscountFixed?: number
}

export interface CartDiscountPayload {
  type: 'fixed' | 'percent'
  value: string | number
}

export interface CalculatedCartLine {
  line_id: string
  product_id?: string | null
  name?: string | null
  sku?: string | null
  unit_price: number
  quantity: number
  line_subtotal: number
  promotion_discount: number
  line_discount: number
  line_net: number
  line_tax: number
  line_total: number
  tax_rate: string
  tax_inclusive: boolean
}

export interface CartCalculation {
  currency: string
  subtotal: number
  line_discounts_total: number
  promotion_discounts_total: number
  global_discount_total: number
  discount_total: number
  tax_total: number
  fees_total: number
  grand_total: number
  lines: CalculatedCartLine[]
  fees: { label: string; code?: string; amount: number }[]
  promotions: { promotion_id: string; name: string; type: string; amount: number; line_id?: string | null }[]
}

export interface PosHeldSale {
  id: string
  label: string
  heldAt: string
  lines: PosCartLine[]
  total?: number
  customerId?: string | null
  customerName?: string | null
  note?: string | null
  globalDiscount?: CartDiscountPayload | null
  fees: { label: string; amount: number; code?: string }[]
}

export interface PosCustomerOption {
  id: string
  name: string
  email?: string | null
  phone?: string | null
}

export interface PosPaymentMethod {
  id?: string
  value: string
  code?: string
  label: string
  label_fr?: string | null
  provider?: string
  requires_customer: boolean
  supports_change: boolean
  is_enabled?: boolean
  available_on_pos?: boolean
  sort_order?: number
}

export interface PosPaymentLine {
  method: string
  amount: number
  tendered?: number
}
