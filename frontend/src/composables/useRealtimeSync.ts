import { onBeforeUnmount, onMounted } from 'vue'
import { useRealtimeStore } from '../stores/realtime'
import type { RealtimePayload } from '../realtime/echoClient'

const TABLE_TYPES = ['table.updated', 'table.occupied', 'table.available', 'table.reserved', 'table.transferred']
const SALE_TYPES = ['sale.created', 'sale.updated', 'sale.completed', 'sale.cancelled', 'sale.merged', 'sale.item_added', 'sale.item_removed']
const PAYMENT_TYPES = ['payment.created', 'payment.completed']
const STOCK_TYPES = ['stock.updated']

export const realtimeTopics = {
  tables: TABLE_TYPES,
  sales: SALE_TYPES,
  payments: PAYMENT_TYPES,
  stock: STOCK_TYPES,
  posFloor: [...TABLE_TYPES, ...SALE_TYPES, ...PAYMENT_TYPES],
  posOverview: [...SALE_TYPES, ...PAYMENT_TYPES, ...TABLE_TYPES],
  posTerminal: [...STOCK_TYPES, ...SALE_TYPES],
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
