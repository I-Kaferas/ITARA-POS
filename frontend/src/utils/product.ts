import type { Product, ProductType } from '../types'
import type { PosProduct } from '../types/pos'

const NON_STOCKABLE: ProductType[] = ['service', 'digital']

export function isStockableProduct(product: Pick<Product, 'product_type'>): boolean {
  return !NON_STOCKABLE.includes(product.product_type ?? 'simple')
}

export function isServiceProduct(product: Pick<Product, 'product_type'>): boolean {
  return !isStockableProduct(product)
}

export function needsSaleQuantity(product: { product_type?: string | null; requires_stock?: boolean | null }): boolean {
  if (product.requires_stock === false) return false
  return isStockableProduct({ product_type: (product.product_type ?? 'simple') as Product['product_type'] })
}

/** Raw on-hand quantity from catalog payload (before cart reservation). */
export function catalogOnHand(product: Pick<PosProduct, 'quantity_on_hand' | 'stock_display'>): number | null {
  let current = Number(product.quantity_on_hand)
  if (!Number.isFinite(current) && typeof product.stock_display === 'string') {
    const match = product.stock_display.match(/^(\d+(?:\.\d+)?)/)
    current = match ? Number(match[1]) : NaN
  }
  return Number.isFinite(current) ? current : null
}

/** Available stock after subtracting cart reservations. */
export function availableStock(
  product: Pick<PosProduct, 'quantity_on_hand' | 'stock_display' | 'product_type' | 'requires_stock' | 'product_id'>,
  reservedByProductId?: Record<string, number>,
): number | null {
  if (!needsSaleQuantity(product)) return null
  const onHand = catalogOnHand(product)
  if (onHand === null) return null
  const reserved = reservedByProductId?.[product.product_id] ?? 0
  return Math.max(0, onHand - reserved)
}

export function cartLineStockUnits(
  product: Pick<PosProduct, 'sale_units'>,
  quantity: number,
  saleUnitId?: string,
): number {
  const saleUnit = product.sale_units?.find(unit => unit.id === saleUnitId)
  const unit = saleUnit?.volume_ml && saleUnit.volume_ml > 0 ? saleUnit.volume_ml : 1
  return Math.max(0, quantity) * unit
}
