import { listTransactions } from './queue'
import { listStockMovements, putStockMovements } from './storage'
import type { LocalStockMovement, OfflineTransaction } from './types'
import { isRecord } from './policy'

const UNSETTLED = new Set(['unpaid', 'on_account', 'house', 'house_offer', 'pending', 'held'])

export function isSettledSale(payload: Record<string, unknown>): boolean {
  const payments = payload.payments
  if (!Array.isArray(payments) || payments.length === 0) return false
  let settled = 0
  for (const line of payments) {
    if (!isRecord(line)) continue
    const method = String(line.method ?? '').toLowerCase()
    if (UNSETTLED.has(method)) continue
    const amount = Number(line.amount ?? 0)
    if (Number.isFinite(amount)) settled += amount
  }
  return settled > 0
}

export function movementsForPayload(
  saleUuid: string,
  payload: Record<string, unknown>,
  createdAt: string,
): LocalStockMovement[] {
  if (!isSettledSale(payload)) return []
  const items = Array.isArray(payload.items) ? payload.items : []
  const warehouseId = typeof payload.warehouse_id === 'string' && payload.warehouse_id
    ? payload.warehouse_id
    : null
  const movements: LocalStockMovement[] = []
  items.forEach((raw, index) => {
    if (!isRecord(raw) || raw.is_accompaniment === true) return
    const productId = typeof raw.product_id === 'string' ? raw.product_id : ''
    if (!productId) return
    const stockQty = Number(raw.stock_quantity ?? raw.quantity)
    if (!Number.isFinite(stockQty) || stockQty <= 0) return
    const variantId = typeof raw.product_variant_id === 'string' && raw.product_variant_id
      ? raw.product_variant_id
      : null
    movements.push({
      id: `${saleUuid}:${productId}:${variantId ?? ''}:${index}`,
      saleUuid,
      productId,
      variantId,
      warehouseId,
      quantity: -stockQty,
      type: 'sale',
      status: 'pending',
      createdAt,
    })
  })
  return movements
}

export function movementsForQueuedSale(transaction: OfflineTransaction): LocalStockMovement[] {
  if (transaction.entityType !== 'sale' || transaction.operation !== 'create') return []
  if (transaction.status === 'synced' || transaction.status === 'discarded') return []
  return movementsForPayload(transaction.uuid, transaction.payload, transaction.createdAt)
}

export async function pendingSaleDeltas(): Promise<Map<string, number>> {
  const map = new Map<string, number>()
  for (const row of await listStockMovements()) {
    if (row.status !== 'pending' || row.type !== 'sale') continue
    map.set(row.productId, (map.get(row.productId) ?? 0) + row.quantity)
  }
  return map
}

/** Creates movements for settled offline sales that were stored before the ledger existed. */
export async function backfillQueuedSaleStock(): Promise<void> {
  const existing = new Set((await listStockMovements()).map((row) => row.saleUuid))
  const missing: LocalStockMovement[] = []
  for (const sale of await listTransactions()) {
    if (existing.has(sale.uuid)) continue
    missing.push(...movementsForQueuedSale(sale))
  }
  await putStockMovements(missing)
}

export async function setSaleStockStatus(
  saleUuid: string,
  status: LocalStockMovement['status'],
): Promise<void> {
  const rows = (await listStockMovements())
    .filter((row) => row.saleUuid === saleUuid && row.status === 'pending')
    .map((row) => ({ ...row, status }))
  await putStockMovements(rows)
}

/** Marks pending sale movements voided and returns the quantity to add back, per product. */
export async function voidSaleStock(saleUuid: string): Promise<Record<string, number>> {
  const rows = (await listStockMovements()).filter((row) => row.saleUuid === saleUuid && row.status === 'pending' && row.type === 'sale')
  const restored: Record<string, number> = {}
  for (const row of rows) {
    restored[row.productId] = (restored[row.productId] ?? 0) + (-row.quantity)
  }
  await putStockMovements(rows.map((row) => ({ ...row, status: 'voided' as const })))
  return restored
}
