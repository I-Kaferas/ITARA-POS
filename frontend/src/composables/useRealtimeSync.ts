import { onBeforeUnmount, onMounted } from 'vue'
import { useRealtimeStore } from '../stores/realtime'
import type { RealtimePayload } from '../realtime/echoClient'

const TABLE_TYPES = ['table.updated', 'table.occupied', 'table.available', 'table.reserved', 'table.transferred']
const SALE_TYPES = ['sale.created', 'sale.updated', 'sale.completed', 'sale.cancelled', 'sale.refunded', 'sale.merged', 'sale.item_added', 'sale.item_removed']
const PAYMENT_TYPES = ['payment.created', 'payment.completed']
const STOCK_TYPES = ['stock.updated', 'stock.low', 'stock.out']
const PRODUCT_TYPES = ['product.created', 'product.updated', 'product.price.changed', 'category.created', 'category.updated', 'unit.created', 'unit.updated']
const SHIFT_TYPES = ['shift.opened', 'shift.closed', 'shift.updated', 'cash.movement.created']
const EXPENSE_TYPES = ['expense.created', 'expense.updated']
const PURCHASE_TYPES = ['purchase.created', 'purchase.updated', 'purchase.status.changed', 'purchase.received']

export const realtimeTopics = {
  tables: TABLE_TYPES,
  sales: SALE_TYPES,
  payments: PAYMENT_TYPES,
  stock: STOCK_TYPES,
  products: PRODUCT_TYPES,
  dashboard: [...SALE_TYPES, ...PAYMENT_TYPES, ...STOCK_TYPES, ...EXPENSE_TYPES],
  posFloor: [...TABLE_TYPES, ...SALE_TYPES, ...PAYMENT_TYPES],
  posOverview: [...SALE_TYPES, ...PAYMENT_TYPES, ...TABLE_TYPES],
  posTerminal: [...STOCK_TYPES, ...PRODUCT_TYPES, ...SALE_TYPES],
  shifts: SHIFT_TYPES,
  expenses: EXPENSE_TYPES,
  purchases: PURCHASE_TYPES,
  catalog: ['category.created', 'category.updated', 'unit.created', 'unit.updated', ...PRODUCT_TYPES],
}

export function useRealtimeSync(types: string[], refresh: () => void | Promise<void>) {
  const realtime = useRealtimeStore()
  let timer: ReturnType<typeof setTimeout> | undefined
  let unsubscribe: (() => void) | undefined

  function run() {
    if (timer) clearTimeout(timer)
    timer = setTimeout(() => {
      void refresh()
    }, 250)
  }

  onMounted(() => {
    unsubscribe = realtime.subscribe((payload: RealtimePayload | { type: string }) => {
      if (payload.type === 'resync' || types.includes(payload.type)) run()
    })
  })

  onBeforeUnmount(() => {
    if (timer) clearTimeout(timer)
    unsubscribe?.()
  })
}
