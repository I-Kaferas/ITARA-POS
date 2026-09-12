import type { Product, ProductType } from '../types'

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
