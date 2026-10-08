import { onBeforeUnmount, onMounted } from 'vue'
import { getStoreId } from '../api/client'
import { useRealtimeStore } from '../stores/realtime'
import type { RealtimePayload } from '../realtime/echoClient'

const TABLE_TYPES = ['table.updated', 'table.occupied', 'table.available', 'table.reserved', 'table.transferred']
const SALE_TYPES = ['sale.created', 'sale.updated', 'sale.completed', 'sale.cancelled', 'sale.refunded', 'sale.merged', 'sale.item_added', 'sale.item_removed']
const COMPLETED_SALE_TYPES = ['sale.completed', 'sale.cancelled', 'sale.refunded', 'payment.completed']
const PAYMENT_TYPES = ['payment.created', 'payment.completed']
const STOCK_TYPES = ['stock.updated', 'stock.low', 'stock.out']
const PRODUCT_TYPES = ['product.created', 'product.updated', 'product.price.changed', 'category.created', 'category.updated', 'unit.created', 'unit.updated']
const SHIFT_TYPES = ['shift.opened', 'shift.closed', 'shift.updated', 'cash.movement.created']
const EXPENSE_TYPES = ['expense.created', 'expense.updated']
const PURCHASE_TYPES = ['purchase.created', 'purchase.updated', 'purchase.status.changed', 'purchase.received']
const KITCHEN_TYPES = ['kitchen.new', 'kitchen.sent', 'kitchen.ready', 'kitchen.updated']
const ORDER_TYPES = ['order.created', 'order.updated']
const DEVICE_TYPES = ['device.connected', 'device.disconnected']
const HOTEL_TYPES = ['hotel.reservation.created', 'hotel.reservation.updated', 'hotel.room.updated', 'stay.signed']
const POS_RESERVATION_TYPES = ['pos.reservation.created', 'pos.reservation.updated']

export const realtimeTopics = {
  tables: TABLE_TYPES,
  sales: SALE_TYPES,
  payments: PAYMENT_TYPES,
  stock: STOCK_TYPES,
  products: PRODUCT_TYPES,
  devices: DEVICE_TYPES,
  dashboard: [...COMPLETED_SALE_TYPES, ...STOCK_TYPES, ...EXPENSE_TYPES, 'shift.opened', 'shift.closed', 'notification.created'],
  posFloor: [...TABLE_TYPES, ...SALE_TYPES, ...PAYMENT_TYPES],
  posOverview: [...COMPLETED_SALE_TYPES, ...SHIFT_TYPES, ...DEVICE_TYPES],
  posTerminal: [...STOCK_TYPES, ...PRODUCT_TYPES, 'sale.created', 'sale.completed', 'sale.cancelled', ...DEVICE_TYPES],
  shifts: SHIFT_TYPES,
  expenses: EXPENSE_TYPES,
  purchases: PURCHASE_TYPES,
  catalog: ['category.created', 'category.updated', 'unit.created', 'unit.updated', ...PRODUCT_TYPES],
  kitchen: KITCHEN_TYPES,
  restaurant: [...KITCHEN_TYPES, ...ORDER_TYPES],
  hotel: HOTEL_TYPES,
  posReservations: [...POS_RESERVATION_TYPES, 'table.reserved', 'table.available', 'table.occupied'],
  notifications: [
    ...STOCK_TYPES,
    ...COMPLETED_SALE_TYPES,
    'notification.created',
    'shift.opened',
    'shift.closed',
    'kitchen.new',
    'kitchen.sent',
    'kitchen.ready',
    'hotel.reservation.created',
    'sale.created',
  ],
}

type SyncPayload = RealtimePayload | { type: string; store_id?: string | null }

function concernsCurrentStore(payload: SyncPayload): boolean {
  const storeId = 'store_id' in payload ? payload.store_id : undefined
  const current = getStoreId()
  if (!storeId || !current) return true
  return storeId === current
}

export function useRealtimeSync(
  types: string[],
  refresh: (payload?: SyncPayload) => void | Promise<void>,
) {
  const realtime = useRealtimeStore()
  let timer: ReturnType<typeof setTimeout> | undefined
  let pending: SyncPayload | undefined
  let unsubscribe: (() => void) | undefined

  function run(payload: SyncPayload) {
    pending = payload
    if (timer) clearTimeout(timer)
    timer = setTimeout(() => {
      const next = pending
      pending = undefined
      void refresh(next)
    }, 250)
  }

  onMounted(() => {
    unsubscribe = realtime.subscribe((payload: SyncPayload) => {
      if (payload.type === 'resync') {
        run(payload)
        return
      }
      if (!types.includes(payload.type) || !concernsCurrentStore(payload)) return
      run(payload)
    })
  })

  onBeforeUnmount(() => {
    if (timer) clearTimeout(timer)
    unsubscribe?.()
  })
}
