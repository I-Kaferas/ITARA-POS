import { onMounted, ref, watch } from 'vue'
import { api } from '../api/client'
import { useContextStore } from '../stores/context'
import { realtimeTopics, useRealtimeSync } from './useRealtimeSync'

const count = ref(0)

export function publishQrPendingCount(next: number) {
  count.value = next
}

/** Pending QR orders, refreshed when a QR event arrives. */
export function useQrPendingCount() {
  const context = useContextStore()

  async function load() {
    const storeId = context.currentStoreId
    if (!storeId) {
      count.value = 0
      return
    }
    try {
      const res = await api.get<{ data: { pending_count: number } }>(`/stores/${storeId}/qr-orders?status=submitted`)
      count.value = res.data.pending_count
    } catch {
      /* keep the last count when a refresh fails */
    }
  }

  onMounted(() => {
    void load()
  })
  watch(() => context.currentStoreId, () => {
    void load()
  })
  useRealtimeSync(realtimeTopics.qrOrders, () => load())

  return { count }
}
